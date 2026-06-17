-- FILE NAME: 06_04_admin_visit_transaction_plan_functions.sql
-- Description: Functions for admins to manage visit plans and transactions.
-------------------------------------------------------------------------------

-- Function for admins to get all visit plans (active and inactive)
CREATE OR REPLACE FUNCTION public.get_all_visit_plans_admin(
    p_is_active_filter BOOLEAN DEFAULT NULL
) RETURNS TABLE (
    plan_id UUID,
    name TEXT,
    description TEXT,
    visits INTEGER,
    price DECIMAL,
    is_active BOOLEAN,
    created_at TIMESTAMP WITH TIME ZONE,
    updated_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    IF NOT (public.current_user_has_role('super-admin') OR public.current_user_has_role('accounts-team')) THEN
        RAISE EXCEPTION 'Unauthorized: Insufficient privileges.';
    END IF;

    RETURN QUERY
    SELECT vp.plan_id, vp.name, vp.description, vp.visits, vp.price, vp.is_active, vp.created_at, vp.updated_at
    FROM public.visit_plans vp
    WHERE (p_is_active_filter IS NULL OR vp.is_active = p_is_active_filter)
    ORDER BY vp.price;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;
GRANT EXECUTE ON FUNCTION public.get_all_visit_plans_admin(BOOLEAN) TO authenticated;

-- Function for admins to update a visit plan
CREATE OR REPLACE FUNCTION public.update_visit_plan_admin(
    p_plan_id UUID,
    p_name TEXT,
    p_description TEXT,
    p_visits INTEGER,
    p_price DECIMAL,
    p_is_active BOOLEAN
) RETURNS VOID AS $$
BEGIN
    IF NOT (public.current_user_has_role('super-admin') OR public.current_user_has_role('accounts-team')) THEN
        RAISE EXCEPTION 'Unauthorized: Insufficient privileges.';
    END IF;

    IF p_visits <= 0 THEN RAISE EXCEPTION 'Visits must be positive.'; END IF;
    IF p_price < 0 THEN RAISE EXCEPTION 'Price cannot be negative.'; END IF;
    IF p_name IS NULL OR TRIM(p_name) = '' THEN RAISE EXCEPTION 'Plan name cannot be empty.'; END IF;

    UPDATE public.visit_plans
    SET name = TRIM(p_name),
        description = p_description,
        visits = p_visits,
        price = p_price,
        is_active = p_is_active,
        updated_at = CURRENT_TIMESTAMP
    WHERE plan_id = p_plan_id;

    IF NOT FOUND THEN RAISE EXCEPTION 'Visit Plan with ID % not found.', p_plan_id; END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.update_visit_plan_admin(UUID, TEXT, TEXT, INTEGER, DECIMAL, BOOLEAN) TO authenticated;

-- Function for admins to insert a new visit plan
CREATE OR REPLACE FUNCTION public.insert_visit_plan_admin(
    p_name TEXT,
    p_description TEXT,
    p_visits INTEGER,
    p_price DECIMAL,
    p_is_active BOOLEAN DEFAULT TRUE
) RETURNS UUID AS $$
DECLARE
    v_plan_id UUID;
BEGIN
    IF NOT (public.current_user_has_role('super-admin') OR public.current_user_has_role('accounts-team')) THEN
        RAISE EXCEPTION 'Unauthorized: Insufficient privileges to create visit plans.';
    END IF;

    IF p_visits <= 0 THEN RAISE EXCEPTION 'Visits must be positive.'; END IF;
    IF p_price < 0 THEN RAISE EXCEPTION 'Price cannot be negative.'; END IF;
    IF p_name IS NULL OR TRIM(p_name) = '' THEN RAISE EXCEPTION 'Plan name cannot be empty.'; END IF;

    INSERT INTO public.visit_plans (name, description, visits, price, is_active)
    VALUES (TRIM(p_name), p_description, p_visits, p_price, p_is_active)
    RETURNING plan_id INTO v_plan_id;

    RETURN v_plan_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.insert_visit_plan_admin(TEXT, TEXT, INTEGER, DECIMAL, BOOLEAN) TO authenticated;

-- Function for admins to list all transactions
CREATE OR REPLACE FUNCTION public.get_all_transactions_admin(
    p_customer_user_id_filter UUID DEFAULT NULL,
    p_plan_id_filter UUID DEFAULT NULL,
    p_statuses_filter TEXT[] DEFAULT NULL,
    p_razorpay_order_id_filter TEXT DEFAULT NULL,
    p_created_at_start TIMESTAMPTZ DEFAULT NULL,
    p_created_at_end TIMESTAMPTZ DEFAULT NULL,
    p_offset INTEGER DEFAULT 0,
    p_limit INTEGER DEFAULT 10
) RETURNS TABLE (
    transaction_id UUID,
    customer_user_id UUID,
    customer_name TEXT,
    customer_email TEXT,
    customer_phone TEXT,
    plan_id UUID,
    plan_name TEXT,
    amount DECIMAL,
    status TEXT,
    razorpay_order_id TEXT,
    razorpay_payment_id TEXT,
    razorpay_signature TEXT,
    error_message TEXT,
    admin_notes TEXT,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ,
    total_count BIGINT
) AS $$
BEGIN
    IF NOT (public.current_user_has_role('super-admin') OR public.current_user_has_role('accounts-team')) THEN
        RAISE EXCEPTION 'Unauthorized: Insufficient privileges.';
    END IF;

    RETURN QUERY
    WITH transactions_base AS (
        SELECT
            t.transaction_id, t.user_id AS cust_id,
            cust_user.raw_user_meta_data->>'full_name' AS cust_name,
            cust_user.email::TEXT AS cust_email,
            cust_user.phone::TEXT AS cust_phone,
            t.plan_id AS p_id, vp.name AS p_name, t.amount AS amt, t.status AS stat,
            t.razorpay_order_id AS rz_order_id, t.razorpay_payment_id AS rz_payment_id,
            t.razorpay_signature AS rz_sig, t.error_message AS err_msg,
            t.admin_notes AS adm_notes,
            t.created_at AS cr_at, t.updated_at AS upd_at
        FROM public.transactions t
        JOIN auth.users cust_user ON t.user_id = cust_user.id
        LEFT JOIN public.visit_plans vp ON t.plan_id = vp.plan_id
        WHERE (p_customer_user_id_filter IS NULL OR t.user_id = p_customer_user_id_filter)
          AND (p_plan_id_filter IS NULL OR t.plan_id = p_plan_id_filter)
          AND (p_statuses_filter IS NULL OR t.status = ANY(p_statuses_filter))
          AND (p_razorpay_order_id_filter IS NULL OR t.razorpay_order_id = p_razorpay_order_id_filter)
          AND (p_created_at_start IS NULL OR t.created_at >= p_created_at_start)
          AND (p_created_at_end IS NULL OR t.created_at <= p_created_at_end)
    ),
    transactions_with_count AS (
        SELECT *, COUNT(*) OVER() AS total_rows FROM transactions_base
    )
    SELECT
        twc.transaction_id, twc.cust_id, twc.cust_name, twc.cust_email, twc.cust_phone,
        twc.p_id, twc.p_name, twc.amt, twc.stat,
        twc.rz_order_id, twc.rz_payment_id, twc.rz_sig, twc.err_msg,
        twc.adm_notes,
        twc.cr_at, twc.upd_at, twc.total_rows
    FROM transactions_with_count twc
    ORDER BY twc.cr_at DESC
    OFFSET p_offset
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;
GRANT EXECUTE ON FUNCTION public.get_all_transactions_admin(UUID, UUID, TEXT[], TEXT, TIMESTAMPTZ, TIMESTAMPTZ, INTEGER, INTEGER) TO authenticated;

-- Function for admins to manually update a transaction's status and add notes.
CREATE OR REPLACE FUNCTION public.update_transaction_status_admin(
    p_transaction_id UUID,
    p_new_status TEXT,
    p_admin_notes TEXT DEFAULT NULL
) RETURNS VOID AS $$
DECLARE
    v_existing_admin_notes TEXT;
BEGIN
    IF NOT public.current_user_is_admin() THEN
        RAISE EXCEPTION 'Unauthorized: Admin access required.';
    END IF;
    -- Further role checks can be added if only specific admin roles (e.g., accounts-team, super-admin) can do this.
    IF NOT (public.current_user_has_role('accounts-team') OR public.current_user_has_role('super-admin')) THEN
        RAISE EXCEPTION 'Unauthorized: Insufficient privileges to update transaction status manually.';
    END IF;

    SELECT admin_notes INTO v_existing_admin_notes
    FROM public.transactions
    WHERE transaction_id = p_transaction_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Transaction with ID % not found.', p_transaction_id;
    END IF;

    IF p_admin_notes IS NOT NULL AND TRIM(p_admin_notes) <> '' THEN
        v_existing_admin_notes := COALESCE(v_existing_admin_notes || E'\n\n', '') ||
                                  '--- Admin Update (' || (SELECT COALESCE(raw_user_meta_data->>'full_name', auth.uid()::TEXT) FROM auth.users WHERE id = auth.uid()) || ' @ ' || TO_CHAR(CURRENT_TIMESTAMP, 'YYYY-MM-DD HH24:MI') || ') ---\n' ||
                                  TRIM(p_admin_notes);
    END IF;

    UPDATE public.transactions
    SET status = p_new_status,
        admin_notes = v_existing_admin_notes, -- Use the appended notes
        updated_at = CURRENT_TIMESTAMP
    WHERE transaction_id = p_transaction_id;

    -- Note: This admin function does NOT automatically call complete_purchase.
    -- If a manual update to 'paid' should trigger visit balance updates,
    -- the admin would need to use `update_customer_visits_admin` or
    -- a super-admin might call `complete_purchase` if the `razorpay_order_id` is known.
    -- For now, this function only updates the status and notes.

    RAISE NOTICE 'Transaction % status updated to % by admin %.', p_transaction_id, p_new_status, auth.uid();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.update_transaction_status_admin(UUID, TEXT, TEXT) TO authenticated;