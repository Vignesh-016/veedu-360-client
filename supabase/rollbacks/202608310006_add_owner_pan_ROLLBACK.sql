REVOKE ALL ON FUNCTION public.get_my_owner_profile() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.save_my_owner_profile(TEXT,TEXT,TEXT,TEXT,TEXT,TEXT) FROM PUBLIC, anon, authenticated;
DROP FUNCTION IF EXISTS public.get_my_owner_profile();
DROP FUNCTION IF EXISTS public.save_my_owner_profile(TEXT,TEXT,TEXT,TEXT,TEXT,TEXT);
CREATE FUNCTION public.get_my_owner_profile()
RETURNS TABLE (address_line1 TEXT, address_line2 TEXT, city TEXT, state TEXT, pincode TEXT, updated_at TIMESTAMPTZ)
LANGUAGE sql SECURITY DEFINER STABLE SET search_path = public
AS $$ SELECT op.address_line1, op.address_line2, op.city, op.state, op.pincode, op.updated_at FROM public.owner_profiles op WHERE op.owner_user_id = auth.uid(); $$;
CREATE FUNCTION public.save_my_owner_profile(p_address_line1 TEXT,p_address_line2 TEXT,p_city TEXT,p_state TEXT,p_pincode TEXT)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_user_id UUID := auth.uid(); v_line1 TEXT := btrim(p_address_line1); v_line2 TEXT := NULLIF(btrim(COALESCE(p_address_line2,'')), ''); v_city TEXT := btrim(p_city); v_state TEXT := btrim(p_state); v_pincode TEXT := btrim(p_pincode);
BEGIN IF v_user_id IS NULL THEN RAISE EXCEPTION 'Authentication required.'; END IF; IF v_line1='' OR v_city='' OR v_state='' THEN RAISE EXCEPTION 'Required address field is missing.'; END IF; IF v_pincode !~ '^[0-9]{6}$' THEN RAISE EXCEPTION 'PIN code must contain exactly 6 digits.'; END IF; INSERT INTO public.owner_profiles(owner_user_id,address_line1,address_line2,city,state,pincode) VALUES(v_user_id,v_line1,v_line2,v_city,v_state,v_pincode) ON CONFLICT(owner_user_id) DO UPDATE SET address_line1=EXCLUDED.address_line1,address_line2=EXCLUDED.address_line2,city=EXCLUDED.city,state=EXCLUDED.state,pincode=EXCLUDED.pincode,updated_at=NOW(); END; $$;
GRANT EXECUTE ON FUNCTION public.get_my_owner_profile() TO authenticated;
GRANT EXECUTE ON FUNCTION public.save_my_owner_profile(TEXT,TEXT,TEXT,TEXT,TEXT) TO authenticated;
ALTER TABLE public.owner_profiles DROP CONSTRAINT IF EXISTS owner_profiles_pan_check;
ALTER TABLE public.owner_profiles DROP COLUMN IF EXISTS pan_number;
