CREATE TABLE IF NOT EXISTS public.route_transfers (
  transfer_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  rent_record_id UUID NOT NULL UNIQUE REFERENCES public.rent_records(rent_record_id),
  payment_attempt_id UUID REFERENCES public.rent_payment_attempts(payment_attempt_id),
  razorpay_payment_id TEXT NOT NULL,
  owner_user_id UUID NOT NULL,
  razorpay_account_id TEXT NOT NULL,
  razorpay_transfer_id TEXT UNIQUE,
  total_amount_paise BIGINT NOT NULL CHECK (total_amount_paise > 0),
  owner_share_paise BIGINT NOT NULL CHECK (owner_share_paise >= 0),
  admin_share_paise BIGINT NOT NULL CHECK (admin_share_paise >= 0),
  status TEXT NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING','PROCESSING','PROCESSED','FAILED')),
  failure_reason TEXT,
  attempt_count INTEGER NOT NULL DEFAULT 0 CHECK (attempt_count >= 0),
  last_attempted_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT route_transfers_split_invariant CHECK (owner_share_paise + admin_share_paise = total_amount_paise)
);

CREATE OR REPLACE FUNCTION public.claim_rent_route_transfer(p_rent_record_id UUID)
RETURNS SETOF public.route_transfers
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE r public.rent_records%ROWTYPE; a public.rent_payment_attempts%ROWTYPE; p public.owner_payout_accounts%ROWTYPE; t public.route_transfers%ROWTYPE;
BEGIN
  SELECT * INTO r FROM public.rent_records WHERE rent_record_id=p_rent_record_id FOR UPDATE;
  IF NOT FOUND OR r.status <> 'PAID' THEN RAISE EXCEPTION 'Rent is not paid.'; END IF;
  IF r.total_amount_paise IS NULL OR r.owner_share_paise IS NULL OR r.admin_share_paise IS NULL OR r.total_amount_paise <= 0 OR r.owner_share_paise < 0 OR r.admin_share_paise < 0 OR r.owner_share_paise + r.admin_share_paise <> r.total_amount_paise THEN RAISE EXCEPTION 'Invalid rent split snapshot.'; END IF;
  SELECT * INTO a FROM public.rent_payment_attempts WHERE rent_record_id=p_rent_record_id AND status='PAID' AND razorpay_payment_id IS NOT NULL ORDER BY updated_at DESC LIMIT 1;
  IF NOT FOUND THEN RAISE EXCEPTION 'Successful rent payment not found.'; END IF;
  SELECT * INTO p FROM public.owner_payout_accounts WHERE owner_user_id=r.landlord_user_id;
  IF NOT FOUND OR COALESCE(p.payment_eligible,FALSE) IS NOT TRUE OR p.razorpay_account_id IS NULL THEN RAISE EXCEPTION 'Owner payout account is not transfer eligible.'; END IF;
  SELECT * INTO t FROM public.route_transfers WHERE rent_record_id=p_rent_record_id FOR UPDATE;
  IF FOUND THEN
    IF t.status='PROCESSED' OR t.status='PROCESSING' THEN RETURN NEXT t; RETURN; END IF;
    UPDATE public.route_transfers SET status='PROCESSING', attempt_count=attempt_count+1, last_attempted_at=NOW(), failure_reason=NULL, updated_at=NOW() WHERE transfer_id=t.transfer_id RETURNING * INTO t;
  ELSE
    INSERT INTO public.route_transfers(rent_record_id,payment_attempt_id,razorpay_payment_id,owner_user_id,razorpay_account_id,total_amount_paise,owner_share_paise,admin_share_paise,status,attempt_count,last_attempted_at)
    VALUES (p_rent_record_id,a.payment_attempt_id,a.razorpay_payment_id,r.landlord_user_id,p.razorpay_account_id,r.total_amount_paise,r.owner_share_paise,r.admin_share_paise,'PROCESSING',1,NOW()) RETURNING * INTO t;
  END IF;
  RETURN NEXT t;
END; $$;
REVOKE ALL ON FUNCTION public.claim_rent_route_transfer(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.claim_rent_route_transfer(UUID) TO authenticated;

-- Queue eligibility is evaluated after payment completion; payout failure never affects payment state.
CREATE OR REPLACE FUNCTION public.complete_rent_payment(p_order_id TEXT,p_payment_id TEXT) RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE a public.rent_payment_attempts%ROWTYPE; r public.rent_records%ROWTYPE; v_actor UUID:=auth.uid(); p public.owner_payout_accounts%ROWTYPE;
BEGIN
 SELECT * INTO a FROM public.rent_payment_attempts WHERE razorpay_order_id=p_order_id FOR UPDATE;
 IF NOT FOUND OR (v_actor IS NOT NULL AND a.tenant_user_id<>v_actor) THEN RAISE EXCEPTION 'Payment attempt not found.'; END IF;
 SELECT * INTO r FROM public.rent_records WHERE rent_record_id=a.rent_record_id FOR UPDATE;
 IF a.status='PAID' THEN RETURN; END IF;
 IF r.status='CANCELLED' THEN RAISE EXCEPTION 'Rent is cancelled.'; END IF;
 UPDATE public.rent_payment_attempts SET status='PAID',razorpay_payment_id=COALESCE(razorpay_payment_id,p_payment_id),failure_reason=NULL,updated_at=NOW() WHERE payment_attempt_id=a.payment_attempt_id;
 UPDATE public.rent_records SET status='PAID',amount_paid=(a.amount_paise::numeric/100),updated_at=NOW() WHERE rent_record_id=r.rent_record_id;
 INSERT INTO public.rent_payments(rent_record_id,paid_by_user_id,amount,payment_date,payment_method,transaction_ref,notes) VALUES(r.rent_record_id,a.tenant_user_id,(a.amount_paise::numeric/100),NOW(),'RAZORPAY',p_payment_id,'Online rent payment') ON CONFLICT (transaction_ref) DO NOTHING;
 SELECT * INTO p FROM public.owner_payout_accounts WHERE owner_user_id=r.landlord_user_id;
 IF COALESCE(p.payment_eligible,FALSE) AND p.razorpay_account_id IS NOT NULL THEN
   INSERT INTO public.route_transfers(rent_record_id,payment_attempt_id,razorpay_payment_id,owner_user_id,razorpay_account_id,total_amount_paise,owner_share_paise,admin_share_paise)
   VALUES(r.rent_record_id,a.payment_attempt_id,p_payment_id,r.landlord_user_id,p.razorpay_account_id,r.total_amount_paise,r.owner_share_paise,r.admin_share_paise) ON CONFLICT (rent_record_id) DO NOTHING;
 END IF;
END; $$;
