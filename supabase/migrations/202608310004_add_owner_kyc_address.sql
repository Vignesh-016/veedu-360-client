-- Stage 4A: one residential/KYC address per owner. No Razorpay calls.
CREATE TABLE public.owner_profiles (
    owner_user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE RESTRICT,
    address_line1 TEXT NOT NULL,
    address_line2 TEXT,
    city TEXT NOT NULL,
    state TEXT NOT NULL,
    pincode TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT owner_profiles_address_line1_check CHECK (btrim(address_line1) <> ''),
    CONSTRAINT owner_profiles_city_check CHECK (btrim(city) <> ''),
    CONSTRAINT owner_profiles_state_check CHECK (btrim(state) <> ''),
    CONSTRAINT owner_profiles_pincode_check CHECK (pincode ~ '^[0-9]{6}$')
);

CREATE TRIGGER owner_profiles_set_updated_at
BEFORE UPDATE ON public.owner_profiles
FOR EACH ROW EXECUTE FUNCTION public.set_current_timestamp_updated_at();

ALTER TABLE public.owner_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.owner_profiles FORCE ROW LEVEL SECURITY;
CREATE POLICY owner_profiles_select_own ON public.owner_profiles FOR SELECT TO authenticated USING (owner_user_id = auth.uid());
CREATE POLICY owner_profiles_insert_own ON public.owner_profiles FOR INSERT TO authenticated WITH CHECK (owner_user_id = auth.uid());
CREATE POLICY owner_profiles_update_own ON public.owner_profiles FOR UPDATE TO authenticated USING (owner_user_id = auth.uid()) WITH CHECK (owner_user_id = auth.uid());
REVOKE ALL ON TABLE public.owner_profiles FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.get_my_owner_profile()
RETURNS TABLE (address_line1 TEXT, address_line2 TEXT, city TEXT, state TEXT, pincode TEXT, updated_at TIMESTAMPTZ)
LANGUAGE sql SECURITY DEFINER STABLE SET search_path = public
AS $$ SELECT op.address_line1, op.address_line2, op.city, op.state, op.pincode, op.updated_at FROM public.owner_profiles op WHERE op.owner_user_id = auth.uid(); $$;

CREATE OR REPLACE FUNCTION public.save_my_owner_profile(
    p_address_line1 TEXT, p_address_line2 TEXT, p_city TEXT, p_state TEXT, p_pincode TEXT
) RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_user_id UUID := auth.uid(); v_line1 TEXT := btrim(p_address_line1); v_line2 TEXT := NULLIF(btrim(COALESCE(p_address_line2, '')), ''); v_city TEXT := btrim(p_city); v_state TEXT := btrim(p_state); v_pincode TEXT := btrim(p_pincode);
BEGIN
    IF v_user_id IS NULL THEN RAISE EXCEPTION 'Authentication required.'; END IF;
    IF v_line1 = '' THEN RAISE EXCEPTION 'Address line 1 is required.'; END IF;
    IF v_city = '' THEN RAISE EXCEPTION 'City is required.'; END IF;
    IF v_state = '' THEN RAISE EXCEPTION 'State is required.'; END IF;
    IF v_pincode !~ '^[0-9]{6}$' THEN RAISE EXCEPTION 'PIN code must contain exactly 6 digits.'; END IF;
    INSERT INTO public.owner_profiles(owner_user_id,address_line1,address_line2,city,state,pincode) VALUES (v_user_id,v_line1,v_line2,v_city,v_state,v_pincode)
    ON CONFLICT (owner_user_id) DO UPDATE SET address_line1=EXCLUDED.address_line1,address_line2=EXCLUDED.address_line2,city=EXCLUDED.city,state=EXCLUDED.state,pincode=EXCLUDED.pincode,updated_at=NOW();
END; $$;

REVOKE ALL ON FUNCTION public.get_my_owner_profile() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.save_my_owner_profile(TEXT,TEXT,TEXT,TEXT,TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_my_owner_profile() TO authenticated;
GRANT EXECUTE ON FUNCTION public.save_my_owner_profile(TEXT,TEXT,TEXT,TEXT,TEXT) TO authenticated;
