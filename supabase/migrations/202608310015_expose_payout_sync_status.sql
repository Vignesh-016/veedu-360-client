DROP FUNCTION IF EXISTS public.get_my_owner_payout_account();

CREATE FUNCTION public.get_my_owner_payout_account()
RETURNS TABLE (account_holder_name TEXT,masked_account_number TEXT,ifsc_code TEXT,status TEXT,route_consent_accepted BOOLEAN,payment_eligible BOOLEAN,razorpay_account_status TEXT,razorpay_product_status TEXT,route_onboarding_error TEXT,updated_at TIMESTAMPTZ)
LANGUAGE plpgsql SECURITY DEFINER STABLE SET search_path=public AS $$
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Authentication required.'; END IF;
 RETURN QUERY SELECT opa.account_holder_name,repeat('X',greatest(char_length(opa.account_number)-4,0))||right(opa.account_number,4),opa.ifsc_code,CASE WHEN opa.payment_eligible THEN 'VERIFIED' ELSE opa.status END,opa.route_consent_accepted,opa.payment_eligible,opa.razorpay_account_status,opa.razorpay_product_status,opa.route_onboarding_error,opa.updated_at FROM public.owner_payout_accounts opa WHERE opa.owner_user_id=auth.uid();
END; $$;
REVOKE ALL ON FUNCTION public.get_my_owner_payout_account() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.get_my_owner_payout_account() TO authenticated;
NOTIFY pgrst,'reload schema';
