-- Restore the prior function body; the partial unique index remains unchanged.
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
   INSERT INTO public.route_transfers(rent_record_id,payment_attempt_id,razorpay_payment_id,owner_user_id,razorpay_account_id,total_amount_paise,owner_share_paise,admin_share_paise) VALUES(r.rent_record_id,a.payment_attempt_id,p_payment_id,r.landlord_user_id,p.razorpay_account_id,r.total_amount_paise,r.owner_share_paise,r.admin_share_paise) ON CONFLICT (rent_record_id) DO NOTHING;
 END IF;
END; $$;
