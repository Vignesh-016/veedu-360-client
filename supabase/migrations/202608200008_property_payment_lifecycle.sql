    -- Keep owner-submitted property drafts out of the admin workflow until payment succeeds.
    DO $$
    BEGIN
        IF NOT EXISTS (
            SELECT 1
            FROM pg_enum
            WHERE enumtypid = 'public.property_admin_status_enum'::regtype
            AND enumlabel = 'PAYMENT_PENDING'
        ) THEN
            ALTER TYPE public.property_admin_status_enum ADD VALUE 'PAYMENT_PENDING';
        END IF;
    END;
    $$;

    -- Atomically mark the management payment as paid and release the property to the
    -- normal owner-verification workflow. The unique notification index makes this idempotent.
    DROP FUNCTION IF EXISTS public.complete_property_management_payment(TEXT, TEXT, TEXT);
    CREATE OR REPLACE FUNCTION public.complete_property_management_payment(
        p_razorpay_order_id TEXT,
        p_razorpay_payment_id TEXT,
        p_razorpay_signature TEXT
    ) RETURNS TABLE (property_id UUID, status TEXT)
    LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
    DECLARE
        v_transaction public.transactions%ROWTYPE;
        v_property_id UUID;
    BEGIN
        SELECT * INTO v_transaction
        FROM public.transactions
        WHERE razorpay_order_id = p_razorpay_order_id
        AND payment_type = 'property_management'
        FOR UPDATE;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'Management payment order was not found.';
        END IF;

        v_property_id := v_transaction.property_id;

        IF v_property_id IS NULL THEN
            RAISE EXCEPTION 'Management payment is not linked to a property.';
        END IF;

        UPDATE public.transactions
        SET status = 'paid',
            razorpay_payment_id = p_razorpay_payment_id,
            razorpay_signature = p_razorpay_signature,
            error_message = NULL,
            updated_at = now()
        WHERE transaction_id = v_transaction.transaction_id;

        UPDATE public.properties
        SET admin_status = 'SUBMITTED',
            is_listed = FALSE,
            updated_at = now()
        WHERE property_id = v_property_id
        AND submitter = v_transaction.user_id
        AND admin_status = 'PAYMENT_PENDING';

        IF NOT FOUND THEN
                    IF EXISTS (
                            SELECT 1 FROM public.properties
                            WHERE property_id = v_property_id
                                AND submitter = v_transaction.user_id
                                AND admin_status = 'SUBMITTED'
                    ) THEN
                            RETURN QUERY SELECT v_property_id, 'paid'::TEXT;
                            RETURN;
                    END IF;
                    RAISE EXCEPTION 'Pending property was not found or is no longer payable.';
        END IF;

        INSERT INTO public.admin_notifications (
            recipient_admin_id,
            type,
            source_id,
            payload,
            page_context,
            target_role
        )
        SELECT
            admin_user.user_id,
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
        FROM public.admins AS admin_user
        WHERE admin_user.is_active = TRUE
        AND admin_user.roles && ARRAY[
            'super-admin',
            'telecalling-owner-team',
            'marketing-team'
        ]::public.admin_role_enum[]
        ON CONFLICT (type, source_id, recipient_admin_id)
        WHERE source_id IS NOT NULL AND recipient_admin_id IS NOT NULL
        DO NOTHING;

        RETURN QUERY SELECT v_property_id, 'paid'::TEXT;
    END;
    $$;

    GRANT EXECUTE ON FUNCTION public.complete_property_management_payment(TEXT, TEXT, TEXT) TO service_role;

    -- Remove only an unpaid pending draft. A paid transaction is never deleted by this path.
    CREATE OR REPLACE FUNCTION public.discard_pending_property_customer(
        p_property_id UUID
    ) RETURNS BOOLEAN
    LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
    DECLARE
        v_user_id UUID := auth.uid();
        v_deleted BOOLEAN := FALSE;
        v_deleted_count INTEGER;
    BEGIN
        IF v_user_id IS NULL THEN
            RAISE EXCEPTION 'Authentication required.';
        END IF;

        DELETE FROM public.properties p
        WHERE p.property_id = p_property_id
        AND p.submitter = v_user_id
        AND p.admin_status = 'PAYMENT_PENDING'
        AND NOT EXISTS (
            SELECT 1
            FROM public.transactions t
            WHERE t.property_id = p.property_id
                AND t.payment_type = 'property_management'
                AND t.status = 'paid'
        );

        GET DIAGNOSTICS v_deleted_count = ROW_COUNT;
        v_deleted := v_deleted_count > 0;
        RETURN v_deleted;
    END;
    $$;

    GRANT EXECUTE ON FUNCTION public.discard_pending_property_customer(UUID) TO authenticated;

    -- Failed Razorpay orders must not leave drafts visible to admins or owners.
    CREATE OR REPLACE FUNCTION public.discard_failed_property_management_payment(
        p_razorpay_order_id TEXT
    ) RETURNS VOID
    LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
    DECLARE
        v_property_id UUID;
    BEGIN
        SELECT property_id INTO v_property_id
        FROM public.transactions
        WHERE razorpay_order_id = p_razorpay_order_id
        AND payment_type = 'property_management'
        AND status <> 'paid';

        UPDATE public.transactions
        SET status = 'failed', updated_at = now()
        WHERE razorpay_order_id = p_razorpay_order_id
        AND payment_type = 'property_management'
        AND status <> 'paid';

        IF v_property_id IS NOT NULL THEN
            DELETE FROM public.properties
            WHERE property_id = v_property_id
            AND admin_status = 'PAYMENT_PENDING';
        END IF;
    END;
    $$;

    GRANT EXECUTE ON FUNCTION public.discard_failed_property_management_payment(TEXT) TO service_role;
