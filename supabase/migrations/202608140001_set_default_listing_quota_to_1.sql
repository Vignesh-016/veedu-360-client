-- Migration: Update default listing_quota to 1 and update helper RPCs

-- 1. Alter customers table column default listing_quota to 1
ALTER TABLE public.customers ALTER COLUMN listing_quota SET DEFAULT 1;

-- 2. Update existing customers where listing_quota is null or set to previous default 50
UPDATE public.customers SET listing_quota = 1 WHERE listing_quota IS NULL OR listing_quota = 50;

-- 3. Update create_customer_for_new_user trigger function to insert listing_quota = 1
CREATE OR REPLACE FUNCTION public.create_customer_for_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.customers (user_id, visit_balance, listing_quota)
    VALUES (NEW.id, 5, 1)
    ON CONFLICT (user_id) DO NOTHING;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. Update get_visit_status_customer to return COALESCE(c.listing_quota, 1)
CREATE OR REPLACE FUNCTION public.get_visit_status_customer()
RETURNS TABLE (visit_balance INTEGER, expiry_date DATE, listing_quota INTEGER) AS $$
DECLARE
    v_user_id UUID := auth.uid();
BEGIN
    IF v_user_id IS NULL THEN
        RETURN QUERY SELECT 0, CAST(NULL AS DATE), 1;
        RETURN;
    END IF;

    RETURN QUERY
    SELECT 
        c.visit_balance, 
        c.expiry_date,
        COALESCE(c.listing_quota, 1) AS listing_quota
    FROM public.customers c
    WHERE c.user_id = v_user_id;

    IF NOT FOUND THEN
        RETURN QUERY SELECT 0, CAST(NULL AS DATE), 1;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. Update complete_purchase function
CREATE OR REPLACE FUNCTION public.complete_purchase(
    p_razorpay_order_id TEXT
) RETURNS VOID AS $$
DECLARE
    v_transaction RECORD;
    v_visit_plan RECORD;
    v_contact_plan RECORD;
    v_customer RECORD;
BEGIN
    IF current_setting('role', true) <> 'service_role' THEN
        RAISE EXCEPTION 'Unauthorized: This function can only be called by service_role.';
    END IF;

    SELECT user_id, plan_id, contact_plan_id, status
    INTO v_transaction
    FROM public.transactions
    WHERE razorpay_order_id = p_razorpay_order_id;

    IF NOT FOUND THEN
        RAISE WARNING 'Transaction with Razorpay Order ID % not found in complete_purchase.', p_razorpay_order_id;
        RETURN;
    END IF;

    IF v_transaction.status <> 'paid' THEN
        RAISE WARNING 'Transaction % is not marked as paid. Cannot complete purchase.', p_razorpay_order_id;
        RETURN;
    END IF;

    -- Fetch customer info or create if missing
    SELECT user_id, expiry_date
    INTO v_customer
    FROM public.customers
    WHERE user_id = v_transaction.user_id;

    IF NOT FOUND THEN
        INSERT INTO public.customers (user_id, visit_balance, contact_balance, listing_quota, expiry_date)
        VALUES (v_transaction.user_id, 0, 0, 1, (CURRENT_DATE + INTERVAL '30 days'))
        ON CONFLICT (user_id) DO NOTHING;

        SELECT user_id, expiry_date
        INTO v_customer
        FROM public.customers
        WHERE user_id = v_transaction.user_id;
    END IF;

    IF v_transaction.plan_id IS NOT NULL THEN
        -- Visit Plan (only add visits if it's NOT a listing plan)
        SELECT visits, name INTO v_visit_plan FROM public.visit_plans WHERE plan_id = v_transaction.plan_id;
        IF FOUND AND v_visit_plan.visits IS NOT NULL AND v_visit_plan.name NOT ILIKE '%listing%' THEN
            UPDATE public.customers
            SET visit_balance = visit_balance + v_visit_plan.visits,
                expiry_date = GREATEST(COALESCE(expiry_date, CURRENT_DATE - INTERVAL '1 day'), CURRENT_DATE) + INTERVAL '30 days',
                updated_at = CURRENT_TIMESTAMP
            WHERE user_id = v_transaction.user_id;
        END IF;

    ELSIF v_transaction.contact_plan_id IS NOT NULL THEN
        -- Contact Plan
        SELECT contacts INTO v_contact_plan FROM public.contact_plans WHERE plan_id = v_transaction.contact_plan_id;
        IF NOT FOUND THEN
            RAISE WARNING 'Contact plan % not found.', v_transaction.contact_plan_id;
            RETURN;
        END IF;

        UPDATE public.customers
        SET contact_balance = contact_balance + v_contact_plan.contacts,
            updated_at = CURRENT_TIMESTAMP
        WHERE user_id = v_transaction.user_id;
    END IF;

    RAISE NOTICE 'Purchase completed for Razorpay Order ID %.', p_razorpay_order_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
