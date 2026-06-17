-------------------------------------------------------------------------------
-- File: 03_helper_functions.sql
-- Description: Core helper functions (Post-Upgrade Plan).
-------------------------------------------------------------------------------

-- Trigger function to update the 'updated_at' column
CREATE OR REPLACE FUNCTION public.set_current_timestamp_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger function to create a customer record for a new user
CREATE OR REPLACE FUNCTION public.create_customer_for_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.customers (user_id)
    VALUES (NEW.id)
    ON CONFLICT (user_id) DO NOTHING;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Helper function to check if the current user is an active admin
CREATE OR REPLACE FUNCTION public.current_user_is_admin()
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1
        FROM public.admins adm
        WHERE adm.user_id = auth.uid() AND adm.is_active = TRUE
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;
GRANT EXECUTE ON FUNCTION public.current_user_is_admin() TO authenticated;

-- Helper function to check if the current user is an active admin with a specific role
CREATE OR REPLACE FUNCTION public.current_user_has_role(p_role public.admin_role_enum)
RETURNS BOOLEAN AS $$
BEGIN
    IF NOT public.current_user_is_admin() THEN
        RETURN FALSE;
    END IF;
    RETURN EXISTS (
        SELECT 1
        FROM public.admins adm
        WHERE adm.user_id = auth.uid() AND p_role = ANY(adm.roles)
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;
GRANT EXECUTE ON FUNCTION public.current_user_has_role(public.admin_role_enum) TO authenticated;

-- Helper function to check if a specific user is an active admin with a specific role
CREATE OR REPLACE FUNCTION public.user_is_admin_with_role(p_user_id UUID, p_role public.admin_role_enum)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1
        FROM public.admins adm
        WHERE adm.user_id = p_user_id AND adm.is_active = TRUE AND p_role = ANY(adm.roles)
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;
GRANT EXECUTE ON FUNCTION public.user_is_admin_with_role(UUID, public.admin_role_enum) TO authenticated;


-- Helper function to check if a user is the property submitter/owner
CREATE OR REPLACE FUNCTION public.check_user_is_property_submitter(p_property_id UUID, p_user_id UUID DEFAULT auth.uid())
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1
        FROM public.properties p
        WHERE p.property_id = p_property_id AND p.submitter = p_user_id
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;
GRANT EXECUTE ON FUNCTION public.check_user_is_property_submitter(UUID, UUID) TO authenticated;


-- Helper function to check if a user is the property tenant
CREATE OR REPLACE FUNCTION public.check_user_is_property_tenant(p_property_id UUID, p_user_id UUID DEFAULT auth.uid())
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1
        FROM public.properties p
        WHERE p.property_id = p_property_id AND p.tenant = p_user_id
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;
GRANT EXECUTE ON FUNCTION public.check_user_is_property_tenant(UUID, UUID) TO authenticated;


-- Helper function to check if a user can access a specific ticket
CREATE OR REPLACE FUNCTION public.check_user_can_access_ticket(p_ticket_id BIGINT, p_user_id UUID DEFAULT auth.uid())
RETURNS BOOLEAN AS $$
DECLARE
    v_ticket_property_id UUID;
    v_ticket_raiser_id UUID;
BEGIN
    -- Admins with specific roles can access all tickets, or tickets based on assignment.
    -- Super-admin has blanket access.
    -- Telecalling teams can access all tickets (as per plan).
    -- Marketing/Sales/Accounts might have more restricted access based on property or assignment if needed,
    -- but for now, let's give broader access to ticket-handling roles.
    IF public.user_is_admin_with_role(p_user_id, 'super-admin') OR
       public.user_is_admin_with_role(p_user_id, 'telecalling-owner-team') OR
       public.user_is_admin_with_role(p_user_id, 'telecalling-tenant-team') THEN
        RETURN TRUE;
    END IF;

    SELECT t.property_id, t.raised_by_user_id, t.assigned_support_admin_id
    INTO v_ticket_property_id, v_ticket_raiser_id
    FROM public.tickets t
    WHERE t.ticket_id = p_ticket_id;

    IF NOT FOUND THEN
        RETURN FALSE; -- Ticket doesn't exist
    END IF;

    -- If the user is the one who raised the ticket
    IF v_ticket_raiser_id = p_user_id THEN
        RETURN TRUE;
    END IF;

    -- If the user is the owner (submitter) of the property related to the ticket
    IF public.check_user_is_property_submitter(v_ticket_property_id, p_user_id) THEN
        RETURN TRUE;
    END IF;

    -- If the user is the current tenant of the property related to the ticket
    -- (This check is technically covered by raised_by_user_id IF the ticket raiser is always the current tenant,
    -- but kept for robustness if other users could raise tickets on behalf of tenant in future)
    IF public.check_user_is_property_tenant(v_ticket_property_id, p_user_id) THEN
        RETURN TRUE;
    END IF;

    -- If the ticket is assigned to this admin (who might not be super-admin or telecaller)
    IF EXISTS (SELECT 1 FROM public.tickets t WHERE t.ticket_id = p_ticket_id AND t.assigned_support_admin_id = p_user_id) THEN
        RETURN TRUE;
    END IF;

    RETURN FALSE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;
GRANT EXECUTE ON FUNCTION public.check_user_can_access_ticket(BIGINT, UUID) TO authenticated;


-- Trigger function to update rent record status after payment
CREATE OR REPLACE FUNCTION public.update_rent_record_on_payment()
RETURNS TRIGGER AS $$
DECLARE
    v_rent_record_id UUID := NEW.rent_record_id;
    v_total_paid DECIMAL;
    v_amount_due DECIMAL;
    v_current_status public.rent_status_enum;
BEGIN
    SELECT SUM(amount)
    INTO v_total_paid
    FROM public.rent_payments
    WHERE rent_record_id = v_rent_record_id;

    SELECT amount_due, status
    INTO v_amount_due, v_current_status
    FROM public.rent_records
    WHERE rent_record_id = v_rent_record_id;

    UPDATE public.rent_records
    SET amount_paid = COALESCE(v_total_paid, 0.00) -- Ensure amount_paid is not NULL
    WHERE rent_record_id = v_rent_record_id;

    IF v_current_status <> 'CANCELLED' THEN
        IF COALESCE(v_total_paid, 0.00) >= v_amount_due THEN
            UPDATE public.rent_records
            SET status = 'PAID'
            WHERE rent_record_id = v_rent_record_id;
        ELSIF COALESCE(v_total_paid, 0.00) > 0 AND COALESCE(v_total_paid, 0.00) < v_amount_due THEN
            UPDATE public.rent_records
            SET status = 'PARTIALLY_PAID'
            WHERE rent_record_id = v_rent_record_id AND status <> 'PAID';
        ELSIF COALESCE(v_total_paid, 0.00) = 0.00 AND v_current_status <> 'DUE' AND v_current_status <> 'OVERDUE' THEN
             -- If all payments are removed, revert to DUE unless it was already OVERDUE
            IF (SELECT due_date FROM public.rent_records WHERE rent_record_id = v_rent_record_id) < CURRENT_DATE THEN
                 UPDATE public.rent_records SET status = 'OVERDUE' WHERE rent_record_id = v_rent_record_id;
            ELSE
                 UPDATE public.rent_records SET status = 'DUE' WHERE rent_record_id = v_rent_record_id;
            END IF;
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- Trigger function to update ticket completion timestamps
CREATE OR REPLACE FUNCTION public.update_ticket_completion_timestamps()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.status = 'RESOLVED' AND OLD.status <> 'RESOLVED' THEN
        NEW.resolved_at = CURRENT_TIMESTAMP;
    ELSIF NEW.status <> 'RESOLVED' AND OLD.status = 'RESOLVED' THEN
        NEW.resolved_at = NULL; -- Allow un-resolving
    END IF;

    IF NEW.status IN ('CLOSED', 'CANCELLED') AND OLD.status NOT IN ('CLOSED', 'CANCELLED') THEN
        NEW.closed_at = CURRENT_TIMESTAMP;
        IF NEW.resolved_at IS NULL AND NEW.status = 'CLOSED' THEN -- Only set resolved_at if closing a non-resolved ticket
             NEW.resolved_at = CURRENT_TIMESTAMP;
        END IF;
    ELSIF NEW.status NOT IN ('CLOSED', 'CANCELLED') AND OLD.status IN ('CLOSED', 'CANCELLED') THEN
        NEW.closed_at = NULL; -- Allow re-opening
        -- If re-opening from CANCELLED, resolved_at might need to be cleared if it was set due to cancellation.
        -- If re-opening from CLOSED, resolved_at might remain if it was genuinely resolved.
        -- For simplicity, if not 'RESOLVED', 'CLOSED', or 'CANCELLED', clear closed_at.
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


-- Trigger function to check if ticket raiser is the property owner or tenant
CREATE OR REPLACE FUNCTION public.check_ticket_raiser_is_tenant()
RETURNS TRIGGER AS $$
DECLARE
    v_property_submitter_id UUID;
    v_property_tenant_id UUID;
BEGIN
    SELECT submitter, tenant
    INTO v_property_submitter_id, v_property_tenant_id
    FROM public.properties
    WHERE property_id = NEW.property_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Property ID % not found when attempting to create a ticket.', NEW.property_id;
        RETURN NULL; 
    END IF;

    -- Check if the ticket raiser is the property owner (submitter)
    IF NEW.raised_by_user_id IS NOT NULL AND NEW.raised_by_user_id = v_property_submitter_id THEN
        RETURN NEW;
    END IF;

    -- Check if the ticket raiser is the current tenant of the property
    IF v_property_tenant_id IS NOT NULL AND NEW.raised_by_user_id IS NOT NULL AND NEW.raised_by_user_id = v_property_tenant_id THEN
        RETURN NEW;
    END IF;
    
    -- If the raiser is neither the owner nor the tenant, raise an exception.
    RAISE EXCEPTION 'User % is not authorized to raise a ticket for property %. Only the property owner or current tenant can raise tickets.',
        NEW.raised_by_user_id, NEW.property_id;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Helper function to get the roles of the currently authenticated admin user
CREATE OR REPLACE FUNCTION public.get_my_admin_roles()
RETURNS public.admin_role_enum[] AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_admin_roles public.admin_role_enum[];
BEGIN
    SELECT roles
    INTO v_admin_roles
    FROM public.admins
    WHERE user_id = v_user_id AND is_active = TRUE;

    IF NOT FOUND THEN
        RETURN '{}'::public.admin_role_enum[];
    END IF;

    RETURN COALESCE(v_admin_roles, '{}'::public.admin_role_enum[]);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

-- Grant execution to authenticated users (admins)
GRANT EXECUTE ON FUNCTION public.get_my_admin_roles() TO authenticated;