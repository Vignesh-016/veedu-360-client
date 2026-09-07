CREATE OR REPLACE FUNCTION public.save_my_owner_payout_account(p_account_holder_name TEXT,p_account_number TEXT,p_ifsc_code TEXT,p_route_consent BOOLEAN)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE v_user UUID:=auth.uid(); v_holder TEXT:=btrim(p_account_holder_name); v_account TEXT:=btrim(p_account_number); v_ifsc TEXT:=upper(btrim(p_ifsc_code)); v_old public.owner_payout_accounts%ROWTYPE; v_changed BOOLEAN;
BEGIN
 IF v_user IS NULL THEN RAISE EXCEPTION 'Authentication required.'; END IF;
 IF p_route_consent IS NOT TRUE THEN RAISE EXCEPTION 'Please accept the Razorpay payout terms before verifying your bank account.'; END IF;
 IF v_holder IS NULL OR char_length(v_holder) NOT BETWEEN 2 AND 200 OR v_account !~ '^[0-9]{6,35}$' OR v_ifsc !~ '^[A-Z]{4}0[A-Z0-9]{6}$' THEN RAISE EXCEPTION 'Invalid payout bank details.'; END IF;
 SELECT * INTO v_old FROM public.owner_payout_accounts WHERE owner_user_id=v_user;
 v_changed := NOT FOUND OR v_old.account_holder_name IS DISTINCT FROM v_holder OR v_old.account_number IS DISTINCT FROM v_account OR v_old.ifsc_code IS DISTINCT FROM v_ifsc;
 INSERT INTO public.owner_payout_accounts(owner_user_id,account_holder_name,account_number,ifsc_code,status,route_consent_accepted,route_consent_at,route_consent_version,created_at,updated_at) VALUES(v_user,v_holder,v_account,v_ifsc,CASE WHEN v_changed THEN 'PENDING_VERIFICATION' ELSE COALESCE(v_old.status,'PENDING_VERIFICATION') END,TRUE,NOW(),'v1',NOW(),NOW())
 ON CONFLICT(owner_user_id) DO UPDATE SET account_holder_name=EXCLUDED.account_holder_name,account_number=EXCLUDED.account_number,ifsc_code=EXCLUDED.ifsc_code,status=CASE WHEN v_changed THEN 'PENDING_VERIFICATION' ELSE public.owner_payout_accounts.status END,route_consent_accepted=TRUE,route_consent_at=COALESCE(public.owner_payout_accounts.route_consent_at,NOW()),route_consent_version='v1',payment_eligible=CASE WHEN v_changed THEN FALSE ELSE public.owner_payout_accounts.payment_eligible END,updated_at=NOW();
END; $$;
REVOKE ALL ON FUNCTION public.save_my_owner_payout_account(TEXT,TEXT,TEXT,BOOLEAN) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.save_my_owner_payout_account(TEXT,TEXT,TEXT,BOOLEAN) TO authenticated;
NOTIFY pgrst,'reload schema';
