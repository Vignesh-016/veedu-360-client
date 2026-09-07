import Razorpay from 'npm:razorpay@2.9.6';
import crypto from 'node:crypto';
import supabaseAdmin from '../_shared/supabaseAdmin.ts';
import { getRazorpayCredentials } from '../_shared/razorpayCredentials.ts';

const cors={'Access-Control-Allow-Origin':'*','Access-Control-Allow-Headers':'authorization,apikey,content-type,x-client-info','Access-Control-Allow-Methods':'OPTIONS,POST'};
const json=(body:unknown,status=200)=>new Response(JSON.stringify(body),{status,headers:{...cors,'Content-Type':'application/json'}});
const dbError=(error:any)=>({db_code:error?.code??null,db_message:error?.message??null,db_details:error?.details??null,db_hint:error?.hint??null});

Deno.serve(async req=>{
  if(req.method==='OPTIONS') return new Response(null,{status:204,headers:cors});
  if(req.method!=='POST') return json({error:'Method not allowed'},405);
  let step='auth';
  try {
    const auth=req.headers.get('Authorization');
    if(!auth?.startsWith('Bearer ')) return json({success:false,step,error:'Unauthorized'},401);
    const {data:{user}}=await supabaseAdmin.auth.getUser(auth.slice(7));
    if(!user) return json({success:false,step,error:'Unauthorized'},401);
    step='request_validation';
    const body=await req.json();
    const {razorpay_order_id,razorpay_payment_id,razorpay_signature}=body;
    if(!razorpay_order_id||!razorpay_payment_id||!razorpay_signature) return json({success:false,step,error:'Missing Razorpay payment response.'},400);
    step='attempt_lookup';
    const {data:attempt,error:attemptError}=await (supabaseAdmin as any).from('rent_payment_attempts').select('*,rent_records(*)').eq('razorpay_order_id',razorpay_order_id).maybeSingle();
    if(attemptError) return json({success:false,step,error:'Payment attempt lookup failed.',...dbError(attemptError)},500);
    if(!attempt||attempt.tenant_user_id!==user.id) return json({success:false,step,error:'Payment attempt not found.'},403);
    const {keyId,keySecret}=getRazorpayCredentials();
    if(!keyId||!keySecret) return json({success:false,step,error:'Payment gateway is not configured.'},500);
    step='signature_verification';
    const expected=crypto.createHmac('sha256',keySecret).update(`${razorpay_order_id}|${razorpay_payment_id}`).digest('hex');
    if(expected!==razorpay_signature) return json({success:false,step,error:'Invalid payment signature.'},400);
    step='razorpay_payment_fetch';
    const rp=new Razorpay({key_id:keyId,key_secret:keySecret});
    const payment:any=await rp.payments.fetch(razorpay_payment_id);
    if(payment.order_id!==razorpay_order_id) return json({success:false,step:'order_validation',error:'Razorpay order does not match the payment attempt.'},400);
    if(payment.currency!=='INR'||Number(payment.amount)!==Number(attempt.amount_paise)||payment.status!=='captured') return json({success:false,step:'amount_validation',error:'Razorpay payment did not match the rent amount or captured state.',razorpay_status:payment.status},400);
    step='complete_rent_payment';
    const {error:completeError}=await supabaseAdmin.rpc('complete_rent_payment',{p_order_id:razorpay_order_id,p_payment_id:razorpay_payment_id});
    if(completeError) {
      const {data:current}=await (supabaseAdmin as any).from('rent_payment_attempts').select('status').eq('payment_attempt_id',attempt.payment_attempt_id).maybeSingle();
      if(current?.status!=='PAID') return json({success:false,step,error:'Rent payment completion failed.',...dbError(completeError)},500);
      return json({success:true,already_processed:true});
    }
    step='route_transfer_trigger';
    let transfer_status='PENDING';
    try { const transferResponse=await fetch(`${Deno.env.get('SUPABASE_URL')}/functions/v1/process-rent-route-transfer`,{method:'POST',headers:{Authorization:`Bearer ${Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')}`,'Content-Type':'application/json'},body:JSON.stringify({rent_record_id:attempt.rent_record_id})}); transfer_status=transferResponse.ok?'SUCCESS':'FAILED'; } catch { transfer_status='FAILED'; }
    return json({success:true,payment_status:'PAID',transfer_status});
  } catch(error:any) {
    return json({success:false,step,error:error?.message||'Payment verification failed.'},500);
  }
});
