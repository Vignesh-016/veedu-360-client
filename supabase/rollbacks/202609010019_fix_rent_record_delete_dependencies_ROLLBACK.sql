CREATE OR REPLACE FUNCTION public.delete_rent_record_admin(p_rent_record_id UUID)
RETURNS VOID AS $$
BEGIN
  IF NOT (public.current_user_has_role('super-admin') OR public.current_user_has_role('accounts-team')) THEN RAISE EXCEPTION 'Unauthorized: Insufficient privileges.'; END IF;
  DELETE FROM public.rent_records WHERE rent_record_id=p_rent_record_id;
END; $$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.delete_rent_record_admin(UUID) TO authenticated;
