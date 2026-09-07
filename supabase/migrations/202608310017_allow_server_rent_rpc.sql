CREATE OR REPLACE FUNCTION public.create_rent_record_admin(p_property_id UUID,p_due_date DATE,p_period_start_date DATE,p_period_end_date DATE,p_amount_due DECIMAL,p_notes TEXT DEFAULT NULL)
RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE v_id UUID; v RECORD; total BIGINT; admin_share BIGINT; owner_share BIGINT; is_server BOOLEAN := current_setting('request.jwt.claim.role', true) = 'service_role';
BEGIN
 IF NOT is_server AND NOT (public.current_user_has_role('accounts-team') OR public.current_user_has_role('super-admin')) THEN RAISE EXCEPTION 'Unauthorized: Insufficient privileges to create rent records.'; END IF;
 SELECT p.tenant,p.submitter,p.listing_type,p.management_plan_id,msp.percentage commission_percentage,opa.payment_eligible,opa.razorpay_account_id,opa.razorpay_product_id,opa.razorpay_product_status INTO v FROM properties p LEFT JOIN management_service_plans msp ON msp.plan_id=p.management_plan_id LEFT JOIN owner_payout_accounts opa ON opa.owner_user_id=p.submitter WHERE p.property_id=p_property_id;
 IF NOT FOUND THEN RAISE EXCEPTION 'Property ID % not found.',p_property_id; END IF;
 IF v.listing_type<>'RENTAL' OR v.tenant IS NULL OR v.submitter IS NULL THEN RAISE EXCEPTION 'Property is not ready for rent creation.'; END IF;
 IF v.payment_eligible IS NOT TRUE OR v.razorpay_account_id IS NULL OR v.razorpay_product_id IS NULL OR v.razorpay_product_status <> 'activated' THEN RAISE EXCEPTION 'Owner payout account is not verified'; END IF;
 IF v.management_plan_id IS NULL OR v.commission_percentage IS NULL OR v.commission_percentage NOT BETWEEN 0 AND 100 THEN RAISE EXCEPTION 'Property does not have a valid management plan.'; END IF;
 IF p_amount_due IS NULL OR p_amount_due<=0 THEN RAISE EXCEPTION 'Amount due must be positive.'; END IF;
 IF p_period_end_date<p_period_start_date OR p_due_date<p_period_start_date THEN RAISE EXCEPTION 'Invalid rent dates.'; END IF;
 total:=ROUND(p_amount_due*100)::BIGINT; admin_share:=ROUND(total*v.commission_percentage/100)::BIGINT; owner_share:=total-admin_share;
 INSERT INTO rent_records(property_id,tenant_user_id,landlord_user_id,due_date,period_start_date,period_end_date,amount_due,commission_percentage,total_amount_paise,admin_share_paise,owner_share_paise,status,notes) VALUES(p_property_id,v.tenant,v.submitter,p_due_date,p_period_start_date,p_period_end_date,p_amount_due,v.commission_percentage,total,admin_share,owner_share,'DUE',p_notes) RETURNING rent_record_id INTO v_id;
 RETURN v_id;
END; $$;
