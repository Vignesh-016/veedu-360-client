-- Replace two drifted/duplicate interaction triggers. One referenced the
-- nonexistent interaction_type and notes columns and blocked wishlist inserts.
DROP TRIGGER IF EXISTS trigger_on_interaction_created_notification
    ON public.customers_interaction;
DROP TRIGGER IF EXISTS trigger_on_new_interaction
    ON public.customers_interaction;

DROP FUNCTION IF EXISTS public.on_interaction_created_notification();
DROP FUNCTION IF EXISTS public.notify_on_new_interaction();

CREATE OR REPLACE FUNCTION public.notify_admins_of_customer_interaction()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    notification_type TEXT;
    notification_title TEXT;
BEGIN
    -- An UPDATE notification is meaningful only when the workflow status changes.
    IF TG_OP = 'UPDATE' AND OLD.status IS NOT DISTINCT FROM NEW.status THEN
        RETURN NEW;
    END IF;

    notification_type := 'interaction_' || lower(NEW.status::TEXT);
    notification_title := CASE NEW.status::TEXT
        WHEN 'WISHLISTED' THEN 'Property added to wishlist'
        WHEN 'VISIT_PENDING' THEN 'New property visit request'
        WHEN 'VISIT_CONFIRMED_PENDING_SALES' THEN 'Visit awaiting sales assignment'
        WHEN 'VISIT_SCHEDULED_WITH_SALES' THEN 'Property visit scheduled'
        WHEN 'VISIT_COMPLETED' THEN 'Property visit completed'
        ELSE 'Customer interaction updated'
    END;

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
        notification_type,
        NEW.interaction_id::TEXT,
        jsonb_build_object(
            'title', notification_title,
            'message', 'Status: ' || NEW.status::TEXT,
            'interaction_id', NEW.interaction_id,
            'property_id', NEW.property_id,
            'user_id', NEW.user_id,
            'status', NEW.status
        ),
        'interactions',
        'customer-interactions'
    FROM public.admins AS admin_user
    WHERE admin_user.is_active = TRUE
      AND admin_user.roles && ARRAY[
          'super-admin',
          'telecalling-tenant-team'
      ]::public.admin_role_enum[]
    ON CONFLICT (type, source_id, recipient_admin_id)
    WHERE source_id IS NOT NULL AND recipient_admin_id IS NOT NULL
    DO NOTHING;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trigger_notify_admins_of_customer_interaction
    AFTER INSERT OR UPDATE OF status
    ON public.customers_interaction
    FOR EACH ROW
    EXECUTE FUNCTION public.notify_admins_of_customer_interaction();
