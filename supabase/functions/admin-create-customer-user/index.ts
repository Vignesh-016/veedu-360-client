/// <reference path="../global.d.ts" />
import supabaseAdmin from '../_shared/supabaseAdmin.ts';

const cors = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization,apikey,content-type,x-client-info', 'Access-Control-Allow-Methods': 'OPTIONS,POST' };
const respond = (body: Record<string, unknown>, status = 200) => new Response(JSON.stringify(body), { status, headers: { ...cors, 'Content-Type': 'application/json' } });
const normalizePhone = (value: string) => {
  const digits = value.replace(/\D/g, '');
  const local = digits.startsWith('91') && digits.length === 12 ? digits.slice(2) : digits.startsWith('0') && digits.length === 11 ? digits.slice(1) : digits;
  if (!/^[6-9]\d{9}$/.test(local)) throw new Error('Please enter a valid mobile number.');
  return `+91${local}`;
};
const safeError = (error: any) => ({ code: error?.code || error?.status || 'UNKNOWN', message: error?.message || 'Unknown error' });

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response(null, { status: 204, headers: cors });
  if (req.method !== 'POST') return respond({ success: false, code: 'METHOD_NOT_ALLOWED', message: 'Method not allowed.' }, 405);
  const header = req.headers.get('Authorization');
  if (!header?.startsWith('Bearer ')) return respond({ success: false, code: 'UNAUTHORIZED', message: 'Authentication required.' }, 401);
  const { data: { user } } = await supabaseAdmin.auth.getUser(header.slice(7));
  if (!user) return respond({ success: false, code: 'UNAUTHORIZED', message: 'Authentication required.' }, 401);
  const { data: admin } = await (supabaseAdmin as any).from('admins').select('is_active,roles').eq('user_id', user.id).maybeSingle();
  if (!admin?.is_active || !Array.isArray(admin.roles) || admin.roles.length === 0) {
    console.warn('Admin customer create forbidden', { admin_user_id: user.id });
    return respond({ success: false, code: 'ADMIN_FORBIDDEN', message: 'You are not authorised to create customer accounts.' }, 403);
  }
  try {
    const body = await req.json().catch(() => null);
    if (!body || typeof body !== 'object') return respond({ success: false, code: 'INVALID_REQUEST', message: 'Please provide customer details.' }, 400);
    const fullName = String(body?.full_name ?? '').trim();
    const email = String(body?.email ?? '').trim().toLowerCase();
    if (!fullName || fullName.length > 200) return respond({ success: false, code: 'INVALID_NAME', message: 'Please enter a valid full name.' }, 400);
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) || email.length > 320) return respond({ success: false, code: 'INVALID_EMAIL', message: 'Please enter a valid email address.' }, 400);
    let phone: string;
    try { phone = normalizePhone(String(body?.phone ?? '')); } catch { return respond({ success: false, code: 'INVALID_PHONE', message: 'Please enter a valid mobile number.' }, 400); }
    console.log('Admin customer create input accepted', { admin_user_id: user.id, email, phone_last4: phone.slice(-4), step: 'duplicate_check' });
    let page = 1;
    let match: any = null;
    while (!match) {
      const { data, error } = await supabaseAdmin.auth.admin.listUsers({ page, perPage: 1000 });
      if (error) { console.error('Admin customer duplicate check failed', { admin_user_id: user.id, step: 'duplicate_check', ...safeError(error) }); return respond({ success: false, code: 'DUPLICATE_CHECK_FAILED', message: 'Unable to check existing customer accounts.' }, 500); }
      match = data.users.find((candidate: any) => {
        const candidateDigits = String(candidate.phone || '').replace(/\D/g, '');
        const candidateLocal = candidateDigits.startsWith('91') && candidateDigits.length === 12 ? candidateDigits.slice(2) : candidateDigits.startsWith('0') && candidateDigits.length === 11 ? candidateDigits.slice(1) : candidateDigits;
        return candidate.email?.trim().toLowerCase() === email || candidateLocal === phone.slice(3);
      });
      if (match || data.users.length < 1000) break;
      page += 1;
    }
    if (match) {
      const { data: existingAdmin } = await (supabaseAdmin as any).from('admins').select('user_id').eq('user_id', match.id).maybeSingle();
      if (existingAdmin) return respond({ success: false, code: 'ADMIN_ACCOUNT_CONFLICT', message: 'This email belongs to an administrator and cannot be used as a property owner.' }, 409);
      console.log('Admin customer already exists', { admin_user_id: user.id, customer_user_id: match.id, step: 'duplicate_check' });
      return respond({ success: true, existing: true, user: { user_id: match.id, full_name: match.user_metadata?.full_name || match.user_metadata?.name || fullName, email: match.email || email, phone: match.phone || phone }, message: 'Existing customer found and selected.' });
    }
    const { data: created, error } = await supabaseAdmin.auth.admin.createUser({ email, phone, email_confirm: true, phone_confirm: true, user_metadata: { full_name: fullName, phone } });
    if (error || !created.user) {
      console.error('Admin customer Auth creation failed', { admin_user_id: user.id, email, phone_last4: phone.slice(-4), step: 'auth_create', ...safeError(error) });
      const duplicate = /already|exists|registered|phone/i.test(error?.message || '');
      return respond({ success: false, code: duplicate ? 'CUSTOMER_ALREADY_EXISTS' : 'AUTH_USER_CREATE_FAILED', message: duplicate ? 'A customer with this email or mobile number already exists.' : 'Unable to create the customer account.' }, duplicate ? 409 : 500);
    }
    console.log('Admin customer Auth user created', { admin_user_id: user.id, customer_user_id: created.user.id, step: 'customer_trigger_check' });
    let customerExists = false;
    for (let attempt = 0; attempt < 5; attempt += 1) {
      const { data: customer } = await (supabaseAdmin as any).from('customers').select('user_id').eq('user_id', created.user.id).maybeSingle();
      if (customer) { customerExists = true; break; }
      await new Promise((resolve) => setTimeout(resolve, 150 * (attempt + 1)));
    }
    if (!customerExists) { console.error('Customer trigger did not create profile', { admin_user_id: user.id, customer_user_id: created.user.id, step: 'customer_trigger_check' }); return respond({ success: false, code: 'CUSTOMER_PROFILE_NOT_CREATED', message: 'Customer account was created, but the customer profile could not be completed.' }, 500); }
    console.log('Admin customer create completed', { admin_user_id: user.id, customer_user_id: created.user.id, existing: false });
    return respond({ success: true, existing: false, user: { user_id: created.user.id, full_name: fullName, email, phone }, message: 'Customer created.' });
  } catch (error) {
    console.error('Admin customer create unexpected failure', { admin_user_id: user.id, step: 'unexpected', ...safeError(error) });
    return respond({ success: false, code: 'INTERNAL_ERROR', message: 'Unable to create the customer account.' }, 500);
  }
});
