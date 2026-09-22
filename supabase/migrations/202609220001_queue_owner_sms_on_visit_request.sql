-- Queue an owner SMS immediately when a tenant requests a property visit.
-- The existing VISIT_SCHEDULED_WITH_SALES trigger remains responsible for the
-- later scheduled-visit notification, so this is a separate event.

CREATE OR REPLACE FUNCTION public.queue_visit_requested_owner_sms()
RETURNS TRIGGER AS $$
DECLARE
    v_owner_phone TEXT;
    v_property_address TEXT;
    v_owner_id UUID;
BEGIN
    SELECT p.submitter, p.address
    INTO v_owner_id, v_property_address
    FROM public.properties p
    WHERE p.property_id = NEW.property_id;

    IF v_owner_id IS NULL THEN
        RAISE WARNING 'Property % has no owner/submitter. Cannot queue visit request SMS.', NEW.property_id;
        RETURN NEW;
    END IF;

    SELECT phone
    INTO v_owner_phone
    FROM auth.users
    WHERE id = v_owner_id;

    IF v_owner_phone IS NULL OR TRIM(v_owner_phone) = '' THEN
        RAISE WARNING 'Owner % of property % has no phone number. Skipping visit request SMS.', v_owner_id, NEW.property_id;
        RETURN NEW;
    END IF;

    INSERT INTO public.service_sms_log (sms_type, to_phone_number, variables)
    VALUES (
        'VISIT_BOOKING_TO_OWNER',
        v_owner_phone,
        ARRAY[
            COALESCE(v_property_address, 'your property'),
            to_char(NEW.scheduled_for, 'DD-Mon-YYYY')
        ]
    );

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.queue_visit_requested_owner_sms() TO authenticated;

DROP TRIGGER IF EXISTS trigger_queue_visit_requested_owner_sms
ON public.customers_interaction;

CREATE TRIGGER trigger_queue_visit_requested_owner_sms_insert
AFTER INSERT ON public.customers_interaction
FOR EACH ROW
WHEN (NEW.status = 'VISIT_PENDING')
EXECUTE FUNCTION public.queue_visit_requested_owner_sms();

CREATE TRIGGER trigger_queue_visit_requested_owner_sms_update
AFTER UPDATE OF status ON public.customers_interaction
FOR EACH ROW
WHEN (OLD.status IS DISTINCT FROM NEW.status AND NEW.status = 'VISIT_PENDING')
EXECUTE FUNCTION public.queue_visit_requested_owner_sms();

COMMENT ON TRIGGER trigger_queue_visit_requested_owner_sms_insert ON public.customers_interaction IS
'Queues an owner SMS immediately when a tenant creates or requests a property visit.';

COMMENT ON TRIGGER trigger_queue_visit_requested_owner_sms_update ON public.customers_interaction IS
'Queues an owner SMS immediately when a tenant creates or requests a property visit.';
