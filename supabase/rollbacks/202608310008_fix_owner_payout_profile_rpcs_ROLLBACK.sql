-- Restore the preceding six-parameter profile RPC; data and tables are preserved.
DROP FUNCTION IF EXISTS public.save_my_owner_profile(TEXT,TEXT,TEXT,TEXT,TEXT,TEXT,BOOLEAN);
CREATE FUNCTION public.save_my_owner_profile(p_address_line1 TEXT,p_address_line2 TEXT,p_city TEXT,p_state TEXT,p_pincode TEXT,p_pan_number TEXT)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE v_user UUID:=auth.uid(); v_pan TEXT:=NULLIF(upper(btrim(COALESCE(p_pan_number,''))), ''); v_old_pan TEXT;
BEGIN IF v_user IS NULL THEN RAISE EXCEPTION 'Authentication required.'; END IF; SELECT pan_number INTO v_old_pan FROM public.owner_profiles WHERE owner_user_id=v_user; v_pan:=COALESCE(v_pan,v_old_pan); IF btrim(COALESCE(p_address_line1,''))='' OR btrim(COALESCE(p_city,''))='' OR btrim(COALESCE(p_state,''))='' OR btrim(COALESCE(p_pincode,'')) !~ '^[0-9]{6}$' OR v_pan IS NULL OR v_pan !~ '^[A-Z]{5}[0-9]{4}[A-Z]$' THEN RAISE EXCEPTION 'Invalid owner profile.'; END IF; INSERT INTO public.owner_profiles(owner_user_id,address_line1,address_line2,city,state,pincode,pan_number) VALUES(v_user,btrim(p_address_line1),NULLIF(btrim(COALESCE(p_address_line2,'')),''),btrim(p_city),btrim(p_state),btrim(p_pincode),v_pan) ON CONFLICT(owner_user_id) DO UPDATE SET address_line1=EXCLUDED.address_line1,address_line2=EXCLUDED.address_line2,city=EXCLUDED.city,state=EXCLUDED.state,pincode=EXCLUDED.pincode,pan_number=EXCLUDED.pan_number,updated_at=NOW(); END; $$;
GRANT EXECUTE ON FUNCTION public.save_my_owner_profile(TEXT,TEXT,TEXT,TEXT,TEXT,TEXT) TO authenticated;
NOTIFY pgrst, 'reload schema';
