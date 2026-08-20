-- Create one persistent, per-admin unread notification for each homepage enquiry.
-- admin_notifications is already subscribed to Supabase Realtime, so the bell and
-- Enquiries sidebar badge update without polling.

CREATE OR REPLACE FUNCTION public.notify_admins_of_customer_enquiry()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    INSERT INTO public.admin_notifications (
        recipient_admin_id, type, source_id, payload, page_context, target_role
    )
    SELECT
        admin_user.user_id,
        'customer_enquiry_created',
        NEW.enquiry_id::TEXT,
        jsonb_build_object(
            'title', 'New ' || lower(NEW.enquiry_type) || ' enquiry',
            'message', NEW.customer_name || ' · ' || NEW.contact_phone,
            'enquiry_id', NEW.enquiry_id,
            'enquiry_type', NEW.enquiry_type
        ),
        'enquiries',
        'customer-enquiries'
    FROM public.admins AS admin_user
    WHERE admin_user.is_active = TRUE
      AND admin_user.roles && ARRAY[
          'super-admin', 'telecalling-owner-team', 'telecalling-tenant-team'
      ]::public.admin_role_enum[]
    ON CONFLICT (type, source_id, recipient_admin_id)
    WHERE source_id IS NOT NULL AND recipient_admin_id IS NOT NULL
    DO NOTHING;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trigger_notify_admins_of_customer_enquiry ON public.customer_enquiries;
CREATE TRIGGER trigger_notify_admins_of_customer_enquiry
    AFTER INSERT ON public.customer_enquiries
    FOR EACH ROW EXECUTE FUNCTION public.notify_admins_of_customer_enquiry();
