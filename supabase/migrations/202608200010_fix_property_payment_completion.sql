-- The RETURNS TABLE column name property_id is also a PL/pgSQL output
-- variable. Qualifying all table columns prevents PostgreSQL from resolving
-- property_id ambiguously during Razorpay payment completion.
DROP FUNCTION IF EXISTS public.complete_property_management_payment(TEXT, TEXT, TEXT);

CREATE FUNCTION public.complete_property_management_payment(
    p_razorpay_order_id TEXT,
    p_razorpay_payment_id TEXT,
    p_razorpay_signature TEXT
) RETURNS TABLE (property_id UUID, status TEXT)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
    v_transaction public.transactions%ROWTYPE;
    v_property_id UUID;
BEGIN
    SELECT t.* INTO v_transaction
    FROM public.transactions AS t
    WHERE t.razorpay_order_id = p_razorpay_order_id
      AND t.payment_type = 'property_management'
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Management payment order was not found.';
    END IF;

    v_property_id := v_transaction.property_id;
    IF v_property_id IS NULL THEN
        RAISE EXCEPTION 'Management payment is not linked to a property.';
    END IF;

    UPDATE public.transactions AS t
    SET status = 'paid',
        razorpay_payment_id = p_razorpay_payment_id,
        razorpay_signature = COALESCE(p_razorpay_signature, t.razorpay_signature),
        error_message = NULL,
        updated_at = now()
    WHERE t.transaction_id = v_transaction.transaction_id;

    UPDATE public.properties AS p
    SET admin_status = 'SUBMITTED',
        is_listed = FALSE,
        updated_at = now()
    WHERE p.property_id = v_property_id
      AND p.submitter = v_transaction.user_id
      AND p.admin_status = 'PAYMENT_PENDING';

    IF NOT FOUND AND NOT EXISTS (
        SELECT 1
        FROM public.properties AS p
        WHERE p.property_id = v_property_id
          AND p.submitter = v_transaction.user_id
          AND p.admin_status = 'SUBMITTED'
    ) THEN
        RAISE EXCEPTION 'Pending property was not found or is no longer payable.';
    END IF;

    INSERT INTO public.admin_notifications (
        recipient_admin_id, type, source_id, payload, page_context, target_role
    )
    SELECT
        a.user_id,
        'property_payment_completed',
        v_property_id::TEXT,
        jsonb_build_object(
            'title', 'New property payment received',
            'message', 'A property post is ready for owner verification.',
            'property_id', v_property_id,
            'transaction_id', v_transaction.transaction_id
        ),
        'properties',
        'property-management'
    FROM public.admins AS a
    WHERE a.is_active = TRUE
      AND a.roles && ARRAY[
          'super-admin', 'telecalling-owner-team', 'marketing-team'
      ]::public.admin_role_enum[]
    ON CONFLICT (type, source_id, recipient_admin_id)
    WHERE source_id IS NOT NULL AND recipient_admin_id IS NOT NULL
    DO NOTHING;

    RETURN QUERY SELECT v_property_id, 'paid'::TEXT;
END;
$$;

GRANT EXECUTE ON FUNCTION public.complete_property_management_payment(TEXT, TEXT, TEXT) TO service_role;
