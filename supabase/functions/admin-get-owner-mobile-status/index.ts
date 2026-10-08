import supabaseAdmin from '../_shared/supabaseAdmin.ts';
import { admin, json } from '../_shared/adminOwnerOtp.ts';

Deno.serve(async req => {
  if (req.method === 'OPTIONS') return json({}, 204);
  if (req.method !== 'POST') return json({ success: false, code: 'METHOD_NOT_ALLOWED', message: 'Method not allowed.' }, 405);
  const caller = await admin(req, supabaseAdmin);
  if (!caller) return json({ message: 'You are not authorised to view customer mobile status.' }, 403);
  try {
    const { owner_user_id } = await req.json();
    const { data } = await supabaseAdmin.from('customers').select('mobile_verified,mobile_verified_at,mobile_verification_required,created_by_admin').eq('user_id', owner_user_id).maybeSingle();
    const { data: user } = await supabaseAdmin.auth.admin.getUserById(owner_user_id);
    const phone = user?.user?.phone || user?.user?.user_metadata?.phone || '';
    const requiresOtp = Boolean(data?.mobile_verification_required || data?.created_by_admin);
    return json({ success: true, mobile_verified: requiresOtp ? Boolean(data?.mobile_verified) : true, mobile_verified_at: requiresOtp ? (data?.mobile_verified_at || null) : null, phone });
  } catch { return json({ message: 'Unable to load mobile status.' }, 500); }
});
