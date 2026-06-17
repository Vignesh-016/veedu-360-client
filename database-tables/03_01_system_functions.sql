-- FILE NAME: 03_01_system_functions.sql
-- Description: System-level functions, often called by backend services or webhooks.
-------------------------------------------------------------------------------

-- Function to complete a purchase: updates customer's visit balance and expiry date.
-- Called internally after a transaction is confirmed as 'paid'.
CREATE OR REPLACE FUNCTION public.complete_purchase(
    p_razorpay_order_id TEXT
) RETURNS VOID AS $$
DECLARE
    v_transaction RECORD;
    v_plan RECORD;
    v_customer RECORD;
BEGIN
    -- This function should be called by trusted roles, e.g., service_role via update_transaction_status
    IF current_setting('role', true) <> 'service_role' THEN
        RAISE EXCEPTION 'Unauthorized: This function can only be called by service_role.';
    END IF;

    SELECT user_id, plan_id, status
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

    SELECT visits
    INTO v_plan
    FROM public.visit_plans
    WHERE plan_id = v_transaction.plan_id;

    IF NOT FOUND THEN
        RAISE WARNING 'Visit plan % for transaction % not found.', v_transaction.plan_id, p_razorpay_order_id;
        RETURN;
    END IF;

    SELECT user_id, expiry_date
    INTO v_customer
    FROM public.customers
    WHERE user_id = v_transaction.user_id;

    IF NOT FOUND THEN
         -- This should ideally not happen if the user_created trigger for customers works.
        RAISE WARNING 'Customer profile for user ID % not found. Cannot update visit balance.', v_transaction.user_id;
        -- Attempt to create a minimal customer record to apply the plan to.
        INSERT INTO public.customers (user_id, visit_balance, expiry_date)
        VALUES (v_transaction.user_id, v_plan.visits, (CURRENT_DATE + INTERVAL '30 days'))
        ON CONFLICT (user_id) DO NOTHING; -- If created concurrently, do nothing.

        -- Re-fetch customer data if it was just inserted.
        SELECT user_id, expiry_date
        INTO v_customer
        FROM public.customers
        WHERE user_id = v_transaction.user_id;

        IF NOT FOUND THEN
             RAISE EXCEPTION 'Failed to create or find customer profile for user ID % after attempting insert.', v_transaction.user_id;
        END IF;
    END IF;
    
    UPDATE public.customers
    SET visit_balance = visit_balance + v_plan.visits,
        expiry_date = GREATEST(COALESCE(v_customer.expiry_date, CURRENT_DATE - INTERVAL '1 day'), CURRENT_DATE) + INTERVAL '30 days', -- Assumes each plan purchase grants a 30-day validity extension from the later of current expiry or today.
        updated_at = CURRENT_TIMESTAMP
    WHERE user_id = v_transaction.user_id;

    RAISE NOTICE 'Purchase completed for Razorpay Order ID %: User % visits updated.', p_razorpay_order_id, v_transaction.user_id;

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
-- Grant execute to service_role is typically done in 10_revoke_permissions.sql or via Supabase dashboard.


-- Function to update transaction status, typically called by a payment gateway webhook.
CREATE OR REPLACE FUNCTION public.update_transaction_status(
    p_razorpay_order_id TEXT,
    p_status TEXT,
    p_razorpay_payment_id TEXT DEFAULT NULL,
    p_razorpay_signature TEXT DEFAULT NULL,
    p_error_message TEXT DEFAULT NULL
) RETURNS VOID AS $$
DECLARE
    v_transaction_id UUID;
BEGIN
    -- This function is intended to be called by a trusted backend service/webhook (e.g. Supabase Edge Function)
    -- The calling context MUST be switched to 'service_role' before invoking this.
    IF current_setting('role', true) <> 'service_role' THEN
        RAISE EXCEPTION 'Unauthorized: This function can only be called by service_role.';
    END IF;

    UPDATE public.transactions
    SET status = p_status,
        razorpay_payment_id = COALESCE(p_razorpay_payment_id, razorpay_payment_id),
        razorpay_signature = COALESCE(p_razorpay_signature, razorpay_signature),
        error_message = COALESCE(p_error_message, error_message),
        updated_at = CURRENT_TIMESTAMP
    WHERE razorpay_order_id = p_razorpay_order_id
    RETURNING transaction_id INTO v_transaction_id;

    IF NOT FOUND THEN
        RAISE WARNING 'Transaction with Razorpay Order ID % not found. Status not updated.', p_razorpay_order_id;
        RETURN;
    END IF;

    IF p_status = 'paid' THEN
        -- Call complete_purchase to update customer's visit balance
        PERFORM public.complete_purchase(p_razorpay_order_id);
    END IF;

    RAISE NOTICE 'Transaction % (Razorpay Order ID: %) status updated to %.', v_transaction_id, p_razorpay_order_id, p_status;

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
-- Grant execute to service_role is typically done in 10_revoke_permissions.sql or via Supabase dashboard.