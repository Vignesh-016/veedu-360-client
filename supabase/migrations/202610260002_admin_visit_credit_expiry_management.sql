-- Admin-only per-purchase Visit Credit expiry management.
-- Expiry remains attached to each paid transaction/batch.

CREATE TABLE IF NOT EXISTS public.visit_credit_expiry_audit (
    audit_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    transaction_id UUID NOT NULL REFERENCES public.transactions(transaction_id) ON DELETE RESTRICT,
    customer_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
    old_expires_at TIMESTAMPTZ NOT NULL,
    new_expires_at TIMESTAMPTZ NOT NULL,
    reason TEXT,
    changed_by UUID NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
    changed_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_visit_credit_expiry_audit_transaction
    ON public.visit_credit_expiry_audit (transaction_id, changed_at DESC);

ALTER TABLE public.visit_credit_expiry_audit ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS visit_credit_expiry_audit_admin_read ON public.visit_credit_expiry_audit;
CREATE POLICY visit_credit_expiry_audit_admin_read
    ON public.visit_credit_expiry_audit FOR SELECT TO authenticated
    USING (public.current_user_is_admin());

CREATE OR REPLACE FUNCTION public.get_visit_credit_batches_admin(p_customer_user_id UUID)
RETURNS TABLE (
    transaction_id UUID,
    plan_name TEXT,
    credits_purchased INTEGER,
    credits_remaining INTEGER,
    paid_at TIMESTAMPTZ,
    expires_at TIMESTAMPTZ,
    status TEXT
) AS $$
BEGIN
    IF NOT (public.current_user_has_role('super-admin') OR public.current_user_has_role('accounts-team')) THEN
        RAISE EXCEPTION 'Unauthorized: insufficient privileges to view Visit Credit batches.';
    END IF;

    RETURN QUERY
    SELECT
        t.transaction_id,
        vp.name::TEXT,
        t.credits_purchased,
        t.credits_remaining,
        COALESCE(t.paid_at, t.updated_at, t.created_at),
        t.expires_at,
        CASE
            WHEN COALESCE(t.credits_remaining, 0) = 0 THEN 'used'
            WHEN t.expires_at <= CURRENT_TIMESTAMP THEN 'expired'
            ELSE 'active'
        END::TEXT
    FROM public.transactions t
    LEFT JOIN public.visit_plans vp ON vp.plan_id = t.plan_id
    WHERE t.user_id = p_customer_user_id
      AND t.status = 'paid'
      AND COALESCE(t.credits_purchased, 0) > 0
    ORDER BY t.expires_at ASC, COALESCE(t.paid_at, t.created_at) ASC, t.transaction_id ASC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE SET search_path = public;

CREATE OR REPLACE FUNCTION public.update_visit_credit_expiry_admin(
    p_transaction_id UUID,
    p_expires_at TIMESTAMPTZ,
    p_reason TEXT DEFAULT NULL
) RETURNS TABLE (
    transaction_id UUID,
    customer_id UUID,
    credits_remaining INTEGER,
    expires_at TIMESTAMPTZ,
    status TEXT
) AS $$
DECLARE
    v_transaction public.transactions%ROWTYPE;
    v_reason TEXT := NULLIF(BTRIM(p_reason), '');
BEGIN
    IF NOT (public.current_user_has_role('super-admin') OR public.current_user_has_role('accounts-team')) THEN
        RAISE EXCEPTION 'Unauthorized: insufficient privileges to change Visit Credit expiry.';
    END IF;
    IF p_expires_at IS NULL THEN
        RAISE EXCEPTION 'Expiry date is required.';
    END IF;

    SELECT * INTO v_transaction
    FROM public.transactions
    WHERE transactions.transaction_id = p_transaction_id
      AND transactions.status = 'paid'
      AND COALESCE(transactions.credits_purchased, 0) > 0
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Paid Visit Credit batch not found.';
    END IF;
    IF v_transaction.expires_at IS NULL THEN
        RAISE EXCEPTION 'Visit Credit batch has no existing expiry.';
    END IF;

    UPDATE public.transactions
    SET expires_at = p_expires_at, updated_at = CURRENT_TIMESTAMP
    WHERE transactions.transaction_id = p_transaction_id;

    INSERT INTO public.visit_credit_expiry_audit
        (transaction_id, customer_id, old_expires_at, new_expires_at, reason, changed_by)
    VALUES
        (p_transaction_id, v_transaction.user_id, v_transaction.expires_at, p_expires_at, v_reason, auth.uid());

    UPDATE public.customers c
    SET visit_balance = COALESCE((
        SELECT SUM(t.credits_remaining)
        FROM public.transactions t
        WHERE t.user_id = v_transaction.user_id
          AND t.status = 'paid'
          AND COALESCE(t.credits_remaining, 0) > 0
          AND t.expires_at > CURRENT_TIMESTAMP
    ), 0)::INTEGER,
    expiry_date = (
        SELECT MIN(t.expires_at)::DATE
        FROM public.transactions t
        WHERE t.user_id = v_transaction.user_id
          AND t.status = 'paid'
          AND COALESCE(t.credits_remaining, 0) > 0
          AND t.expires_at > CURRENT_TIMESTAMP
    ),
    updated_at = CURRENT_TIMESTAMP
    WHERE c.user_id = v_transaction.user_id;

    RETURN QUERY
    SELECT p_transaction_id, v_transaction.user_id, t.credits_remaining, t.expires_at,
        CASE WHEN COALESCE(t.credits_remaining, 0) = 0 THEN 'used'
             WHEN t.expires_at <= CURRENT_TIMESTAMP THEN 'expired'
             ELSE 'active' END::TEXT
    FROM public.transactions t
    WHERE t.transaction_id = p_transaction_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

GRANT EXECUTE ON FUNCTION public.get_visit_credit_batches_admin(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_visit_credit_expiry_admin(UUID, TIMESTAMPTZ, TEXT) TO authenticated;
