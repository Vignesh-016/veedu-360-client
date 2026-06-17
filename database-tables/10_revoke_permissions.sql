-- FILE NAME: 10_revoke_permissions.sql
-- Description: Revokes direct table access from general roles.
-- Access should be primarily through SECURITY DEFINER functions and RLS policies.
-------------------------------------------------------------------------------

-- Revoke ALL privileges from 'public' role (affects anonymous users)
-- for all tables managed by this application.
REVOKE ALL PRIVILEGES ON TABLE public.admins FROM PUBLIC;
REVOKE ALL PRIVILEGES ON TABLE public.properties FROM PUBLIC;
REVOKE ALL PRIVILEGES ON TABLE public.property_images FROM PUBLIC;
REVOKE ALL PRIVILEGES ON TABLE public.property_documents FROM PUBLIC;
REVOKE ALL PRIVILEGES ON TABLE public.customers FROM PUBLIC;
REVOKE ALL PRIVILEGES ON TABLE public.customer_documents FROM PUBLIC;
REVOKE ALL PRIVILEGES ON TABLE public.customers_interaction FROM PUBLIC;
REVOKE ALL PRIVILEGES ON TABLE public.transactions FROM PUBLIC;
REVOKE ALL PRIVILEGES ON TABLE public.visit_plans FROM PUBLIC;
REVOKE ALL PRIVILEGES ON TABLE public.management_service_plans FROM PUBLIC;
REVOKE ALL PRIVILEGES ON TABLE public.services FROM PUBLIC;
REVOKE ALL PRIVILEGES ON TABLE public.vendors FROM PUBLIC;
REVOKE ALL PRIVILEGES ON TABLE public.vendor_services FROM PUBLIC;
REVOKE ALL PRIVILEGES ON TABLE public.rent_records FROM PUBLIC;
REVOKE ALL PRIVILEGES ON TABLE public.rent_payments FROM PUBLIC;
REVOKE ALL PRIVILEGES ON TABLE public.tickets FROM PUBLIC;
REVOKE ALL PRIVILEGES ON TABLE public.ticket_images FROM PUBLIC;
REVOKE ALL PRIVILEGES ON TABLE public.ticket_comments FROM PUBLIC;
REVOKE ALL PRIVILEGES ON TABLE public.property_owner_contact_assignments FROM PUBLIC;
REVOKE ALL PRIVILEGES ON TABLE public.property_marketing_assignments FROM PUBLIC;
REVOKE ALL PRIVILEGES ON TABLE public.property_visit_assignments FROM PUBLIC;
REVOKE ALL PRIVILEGES ON TABLE public.property_visit_assignment_interactions FROM PUBLIC;
REVOKE ALL PRIVILEGES ON TABLE public.round_robin_state FROM PUBLIC;
REVOKE ALL PRIVILEGES ON TABLE public.otp_sent_log FROM PUBLIC;
REVOKE ALL PRIVILEGES ON TABLE public.rental_applications FROM PUBLIC;
REVOKE ALL PRIVILEGES ON TABLE public.service_sms_log FROM PUBLIC;

-- Revoke ALL privileges from 'authenticated' role (affects logged-in users)
-- for all tables managed by this application.
REVOKE ALL PRIVILEGES ON TABLE public.admins FROM authenticated;
REVOKE ALL PRIVILEGES ON TABLE public.properties FROM authenticated;
REVOKE ALL PRIVILEGES ON TABLE public.property_images FROM authenticated;
REVOKE ALL PRIVILEGES ON TABLE public.property_documents FROM authenticated;
REVOKE ALL PRIVILEGES ON TABLE public.customers FROM authenticated;
REVOKE ALL PRIVILEGES ON TABLE public.customer_documents FROM authenticated;
REVOKE ALL PRIVILEGES ON TABLE public.customers_interaction FROM authenticated;
REVOKE ALL PRIVILEGES ON TABLE public.transactions FROM authenticated;
REVOKE ALL PRIVILEGES ON TABLE public.visit_plans FROM authenticated;
REVOKE ALL PRIVILEGES ON TABLE public.management_service_plans FROM authenticated;
REVOKE ALL PRIVILEGES ON TABLE public.services FROM authenticated;
REVOKE ALL PRIVILEGES ON TABLE public.vendors FROM authenticated;
REVOKE ALL PRIVILEGES ON TABLE public.vendor_services FROM authenticated;
REVOKE ALL PRIVILEGES ON TABLE public.rent_records FROM authenticated;
REVOKE ALL PRIVILEGES ON TABLE public.rent_payments FROM authenticated;
REVOKE ALL PRIVILEGES ON TABLE public.tickets FROM authenticated;
REVOKE ALL PRIVILEGES ON TABLE public.ticket_images FROM authenticated;
REVOKE ALL PRIVILEGES ON TABLE public.ticket_comments FROM authenticated;
REVOKE ALL PRIVILEGES ON TABLE public.property_owner_contact_assignments FROM authenticated;
REVOKE ALL PRIVILEGES ON TABLE public.property_marketing_assignments FROM authenticated;
REVOKE ALL PRIVILEGES ON TABLE public.property_visit_assignments FROM authenticated;
REVOKE ALL PRIVILEGES ON TABLE public.property_visit_assignment_interactions FROM authenticated;
REVOKE ALL PRIVILEGES ON TABLE public.round_robin_state FROM authenticated;
REVOKE ALL PRIVILEGES ON TABLE public.otp_sent_log FROM authenticated;
REVOKE ALL PRIVILEGES ON TABLE public.rental_applications FROM authenticated;
REVOKE ALL PRIVILEGES ON TABLE public.service_sms_log FROM authenticated;

-- === Revoke Specific Function Execution from general roles if needed ===
-- Most functions are SECURITY DEFINER, so direct execution grants are primary.
-- However, if any SECURITY INVOKER functions exist that shouldn't be callable by default:
-- REVOKE EXECUTE ON FUNCTION some_security_invoker_function(params) FROM public, authenticated;

-- Revoke execution of critical payment functions from non-privileged roles.
-- These should only be called by the function owner (postgres) or a trusted backend service role.
REVOKE EXECUTE ON FUNCTION public.update_transaction_status(TEXT, TEXT, TEXT, TEXT, TEXT) FROM public, authenticated;
REVOKE EXECUTE ON FUNCTION public.complete_purchase(TEXT) FROM public, authenticated;
GRANT EXECUTE ON FUNCTION public.update_transaction_status(TEXT, TEXT, TEXT, TEXT, TEXT) TO service_role;
GRANT EXECUTE ON FUNCTION public.complete_purchase(TEXT) TO service_role;

-- Note:
-- 1. RLS policies (07_rls_policies.sql) are the primary mechanism for controlling data access
--    after these broad revokes.
-- 2. The 'postgres' superuser and roles with explicit GRANTS (like 'service_role' if used)
--    will retain their privileges.
-- 3. Access to data is now intended to be almost exclusively through the defined SQL functions
--    and controlled by RLS.

GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.round_robin_state TO postgres; -- If cron runs as postgres