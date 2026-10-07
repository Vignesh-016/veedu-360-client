import supabaseAdmin from '../_shared/supabaseAdmin.ts';
import { admin, json } from '../_shared/adminOwnerOtp.ts';

Deno.serve(async req => {
  if (req.method === 'OPTIONS') return json({}, 204);
  if (req.method !== 'POST') return json({ success: false, code: 'METHOD_NOT_ALLOWED', message: 'Method not allowed.' }, 405);
  const caller = await admin(req, supabaseAdmin);
  if (!caller) return json({ message: 'You are not authorised to view customer mobile status.' }, 403);
  try {
    const { owner_user_id } = await req.json();
    const { data } = await supabaseAdmin.from('customers').select('mobile_verified,mobile_verified_at').eq('user_id', owner_user_id).maybeSingle();
    const { data: user } = await supabaseAdmin.auth.admin.getUserById(owner_user_id);
    const phone = user?.user?.phone || user?.user?.user_metadata?.phone || '';
    return json({ success: true, mobile_verified: Boolean(data?.mobile_verified), mobile_verified_at: data?.mobile_verified_at || null, phone });
  } catch { return json({ message: 'Unable to load mobile status.' }, 500); }
});
