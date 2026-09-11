-- Expose the exact seven-argument PostgREST contract used by the admin Edge Function.
CREATE OR REPLACE FUNCTION public.create_rent_record_admin(
  p_property_id UUID,
  p_due_date DATE,
  p_period_start_date DATE,
  p_period_end_date DATE,
  p_amount_due DECIMAL,
  p_owner_payout_override DECIMAL DEFAULT NULL,
  p_override_reason TEXT DEFAULT NULL
) RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE v_id UUID;
BEGIN
  SELECT public.create_rent_record_admin(p_property_id,p_due_date,p_period_start_date,p_period_end_date,p_amount_due,NULL,p_owner_payout_override,p_override_reason) INTO v_id;
  RETURN v_id;
END; $$;
GRANT EXECUTE ON FUNCTION public.create_rent_record_admin(UUID,DATE,DATE,DATE,DECIMAL,DECIMAL,TEXT) TO authenticated;
NOTIFY pgrst, 'reload schema';
