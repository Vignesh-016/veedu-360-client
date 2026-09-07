ALTER TABLE public.owner_profiles ADD COLUMN pan_number TEXT;
ALTER TABLE public.owner_profiles ADD CONSTRAINT owner_profiles_pan_check CHECK (pan_number IS NULL OR pan_number ~ '^[A-Z]{5}[0-9]{4}[A-Z]$');

DROP FUNCTION IF EXISTS public.get_my_owner_profile();
CREATE FUNCTION public.get_my_owner_profile()
RETURNS TABLE (address_line1 TEXT, address_line2 TEXT, city TEXT, state TEXT, pincode TEXT, pan_masked TEXT, updated_at TIMESTAMPTZ)
LANGUAGE sql SECURITY DEFINER STABLE SET search_path = public
AS $$ SELECT op.address_line1, op.address_line2, op.city, op.state, op.pincode,
  CASE WHEN op.pan_number IS NULL THEN NULL ELSE left(op.pan_number, 5) || '****' || right(op.pan_number, 1) END,
  op.updated_at FROM public.owner_profiles op WHERE op.owner_user_id = auth.uid(); $$;

DROP FUNCTION IF EXISTS public.save_my_owner_profile(TEXT,TEXT,TEXT,TEXT,TEXT);
CREATE FUNCTION public.save_my_owner_profile(
    p_address_line1 TEXT, p_address_line2 TEXT, p_city TEXT, p_state TEXT, p_pincode TEXT, p_pan_number TEXT
) RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_user_id UUID := auth.uid(); v_line1 TEXT := btrim(p_address_line1); v_line2 TEXT := NULLIF(btrim(COALESCE(p_address_line2, '')), ''); v_city TEXT := btrim(p_city); v_state TEXT := btrim(p_state); v_pincode TEXT := btrim(p_pincode); v_pan TEXT := NULLIF(upper(btrim(COALESCE(p_pan_number, ''))), ''); v_existing_pan TEXT;
BEGIN
    IF v_user_id IS NULL THEN RAISE EXCEPTION 'Authentication required.'; END IF;
    IF v_line1 = '' THEN RAISE EXCEPTION 'Address line 1 is required.'; END IF;
    IF v_city = '' THEN RAISE EXCEPTION 'City is required.'; END IF;
    IF v_state = '' THEN RAISE EXCEPTION 'State is required.'; END IF;
    IF v_pincode !~ '^[0-9]{6}$' THEN RAISE EXCEPTION 'PIN code must contain exactly 6 digits.'; END IF;
    SELECT pan_number INTO v_existing_pan FROM public.owner_profiles WHERE owner_user_id = v_user_id;
    IF v_pan IS NULL THEN v_pan := v_existing_pan; END IF;
    IF v_pan IS NULL OR v_pan !~ '^[A-Z]{5}[0-9]{4}[A-Z]$' THEN RAISE EXCEPTION 'PAN must use the valid 10-character format.'; END IF;
    INSERT INTO public.owner_profiles(owner_user_id,address_line1,address_line2,city,state,pincode,pan_number) VALUES (v_user_id,v_line1,v_line2,v_city,v_state,v_pincode,v_pan)
    ON CONFLICT (owner_user_id) DO UPDATE SET address_line1=EXCLUDED.address_line1,address_line2=EXCLUDED.address_line2,city=EXCLUDED.city,state=EXCLUDED.state,pincode=EXCLUDED.pincode,pan_number=EXCLUDED.pan_number,updated_at=NOW();
END; $$;
REVOKE ALL ON FUNCTION public.get_my_owner_profile() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.save_my_owner_profile(TEXT,TEXT,TEXT,TEXT,TEXT,TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_my_owner_profile() TO authenticated;
GRANT EXECUTE ON FUNCTION public.save_my_owner_profile(TEXT,TEXT,TEXT,TEXT,TEXT,TEXT) TO authenticated;
