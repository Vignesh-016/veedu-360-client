import Razorpay from 'npm:razorpay@2.9.6';
import supabaseAdmin from '../_shared/supabaseAdmin.ts';
import { getRazorpayCredentials } from '../_shared/razorpayCredentials.ts';

const cors = {'Access-Control-Allow-Origin':'*','Access-Control-Allow-Headers':'authorization,apikey,content-type,x-client-info','Access-Control-Allow-Methods':'OPTIONS,POST'};
const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status, headers: {...cors, 'Content-Type':'application/json'} });

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response(null, { status: 204, headers: cors });
  if (req.method !== 'POST') return json({error:'Method not allowed'}, 405);
  try {
    const auth = req.headers.get('Authorization');
    if (!auth?.startsWith('Bearer ')) return json({error:'Unauthorized'}, 401);
    const {data:{user}} = await supabaseAdmin.auth.getUser(auth.slice(7));
    if (!user) return json({error:'Unauthorized'}, 401);
    const {rent_record_id} = await req.json();
    const {data:r} = await (supabaseAdmin as any).from('rent_records').select('*').eq('rent_record_id', rent_record_id).eq('tenant_user_id', user.id).maybeSingle();
    if (!r || ['PAID','CANCELLED'].includes(r.status)) return json({error:'Rent is not payable.'}, 400);
    const {data:o} = await (supabaseAdmin as any).from('owner_payout_accounts').select('payment_eligible,razorpay_account_id,razorpay_product_id').eq('owner_user_id', r.landlord_user_id).maybeSingle();
    if (!o?.payment_eligible || !o.razorpay_account_id || !o.razorpay_product_id) return json({error:"Online rent payment is not available yet because the owner's payout account is still being verified."}, 409);
    const {keyId,keySecret} = getRazorpayCredentials();
    if (!keyId || !keySecret) return json({error:'Payment gateway is not configured.'}, 500);
    const amount = Number(r.total_amount_paise);
    if (!Number.isSafeInteger(amount) || amount < 100) return json({error:'Invalid rent amount.'}, 400);
    const razorpay = new Razorpay({key_id:keyId,key_secret:keySecret});
    const order = await razorpay.orders.create({amount,currency:'INR',receipt:`RENT_${rent_record_id.slice(0,8)}_${Date.now()}`});
    const confirmed = await razorpay.orders.fetch(order.id);
    if (confirmed.id !== order.id || confirmed.status !== 'created' || Number(confirmed.amount) !== amount || confirmed.currency !== 'INR') throw new Error('Razorpay order validation failed.');
    const {data:a,error} = await (supabaseAdmin as any).from('rent_payment_attempts').insert({rent_record_id,tenant_user_id:user.id,razorpay_order_id:order.id,amount_paise:r.total_amount_paise}).select('payment_attempt_id').single();
    if (error) throw error;
    return json({success:true,payment_attempt_id:a.payment_attempt_id,razorpay_order_id:order.id,order_id:order.id,amount:order.amount,currency:'INR',keyId,key_id:keyId,razorpay_mode:getRazorpayCredentials().mode});
  } catch { return json({error:'Unable to start rent payment.'}, 500); }
});
