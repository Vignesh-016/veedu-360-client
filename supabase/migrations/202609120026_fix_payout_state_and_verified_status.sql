-- Normalize payout state values before Route onboarding and never expose a
-- verified state unless payment_eligible is explicitly true.
CREATE OR REPLACE FUNCTION public.save_my_owner_payout_account(p_account_holder_name TEXT,p_account_number TEXT,p_ifsc_code TEXT,p_route_consent BOOLEAN)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE v_user UUID:=auth.uid(); v_holder TEXT:=btrim(p_account_holder_name); v_account TEXT:=btrim(p_account_number); v_ifsc TEXT:=upper(btrim(p_ifsc_code)); v_old public.owner_payout_accounts%ROWTYPE; v_changed BOOLEAN;
BEGIN
 IF v_user IS NULL THEN RAISE EXCEPTION 'Authentication required.'; END IF;
 IF p_route_consent IS NOT TRUE THEN RAISE EXCEPTION 'Please accept the Razorpay payout terms before verifying your bank account.'; END IF;
 IF v_holder IS NULL OR char_length(v_holder) NOT BETWEEN 2 AND 200 OR v_account !~ '^[0-9]{6,35}$' OR v_ifsc !~ '^[A-Z]{4}0[A-Z0-9]{6}$' THEN RAISE EXCEPTION 'Invalid payout bank details.'; END IF;
 SELECT * INTO v_old FROM public.owner_payout_accounts WHERE owner_user_id=v_user;
 v_changed := NOT FOUND OR v_old.account_holder_name IS DISTINCT FROM v_holder OR v_old.account_number IS DISTINCT FROM v_account OR v_old.ifsc_code IS DISTINCT FROM v_ifsc;
 INSERT INTO public.owner_payout_accounts(owner_user_id,account_holder_name,account_number,ifsc_code,status,route_consent_accepted,route_consent_at,route_consent_version,created_at,updated_at)
 VALUES(v_user,v_holder,v_account,v_ifsc,'PENDING_VERIFICATION',TRUE,NOW(),'v1',NOW(),NOW())
 ON CONFLICT(owner_user_id) DO UPDATE SET account_holder_name=EXCLUDED.account_holder_name,account_number=EXCLUDED.account_number,ifsc_code=EXCLUDED.ifsc_code,status=CASE WHEN v_changed THEN 'PENDING_VERIFICATION' ELSE public.owner_payout_accounts.status END,route_consent_accepted=TRUE,route_consent_at=COALESCE(public.owner_payout_accounts.route_consent_at,NOW()),route_consent_version='v1',payment_eligible=CASE WHEN v_changed THEN FALSE ELSE public.owner_payout_accounts.payment_eligible END,updated_at=NOW();
END; $$;
GRANT EXECUTE ON FUNCTION public.save_my_owner_payout_account(TEXT,TEXT,TEXT,BOOLEAN) TO authenticated;
DROP FUNCTION IF EXISTS public.get_my_owner_payout_account();
CREATE FUNCTION public.get_my_owner_payout_account()
RETURNS TABLE(account_holder_name TEXT,masked_account_number TEXT,ifsc_code TEXT,status TEXT,route_consent_accepted BOOLEAN,payment_eligible BOOLEAN,razorpay_account_status TEXT,razorpay_product_status TEXT,route_onboarding_error TEXT,updated_at TIMESTAMPTZ)
LANGUAGE plpgsql SECURITY DEFINER STABLE SET search_path=public AS $$ BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Authentication required.'; END IF;
 RETURN QUERY SELECT o.account_holder_name,repeat('X',greatest(char_length(o.account_number)-4,0))||right(o.account_number,4),o.ifsc_code,CASE WHEN o.payment_eligible IS TRUE THEN 'VERIFIED' ELSE COALESCE(o.status,'PENDING_VERIFICATION') END,o.route_consent_accepted,COALESCE(o.payment_eligible,FALSE),o.razorpay_account_status,o.razorpay_product_status,o.route_onboarding_error,o.updated_at FROM public.owner_payout_accounts o WHERE o.owner_user_id=auth.uid();
END; $$;
GRANT EXECUTE ON FUNCTION public.get_my_owner_payout_account() TO authenticated;
NOTIFY pgrst,'reload schema';
