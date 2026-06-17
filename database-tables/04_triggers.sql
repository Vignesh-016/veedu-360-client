-------------------------------------------------------------------------------
-- File: 04_triggers.sql
-- Description: Attaches triggers to tables (Post-Upgrade Plan).
-------------------------------------------------------------------------------

-- Properties
CREATE TRIGGER trigger_set_timestamp_before_update
BEFORE UPDATE ON public.properties
FOR EACH ROW EXECUTE FUNCTION public.set_current_timestamp_updated_at();

-- Property Images
CREATE TRIGGER trigger_set_timestamp_before_update
BEFORE UPDATE ON public.property_images
FOR EACH ROW EXECUTE FUNCTION public.set_current_timestamp_updated_at();

-- Customers
CREATE TRIGGER trigger_set_timestamp_before_update
BEFORE UPDATE ON public.customers
FOR EACH ROW EXECUTE FUNCTION public.set_current_timestamp_updated_at();

-- Customer Interactions
CREATE TRIGGER trigger_set_timestamp_before_update
BEFORE UPDATE ON public.customers_interaction
FOR EACH ROW EXECUTE FUNCTION public.set_current_timestamp_updated_at();

-- Visit Plans
CREATE TRIGGER trigger_set_timestamp_before_update
BEFORE UPDATE ON public.visit_plans
FOR EACH ROW EXECUTE FUNCTION public.set_current_timestamp_updated_at();

-- Transactions
CREATE TRIGGER trigger_set_timestamp_before_update
BEFORE UPDATE ON public.transactions
FOR EACH ROW EXECUTE FUNCTION public.set_current_timestamp_updated_at();

-- Vendors
CREATE TRIGGER trigger_set_timestamp_before_update
BEFORE UPDATE ON public.vendors
FOR EACH ROW EXECUTE FUNCTION public.set_current_timestamp_updated_at();

-- Management Service Plans
CREATE TRIGGER trigger_set_timestamp_before_update
BEFORE UPDATE ON public.management_service_plans
FOR EACH ROW EXECUTE FUNCTION public.set_current_timestamp_updated_at();

-- Rent Records
CREATE TRIGGER trigger_set_timestamp_before_update
BEFORE UPDATE ON public.rent_records
FOR EACH ROW EXECUTE FUNCTION public.set_current_timestamp_updated_at();

-- Tickets
CREATE TRIGGER trigger_set_timestamp_before_update
BEFORE UPDATE ON public.tickets
FOR EACH ROW EXECUTE FUNCTION public.set_current_timestamp_updated_at();

-- Admins
CREATE TRIGGER trigger_set_timestamp_before_update
BEFORE UPDATE ON public.admins
FOR EACH ROW EXECUTE FUNCTION public.set_current_timestamp_updated_at();

-- Property Documents
CREATE TRIGGER trigger_set_timestamp_before_update
BEFORE UPDATE ON public.property_documents
FOR EACH ROW EXECUTE FUNCTION public.set_current_timestamp_updated_at();

-- Customer Documents
CREATE TRIGGER trigger_set_timestamp_before_update
BEFORE UPDATE ON public.customer_documents
FOR EACH ROW EXECUTE FUNCTION public.set_current_timestamp_updated_at();

-- Property Visit Assignments
CREATE TRIGGER trigger_set_timestamp_before_update
BEFORE UPDATE ON public.property_visit_assignments
FOR EACH ROW EXECUTE FUNCTION public.set_current_timestamp_updated_at();

-- Trigger to create customer profile on new user signup
CREATE TRIGGER on_auth_user_created
AFTER INSERT ON auth.users
FOR EACH ROW EXECUTE FUNCTION public.create_customer_for_new_user();

-- Trigger to set resolved_at/closed_at based on ticket status changes
CREATE TRIGGER trigger_update_ticket_completion_timestamps
BEFORE UPDATE ON public.tickets
FOR EACH ROW
WHEN (OLD.status IS DISTINCT FROM NEW.status)
EXECUTE FUNCTION public.update_ticket_completion_timestamps();

-- Trigger to update rent record status after a payment is inserted or updated (or deleted - handled by function)
CREATE TRIGGER trigger_update_rent_record_after_payment_insert
AFTER INSERT ON public.rent_payments
FOR EACH ROW
EXECUTE FUNCTION public.update_rent_record_on_payment();

CREATE TRIGGER trigger_update_rent_record_after_payment_update
AFTER UPDATE OF amount ON public.rent_payments -- Only if amount changes
FOR EACH ROW
EXECUTE FUNCTION public.update_rent_record_on_payment();

-- Trigger to verify the ticket raiser is the tenant (or owner)
CREATE TRIGGER trigger_check_ticket_raiser
BEFORE INSERT ON public.tickets
FOR EACH ROW
EXECUTE FUNCTION public.check_ticket_raiser_is_tenant();


-- Trigger to automatically update 'updated_at'
CREATE TRIGGER trigger_set_timestamp_before_update_round_robin_state
BEFORE UPDATE ON public.round_robin_state
FOR EACH ROW EXECUTE FUNCTION public.set_current_timestamp_updated_at();

-- Trigger function to update 'status_updated_at' when status changes
CREATE OR REPLACE FUNCTION public.set_current_timestamp_status_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.status_updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
COMMENT ON FUNCTION public.set_current_timestamp_status_updated_at() IS 'Sets the status_updated_at field to the current timestamp.';

-- Apply trigger to update 'updated_at' on any row update
CREATE TRIGGER trigger_rental_applications_set_updated_at
BEFORE UPDATE ON public.rental_applications
FOR EACH ROW
EXECUTE FUNCTION public.set_current_timestamp_updated_at();
COMMENT ON TRIGGER trigger_rental_applications_set_updated_at ON public.rental_applications IS 'Automatically updates the updated_at timestamp on row modification.';

-- Apply trigger to update 'status_updated_at' ONLY when the 'status' column changes
CREATE TRIGGER trigger_rental_applications_set_status_updated_at
BEFORE UPDATE OF status ON public.rental_applications
FOR EACH ROW
WHEN (OLD.status IS DISTINCT FROM NEW.status)
EXECUTE FUNCTION public.set_current_timestamp_status_updated_at();
COMMENT ON TRIGGER trigger_rental_applications_set_status_updated_at ON public.rental_applications IS 'Automatically updates the status_updated_at timestamp only when the application status changes.';

-- Service SMS Log
CREATE TRIGGER trigger_set_timestamp_before_update
BEFORE UPDATE ON public.service_sms_log
FOR EACH ROW EXECUTE FUNCTION public.set_current_timestamp_updated_at();