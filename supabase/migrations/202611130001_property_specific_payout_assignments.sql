-- Property-specific payout assignment.
-- Management plans remain service rules only; payout ownership is stored on the property.

ALTER TABLE public.owner_payout_accounts
    ADD COLUMN IF NOT EXISTS payout_account_id UUID DEFAULT gen_random_uuid();

UPDATE public.owner_payout_accounts
SET payout_account_id = gen_random_uuid()
WHERE payout_account_id IS NULL;

ALTER TABLE public.owner_payout_accounts
    ALTER COLUMN payout_account_id SET NOT NULL;

DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM pg_constraint c
        JOIN pg_class t ON t.oid = c.conrelid
        JOIN pg_namespace n ON n.oid = t.relnamespace
        JOIN pg_attribute a ON a.attrelid = t.oid AND a.attnum = ANY(c.conkey)
        WHERE c.conname = 'owner_payout_accounts_pkey'
          AND t.relname = 'owner_payout_accounts'
          AND n.nspname = 'public'
          AND a.attname = 'owner_user_id'
    ) THEN
        ALTER TABLE public.owner_payout_accounts DROP CONSTRAINT owner_payout_accounts_pkey;
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'owner_payout_accounts_pkey'
          AND conrelid = 'public.owner_payout_accounts'::regclass
    ) THEN
        ALTER TABLE public.owner_payout_accounts ADD CONSTRAINT owner_payout_accounts_pkey PRIMARY KEY (payout_account_id);
    END IF;
END;
$$;

CREATE INDEX IF NOT EXISTS owner_payout_accounts_owner_user_id_idx
    ON public.owner_payout_accounts(owner_user_id);

ALTER TABLE public.properties
    ADD COLUMN IF NOT EXISTS payout_account_id UUID
        REFERENCES public.owner_payout_accounts(payout_account_id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS properties_payout_account_id_idx
    ON public.properties(payout_account_id);

-- Legacy rows are safe to backfill only when an owner has exactly one account.
UPDATE public.properties p
SET payout_account_id = a.payout_account_id
FROM public.owner_payout_accounts a
WHERE p.payout_account_id IS NULL
  AND p.submitter = a.owner_user_id
  AND (SELECT COUNT(*) FROM public.owner_payout_accounts x
       WHERE x.owner_user_id = p.submitter) = 1;

CREATE OR REPLACE FUNCTION public.assign_property_payout_account_admin(
    p_property_id UUID,
    p_payout_account_id UUID DEFAULT NULL
) RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
    v_submitter UUID;
    v_owner UUID;
BEGIN
    IF NOT public.current_user_is_admin() THEN
        RAISE EXCEPTION 'Unauthorized: Admin access required.';
    END IF;

    SELECT submitter INTO v_submitter
    FROM public.properties
    WHERE property_id = p_property_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'Property was not found.'; END IF;

    IF p_payout_account_id IS NOT NULL THEN
        SELECT owner_user_id INTO v_owner
        FROM public.owner_payout_accounts
        WHERE payout_account_id = p_payout_account_id;
        IF NOT FOUND THEN RAISE EXCEPTION 'Payout account was not found.'; END IF;
        IF v_submitter IS NULL OR v_owner IS DISTINCT FROM v_submitter THEN
            RAISE EXCEPTION 'Payout account must belong to this property owner.';
        END IF;
    END IF;

    UPDATE public.properties
    SET payout_account_id = p_payout_account_id, updated_at = NOW()
    WHERE property_id = p_property_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_property_payout_accounts_admin(
    p_property_id UUID
) RETURNS TABLE (
    payout_account_id UUID,
    owner_user_id UUID,
    account_holder_name TEXT,
    masked_account_number TEXT,
    ifsc_code TEXT,
    status TEXT,
    payment_eligible BOOLEAN,
    razorpay_account_id TEXT,
    razorpay_product_status TEXT,
    is_selected BOOLEAN
)
LANGUAGE plpgsql SECURITY DEFINER STABLE SET search_path = public AS $$
DECLARE v_owner UUID; v_selected UUID;
BEGIN
    IF NOT public.current_user_is_admin() THEN
        RAISE EXCEPTION 'Unauthorized: Admin access required.';
    END IF;
    SELECT submitter, properties.payout_account_id INTO v_owner, v_selected
    FROM public.properties WHERE property_id = p_property_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'Property was not found.'; END IF;

    RETURN QUERY
    SELECT a.payout_account_id, a.owner_user_id, a.account_holder_name,
        repeat('X', greatest(char_length(a.account_number) - 4, 0)) || right(a.account_number, 4),
        a.ifsc_code, a.status, COALESCE(a.payment_eligible, FALSE),
        a.razorpay_account_id, a.razorpay_product_status,
        a.payout_account_id = v_selected
    FROM public.owner_payout_accounts a
    WHERE a.owner_user_id = v_owner
    ORDER BY a.created_at, a.payout_account_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.assign_property_payout_account_admin(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_property_payout_accounts_admin(UUID) TO authenticated;

-- Keep the customer payout screen compatible after removing the one-account-per-owner key.
DROP FUNCTION IF EXISTS public.save_my_owner_payout_account(TEXT, TEXT, TEXT);
DROP FUNCTION IF EXISTS public.save_my_owner_payout_account(TEXT, TEXT, TEXT, BOOLEAN);
CREATE OR REPLACE FUNCTION public.save_my_owner_payout_account(
    p_account_holder_name TEXT, p_account_number TEXT, p_ifsc_code TEXT
) RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_id UUID := auth.uid(); v_account UUID;
BEGIN
    SELECT payout_account_id INTO v_account FROM public.owner_payout_accounts WHERE owner_user_id=v_id ORDER BY created_at LIMIT 1;
    IF v_account IS NULL THEN
        INSERT INTO public.owner_payout_accounts(owner_user_id,account_holder_name,account_number,ifsc_code,status,created_at,updated_at)
        VALUES(v_id,btrim(p_account_holder_name),btrim(p_account_number),upper(btrim(p_ifsc_code)),'PENDING_VERIFICATION',NOW(),NOW());
    ELSE
        UPDATE public.owner_payout_accounts SET account_holder_name=btrim(p_account_holder_name),account_number=btrim(p_account_number),ifsc_code=upper(btrim(p_ifsc_code)),status='PENDING_VERIFICATION',updated_at=NOW() WHERE payout_account_id=v_account;
    END IF;
END; $$;
CREATE OR REPLACE FUNCTION public.save_my_owner_payout_account(
    p_account_holder_name TEXT, p_account_number TEXT, p_ifsc_code TEXT, p_route_consent BOOLEAN
) RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
    IF p_route_consent IS NOT TRUE THEN RAISE EXCEPTION 'Please accept the Razorpay payout terms before verifying your bank account.'; END IF;
    PERFORM public.save_my_owner_payout_account(p_account_holder_name,p_account_number,p_ifsc_code);
    UPDATE public.owner_payout_accounts SET route_consent_accepted=TRUE,route_consent_at=COALESCE(route_consent_at,NOW()),route_consent_version='v1' WHERE owner_user_id=auth.uid();
END; $$;
GRANT EXECUTE ON FUNCTION public.save_my_owner_payout_account(TEXT,TEXT,TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.save_my_owner_payout_account(TEXT,TEXT,TEXT,BOOLEAN) TO authenticated;

ALTER TABLE public.rent_records
    ADD COLUMN IF NOT EXISTS payout_account_id UUID
        REFERENCES public.owner_payout_accounts(payout_account_id) ON DELETE SET NULL;

ALTER TABLE public.route_transfers
    ADD COLUMN IF NOT EXISTS payout_account_id UUID
        REFERENCES public.owner_payout_accounts(payout_account_id) ON DELETE SET NULL;

CREATE OR REPLACE FUNCTION public.create_rent_record_admin(
 p_property_id UUID,p_due_date DATE,p_period_start_date DATE,p_period_end_date DATE,
 p_amount_due DECIMAL,p_notes TEXT DEFAULT NULL,p_owner_payout_override DECIMAL DEFAULT NULL,p_override_reason TEXT DEFAULT NULL
) RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE v_id UUID; v RECORD; total BIGINT; admin_share BIGINT; owner_share BIGINT; override_paise BIGINT; is_server BOOLEAN:=current_setting('request.jwt.claim.role',true)='service_role';
BEGIN
 IF NOT is_server AND NOT(public.current_user_has_role('accounts-team') OR public.current_user_has_role('super-admin')) THEN RAISE EXCEPTION 'Unauthorized: Insufficient privileges.'; END IF;
 SELECT p.tenant,p.submitter,p.payout_account_id,p.listing_type,p.management_plan_id,
        msp.percentage commission_percentage,COALESCE(msp.requires_payout_account,FALSE) requires_payout,
        opa.razorpay_account_id,opa.razorpay_product_id,opa.razorpay_product_status,opa.payment_eligible
 INTO v
 FROM properties p
 LEFT JOIN management_service_plans msp ON msp.plan_id=p.management_plan_id
 LEFT JOIN owner_payout_accounts opa ON opa.payout_account_id=p.payout_account_id AND opa.owner_user_id=p.submitter
 WHERE p.property_id=p_property_id;
 IF NOT FOUND OR v.listing_type<>'RENTAL' OR v.tenant IS NULL OR v.submitter IS NULL THEN RAISE EXCEPTION 'Property is not ready for rent creation.'; END IF;
 IF v.management_plan_id IS NULL OR v.commission_percentage IS NULL OR v.commission_percentage NOT BETWEEN 0 AND 100 THEN RAISE EXCEPTION 'Property does not have a valid management plan.'; END IF;
 IF v.requires_payout AND (v.payout_account_id IS NULL OR v.razorpay_account_id IS NULL OR v.razorpay_product_id IS NULL OR v.razorpay_product_status <> 'activated' OR v.payment_eligible IS NOT TRUE) THEN RAISE EXCEPTION 'PROPERTY_PAYOUT_NOT_ELIGIBLE: Assign a verified payout account to this property.'; END IF;
 IF p_amount_due IS NULL OR p_amount_due<=0 OR p_period_end_date<p_period_start_date OR p_due_date<p_period_start_date THEN RAISE EXCEPTION 'Invalid rent details.'; END IF;
 total:=ROUND(p_amount_due*100)::BIGINT; owner_share:=total-ROUND(total*v.commission_percentage/100.0)::BIGINT;
 IF p_owner_payout_override IS NOT NULL THEN IF NULLIF(btrim(COALESCE(p_override_reason,'')),'') IS NULL THEN RAISE EXCEPTION 'Override reason is required.'; END IF; override_paise:=ROUND(p_owner_payout_override*100)::BIGINT; IF override_paise<0 OR override_paise>total THEN RAISE EXCEPTION 'Owner payout cannot exceed the rent amount.'; END IF; owner_share:=override_paise; END IF;
 admin_share:=total-owner_share;
 INSERT INTO rent_records(property_id,payout_account_id,tenant_user_id,landlord_user_id,due_date,period_start_date,period_end_date,amount_due,commission_percentage,total_amount_paise,admin_share_paise,owner_share_paise,split_override_applied,owner_share_override_paise,split_override_reason,split_override_by,split_override_at,status,notes)
 VALUES(p_property_id,v.payout_account_id,v.tenant,v.submitter,p_due_date,p_period_start_date,p_period_end_date,p_amount_due,v.commission_percentage,total,admin_share,owner_share,p_owner_payout_override IS NOT NULL,override_paise,NULLIF(btrim(p_override_reason),''),CASE WHEN p_owner_payout_override IS NOT NULL THEN auth.uid() END,CASE WHEN p_owner_payout_override IS NOT NULL THEN NOW() END,'DUE',p_notes) RETURNING rent_record_id INTO v_id;
 RETURN v_id;
END; $$;

-- New transfers use the immutable account snapshot on the rent record. Legacy rows
-- with a null snapshot continue using the historical owner-level lookup.
CREATE OR REPLACE FUNCTION public.claim_rent_route_transfer(p_rent_record_id UUID)
RETURNS SETOF public.route_transfers LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE r public.rent_records%ROWTYPE; a public.rent_payment_attempts%ROWTYPE; p public.owner_payout_accounts%ROWTYPE; t public.route_transfers%ROWTYPE;
BEGIN
 SELECT * INTO r FROM public.rent_records WHERE rent_record_id=p_rent_record_id FOR UPDATE;
 IF NOT FOUND OR r.status <> 'PAID' THEN RAISE EXCEPTION 'Rent is not paid.'; END IF;
 SELECT * INTO a FROM public.rent_payment_attempts WHERE rent_record_id=p_rent_record_id AND status='PAID' AND razorpay_payment_id IS NOT NULL ORDER BY updated_at DESC LIMIT 1;
 IF NOT FOUND THEN RAISE EXCEPTION 'Successful rent payment not found.'; END IF;
 IF r.payout_account_id IS NOT NULL THEN SELECT * INTO p FROM public.owner_payout_accounts WHERE payout_account_id=r.payout_account_id AND owner_user_id=r.landlord_user_id; ELSE SELECT * INTO p FROM public.owner_payout_accounts WHERE owner_user_id=r.landlord_user_id ORDER BY created_at LIMIT 1; END IF;
 IF NOT FOUND OR COALESCE(p.payment_eligible,FALSE) IS NOT TRUE OR p.razorpay_account_id IS NULL THEN RAISE EXCEPTION 'Property payout account is not transfer eligible.'; END IF;
 SELECT * INTO t FROM public.route_transfers WHERE rent_record_id=p_rent_record_id FOR UPDATE;
 IF FOUND THEN IF t.status IN ('PROCESSED','PROCESSING') THEN RETURN NEXT t; RETURN; END IF; UPDATE public.route_transfers SET status='PROCESSING',attempt_count=attempt_count+1,last_attempted_at=NOW(),failure_reason=NULL,updated_at=NOW() WHERE transfer_id=t.transfer_id RETURNING * INTO t;
 ELSE INSERT INTO public.route_transfers(rent_record_id,payment_attempt_id,razorpay_payment_id,owner_user_id,payout_account_id,razorpay_account_id,total_amount_paise,owner_share_paise,admin_share_paise,status,attempt_count,last_attempted_at) VALUES(p_rent_record_id,a.payment_attempt_id,a.razorpay_payment_id,r.landlord_user_id,r.payout_account_id,p.razorpay_account_id,r.total_amount_paise,r.owner_share_paise,r.admin_share_paise,'PROCESSING',1,NOW()) RETURNING * INTO t; END IF;
 RETURN NEXT t;
END; $$;

CREATE OR REPLACE FUNCTION public.complete_rent_payment(p_order_id TEXT,p_payment_id TEXT) RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE a public.rent_payment_attempts%ROWTYPE; r public.rent_records%ROWTYPE; v_actor UUID:=auth.uid(); p public.owner_payout_accounts%ROWTYPE;
BEGIN
 SELECT * INTO a FROM public.rent_payment_attempts WHERE razorpay_order_id=p_order_id FOR UPDATE;
 IF NOT FOUND OR (v_actor IS NOT NULL AND a.tenant_user_id<>v_actor) THEN RAISE EXCEPTION 'Payment attempt not found.'; END IF;
 SELECT * INTO r FROM public.rent_records WHERE rent_record_id=a.rent_record_id FOR UPDATE;
 IF a.status='PAID' THEN RETURN; END IF; IF r.status='CANCELLED' THEN RAISE EXCEPTION 'Rent is cancelled.'; END IF;
 UPDATE public.rent_payment_attempts SET status='PAID',razorpay_payment_id=COALESCE(razorpay_payment_id,p_payment_id),failure_reason=NULL,updated_at=NOW() WHERE payment_attempt_id=a.payment_attempt_id;
 UPDATE public.rent_records SET status='PAID',amount_paid=(a.amount_paise::numeric/100),updated_at=NOW() WHERE rent_record_id=r.rent_record_id;
 INSERT INTO public.rent_payments(rent_record_id,paid_by_user_id,amount,payment_date,payment_method,transaction_ref,notes) VALUES(r.rent_record_id,a.tenant_user_id,(a.amount_paise::numeric/100),NOW(),'RAZORPAY',p_payment_id,'Online rent payment') ON CONFLICT (transaction_ref) DO NOTHING;
 IF r.payout_account_id IS NOT NULL THEN SELECT * INTO p FROM public.owner_payout_accounts WHERE payout_account_id=r.payout_account_id AND owner_user_id=r.landlord_user_id; ELSE SELECT * INTO p FROM public.owner_payout_accounts WHERE owner_user_id=r.landlord_user_id ORDER BY created_at LIMIT 1; END IF;
 IF COALESCE(p.payment_eligible,FALSE) AND p.razorpay_account_id IS NOT NULL THEN INSERT INTO public.route_transfers(rent_record_id,payment_attempt_id,razorpay_payment_id,owner_user_id,payout_account_id,razorpay_account_id,total_amount_paise,owner_share_paise,admin_share_paise) VALUES(r.rent_record_id,a.payment_attempt_id,p_payment_id,r.landlord_user_id,r.payout_account_id,p.razorpay_account_id,r.total_amount_paise,r.owner_share_paise,r.admin_share_paise) ON CONFLICT (rent_record_id) DO NOTHING; END IF;
END; $$;

NOTIFY pgrst, 'reload schema';
