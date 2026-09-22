-- Queue both visit-booking SMS messages at the moment the tenant requests a visit.
-- The queue processor sends these records through Fast2SMS.

CREATE OR REPLACE FUNCTION public.queue_visit_requested_sms()
RETURNS TRIGGER AS $$
DECLARE
    v_owner_phone TEXT;
    v_tenant_phone TEXT;
    v_property_address TEXT;
    v_owner_id UUID;
BEGIN
    SELECT p.submitter, p.address
    INTO v_owner_id, v_property_address
    FROM public.properties p
    WHERE p.property_id = NEW.property_id;

    IF v_owner_id IS NOT NULL THEN
        SELECT phone INTO v_owner_phone FROM auth.users WHERE id = v_owner_id;
        IF v_owner_phone IS NOT NULL AND TRIM(v_owner_phone) <> '' THEN
            INSERT INTO public.service_sms_log (sms_type, to_phone_number, variables)
            VALUES ('VISIT_BOOKING_TO_OWNER', v_owner_phone,
                    ARRAY[COALESCE(v_property_address, 'your property'),
                          to_char(NEW.scheduled_for, 'DD-Mon-YYYY')]);
        ELSE
            RAISE WARNING 'Owner % has no phone number; visit SMS not queued.', v_owner_id;
        END IF;
    END IF;

    SELECT phone INTO v_tenant_phone FROM auth.users WHERE id = NEW.user_id;
    IF v_tenant_phone IS NOT NULL AND TRIM(v_tenant_phone) <> '' THEN
        INSERT INTO public.service_sms_log (sms_type, to_phone_number, variables)
        VALUES ('VISIT_BOOKING_TO_TENANT', v_tenant_phone,
                ARRAY[COALESCE(v_property_address, 'your property'),
                      to_char(NEW.scheduled_for, 'DD-Mon-YYYY'),
                      'our sales executive']);
    ELSE
        RAISE WARNING 'Tenant % has no phone number; visit SMS not queued.', NEW.user_id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.queue_visit_requested_sms() TO authenticated;

-- Replace the owner-only trigger added previously with one trigger that queues
-- both recipient messages. Keep the later scheduled notification unchanged.
DROP TRIGGER IF EXISTS trigger_queue_visit_requested_owner_sms_insert ON public.customers_interaction;
DROP TRIGGER IF EXISTS trigger_queue_visit_requested_owner_sms_update ON public.customers_interaction;

CREATE TRIGGER trigger_queue_visit_requested_sms_insert
AFTER INSERT ON public.customers_interaction
FOR EACH ROW
WHEN (NEW.status = 'VISIT_PENDING')
EXECUTE FUNCTION public.queue_visit_requested_sms();

CREATE TRIGGER trigger_queue_visit_requested_sms_update
AFTER UPDATE OF status ON public.customers_interaction
FOR EACH ROW
WHEN (OLD.status IS DISTINCT FROM NEW.status AND NEW.status = 'VISIT_PENDING')
EXECUTE FUNCTION public.queue_visit_requested_sms();
