-- Visit-credit purchases are credit batches. Expiry is enforced from the
-- database clock and does not depend on a scheduled job or the client UI.
ALTER TABLE public.transactions
    ADD COLUMN IF NOT EXISTS credits_purchased INTEGER,
    ADD COLUMN IF NOT EXISTS credits_remaining INTEGER,
    ADD COLUMN IF NOT EXISTS paid_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS expires_at TIMESTAMPTZ;

ALTER TABLE public.transactions
    DROP CONSTRAINT IF EXISTS transactions_credits_remaining_check;

ALTER TABLE public.transactions
    ADD CONSTRAINT transactions_credits_remaining_check
    CHECK (credits_remaining IS NULL OR (credits_remaining >= 0 AND credits_purchased IS NOT NULL AND credits_remaining <= credits_purchased));

CREATE INDEX IF NOT EXISTS idx_transactions_visit_credit_batches
    ON public.transactions (user_id, expires_at, status)
    WHERE status = 'paid' AND credits_remaining > 0;

-- Existing paid purchases are assigned to the most recent purchase for each
-- customer using the already-authoritative aggregate balance. Older rows keep
-- their history but cannot accidentally duplicate the customer's balance.
WITH paid_rows AS (
    SELECT t.transaction_id, t.user_id, vp.visits,
           ROW_NUMBER() OVER (PARTITION BY t.user_id ORDER BY COALESCE(t.updated_at, t.created_at) DESC) AS row_number,
           c.visit_balance,
           COALESCE(t.updated_at, t.created_at) AS purchase_time
    FROM public.transactions t
    JOIN public.visit_plans vp ON vp.plan_id = t.plan_id
    JOIN public.customers c ON c.user_id = t.user_id
    WHERE t.status = 'paid' AND t.credits_purchased IS NULL
), backfill AS (
    SELECT transaction_id, visits,
           CASE WHEN row_number = 1 THEN GREATEST(visit_balance, 0) ELSE 0 END AS remaining,
           purchase_time AS paid_at
    FROM paid_rows
)
UPDATE public.transactions t
SET credits_purchased = backfill.visits,
    credits_remaining = backfill.remaining,
    paid_at = backfill.paid_at,
    expires_at = backfill.paid_at + INTERVAL '60 days'
FROM backfill
WHERE t.transaction_id = backfill.transaction_id;

CREATE OR REPLACE FUNCTION public.complete_purchase(p_razorpay_order_id TEXT)
RETURNS VOID AS $$
DECLARE
    v_transaction public.transactions%ROWTYPE;
    v_visits INTEGER;
    v_paid_at TIMESTAMPTZ;
    v_contact_credits INTEGER;
BEGIN
    IF current_setting('role', true) <> 'service_role' THEN
        RAISE EXCEPTION 'Unauthorized: this function can only be called by service_role.';
    END IF;

    SELECT * INTO v_transaction
    FROM public.transactions
    WHERE razorpay_order_id = p_razorpay_order_id
    FOR UPDATE;

    IF NOT FOUND OR v_transaction.status <> 'paid' THEN
        RETURN;
    END IF;

    -- Idempotent payment callbacks must not allocate a batch twice.
    IF v_transaction.credits_purchased IS NOT NULL THEN
        RETURN;
    END IF;

    IF v_transaction.contact_plan_id IS NOT NULL THEN
        SELECT contacts INTO v_contact_credits FROM public.contact_plans WHERE plan_id = v_transaction.contact_plan_id;
        IF NOT FOUND THEN RAISE EXCEPTION 'Contact plan not found.'; END IF;
        UPDATE public.customers SET contact_balance = contact_balance + v_contact_credits, updated_at = CURRENT_TIMESTAMP WHERE user_id = v_transaction.user_id;
        UPDATE public.transactions SET credits_purchased = 0, credits_remaining = 0, updated_at = CURRENT_TIMESTAMP WHERE transaction_id = v_transaction.transaction_id;
        RETURN;
    END IF;

    SELECT visits INTO v_visits FROM public.visit_plans WHERE plan_id = v_transaction.plan_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'Visit plan not found.'; END IF;

    v_paid_at := COALESCE(v_transaction.updated_at, CURRENT_TIMESTAMP);
    UPDATE public.transactions
    SET credits_purchased = v_visits,
        credits_remaining = v_visits,
        paid_at = v_paid_at,
        expires_at = v_paid_at + INTERVAL '60 days',
        updated_at = CURRENT_TIMESTAMP
    WHERE transaction_id = v_transaction.transaction_id;

    UPDATE public.customers
    SET visit_balance = COALESCE((
            SELECT SUM(t.credits_remaining)
            FROM public.transactions t
            WHERE t.user_id = v_transaction.user_id
              AND t.status = 'paid'
              AND t.credits_remaining > 0
              AND t.expires_at > CURRENT_TIMESTAMP
        ), 0),
        expiry_date = (SELECT MIN(t.expires_at)::DATE FROM public.transactions t WHERE t.user_id = v_transaction.user_id AND t.status = 'paid' AND t.credits_remaining > 0 AND t.expires_at > CURRENT_TIMESTAMP),
        updated_at = CURRENT_TIMESTAMP
    WHERE user_id = v_transaction.user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP FUNCTION IF EXISTS public.get_my_transactions_customer(INTEGER, INTEGER);

CREATE FUNCTION public.get_my_transactions_customer(
    p_offset INTEGER DEFAULT 0,
    p_limit INTEGER DEFAULT 10
) RETURNS TABLE (
    transaction_id UUID, plan_id UUID, plan_name TEXT, amount DECIMAL, status TEXT,
    razorpay_order_id TEXT, razorpay_payment_id TEXT, error_message TEXT,
    created_at TIMESTAMPTZ, updated_at TIMESTAMPTZ, total_count BIGINT,
    paid_at TIMESTAMPTZ, expires_at TIMESTAMPTZ, credits_purchased INTEGER,
    credits_remaining INTEGER
) AS $$
DECLARE v_current_user_id UUID := auth.uid();
BEGIN
    IF v_current_user_id IS NULL THEN RAISE EXCEPTION 'Authentication required.'; END IF;
    RETURN QUERY
    WITH user_transactions AS (
        SELECT t.transaction_id, t.plan_id, vp.name AS plan_name_val, t.amount,
            CASE WHEN t.status = 'paid' AND t.expires_at IS NOT NULL AND t.expires_at <= CURRENT_TIMESTAMP AND COALESCE(t.credits_remaining, 0) > 0 THEN 'expired' ELSE t.status END AS status_val,
            t.razorpay_order_id, t.razorpay_payment_id, t.error_message, t.created_at, t.updated_at,
            t.paid_at, t.expires_at, t.credits_purchased, t.credits_remaining
        FROM public.transactions t
        LEFT JOIN public.visit_plans vp ON t.plan_id = vp.plan_id
        WHERE t.user_id = v_current_user_id
    ), counted AS (SELECT *, COUNT(*) OVER() AS total_rows FROM user_transactions)
    SELECT transaction_id, plan_id, plan_name_val, amount, status_val, razorpay_order_id, razorpay_payment_id,
        error_message, created_at, updated_at, total_rows, paid_at, expires_at, credits_purchased, credits_remaining
    FROM counted ORDER BY created_at DESC OFFSET p_offset LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

GRANT EXECUTE ON FUNCTION public.get_my_transactions_customer(INTEGER, INTEGER) TO authenticated;

-- The return columns changed when batch expiry fields were added. PostgreSQL
-- requires dropping the old OUT-parameter row type before recreating it.
DROP FUNCTION IF EXISTS public.get_visit_status_customer();

CREATE FUNCTION public.get_visit_status_customer()
RETURNS TABLE (visit_balance INTEGER, expiry_date DATE) AS $$
DECLARE
    v_user_id UUID := auth.uid();
BEGIN
    IF v_user_id IS NULL THEN RAISE EXCEPTION 'Authentication required.'; END IF;

    RETURN QUERY
    SELECT COALESCE(SUM(t.credits_remaining), CASE WHEN c.expiry_date > CURRENT_DATE THEN c.visit_balance ELSE 0 END)::INTEGER,
           COALESCE(MIN(t.expires_at)::DATE, c.expiry_date)
    FROM public.customers c
    LEFT JOIN public.transactions t ON t.user_id = c.user_id
      AND t.status = 'paid' AND t.credits_remaining > 0 AND t.expires_at > CURRENT_TIMESTAMP
    WHERE c.user_id = v_user_id
    GROUP BY c.visit_balance, c.expiry_date;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

CREATE OR REPLACE FUNCTION public.request_visit_customer(
    p_property_id UUID,
    p_preferred_date DATE
) RETURNS UUID AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_interaction_id UUID;
    v_batch_id UUID;
    v_wishlisted_interaction_id UUID;
BEGIN
    IF v_user_id IS NULL THEN RAISE EXCEPTION 'Authentication required.'; END IF;
    IF p_preferred_date <= CURRENT_DATE THEN RAISE EXCEPTION 'Visit must be scheduled for a future date (tomorrow or later).'; END IF;
    IF NOT EXISTS (SELECT 1 FROM public.properties WHERE property_id = p_property_id AND is_listed = TRUE) THEN RAISE EXCEPTION 'Property not found or not available for visits.'; END IF;

    IF EXISTS (SELECT 1 FROM public.customers_interaction WHERE user_id = v_user_id AND property_id = p_property_id AND scheduled_for = p_preferred_date AND status IN ('VISIT_PENDING', 'VISIT_CONFIRMED_PENDING_SALES', 'VISIT_SCHEDULED_WITH_SALES')) THEN
        RAISE EXCEPTION 'You already have a visit requested or scheduled for this property on this date.';
    END IF;

    -- FEFO: lock and consume the earliest-expiring active batch atomically.
    SELECT transaction_id INTO v_batch_id
    FROM public.transactions
    WHERE user_id = v_user_id AND status = 'paid' AND credits_remaining > 0 AND expires_at > CURRENT_TIMESTAMP
    ORDER BY expires_at ASC, paid_at ASC, transaction_id ASC
    LIMIT 1
    FOR UPDATE SKIP LOCKED;
    IF v_batch_id IS NULL THEN
        UPDATE public.customers SET visit_balance = visit_balance - 1, updated_at = CURRENT_TIMESTAMP
        WHERE user_id = v_user_id AND visit_balance > 0 AND expiry_date > CURRENT_DATE;
        IF NOT FOUND THEN RAISE EXCEPTION 'Your Visit Credits have expired or are insufficient. Purchase a new pack to continue booking visits.'; END IF;
    END IF;

    SELECT interaction_id INTO v_wishlisted_interaction_id FROM public.customers_interaction WHERE user_id = v_user_id AND property_id = p_property_id AND status = 'WISHLISTED' LIMIT 1;
    IF v_wishlisted_interaction_id IS NOT NULL THEN
        UPDATE public.customers_interaction SET status = 'VISIT_PENDING', scheduled_for = p_preferred_date, updated_at = CURRENT_TIMESTAMP WHERE interaction_id = v_wishlisted_interaction_id RETURNING interaction_id INTO v_interaction_id;
    ELSE
        INSERT INTO public.customers_interaction (user_id, property_id, status, scheduled_for) VALUES (v_user_id, p_property_id, 'VISIT_PENDING', p_preferred_date) RETURNING interaction_id INTO v_interaction_id;
    END IF;

    IF v_batch_id IS NOT NULL THEN
        UPDATE public.transactions SET credits_remaining = credits_remaining - 1, updated_at = CURRENT_TIMESTAMP WHERE transaction_id = v_batch_id;
    END IF;
    UPDATE public.customers c SET visit_balance = COALESCE((SELECT SUM(t.credits_remaining) FROM public.transactions t WHERE t.user_id = c.user_id AND t.status = 'paid' AND t.credits_remaining > 0 AND t.expires_at > CURRENT_TIMESTAMP), 0), expiry_date = (SELECT MIN(t.expires_at)::DATE FROM public.transactions t WHERE t.user_id = c.user_id AND t.status = 'paid' AND t.credits_remaining > 0 AND t.expires_at > CURRENT_TIMESTAMP), updated_at = CURRENT_TIMESTAMP WHERE c.user_id = v_user_id;
    RETURN v_interaction_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
