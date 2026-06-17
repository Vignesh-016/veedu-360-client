-- FILE NAME: 05_04_customer_account_management_functions.sql
-- Description: Functions for customers to manage their account, visits, transactions.
-------------------------------------------------------------------------------

-- Function to get customer's visit balance and expiry date
CREATE OR REPLACE FUNCTION public.get_visit_status_customer()
RETURNS TABLE (visit_balance INTEGER, expiry_date DATE) AS $$
DECLARE
    v_user_id UUID := auth.uid();
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.';
    END IF;

    RETURN QUERY
    SELECT
        c.visit_balance,
        c.expiry_date
    FROM public.customers c
    WHERE c.user_id = v_user_id;

    -- If customer record doesn't exist (shouldn't happen due to trigger), return 0/null
    IF NOT FOUND THEN
        RETURN QUERY SELECT 0, CAST(NULL AS DATE);
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;
GRANT EXECUTE ON FUNCTION public.get_visit_status_customer() TO authenticated;

-- Function to get active visit plans available for purchase
CREATE OR REPLACE FUNCTION public.get_visit_plans_customer()
RETURNS TABLE (
    plan_id UUID,
    name TEXT,
    description TEXT,
    visits INTEGER,
    price DECIMAL
) AS $$
BEGIN
    -- No explicit auth check needed if RLS allows authenticated to select from visit_plans.
    -- Assuming RLS: CREATE POLICY visit_plans_select_active_authenticated ON public.visit_plans FOR SELECT TO authenticated USING (is_active = TRUE);
    RETURN QUERY
    SELECT vp.plan_id, vp.name, vp.description, vp.visits, vp.price
    FROM public.visit_plans vp
    WHERE vp.is_active = TRUE
    ORDER BY vp.price ASC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE; -- Or VOLATILE if it depends on auth.uid() in a more complex way for filtering
GRANT EXECUTE ON FUNCTION public.get_visit_plans_customer() TO authenticated;

-- Function to create a transaction record (called before redirecting to payment gateway)
CREATE OR REPLACE FUNCTION public.create_transaction_customer(
    p_plan_id UUID,
    p_razorpay_order_id TEXT -- Or any payment gateway order ID
)
RETURNS UUID AS $$
DECLARE
    v_transaction_id UUID;
    v_user_id UUID := auth.uid();
    v_amount DECIMAL;
    v_plan_is_active BOOLEAN;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.';
    END IF;

    SELECT price, is_active INTO v_amount, v_plan_is_active
    FROM public.visit_plans
    WHERE plan_id = p_plan_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Visit Plan ID % not found.', p_plan_id;
    END IF;
    IF v_plan_is_active = FALSE THEN
        RAISE EXCEPTION 'Visit Plan ID % is not active.', p_plan_id;
    END IF;

    IF p_razorpay_order_id IS NULL OR TRIM(p_razorpay_order_id) = '' THEN
        RAISE EXCEPTION 'Payment gateway Order ID cannot be null or empty.';
    END IF;

    INSERT INTO public.transactions (user_id, plan_id, amount, razorpay_order_id, status)
    VALUES (v_user_id, p_plan_id, v_amount, p_razorpay_order_id, 'created')
    RETURNING transaction_id INTO v_transaction_id;

    RETURN v_transaction_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.create_transaction_customer(UUID, TEXT) TO authenticated;

-- Function to get the current user's transaction history
CREATE OR REPLACE FUNCTION public.get_my_transactions_customer(
    p_offset INTEGER DEFAULT 0,
    p_limit INTEGER DEFAULT 10
) RETURNS TABLE (
    transaction_id UUID,
    plan_id UUID,
    plan_name TEXT,
    amount DECIMAL,
    status TEXT,
    razorpay_order_id TEXT,
    razorpay_payment_id TEXT,
    error_message TEXT,
    created_at TIMESTAMP WITH TIME ZONE,
    updated_at TIMESTAMP WITH TIME ZONE,
    total_count BIGINT
) AS $$
DECLARE
    v_current_user_id UUID := auth.uid();
BEGIN
    IF v_current_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.';
    END IF;

    RETURN QUERY
    WITH user_transactions AS (
        SELECT
            t.transaction_id, t.plan_id, vp.name AS plan_name_val, t.amount, t.status,
            t.razorpay_order_id, t.razorpay_payment_id, t.error_message,
            t.created_at, t.updated_at
        FROM public.transactions t
        LEFT JOIN public.visit_plans vp ON t.plan_id = vp.plan_id
        WHERE t.user_id = v_current_user_id
    ),
    transactions_with_count AS (
        SELECT *, COUNT(*) OVER() AS total_rows FROM user_transactions
    )
    SELECT
        twc.transaction_id, twc.plan_id, twc.plan_name_val, twc.amount, twc.status,
        twc.razorpay_order_id, twc.razorpay_payment_id, twc.error_message,
        twc.created_at, twc.updated_at,
        twc.total_rows
    FROM transactions_with_count twc
    ORDER BY twc.created_at DESC
    OFFSET p_offset
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;
GRANT EXECUTE ON FUNCTION public.get_my_transactions_customer(INTEGER, INTEGER) TO authenticated;