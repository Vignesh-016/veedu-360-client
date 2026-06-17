-- Description: Contains trigger functions to queue SMS messages based on application events.
-------------------------------------------------------------------------------

-- ==== Trigger for POST_SUBMITTED ====

-- 1. Trigger Function Definition
CREATE OR REPLACE FUNCTION public.queue_post_submitted_sms()
RETURNS TRIGGER AS $$
DECLARE
    v_submitter_phone TEXT;
BEGIN
    -- Get the phone number of the user who submitted the property from the auth.users table.
    SELECT phone INTO v_submitter_phone FROM auth.users WHERE id = NEW.submitter;

    -- Only proceed if a valid, non-empty phone number exists.
    IF v_submitter_phone IS NOT NULL AND TRIM(v_submitter_phone) <> '' THEN
        INSERT INTO public.service_sms_log (sms_type, to_phone_number, variables)
        VALUES ('POST_SUBMITTED', v_submitter_phone, '{}');
    ELSE
        -- Optionally, log a warning if the user has no phone number for debugging.
        RAISE WARNING 'User % submitted property % but has no phone number. Skipping POST_SUBMITTED SMS.', NEW.submitter, NEW.property_id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION public.queue_post_submitted_sms() IS 'Queues an SMS to the owner after they submit a new property. Runs as SECURITY DEFINER to insert into service_sms_log.';

-- Grant execute permission to the role that inserts properties (authenticated users)
GRANT EXECUTE ON FUNCTION public.queue_post_submitted_sms() TO authenticated;


-- 2. Attach the Trigger to the properties table
-- This trigger will fire automatically AFTER a new row is inserted into public.properties.
CREATE TRIGGER trigger_queue_post_submitted_sms
AFTER INSERT ON public.properties
FOR EACH ROW
EXECUTE FUNCTION public.queue_post_submitted_sms();

COMMENT ON TRIGGER trigger_queue_post_submitted_sms ON public.properties IS 'After a property is inserted, queue a POST_SUBMITTED SMS to the owner.';

-- ==== Trigger for MARKETING_ASSIGNED & MARKETING_REASSIGNED ====

-- 1. Trigger Function Definition for Marketing Assignments
CREATE OR REPLACE FUNCTION public.queue_marketing_assignment_sms()
RETURNS TRIGGER AS $$
DECLARE
    v_customer_sms_type public.sms_type_enum;
    v_new_marketer_details RECORD; -- To hold full_name and phone of the new marketer
    v_property_owner_id UUID;
    v_owner_phone TEXT;
BEGIN
    -- Determine the correct SMS type for the customer based on the operation
    IF TG_OP = 'INSERT' THEN
        v_customer_sms_type := 'MARKETING_ASSIGNED_TO_CUSTOMER';
    ELSIF TG_OP = 'UPDATE' THEN
        v_customer_sms_type := 'MARKETING_REASSIGNED_TO_CUSTOMER';
    ELSE
        -- Should not happen with the defined triggers, but good for safety
        RETURN NULL;
    END IF;

    -- Step 1: Get details for the NEWLY assigned marketer
    SELECT
        u.phone,
        u.raw_user_meta_data->>'full_name' AS full_name
    INTO v_new_marketer_details
    FROM auth.users u
    WHERE u.id = NEW.assigned_admin_id;

    -- Step 2: Get the property owner's phone number
    SELECT p.submitter INTO v_property_owner_id
    FROM public.properties p WHERE p.property_id = NEW.property_id;

    IF v_property_owner_id IS NOT NULL THEN
        SELECT u.phone INTO v_owner_phone
        FROM auth.users u WHERE u.id = v_property_owner_id;
    END IF;


    -- Step 3: Queue SMS to the property owner (customer)
    IF v_owner_phone IS NOT NULL AND TRIM(v_owner_phone) <> '' THEN
        IF v_new_marketer_details.full_name IS NOT NULL AND TRIM(v_new_marketer_details.full_name) <> '' THEN
            INSERT INTO public.service_sms_log (sms_type, to_phone_number, variables)
            VALUES (v_customer_sms_type, v_owner_phone, ARRAY[v_new_marketer_details.full_name]);
        ELSE
            -- Marketer name is missing, but still notify the owner.
            INSERT INTO public.service_sms_log (sms_type, to_phone_number, variables)
            VALUES (v_customer_sms_type, v_owner_phone, ARRAY['our marketing executive']); -- Fallback variable
            RAISE WARNING 'Marketer % has no full_name. Sending generic SMS to property owner for property %.', NEW.assigned_admin_id, NEW.property_id;
        END IF;
    ELSE
        RAISE WARNING 'Property owner % for property % has no phone number. Skipping customer SMS for marketing assignment.', v_property_owner_id, NEW.property_id;
    END IF;

    -- Step 4: Queue SMS to the newly assigned marketer
    IF v_new_marketer_details.phone IS NOT NULL AND TRIM(v_new_marketer_details.phone) <> '' THEN
        INSERT INTO public.service_sms_log (sms_type, to_phone_number, variables)
        VALUES ('MARKETING_ASSIGNED_TO_MARKETER', v_new_marketer_details.phone, '{}');
    ELSE
        RAISE WARNING 'Marketer % has no phone number. Skipping marketer SMS for marketing assignment on property %.', NEW.assigned_admin_id, NEW.property_id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION public.queue_marketing_assignment_sms() IS 'Queues SMS to the property owner and the assigned marketer upon a new or updated marketing assignment. Runs as SECURITY DEFINER to insert into service_sms_log.';

-- Grant execute permission
GRANT EXECUTE ON FUNCTION public.queue_marketing_assignment_sms() TO authenticated; -- Or the role performing the assignment if more specific


-- 2. Attach the Triggers to the property_marketing_assignments table
CREATE TRIGGER trigger_queue_new_marketing_assignment_sms
AFTER INSERT ON public.property_marketing_assignments
FOR EACH ROW
EXECUTE FUNCTION public.queue_marketing_assignment_sms();

COMMENT ON TRIGGER trigger_queue_new_marketing_assignment_sms ON public.property_marketing_assignments IS 'After a new marketing assignment is created, queue SMS notifications to the owner and the marketer.';


CREATE TRIGGER trigger_queue_reassigned_marketing_assignment_sms
AFTER UPDATE ON public.property_marketing_assignments
FOR EACH ROW
WHEN (OLD.assigned_admin_id IS DISTINCT FROM NEW.assigned_admin_id) -- IMPORTANT: Only fire when the marketer changes
EXECUTE FUNCTION public.queue_marketing_assignment_sms();

COMMENT ON TRIGGER trigger_queue_reassigned_marketing_assignment_sms ON public.property_marketing_assignments IS 'After a marketing assignment is updated to a new marketer, queue SMS notifications.';

-- ==== Trigger for RENT_APPROVAL & RENTED_APPROVAL ====

-- 1. Trigger Function Definition for Property Rented Event
CREATE OR REPLACE FUNCTION public.queue_property_rented_sms()
RETURNS TRIGGER AS $$
DECLARE
    v_tenant_phone TEXT;
    v_owner_phone TEXT;
BEGIN
    -- This trigger is designed to run only when admin_status changes to 'RENTED'.

    -- Step 1: Get Tenant's Phone Number
    IF NEW.tenant IS NOT NULL THEN
        SELECT phone INTO v_tenant_phone FROM auth.users WHERE id = NEW.tenant;

        -- Queue SMS to the Tenant
        IF v_tenant_phone IS NOT NULL AND TRIM(v_tenant_phone) <> '' THEN
            INSERT INTO public.service_sms_log (sms_type, to_phone_number, variables)
            VALUES ('RENT_APPROVAL_TO_CUSTOMER', v_tenant_phone, '{}');
        ELSE
            RAISE WARNING 'Property % rented to tenant %, but tenant has no phone number. Skipping RENT_APPROVAL_TO_CUSTOMER SMS.', NEW.property_id, NEW.tenant;
        END IF;
    ELSE
        RAISE WARNING 'Property % was marked as RENTED but has no tenant assigned. Cannot send tenant SMS.', NEW.property_id;
    END IF;


    -- Step 2: Get Owner's (Submitter's) Phone Number
    IF NEW.submitter IS NOT NULL THEN
        SELECT phone INTO v_owner_phone FROM auth.users WHERE id = NEW.submitter;

        -- Queue SMS to the Owner
        IF v_owner_phone IS NOT NULL AND TRIM(v_owner_phone) <> '' THEN
            INSERT INTO public.service_sms_log (sms_type, to_phone_number, variables)
            VALUES ('RENTED_APPROVAL_TO_OWNER', v_owner_phone, ARRAY[NEW.address]);
        ELSE
            RAISE WARNING 'Property % rented, but owner % has no phone number. Skipping RENTED_APPROVAL_TO_OWNER SMS.', NEW.property_id, NEW.submitter;
        END IF;
    ELSE
        RAISE WARNING 'Property % was marked as RENTED but has no owner/submitter. Cannot send owner SMS.', NEW.property_id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION public.queue_property_rented_sms() IS 'Queues SMS notifications to both the new tenant and the property owner when a property''s status is updated to RENTED.';

-- Grant execute permission
GRANT EXECUTE ON FUNCTION public.queue_property_rented_sms() TO authenticated;


-- 2. Attach the Trigger to the properties table
CREATE TRIGGER trigger_queue_property_rented_sms
AFTER UPDATE OF admin_status, tenant ON public.properties
FOR EACH ROW
-- Fire only when the new state is RENTED with a tenant, AND it's a meaningful change (either status changed, or tenant changed).
WHEN (NEW.admin_status = 'RENTED' AND NEW.tenant IS NOT NULL AND (OLD.admin_status IS DISTINCT FROM NEW.admin_status OR OLD.tenant IS DISTINCT FROM NEW.tenant))
EXECUTE FUNCTION public.queue_property_rented_sms();

COMMENT ON TRIGGER trigger_queue_property_rented_sms ON public.properties IS 'After a property is marked as RENTED with a tenant assigned, queue SMS notifications to the tenant and owner.';

-- ==== Trigger for TICKET_CREATED & TICKET_CLOSED ====

-- 1. Trigger Function Definition
CREATE OR REPLACE FUNCTION public.queue_ticket_event_sms()
RETURNS TRIGGER AS $$
DECLARE
    v_sms_type public.sms_type_enum;
    v_raiser_phone TEXT;
    v_ticket_record RECORD;
BEGIN
    IF TG_OP = 'INSERT' THEN
        v_sms_type := 'TICKET_CREATED';
        v_ticket_record := NEW;
    ELSIF TG_OP = 'UPDATE' THEN
        v_sms_type := 'TICKET_CLOSED';
        v_ticket_record := NEW;
    ELSE
        RETURN NULL; -- Should not happen
    END IF;

    SELECT phone INTO v_raiser_phone FROM auth.users WHERE id = v_ticket_record.raised_by_user_id;

    IF v_raiser_phone IS NOT NULL AND TRIM(v_raiser_phone) <> '' THEN
        INSERT INTO public.service_sms_log (sms_type, to_phone_number, variables)
        VALUES (v_sms_type, v_raiser_phone, '{}');
    ELSE
        RAISE WARNING 'User % for ticket % has no phone number. Skipping % SMS.', v_ticket_record.raised_by_user_id, v_ticket_record.ticket_id, v_sms_type;
    END IF;

    RETURN v_ticket_record;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION public.queue_ticket_event_sms() IS 'Queues an SMS to the ticket raiser when a ticket is created or closed.';
GRANT EXECUTE ON FUNCTION public.queue_ticket_event_sms() TO authenticated;

-- 2. Attach Triggers to the tickets table
CREATE TRIGGER trigger_queue_ticket_created_sms
AFTER INSERT ON public.tickets
FOR EACH ROW
EXECUTE FUNCTION public.queue_ticket_event_sms();

CREATE TRIGGER trigger_queue_ticket_closed_sms
AFTER UPDATE OF status ON public.tickets
FOR EACH ROW
WHEN (OLD.status IS DISTINCT FROM NEW.status AND NEW.status = 'CLOSED')
EXECUTE FUNCTION public.queue_ticket_event_sms();


-- ==== Trigger for CREDITS_PURCHASED ====

-- 1. Trigger Function Definition
CREATE OR REPLACE FUNCTION public.queue_credits_purchased_sms()
RETURNS TRIGGER AS $$
DECLARE
    v_purchaser_phone TEXT;
    v_current_balance INTEGER;
BEGIN
    SELECT phone INTO v_purchaser_phone FROM auth.users WHERE id = NEW.user_id;

    IF v_purchaser_phone IS NOT NULL AND TRIM(v_purchaser_phone) <> '' THEN
        SELECT visit_balance INTO v_current_balance FROM public.customers WHERE user_id = NEW.user_id;
        IF NOT FOUND THEN
            RAISE WARNING 'Customer profile not found for user % after purchase. Cannot get current balance for SMS.', NEW.user_id;
            v_current_balance := 0;
        END IF;

        INSERT INTO public.service_sms_log (sms_type, to_phone_number, variables)
        VALUES (
            'CREDITS_PURCHASED',
            v_purchaser_phone,
            ARRAY[ NEW.amount::TEXT, v_current_balance::TEXT ]
        );
    ELSE
        RAISE WARNING 'User % purchased credits but has no phone number. Skipping CREDITS_PURCHASED SMS.', NEW.user_id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION public.queue_credits_purchased_sms() IS 'Queues an SMS to a user after their transaction for visit credits is successfully marked as paid.';
GRANT EXECUTE ON FUNCTION public.queue_credits_purchased_sms() TO authenticated;

-- 2. Attach Trigger to the transactions table
CREATE TRIGGER trigger_queue_credits_purchased_sms
AFTER UPDATE OF status ON public.transactions
FOR EACH ROW
WHEN (OLD.status IS DISTINCT FROM NEW.status AND NEW.status = 'paid')
EXECUTE FUNCTION public.queue_credits_purchased_sms();


-- ==== Trigger for RENT_DUE ====

-- 1. Trigger Function Definition
CREATE OR REPLACE FUNCTION public.queue_rent_due_sms()
RETURNS TRIGGER AS $$
DECLARE
    v_tenant_phone TEXT;
    v_property_address TEXT;
BEGIN
    SELECT phone INTO v_tenant_phone FROM auth.users WHERE id = NEW.tenant_user_id;

    IF v_tenant_phone IS NOT NULL AND TRIM(v_tenant_phone) <> '' THEN
        SELECT address INTO v_property_address FROM public.properties WHERE property_id = NEW.property_id;
        IF NOT FOUND THEN
            v_property_address := 'your property (ID ' || NEW.property_id::TEXT || ')';
        END IF;

        INSERT INTO public.service_sms_log (sms_type, to_phone_number, variables)
        VALUES (
            'RENT_DUE',
            v_tenant_phone,
            ARRAY[
                v_property_address,
                to_char(NEW.due_date, 'DD-Mon-YYYY'),
                NEW.amount_due::TEXT
            ]
        );
    ELSE
        RAISE WARNING 'Tenant % for rent record on property % has no phone number. Skipping RENT_DUE SMS.', NEW.tenant_user_id, NEW.property_id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION public.queue_rent_due_sms() IS 'Queues a rent due reminder SMS to the tenant when a new rent record is created for them.';
GRANT EXECUTE ON FUNCTION public.queue_rent_due_sms() TO authenticated;

-- 2. Attach Trigger to the rent_records table
CREATE TRIGGER trigger_queue_rent_due_sms
AFTER INSERT ON public.rent_records
FOR EACH ROW
EXECUTE FUNCTION public.queue_rent_due_sms();

-- ==== Trigger for VISIT_BOOKING_TO_OWNER & VISIT_BOOKING_TO_TENANT ====

-- 1. Trigger Function Definition for Visit Scheduled Event
CREATE OR REPLACE FUNCTION public.queue_visit_scheduled_sms()
RETURNS TRIGGER AS $$
DECLARE
    v_owner_phone TEXT;
    v_customer_phone TEXT;
    v_property_details RECORD;
    v_sales_admin_name TEXT;
BEGIN
    -- This trigger is designed to run only when status changes to 'VISIT_SCHEDULED_WITH_SALES'.

    -- Step 1: Fetch common details (Property Address, Owner ID, Sales Admin Name)
    SELECT
        p.address,
        p.submitter
    INTO v_property_details
    FROM public.properties p
    WHERE p.property_id = NEW.property_id;

    IF NOT FOUND THEN
        RAISE WARNING 'Property % not found for interaction %. Cannot send visit scheduled SMS.', NEW.property_id, NEW.interaction_id;
        RETURN NEW;
    END IF;

    IF NEW.assigned_sales_admin_id IS NOT NULL THEN
        SELECT u.raw_user_meta_data->>'full_name' INTO v_sales_admin_name
        FROM auth.users u
        WHERE u.id = NEW.assigned_sales_admin_id;
    END IF;


    -- Step 2: Queue SMS to the Property Owner
    IF v_property_details.submitter IS NOT NULL THEN
        SELECT phone INTO v_owner_phone FROM auth.users WHERE id = v_property_details.submitter;

        IF v_owner_phone IS NOT NULL AND TRIM(v_owner_phone) <> '' THEN
            INSERT INTO public.service_sms_log (sms_type, to_phone_number, variables)
            VALUES (
                'VISIT_BOOKING_TO_OWNER',
                v_owner_phone,
                ARRAY[
                    v_property_details.address,
                    to_char(NEW.scheduled_for, 'DD-Mon-YYYY')
                ]
            );
        ELSE
            RAISE WARNING 'Owner % of property % has no phone number. Skipping VISIT_BOOKING_TO_OWNER SMS.', v_property_details.submitter, NEW.property_id;
        END IF;
    ELSE
         RAISE WARNING 'Property % has no owner/submitter. Cannot send VISIT_BOOKING_TO_OWNER SMS.', NEW.property_id;
    END IF;


    -- Step 3: Queue SMS to the Customer (prospective tenant)
    SELECT phone INTO v_customer_phone FROM auth.users WHERE id = NEW.user_id;

    IF v_customer_phone IS NOT NULL AND TRIM(v_customer_phone) <> '' THEN
        INSERT INTO public.service_sms_log (sms_type, to_phone_number, variables)
        VALUES (
            'VISIT_BOOKING_TO_TENANT',
            v_customer_phone,
            ARRAY[
                v_property_details.address,
                to_char(NEW.scheduled_for, 'DD-Mon-YYYY'),
                COALESCE(v_sales_admin_name, 'our sales executive') -- Use a fallback if name is missing
            ]
        );
    ELSE
        RAISE WARNING 'Customer % for interaction % has no phone number. Skipping VISIT_BOOKING_TO_TENANT SMS.', NEW.user_id, NEW.interaction_id;
    END IF;


    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION public.queue_visit_scheduled_sms() IS 'Queues SMS notifications to the property owner and the customer when a property visit is scheduled with a sales admin.';
GRANT EXECUTE ON FUNCTION public.queue_visit_scheduled_sms() TO authenticated;


-- 2. Attach the Trigger to the customers_interaction table
CREATE TRIGGER trigger_queue_visit_scheduled_sms
AFTER UPDATE OF status ON public.customers_interaction
FOR EACH ROW
WHEN (OLD.status IS DISTINCT FROM NEW.status AND NEW.status = 'VISIT_SCHEDULED_WITH_SALES')
EXECUTE FUNCTION public.queue_visit_scheduled_sms();

COMMENT ON TRIGGER trigger_queue_visit_scheduled_sms ON public.customers_interaction IS 'After an interaction status is updated to VISIT_SCHEDULED_WITH_SALES, queue SMS notifications.';

-- ==== Trigger for TICKET_ASSIGNED_TO_VENDOR & TICKET_VENDOR_DETAILS_TO_RAISER ====

-- 1. Trigger Function Definition for Ticket Vendor Assignment Event
CREATE OR REPLACE FUNCTION public.queue_vendor_assignment_sms()
RETURNS TRIGGER AS $$
DECLARE
    v_vendor_details RECORD;
    v_raiser_phone TEXT;
BEGIN
    -- This trigger is designed to run only when assigned_to_vendor_id is newly set.

    -- Step 1: Get the assigned vendor's details (phone and company name)
    SELECT phone, company_name
    INTO v_vendor_details
    FROM public.vendors
    WHERE vendor_id = NEW.assigned_to_vendor_id;

    IF NOT FOUND THEN
        RAISE WARNING 'Vendor ID % assigned to ticket % was not found. Cannot send vendor assignment SMS.', NEW.assigned_to_vendor_id, NEW.ticket_id;
        RETURN NEW; -- Exit gracefully
    END IF;


    -- Step 2: Queue SMS to the assigned Vendor
    IF v_vendor_details.phone IS NOT NULL AND TRIM(v_vendor_details.phone) <> '' THEN
        INSERT INTO public.service_sms_log (sms_type, to_phone_number, variables)
        VALUES ('TICKET_ASSIGNED_TO_VENDOR', v_vendor_details.phone, '{}');
    ELSE
        RAISE WARNING 'Vendor % has no phone number. Skipping TICKET_ASSIGNED_TO_VENDOR SMS for ticket %.', NEW.assigned_to_vendor_id, NEW.ticket_id;
    END IF;


    -- Step 3: Get the ticket raiser's phone number
    SELECT phone INTO v_raiser_phone FROM auth.users WHERE id = NEW.raised_by_user_id;

    -- Step 4: Queue SMS to the ticket Raiser with vendor details
    IF v_raiser_phone IS NOT NULL AND TRIM(v_raiser_phone) <> '' THEN
        INSERT INTO public.service_sms_log (sms_type, to_phone_number, variables)
        VALUES (
            'TICKET_VENDOR_DETAILS_TO_RAISER',
            v_raiser_phone,
            ARRAY[
                COALESCE(v_vendor_details.company_name, 'the assigned vendor'),
                NEW.ticket_id::TEXT
            ]
        );
    ELSE
        RAISE WARNING 'Ticket raiser % for ticket % has no phone number. Skipping TICKET_VENDOR_DETAILS_TO_RAISER SMS.', NEW.raised_by_user_id, NEW.ticket_id;
    END IF;


    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION public.queue_vendor_assignment_sms() IS 'Queues SMS notifications to the vendor and the ticket raiser when a ticket is assigned to a vendor.';
GRANT EXECUTE ON FUNCTION public.queue_vendor_assignment_sms() TO authenticated;


-- 2. Attach the Trigger to the tickets table
CREATE TRIGGER trigger_queue_vendor_assignment_sms
AFTER UPDATE OF assigned_to_vendor_id ON public.tickets
FOR EACH ROW
WHEN (OLD.assigned_to_vendor_id IS DISTINCT FROM NEW.assigned_to_vendor_id AND NEW.assigned_to_vendor_id IS NOT NULL)
EXECUTE FUNCTION public.queue_vendor_assignment_sms();

COMMENT ON TRIGGER trigger_queue_vendor_assignment_sms ON public.tickets IS 'After a ticket is assigned to a vendor, queue SMS notifications to both parties.';
