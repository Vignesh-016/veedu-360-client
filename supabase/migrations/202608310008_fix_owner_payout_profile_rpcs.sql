-- Fix RPC signatures for the deployed frontend; preserve all existing data.
DROP FUNCTION IF EXISTS public.save_my_owner_profile(TEXT,TEXT,TEXT,TEXT,TEXT,TEXT);
DROP FUNCTION IF EXISTS public.save_my_owner_profile(TEXT,TEXT,TEXT,TEXT,TEXT,TEXT,BOOLEAN);

CREATE FUNCTION public.save_my_owner_profile(p_address_line1 TEXT,p_address_line2 TEXT,p_city TEXT,p_state TEXT,p_pincode TEXT,p_pan_number TEXT,p_route_consent BOOLEAN)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE v_user UUID:=auth.uid(); v_pan TEXT:=NULLIF(upper(btrim(COALESCE(p_pan_number,''))), ''); v_old_pan TEXT;
BEGIN
 IF v_user IS NULL THEN RAISE EXCEPTION 'Authentication required.'; END IF;
 SELECT pan_number INTO v_old_pan FROM public.owner_profiles WHERE owner_user_id=v_user;
 v_pan:=COALESCE(v_pan,v_old_pan);
 IF btrim(COALESCE(p_address_line1,''))='' OR btrim(COALESCE(p_city,''))='' OR btrim(COALESCE(p_state,''))='' OR btrim(COALESCE(p_pincode,'')) !~ '^[0-9]{6}$' THEN RAISE EXCEPTION 'Invalid address.'; END IF;
 IF v_pan IS NULL OR v_pan !~ '^[A-Z]{5}[0-9]{4}[A-Z]$' THEN RAISE EXCEPTION 'PAN must use the valid 10-character format.'; END IF;
 INSERT INTO public.owner_profiles(owner_user_id,address_line1,address_line2,city,state,pincode,pan_number) VALUES(v_user,btrim(p_address_line1),NULLIF(btrim(COALESCE(p_address_line2,'')),''),btrim(p_city),btrim(p_state),btrim(p_pincode),v_pan) ON CONFLICT(owner_user_id) DO UPDATE SET address_line1=EXCLUDED.address_line1,address_line2=EXCLUDED.address_line2,city=EXCLUDED.city,state=EXCLUDED.state,pincode=EXCLUDED.pincode,pan_number=EXCLUDED.pan_number,updated_at=NOW();
 IF COALESCE(p_route_consent,FALSE) THEN UPDATE public.owner_payout_accounts SET route_consent_accepted=TRUE,route_consent_at=COALESCE(route_consent_at,NOW()),route_consent_version='v1',updated_at=NOW() WHERE owner_user_id=v_user; END IF;
END; $$;

CREATE OR REPLACE FUNCTION public.save_my_owner_payout_account(p_account_holder_name TEXT,p_account_number TEXT,p_ifsc_code TEXT)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE v_user UUID:=auth.uid(); v_holder TEXT:=btrim(p_account_holder_name); v_account TEXT:=btrim(p_account_number); v_ifsc TEXT:=upper(btrim(p_ifsc_code)); v_old_account TEXT;
BEGIN
 IF v_user IS NULL THEN RAISE EXCEPTION 'Authentication required.'; END IF;
 IF v_holder IS NULL OR char_length(v_holder) NOT BETWEEN 2 AND 200 OR v_account !~ '^[0-9]{6,35}$' OR v_ifsc !~ '^[A-Z]{4}0[A-Z0-9]{6}$' THEN RAISE EXCEPTION 'Invalid payout bank details.'; END IF;
 SELECT account_number INTO v_old_account FROM public.owner_payout_accounts WHERE owner_user_id=v_user;
 INSERT INTO public.owner_payout_accounts(owner_user_id,account_holder_name,account_number,ifsc_code,status,created_at,updated_at) VALUES(v_user,v_holder,v_account,v_ifsc,'PENDING_VERIFICATION',NOW(),NOW())
 ON CONFLICT(owner_user_id) DO UPDATE SET account_holder_name=EXCLUDED.account_holder_name,account_number=EXCLUDED.account_number,ifsc_code=EXCLUDED.ifsc_code,status='PENDING_VERIFICATION',payment_eligible=CASE WHEN v_old_account IS DISTINCT FROM v_account THEN FALSE ELSE public.owner_payout_accounts.payment_eligible END,updated_at=NOW();
END; $$;
REVOKE ALL ON FUNCTION public.save_my_owner_profile(TEXT,TEXT,TEXT,TEXT,TEXT,TEXT,BOOLEAN) FROM PUBLIC,anon; GRANT EXECUTE ON FUNCTION public.save_my_owner_profile(TEXT,TEXT,TEXT,TEXT,TEXT,TEXT,BOOLEAN) TO authenticated;
REVOKE ALL ON FUNCTION public.save_my_owner_payout_account(TEXT,TEXT,TEXT) FROM PUBLIC,anon; GRANT EXECUTE ON FUNCTION public.save_my_owner_payout_account(TEXT,TEXT,TEXT) TO authenticated;
NOTIFY pgrst, 'reload schema';
