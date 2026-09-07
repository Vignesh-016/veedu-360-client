ALTER TABLE public.owner_payout_accounts
  ADD COLUMN razorpay_account_id TEXT UNIQUE,
  ADD COLUMN razorpay_account_status TEXT,
  ADD COLUMN razorpay_stakeholder_id TEXT,
  ADD COLUMN razorpay_product_id TEXT,
  ADD COLUMN razorpay_product_status TEXT,
  ADD COLUMN payment_eligible BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN route_onboarding_error TEXT,
  ADD COLUMN linked_account_created_at TIMESTAMPTZ,
  ADD COLUMN last_status_checked_at TIMESTAMPTZ,
  ADD COLUMN route_consent_accepted BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN route_consent_at TIMESTAMPTZ,
  ADD COLUMN route_consent_version TEXT;

CREATE OR REPLACE FUNCTION public.save_my_owner_profile(
 p_address_line1 TEXT,p_address_line2 TEXT,p_city TEXT,p_state TEXT,p_pincode TEXT,p_pan_number TEXT,p_route_consent BOOLEAN DEFAULT FALSE
) RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE v_user UUID:=auth.uid(); v_pan TEXT:=NULLIF(upper(btrim(COALESCE(p_pan_number,''))), ''); v_consent BOOLEAN:=COALESCE(p_route_consent,FALSE); v_old_consent BOOLEAN;
BEGIN
 IF v_user IS NULL THEN RAISE EXCEPTION 'Authentication required.'; END IF;
 IF btrim(p_address_line1)='' OR btrim(p_city)='' OR btrim(p_state)='' OR btrim(p_pincode) !~ '^[0-9]{6}$' THEN RAISE EXCEPTION 'Invalid address.'; END IF;
 IF v_pan IS NULL OR v_pan !~ '^[A-Z]{5}[0-9]{4}[A-Z]$' THEN RAISE EXCEPTION 'PAN must use the valid 10-character format.'; END IF;
 SELECT route_consent_accepted INTO v_old_consent FROM public.owner_payout_accounts WHERE owner_user_id=v_user;
 INSERT INTO public.owner_profiles(owner_user_id,address_line1,address_line2,city,state,pincode,pan_number) VALUES(v_user,btrim(p_address_line1),NULLIF(btrim(COALESCE(p_address_line2,'')),''),btrim(p_city),btrim(p_state),btrim(p_pincode),v_pan)
 ON CONFLICT(owner_user_id) DO UPDATE SET address_line1=EXCLUDED.address_line1,address_line2=EXCLUDED.address_line2,city=EXCLUDED.city,state=EXCLUDED.state,pincode=EXCLUDED.pincode,pan_number=EXCLUDED.pan_number,updated_at=NOW();
 IF v_consent THEN UPDATE public.owner_payout_accounts SET route_consent_accepted=TRUE,route_consent_at=COALESCE(route_consent_at,NOW()),route_consent_version='v1',updated_at=NOW() WHERE owner_user_id=v_user; END IF;
END; $$;
DROP FUNCTION IF EXISTS public.save_my_owner_payout_account(TEXT,TEXT,TEXT);

CREATE OR REPLACE FUNCTION public.associate_owner_razorpay_account(p_owner_user_id UUID,p_razorpay_account_id TEXT)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE v_roles public.admin_role_enum[]; v_existing UUID;
BEGIN
 SELECT roles INTO v_roles FROM public.admins WHERE user_id=auth.uid();
 IF NOT (v_roles @> ARRAY['super-admin'::public.admin_role_enum]) THEN RAISE EXCEPTION 'Admin access required.'; END IF;
 IF p_razorpay_account_id !~ '^acc_[A-Za-z0-9]+$' THEN RAISE EXCEPTION 'Invalid Razorpay account ID.'; END IF;
 SELECT owner_user_id INTO v_existing FROM public.owner_payout_accounts WHERE razorpay_account_id=p_razorpay_account_id;
 IF v_existing IS NOT NULL AND v_existing<>p_owner_user_id THEN RAISE EXCEPTION 'Razorpay account is already associated with another owner.'; END IF;
 UPDATE public.owner_payout_accounts SET razorpay_account_id=p_razorpay_account_id,razorpay_account_status='ASSOCIATION_PENDING',payment_eligible=FALSE,updated_at=NOW() WHERE owner_user_id=p_owner_user_id;
 IF NOT FOUND THEN RAISE EXCEPTION 'Owner payout account not found.'; END IF;
END; $$;
GRANT EXECUTE ON FUNCTION public.associate_owner_razorpay_account(UUID,TEXT) TO authenticated;
CREATE OR REPLACE FUNCTION public.save_my_route_consent(p_accepted BOOLEAN)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$ BEGIN IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Authentication required.'; END IF; UPDATE public.owner_payout_accounts SET route_consent_accepted=COALESCE(p_accepted,FALSE),route_consent_at=CASE WHEN COALESCE(p_accepted,FALSE) THEN NOW() ELSE NULL END,route_consent_version=CASE WHEN COALESCE(p_accepted,FALSE) THEN 'v1' ELSE NULL END,updated_at=NOW() WHERE owner_user_id=auth.uid(); END; $$;
REVOKE ALL ON FUNCTION public.save_my_route_consent(BOOLEAN) FROM PUBLIC,anon; GRANT EXECUTE ON FUNCTION public.save_my_route_consent(BOOLEAN) TO authenticated;
