CREATE OR REPLACE FUNCTION public.delete_rent_record_admin(p_rent_record_id UUID)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
BEGIN
  IF NOT (public.current_user_has_role('super-admin') OR public.current_user_has_role('accounts-team')) THEN
    RAISE EXCEPTION 'Unauthorized: Insufficient privileges.';
  END IF;
  -- Child rows must be removed explicitly because rent_payment_attempts has no cascade.
  DELETE FROM public.route_transfers WHERE rent_record_id=p_rent_record_id;
  DELETE FROM public.rent_payments WHERE rent_record_id=p_rent_record_id;
  DELETE FROM public.rent_payment_attempts WHERE rent_record_id=p_rent_record_id;
  DELETE FROM public.rent_records WHERE rent_record_id=p_rent_record_id;
  IF NOT FOUND THEN RAISE WARNING 'Rent Record ID % not found.', p_rent_record_id; END IF;
END; $$;
GRANT EXECUTE ON FUNCTION public.delete_rent_record_admin(UUID) TO authenticated;
