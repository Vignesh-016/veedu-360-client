DROP FUNCTION IF EXISTS public.create_rent_record_admin(UUID,DATE,DATE,DATE,DECIMAL,TEXT);
DROP FUNCTION IF EXISTS public.create_rent_record_admin(UUID,DATE,DATE,DATE,DECIMAL,DECIMAL,TEXT);

CREATE OR REPLACE FUNCTION public.create_rent_record_admin(
 p_property_id UUID,p_due_date DATE,p_period_start_date DATE,p_period_end_date DATE,
 p_amount_due DECIMAL,p_notes TEXT DEFAULT NULL,p_owner_payout_override DECIMAL DEFAULT NULL,p_override_reason TEXT DEFAULT NULL
) RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE v_id UUID; v RECORD; total BIGINT; admin_share BIGINT; owner_share BIGINT; override_paise BIGINT; is_server BOOLEAN:=current_setting('request.jwt.claim.role',true)='service_role';
BEGIN
 IF NOT is_server AND NOT(public.current_user_has_role('accounts-team') OR public.current_user_has_role('super-admin')) THEN RAISE EXCEPTION 'Unauthorized: Insufficient privileges.'; END IF;
 SELECT p.tenant,p.submitter,p.listing_type,p.management_plan_id,msp.percentage commission_percentage INTO v FROM properties p LEFT JOIN management_service_plans msp ON msp.plan_id=p.management_plan_id WHERE p.property_id=p_property_id;
 IF NOT FOUND OR v.listing_type<>'RENTAL' OR v.tenant IS NULL OR v.submitter IS NULL THEN RAISE EXCEPTION 'Property is not ready for rent creation.'; END IF;
 IF v.management_plan_id IS NULL OR v.commission_percentage IS NULL OR v.commission_percentage NOT BETWEEN 0 AND 100 THEN RAISE EXCEPTION 'Property does not have a valid management plan.'; END IF;
 IF p_amount_due IS NULL OR p_amount_due<=0 OR p_period_end_date<p_period_start_date OR p_due_date<p_period_start_date THEN RAISE EXCEPTION 'Invalid rent details.'; END IF;
 total:=ROUND(p_amount_due*100)::BIGINT; owner_share:=total-ROUND(total*v.commission_percentage/100.0)::BIGINT;
 IF p_owner_payout_override IS NOT NULL THEN
   IF NULLIF(btrim(COALESCE(p_override_reason,'')),'') IS NULL THEN RAISE EXCEPTION 'Override reason is required.'; END IF;
   override_paise:=ROUND(p_owner_payout_override*100)::BIGINT; IF override_paise<0 OR p_owner_payout_override>p_amount_due THEN RAISE EXCEPTION 'Owner payout cannot exceed the rent amount.'; END IF;
   owner_share:=override_paise;
 END IF;
 admin_share:=total-owner_share;
 INSERT INTO rent_records(property_id,tenant_user_id,landlord_user_id,due_date,period_start_date,period_end_date,amount_due,commission_percentage,total_amount_paise,admin_share_paise,owner_share_paise,split_override_applied,owner_share_override_paise,split_override_reason,split_override_by,split_override_at,status,notes) VALUES(p_property_id,v.tenant,v.submitter,p_due_date,p_period_start_date,p_period_end_date,p_amount_due,v.commission_percentage,total,admin_share,owner_share,p_owner_payout_override IS NOT NULL,override_paise,NULLIF(btrim(p_override_reason),''),CASE WHEN p_owner_payout_override IS NOT NULL THEN auth.uid() END,CASE WHEN p_owner_payout_override IS NOT NULL THEN NOW() END,'DUE',p_notes) RETURNING rent_record_id INTO v_id;
 RETURN v_id;
END; $$;
GRANT EXECUTE ON FUNCTION public.create_rent_record_admin(UUID,DATE,DATE,DATE,DECIMAL,TEXT,DECIMAL,TEXT) TO authenticated;
NOTIFY pgrst,'reload schema';
