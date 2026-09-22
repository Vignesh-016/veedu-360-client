-- Use the same authoritative tenancy source as lease finalization:
-- properties.tenant + properties.admin_status = RENTED.
-- Do not edit the previously applied recurring-rent migrations.
CREATE OR REPLACE FUNCTION public.create_recurring_rent_agreement(
  p_property_id UUID, p_move_in_date DATE, p_monthly_rent NUMERIC,
  p_due_day INTEGER DEFAULT 5, p_total_months INTEGER DEFAULT 12, p_notes TEXT DEFAULT NULL
) RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE
  v_property RECORD;
  v_agreement_id UUID;
  v_admin_id UUID := auth.uid();
BEGIN
  IF NOT (public.current_user_has_role('accounts-team') OR public.current_user_has_role('super-admin')) THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;
  IF p_move_in_date IS NULL OR p_monthly_rent <= 0 OR p_due_day NOT BETWEEN 1 AND 28 OR p_total_months NOT BETWEEN 1 AND 60 THEN
    RAISE EXCEPTION 'Invalid recurring rent setup';
  END IF;

  SELECT property_id, listing_type, tenant, submitter, admin_status
    INTO v_property
    FROM public.properties
   WHERE property_id = p_property_id
   FOR SHARE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Property not found';
  END IF;
  IF v_property.listing_type <> 'RENTAL' THEN
    RAISE EXCEPTION 'Property is not a rental property';
  END IF;
  IF v_property.tenant IS NULL THEN
    RAISE EXCEPTION 'Property has no active tenant assigned';
  END IF;
  IF v_property.submitter IS NULL THEN
    RAISE EXCEPTION 'Property has no owner assigned';
  END IF;
  IF v_property.admin_status <> 'RENTED' THEN
    RAISE EXCEPTION 'Property is not currently in rented status';
  END IF;

  -- The current property relationship is authoritative. If an application row
  -- exists, it must belong to the current tenant, but a stale historical or
  -- differently-labelled application status must not block a valid RENTED property.
  IF EXISTS (
    SELECT 1 FROM public.rental_applications ra
     WHERE ra.property_id = p_property_id
       AND ra.status IN ('TENANCY_ACTIVE', 'LEASE_FINALIZED')
       AND ra.user_id <> v_property.tenant
  ) THEN
    RAISE EXCEPTION 'Current property tenant does not match active rental application';
  END IF;

  INSERT INTO public.recurring_rent_agreements(
    property_id, tenant_user_id, landlord_user_id, move_in_date, key_handover_date,
    monthly_rent, due_day, auto_generate_months, generated_months,
    next_period_start, next_due_date, status, notes, created_by, created_by_admin
  ) VALUES (
    v_property.property_id, v_property.tenant, v_property.submitter,
    p_move_in_date, p_move_in_date, p_monthly_rent, p_due_day, p_total_months, 0,
    p_move_in_date,
    (p_move_in_date + INTERVAL '1 month')::date + (p_due_day - 1),
    'ACTIVE', p_notes, v_admin_id, v_admin_id
  ) RETURNING agreement_id INTO v_agreement_id;

  RETURN v_agreement_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.create_recurring_rent_agreement(UUID, DATE, NUMERIC, INTEGER, INTEGER, TEXT) TO authenticated;
