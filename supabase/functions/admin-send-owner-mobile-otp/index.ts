import supabaseAdmin from '../_shared/supabaseAdmin.ts';
import { admin, hashOtp, json, normalizeOwnerPhone } from '../_shared/adminOwnerOtp.ts';

Deno.serve(async req => {
  if (req.method === 'OPTIONS') return json({}, 204);
  if (req.method !== 'POST') return json({ success: false, code: 'METHOD_NOT_ALLOWED', message: 'Method not allowed.' }, 405);
  let stage = 'admin_auth';
  let challengeId: string | null = null;
  let ownerId = '';
  try {
    const caller = await admin(req, supabaseAdmin);
    if (!caller) return json({ success: false, code: 'ADMIN_FORBIDDEN', message: 'You are not authorised to verify customer mobile numbers.' }, 403);
    console.log('[admin-send-owner-mobile-otp] stage=admin-auth-ok');
    stage = 'request';
    const body = await req.json().catch(() => null);
    ownerId = String(body?.owner_user_id || '');
    if (!ownerId) return json({ success: false, code: 'OWNER_NOT_FOUND', message: 'The selected customer could not be found.' }, 404);
    stage = 'owner_lookup';
    const { data: owner, error: ownerError } = await supabaseAdmin.auth.admin.getUserById(ownerId);
    if (ownerError || !owner?.user) return json({ success: false, code: 'OWNER_NOT_FOUND', message: 'The selected customer could not be found.' }, 404);
    console.log('[admin-send-owner-mobile-otp] stage=owner-loaded');
    stage = 'phone';
    const rawPhone = owner.user.phone || owner.user.user_metadata?.phone || '';
    if (!rawPhone) return json({ success: false, code: 'PHONE_MISSING', message: 'This customer does not have a mobile number.' }, 400);
    let phone: string;
    try { phone = normalizeOwnerPhone(rawPhone); } catch { return json({ success: false, code: 'PHONE_INVALID', message: 'This customer does not have a valid mobile number.' }, 400); }
    stage = 'rate_limit';
    const { count, error: rateError } = await supabaseAdmin.from('otp_sent_log').select('*', { count: 'exact', head: true }).eq('phone_number', phone).gte('sent_at', new Date(Date.now() - 60_000).toISOString());
    if (rateError) throw rateError;
    if ((count || 0) >= 1) return json({ success: false, code: 'RATE_LIMITED', message: 'Please wait before requesting another verification code.' }, 429);
    stage = 'challenge';
    const otp = String(crypto.getRandomValues(new Uint32Array(1))[0] % 1_000_000).padStart(6, '0');
    const otpHash = await hashOtp(ownerId, phone, otp);
    const { error: invalidateError } = await supabaseAdmin.from('admin_owner_mobile_otp_challenges').update({ used_at: new Date().toISOString() }).eq('owner_user_id', ownerId).is('used_at', null);
    if (invalidateError) { console.error('[admin-send-owner-mobile-otp]', { stage: 'invalidate_previous', code: invalidateError.code, message: invalidateError.message, details: invalidateError.details, hint: invalidateError.hint }); throw invalidateError; }
    const { data: challenge, error: challengeError } = await supabaseAdmin.from('admin_owner_mobile_otp_challenges').insert({ owner_user_id: ownerId, phone_normalized: phone, otp_hash: otpHash, expires_at: new Date(Date.now() + 300_000).toISOString(), created_by_admin: caller.id }).select('id').single();
    if (challengeError || !challenge) { if (challengeError) console.error('[admin-send-owner-mobile-otp]', { stage: 'insert_new_challenge', code: challengeError.code, message: challengeError.message, details: challengeError.details, hint: challengeError.hint }); throw challengeError || new Error('Challenge was not created.'); }
    challengeId = challenge.id;
    console.log('[admin-send-owner-mobile-otp] stage=challenge-created');
    stage = 'sms';
    const key = Deno.env.get('FASTSMS_API_KEY');
    if (!key) return json({ success: false, code: 'SMS_PROVIDER_FAILED', message: 'Unable to send the verification code right now. Please try again.' }, 502);
    console.log('[admin-send-owner-mobile-otp] stage=sms-send-start');
    const params = new URLSearchParams({ authorization: key, route: 'dlt', sender_id: Deno.env.get('FASTSMS_SENDER_ID') || 'VDU360', message: Deno.env.get('FASTSMS_DLT_MESSAGE_ID') || '194505', variables_values: `${otp}|`, flash: '1', numbers: phone });
    const sms = await fetch(`https://www.fast2sms.com/dev/bulkV2?${params}`, { method: 'GET' });
    if (!sms.ok) { await supabaseAdmin.from('admin_owner_mobile_otp_challenges').update({ used_at: new Date().toISOString() }).eq('id', challengeId); console.error('[admin-send-owner-mobile-otp] provider failure', { stage, status: sms.status }); return json({ success: false, code: 'SMS_PROVIDER_FAILED', message: 'Unable to send the verification code right now. Please try again.' }, 502); }
    const providerBody = await sms.json().catch(() => ({}));
    if (providerBody.return === false) { await supabaseAdmin.from('admin_owner_mobile_otp_challenges').update({ used_at: new Date().toISOString() }).eq('id', challengeId); return json({ success: false, code: 'SMS_PROVIDER_FAILED', message: 'Unable to send the verification code right now. Please try again.' }, 502); }
    await supabaseAdmin.from('otp_sent_log').insert({ phone_number: phone });
    console.log('[admin-send-owner-mobile-otp] stage=sms-send-success');
    return json({ success: true, message: 'Verification code sent successfully.' });
  } catch (error: any) {
    if (challengeId) await supabaseAdmin.from('admin_owner_mobile_otp_challenges').update({ used_at: new Date().toISOString() }).eq('id', challengeId);
    console.error('[admin-send-owner-mobile-otp]', { stage, code: error?.code, status: error?.status, message: error?.message || 'unknown', owner_user_id: ownerId || undefined });
    const code = stage === 'challenge' ? 'OTP_CHALLENGE_FAILED' : stage === 'sms' ? 'SMS_PROVIDER_FAILED' : 'INTERNAL_ERROR';
    const status = stage === 'sms' ? 502 : 500;
    return json({ success: false, code, message: stage === 'challenge' ? 'Unable to prepare mobile verification.' : stage === 'sms' ? 'Unable to send the verification code right now. Please try again.' : 'Unable to send verification code.' }, status);
  }
});
