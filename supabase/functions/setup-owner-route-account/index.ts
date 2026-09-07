/// <reference path="../global.d.ts" />
import supabaseAdmin from '../_shared/supabaseAdmin.ts';
import { getRazorpayCredentials } from '../_shared/razorpayCredentials.ts';

const corsHeaders={'Access-Control-Allow-Origin':'*','Access-Control-Allow-Headers':'authorization,apikey,content-type,x-client-info','Access-Control-Allow-Methods':'OPTIONS,POST'};
const out=(body:Record<string,unknown>,status=200)=>new Response(JSON.stringify(body),{status,headers:{...corsHeaders,'Content-Type':'application/json'}});
const normalizeIndianMobile=(raw:string)=>{const digits=raw.replace(/\D/g,''); if(digits.length===12&&digits.startsWith('91'))return digits.slice(2); if(digits.length===11&&digits.startsWith('0'))return digits.slice(1); if(digits.length===10)return digits; throw new Error('Owner phone number is invalid for Razorpay stakeholder verification.');};
Deno.serve(async(req)=>{
  if(req.method==='OPTIONS') { console.log('OPTIONS request handled'); return new Response(null,{status:204,headers:corsHeaders}); }
  if(req.method!=='POST') return out({error:'Method not allowed'},405);
  const auth=req.headers.get('Authorization'); if(!auth?.startsWith('Bearer ')) return out({error:'Unauthorized'},401);
  const {data:{user},error}=await supabaseAdmin.auth.getUser(auth.slice(7)); if(error||!user) return out({error:'Unauthorized'},401);
  const body=await req.json().catch(()=>({})); const target=body.owner_user_id||user.id; const refreshOnly=body.refresh_only===true;
  const {data:admin}=await (supabaseAdmin as any).from('admins').select('roles').eq('user_id',user.id).maybeSingle();
  const isAdmin=Array.isArray(admin?.roles)&&admin.roles.includes('super-admin'); if(target!==user.id&&!isAdmin) return out({error:'Forbidden'},403);
  const {data:profile}=await (supabaseAdmin as any).from('owner_profiles').select('address_line1,address_line2,city,state,pincode,pan_number').eq('owner_user_id',target).maybeSingle();
  const {data:payout}=await (supabaseAdmin as any).from('owner_payout_accounts').select('*').eq('owner_user_id',target).maybeSingle();
  console.log('POST onboarding started');
  if(!profile||!payout) return out({error:'Owner profile or payout account is incomplete.'},400);
  console.log('Owner profile loaded'); console.log('Payout account loaded');
  if(!payout.route_consent_accepted) return out({error:'Route consent is required.'},400);
  if(!profile.address_line1||!profile.city||!profile.state||!profile.pincode) return out({error:'Owner address is incomplete.'},400);
  if(!profile.pan_number) return out({error:'Owner PAN is missing.'},400);
  if(!payout.account_number||!payout.ifsc_code) return out({error:'Owner bank details are incomplete.'},400);
  const {keyId,keySecret}=getRazorpayCredentials(); if(!keyId||!keySecret) return out({error:'Razorpay is not configured.'},500);
  const headers={Authorization:`Basic ${btoa(`${keyId}:${keySecret}`)}`,'Content-Type':'application/json'};
  const call=async(url:string,method='GET',payload?:unknown,step='razorpay_request')=>{const r=await fetch(`https://api.razorpay.com${url}`,{method,headers,body:payload?JSON.stringify(payload):undefined}); const d=await r.json().catch(()=>({})); console.log(`${method} ${url} HTTP status:`,r.status); if(!r.ok){const e=d?.error||{}; const err=new Error(`Razorpay request failed (${r.status}): ${e.description||e.reason||e.code||'Request rejected'}`); (err as any).step=step; (err as any).upstreamStatus=r.status; (err as any).safeCode=e.code; throw err;} if(url.includes('/products/')) console.log('Product activation_status:',d?.activation_status||'missing','active_configuration:',!!d?.active_configuration,'requested_configuration:',!!d?.requested_configuration); return d;};
  try {
    const targetUser=(await supabaseAdmin.auth.admin.getUserById(target)).data.user; if(!targetUser) return out({error:'Owner user not found.'},400);
    const phoneDigits=String(targetUser.phone||'').replace(/\D/g,'');
    if(phoneDigits.length<10) return out({error:'Owner phone is missing or invalid.'},400);
    const stakeholderPhone=normalizeIndianMobile(String(targetUser.phone||''));
    let accountId=payout.razorpay_account_id;
    let account:any;
    if(accountId) account=await call(`/v2/accounts/${accountId}`);
    else {
      const fullName=targetUser.user_metadata?.full_name||targetUser.user_metadata?.name;
      const category=Deno.env.get('RAZORPAY_ROUTE_CATEGORY'); const subcategory=Deno.env.get('RAZORPAY_ROUTE_SUBCATEGORY'); const businessType=Deno.env.get('RAZORPAY_ROUTE_BUSINESS_TYPE');
      if(!fullName) return out({error:'Owner full name is missing.'},400);
      if(!category||!subcategory||!businessType) return out({error:'Route business configuration is pending.'},400);
      console.log('Creating Razorpay linked account');
      console.log('Razorpay business_type:', businessType, 'legal_info included: false');
      account=await call('/v2/accounts','POST',{email:targetUser.email,phone:phoneDigits,type:'route',legal_business_name:fullName,customer_facing_business_name:fullName,business_type:businessType,contact_name:fullName,profile:{category,subcategory,addresses:{registered:{street1:profile.address_line1,street2:profile.address_line2||undefined,city:profile.city,state:profile.state,postal_code:profile.pincode,country:'IN'}}}},'linked_account_creation');
      if(!account?.id) throw new Error('Razorpay linked account response did not include an account ID.');
      accountId=account.id;
      const {error:saveError}=await (supabaseAdmin as any).from('owner_payout_accounts').update({razorpay_account_id:accountId,razorpay_account_status:account.status||'created',linked_account_created_at:new Date().toISOString(),payment_eligible:false,updated_at:new Date().toISOString()}).eq('owner_user_id',target);
      if(saveError) throw new Error('Linked account was created but could not be saved locally.');
      console.log('Razorpay linked account created'); console.log('razorpay_account_id persisted');
    }
    let stakeholderId=payout.razorpay_stakeholder_id;
    if(!stakeholderId){console.log('Creating stakeholder; phone length:',stakeholderPhone.length); const s=await call(`/v2/accounts/${accountId}/stakeholders`,'POST',{name:targetUser.user_metadata?.full_name||targetUser.user_metadata?.name,email:targetUser.email,phone:{primary:stakeholderPhone},percentage_ownership:100,relationship:{director:false,executive:false},addresses:{residential:{street:[profile.address_line1,profile.address_line2].filter(Boolean).join(', '),city:profile.city,state:profile.state,postal_code:profile.pincode,country:'IN'}},kyc:{pan:profile.pan_number}},'stakeholder_creation'); if(!s?.id) throw new Error('Razorpay stakeholder response did not include an ID.'); stakeholderId=s.id; console.log('Stakeholder created'); await (supabaseAdmin as any).from('owner_payout_accounts').update({razorpay_stakeholder_id:stakeholderId,razorpay_account_status:account.status,updated_at:new Date().toISOString()}).eq('owner_user_id',target); }
    let productId=payout.razorpay_product_id; let product:any;
    console.log('Product request started');
    if(productId) product=await call(`/v2/accounts/${accountId}/products/${productId}`); else {product=await call(`/v2/accounts/${accountId}/products`,'POST',{product_name:'route',tnc_accepted:true}); productId=product.id;}
    if(productId && !refreshOnly && (!payout.razorpay_product_id || payout.status === 'PENDING_VERIFICATION')) { console.log('Bank config started'); product=await call(`/v2/accounts/${accountId}/products/${productId}`,'PATCH',{settlements:{account_number:payout.account_number,ifsc_code:payout.ifsc_code,beneficiary_name:payout.account_holder_name},tnc_accepted:true},'bank_configuration'); console.log('Bank configuration submitted'); }
    console.log('Fetching Route status');
    const status=String(product.activation_status||product.status||'requested').toLowerCase(); const eligible= status==='activated'&&!!accountId&&!!stakeholderId&&!!productId;
    const mapped=status==='activated'?'Verified':status==='needs_clarification'?'Action Required':status==='verification_failed'?'Verification Failed':status==='suspended'?'Suspended':'Verification In Progress';
    const reason=eligible?null:status==='needs_clarification'?'Bank details changed and require Razorpay re-verification.':status==='verification_failed'?'Razorpay could not verify the submitted bank details.':status==='suspended'?'Payout account is suspended.':'Razorpay is verifying the payout details.';
    await (supabaseAdmin as any).from('owner_payout_accounts').update({razorpay_account_status:account.status,razorpay_stakeholder_id:stakeholderId,razorpay_product_id:productId,razorpay_product_status:status,payment_eligible:eligible,route_onboarding_error:null,last_status_checked_at:new Date().toISOString(),updated_at:new Date().toISOString()}).eq('owner_user_id',target);
    return out({status:mapped,reason,payment_eligible:eligible});
  } catch(e){const safe=e instanceof Error?e.message:'Onboarding failed'; const step=(e as any)?.step||'onboarding'; const status=(e as any)?.upstreamStatus||502; console.error('Route onboarding failed:',safe); await (supabaseAdmin as any).from('owner_payout_accounts').update({route_onboarding_error:safe,payment_eligible:false,updated_at:new Date().toISOString()}).eq('owner_user_id',target); return out({success:false,step,error:safe,upstream_status:status},status>=400&&status<600?status:502);}
});
