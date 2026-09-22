-- Keep manually assigned visit credits usable.
-- Previously an admin could set a positive balance while leaving an expired
-- expiry_date, which made the customer UI show credits but booking reject them.

CREATE OR REPLACE FUNCTION public.update_customer_visits_admin(
    p_customer_user_id UUID,
    p_new_visit_balance INTEGER,
    p_new_expiry_date DATE
) RETURNS VOID AS $$
DECLARE
    v_effective_expiry DATE;
BEGIN
    IF NOT (public.current_user_has_role('super-admin') OR public.current_user_has_role('accounts-team')) THEN
        RAISE EXCEPTION 'Unauthorized: Insufficient privileges to modify visit balances.';
    END IF;

    IF p_new_visit_balance < 0 THEN
        RAISE EXCEPTION 'Visit balance cannot be negative.';
    END IF;

    -- Positive credits must have a usable validity period. Preserve a future
    -- date explicitly supplied by admin; otherwise start a fresh 30-day period.
    v_effective_expiry := CASE
        WHEN p_new_visit_balance > 0
             AND (p_new_expiry_date IS NULL OR p_new_expiry_date < CURRENT_DATE)
            THEN CURRENT_DATE + 30
        ELSE COALESCE(p_new_expiry_date, CURRENT_DATE)
    END;

    INSERT INTO public.customers (user_id, visit_balance, expiry_date, updated_at)
    VALUES (p_customer_user_id, p_new_visit_balance, v_effective_expiry, CURRENT_TIMESTAMP)
    ON CONFLICT (user_id) DO UPDATE
    SET visit_balance = EXCLUDED.visit_balance,
        expiry_date = EXCLUDED.expiry_date,
        updated_at = CURRENT_TIMESTAMP;

    IF NOT EXISTS (SELECT 1 FROM auth.users WHERE id = p_customer_user_id) THEN
        RAISE EXCEPTION 'User ID % not found in auth.users.', p_customer_user_id;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.update_customer_visits_admin(UUID, INTEGER, DATE) TO authenticated;

-- Repair existing records created by the old admin workflow. Only customers
-- who still have unused visit credits are changed; customers with zero
-- credits keep their existing expiry value.
UPDATE public.customers
SET expiry_date = CURRENT_DATE + 30,
    updated_at = CURRENT_TIMESTAMP
WHERE visit_balance > 0
  AND expiry_date < CURRENT_DATE;
