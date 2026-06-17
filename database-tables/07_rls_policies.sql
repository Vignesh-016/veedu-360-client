-- Description: Row Level Security policies for all tables.
-------------------------------------------------------------------------------

-- Enable RLS on all relevant tables
ALTER TABLE public.admins ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.properties ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.property_images ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.property_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.customer_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.customers_interaction ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.visit_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.management_service_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.services ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vendors ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vendor_services ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rent_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rent_payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tickets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ticket_images ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ticket_comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.property_owner_contact_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.property_marketing_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.property_visit_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.property_visit_assignment_interactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.round_robin_state ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.otp_sent_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rental_applications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.service_sms_log ENABLE ROW LEVEL SECURITY;

-- Force RLS for table owners (good practice)
ALTER TABLE public.admins FORCE ROW LEVEL SECURITY;
ALTER TABLE public.properties FORCE ROW LEVEL SECURITY;
ALTER TABLE public.property_images FORCE ROW LEVEL SECURITY;
ALTER TABLE public.property_documents FORCE ROW LEVEL SECURITY;
ALTER TABLE public.customers FORCE ROW LEVEL SECURITY;
ALTER TABLE public.customer_documents FORCE ROW LEVEL SECURITY;
ALTER TABLE public.customers_interaction FORCE ROW LEVEL SECURITY;
ALTER TABLE public.transactions FORCE ROW LEVEL SECURITY;
ALTER TABLE public.visit_plans FORCE ROW LEVEL SECURITY;
ALTER TABLE public.management_service_plans FORCE ROW LEVEL SECURITY;
ALTER TABLE public.services FORCE ROW LEVEL SECURITY;
ALTER TABLE public.vendors FORCE ROW LEVEL SECURITY;
ALTER TABLE public.vendor_services FORCE ROW LEVEL SECURITY;
ALTER TABLE public.rent_records FORCE ROW LEVEL SECURITY;
ALTER TABLE public.rent_payments FORCE ROW LEVEL SECURITY;
ALTER TABLE public.tickets FORCE ROW LEVEL SECURITY;
ALTER TABLE public.ticket_images FORCE ROW LEVEL SECURITY;
ALTER TABLE public.ticket_comments FORCE ROW LEVEL SECURITY;
ALTER TABLE public.property_owner_contact_assignments FORCE ROW LEVEL SECURITY;
ALTER TABLE public.property_marketing_assignments FORCE ROW LEVEL SECURITY;
ALTER TABLE public.property_visit_assignments FORCE ROW LEVEL SECURITY;
ALTER TABLE public.property_visit_assignment_interactions FORCE ROW LEVEL SECURITY;
ALTER TABLE public.round_robin_state FORCE ROW LEVEL SECURITY;
ALTER TABLE public.otp_sent_log FORCE ROW LEVEL SECURITY;
ALTER TABLE public.rental_applications FORCE ROW LEVEL SECURITY;
ALTER TABLE public.service_sms_log FORCE ROW LEVEL SECURITY;

--- ==== Policies for 'public.admins' table ====
-- Super-admins can see all admin records
CREATE POLICY admins_select_super_admin ON public.admins
    FOR SELECT TO authenticated USING (public.current_user_has_role('super-admin'));

-- Admins can see their own record
CREATE POLICY admins_select_own ON public.admins
    FOR SELECT TO authenticated USING (user_id = auth.uid());

-- Only super-admins can insert/update/delete admin records (via functions)
CREATE POLICY admins_modify_super_admin ON public.admins
    FOR ALL TO authenticated
    USING (public.current_user_has_role('super-admin'))
    WITH CHECK (public.current_user_has_role('super-admin'));


--- ==== Policies for 'public.properties' table ====
-- Super-admins have full access.
CREATE POLICY properties_all_access_super_admin ON public.properties
    FOR ALL TO authenticated
    USING (public.current_user_has_role('super-admin'))
    WITH CHECK (public.current_user_has_role('super-admin'));

-- Authenticated users (customers) can see publicly listed properties.
CREATE POLICY properties_select_listed_for_authenticated ON public.properties
    FOR SELECT TO authenticated
    USING (is_listed = TRUE);

-- Anonymous users can see publicly listed properties.
CREATE POLICY properties_select_listed_for_anon ON public.properties
    FOR SELECT TO anon
    USING (is_listed = TRUE);

-- Property submitters (owners) can view their own properties regardless of status.
CREATE POLICY properties_select_own_by_submitter ON public.properties
    FOR SELECT TO authenticated
    USING (submitter = auth.uid());

-- Tenants can view properties they currently occupy if not in a fully inactive state.
CREATE POLICY properties_select_occupied_by_tenant ON public.properties
    FOR SELECT TO authenticated
    USING (tenant = auth.uid() AND admin_status NOT IN ('REJECTED', 'SOLD'));

-- Admins with specific roles can view properties based on workflow status or assignment
CREATE POLICY properties_select_telecalling_owner_team ON public.properties
    FOR SELECT TO authenticated
    USING (
        public.current_user_has_role('telecalling-owner-team') AND
        (admin_status IN ('SUBMITTED', 'OWNER_CONTACT_PENDING') OR
         EXISTS (SELECT 1 FROM public.property_owner_contact_assignments poca WHERE poca.property_id = properties.property_id AND poca.assigned_admin_id = auth.uid()))
    );

CREATE POLICY properties_select_marketing_team ON public.properties
    FOR SELECT TO authenticated
    USING (
        public.current_user_has_role('marketing-team') AND
        (admin_status IN ('OWNER_VERIFIED', 'MARKETING_VISIT_PENDING') OR
         EXISTS (SELECT 1 FROM public.property_marketing_assignments pma WHERE pma.property_id = properties.property_id AND pma.assigned_admin_id = auth.uid()))
    );

-- Sales team can view properties relevant to their assigned visits
CREATE POLICY properties_select_sales_team_for_visits ON public.properties
    FOR SELECT TO authenticated
    USING (
        public.current_user_has_role('sales-team') AND
        EXISTS (
            SELECT 1 FROM public.property_visit_assignments pva
            JOIN public.property_visit_assignment_interactions pvai ON pva.visit_assignment_id = pvai.visit_assignment_id
            JOIN public.customers_interaction ci ON pvai.interaction_id = ci.interaction_id
            WHERE pva.assigned_sales_admin_id = auth.uid() AND ci.property_id = properties.property_id
        )
    );

-- Accounts team can view rental properties with tenants.
CREATE POLICY properties_select_accounts_team_rentals ON public.properties
    FOR SELECT TO authenticated
    USING (
        public.current_user_has_role('accounts-team') AND
        listing_type = 'RENTAL' AND tenant IS NOT NULL
    );

-- Authenticated users can insert properties (via function which sets submitter = auth.uid(), admin_status='SUBMITTED').
CREATE POLICY properties_insert_authenticated_user ON public.properties
    FOR INSERT TO authenticated
    WITH CHECK (submitter = auth.uid());

-- Property submitters can update their properties only if in SUBMITTED or REJECTED status (via function).
CREATE POLICY properties_update_own_by_submitter_conditional ON public.properties
    FOR UPDATE TO authenticated
    USING (submitter = auth.uid() AND admin_status IN ('SUBMITTED', 'REJECTED'))
    WITH CHECK (submitter = auth.uid() AND admin_status = 'SUBMITTED'); -- On update, function resets to SUBMITTED

-- Admins can update properties (granularity handled by functions and role checks within them)
CREATE POLICY properties_update_admin_teams ON public.properties
    FOR UPDATE TO authenticated
    USING (
        (public.current_user_has_role('telecalling-owner-team') AND EXISTS (SELECT 1 FROM public.property_owner_contact_assignments poca WHERE poca.property_id = properties.property_id AND poca.assigned_admin_id = auth.uid())) OR
        (public.current_user_has_role('marketing-team') AND EXISTS (SELECT 1 FROM public.property_marketing_assignments pma WHERE pma.property_id = properties.property_id AND pma.assigned_admin_id = auth.uid())) OR
        (public.current_user_has_role('accounts-team')) -- Accounts might update financial details
    )
    WITH CHECK ( -- Further restrict what specific roles can update if needed, or rely on functions
        (public.current_user_has_role('telecalling-owner-team') AND EXISTS (SELECT 1 FROM public.property_owner_contact_assignments poca WHERE poca.property_id = properties.property_id AND poca.assigned_admin_id = auth.uid())) OR
        (public.current_user_has_role('marketing-team') AND EXISTS (SELECT 1 FROM public.property_marketing_assignments pma WHERE pma.property_id = properties.property_id AND pma.assigned_admin_id = auth.uid())) OR
        (public.current_user_has_role('accounts-team'))
    );


--- ==== Policies for 'public.property_images' table ====
-- Super-admins have full access.
CREATE POLICY property_images_all_access_super_admin ON public.property_images
    FOR ALL TO authenticated USING (public.current_user_has_role('super-admin')) WITH CHECK (public.current_user_has_role('super-admin'));

-- Public (anon & authenticated) can see non-internal images for publicly listed properties.
CREATE POLICY property_images_select_public_for_listed ON public.property_images
    FOR SELECT TO public
    USING (is_internal_image = FALSE AND EXISTS (SELECT 1 FROM public.properties p WHERE p.property_id = property_images.property_id AND p.is_listed = TRUE));

-- Property submitters can view all their images (internal or not).
CREATE POLICY property_images_select_all_for_submitter ON public.property_images
    FOR SELECT TO authenticated
    USING (EXISTS (SELECT 1 FROM public.properties p WHERE p.property_id = property_images.property_id AND p.submitter = auth.uid()));

-- Admins involved in property workflow (telecalling-owner, marketing) can see all images for properties they manage/can see.
CREATE POLICY property_images_select_workflow_admins ON public.property_images
    FOR SELECT TO authenticated
    USING (
        (public.current_user_has_role('telecalling-owner-team') AND EXISTS (SELECT 1 FROM public.properties p WHERE p.property_id = property_images.property_id AND p.admin_status IN ('SUBMITTED', 'OWNER_CONTACT_PENDING', 'OWNER_VERIFIED'))) OR
        (public.current_user_has_role('marketing-team') AND EXISTS (SELECT 1 FROM public.properties p WHERE p.property_id = property_images.property_id AND p.admin_status IN ('OWNER_VERIFIED', 'MARKETING_VISIT_PENDING', 'MARKETING_VERIFIED')))
    );

-- Authenticated users (submitters) can insert images for their properties if editable (via function).
CREATE POLICY property_images_insert_for_submitter ON public.property_images
    FOR INSERT TO authenticated
    WITH CHECK (
        EXISTS (SELECT 1 FROM public.properties p WHERE p.property_id = property_images.property_id AND p.submitter = auth.uid() AND p.admin_status IN ('SUBMITTED', 'REJECTED')) AND
        (uploaded_by = auth.uid() OR public.current_user_is_admin()) -- Allow admin to upload on behalf if uploaded_by is admin
    );

-- Admins can insert images for properties they manage (via function where uploaded_by is admin_id).
CREATE POLICY property_images_insert_for_admin ON public.property_images
    FOR INSERT TO authenticated
    WITH CHECK (
        public.current_user_is_admin() AND uploaded_by = auth.uid() AND (
            (public.current_user_has_role('telecalling-owner-team') AND EXISTS (SELECT 1 FROM public.properties p WHERE p.property_id = property_images.property_id AND (p.admin_status IN ('SUBMITTED', 'OWNER_CONTACT_PENDING', 'OWNER_VERIFIED') OR (SELECT poca.assigned_admin_id FROM public.property_owner_contact_assignments poca WHERE poca.property_id = p.property_id) = auth.uid())) ) OR
            (public.current_user_has_role('marketing-team') AND EXISTS (SELECT 1 FROM public.properties p WHERE p.property_id = property_images.property_id AND (p.admin_status IN ('OWNER_VERIFIED', 'MARKETING_VISIT_PENDING', 'MARKETING_VERIFIED') OR (SELECT pma.assigned_admin_id FROM public.property_marketing_assignments pma WHERE pma.property_id = p.property_id) = auth.uid())) )
        )
    );

-- Update/Delete policies follow similar logic: submitter for editable props, or relevant admin for assigned/workflow props.
CREATE POLICY property_images_update_conditional ON public.property_images
    FOR UPDATE TO authenticated
    USING (
        (EXISTS (SELECT 1 FROM public.properties p WHERE p.property_id = property_images.property_id AND p.submitter = auth.uid() AND p.admin_status IN ('SUBMITTED', 'REJECTED'))) OR
        (public.current_user_is_admin() AND uploaded_by = auth.uid()) -- Admin can update images they uploaded
    )
    WITH CHECK (
        (EXISTS (SELECT 1 FROM public.properties p WHERE p.property_id = property_images.property_id AND p.submitter = auth.uid() AND p.admin_status IN ('SUBMITTED', 'REJECTED'))) OR
        (public.current_user_is_admin() AND uploaded_by = auth.uid())
    );

CREATE POLICY property_images_delete_conditional ON public.property_images
    FOR DELETE TO authenticated
    USING (
        (EXISTS (SELECT 1 FROM public.properties p WHERE p.property_id = property_images.property_id AND p.submitter = auth.uid() AND p.admin_status IN ('SUBMITTED', 'REJECTED'))) OR
        (public.current_user_is_admin() AND uploaded_by = auth.uid()) -- Admin can delete images they uploaded
    );


--- ==== Policies for 'public.property_documents' & 'public.customer_documents' ====
-- Super-admins have full access.
CREATE POLICY property_documents_all_access_super_admin ON public.property_documents
    FOR ALL TO authenticated USING (public.current_user_has_role('super-admin')) WITH CHECK (public.current_user_has_role('super-admin'));
CREATE POLICY customer_documents_all_access_super_admin ON public.customer_documents
    FOR ALL TO authenticated USING (public.current_user_has_role('super-admin')) WITH CHECK (public.current_user_has_role('super-admin'));

-- Relevant admins (telecalling-owner, marketing for property; telecalling teams for customer) can manage.
CREATE POLICY property_documents_manage_workflow_admins ON public.property_documents
    FOR ALL TO authenticated
    USING (public.current_user_is_admin() AND uploaded_by = auth.uid() AND (public.current_user_has_role('telecalling-owner-team') OR public.current_user_has_role('marketing-team')))
    WITH CHECK (public.current_user_is_admin() AND uploaded_by = auth.uid() AND (public.current_user_has_role('telecalling-owner-team') OR public.current_user_has_role('marketing-team')));

CREATE POLICY customer_documents_manage_workflow_admins ON public.customer_documents
    FOR ALL TO authenticated
    USING (public.current_user_is_admin() AND uploaded_by = auth.uid() AND (public.current_user_has_role('telecalling-owner-team') OR public.current_user_has_role('telecalling-tenant-team')))
    WITH CHECK (public.current_user_is_admin() AND uploaded_by = auth.uid() AND (public.current_user_has_role('telecalling-owner-team') OR public.current_user_has_role('telecalling-tenant-team')));

-- Owners can see their property documents. Customers can see their own documents.
CREATE POLICY property_documents_select_owner ON public.property_documents
    FOR SELECT TO authenticated
    USING (EXISTS (SELECT 1 FROM public.properties p WHERE p.property_id = property_documents.property_id AND p.submitter = auth.uid()));
CREATE POLICY customer_documents_select_own ON public.customer_documents
    FOR SELECT TO authenticated
    USING (user_id = auth.uid());


--- ==== Policies for 'public.customers' table ====
-- Super-admin and relevant telecalling teams can select/update.
CREATE POLICY customers_select_relevant_admin ON public.customers
    FOR SELECT TO authenticated
    USING (public.current_user_has_role('super-admin') OR public.current_user_has_role('telecalling-owner-team') OR public.current_user_has_role('telecalling-tenant-team'));
CREATE POLICY customers_update_relevant_admin ON public.customers
    FOR UPDATE TO authenticated
    USING (public.current_user_has_role('super-admin') OR public.current_user_has_role('telecalling-owner-team') OR public.current_user_has_role('telecalling-tenant-team'))
    WITH CHECK (public.current_user_has_role('super-admin') OR public.current_user_has_role('telecalling-owner-team') OR public.current_user_has_role('telecalling-tenant-team'));
-- Customers can see their own record.
CREATE POLICY customers_select_own ON public.customers
    FOR SELECT TO authenticated USING (user_id = auth.uid());
-- Insert handled by trigger on auth.users.


--- ==== Policies for 'public.customers_interaction' table ====
-- Super-admins have full access.
CREATE POLICY cust_interaction_all_access_super_admin ON public.customers_interaction
    FOR ALL TO authenticated USING (public.current_user_has_role('super-admin')) WITH CHECK (public.current_user_has_role('super-admin'));
-- Users can manage their own interactions (insert via function, select own, delete if wishlisted/pending).
CREATE POLICY cust_interaction_select_own ON public.customers_interaction
    FOR SELECT TO authenticated USING (user_id = auth.uid());
CREATE POLICY cust_interaction_insert_own ON public.customers_interaction
    FOR INSERT TO authenticated WITH CHECK (user_id = auth.uid());
CREATE POLICY cust_interaction_delete_own_conditional ON public.customers_interaction
    FOR DELETE TO authenticated USING (user_id = auth.uid() AND status IN ('WISHLISTED', 'VISIT_PENDING'));
-- Telecalling-tenant team can manage interactions they are assigned to or that are in VISIT_PENDING status.
CREATE POLICY cust_interaction_manage_tt_team ON public.customers_interaction
    FOR ALL TO authenticated
    USING (public.current_user_has_role('telecalling-tenant-team') AND (assigned_tenant_telecaller_id = auth.uid() OR status = 'VISIT_PENDING'))
    WITH CHECK (public.current_user_has_role('telecalling-tenant-team'));
-- Sales team can manage interactions assigned to them or relevant to their visit assignments.
CREATE POLICY cust_interaction_manage_sales_team ON public.customers_interaction
    FOR ALL TO authenticated
    USING (public.current_user_has_role('sales-team') AND assigned_sales_admin_id = auth.uid()) -- Or based on property_visit_assignments
    WITH CHECK (public.current_user_has_role('sales-team'));


--- ==== Policies for 'public.transactions', 'public.visit_plans', 'public.management_service_plans' ====
-- Super-admin & Accounts team full access.
CREATE POLICY transactions_manage_accounts_super_admin ON public.transactions
    FOR ALL TO authenticated USING (public.current_user_has_role('super-admin') OR public.current_user_has_role('accounts-team')) WITH CHECK (public.current_user_has_role('super-admin') OR public.current_user_has_role('accounts-team'));
CREATE POLICY visit_plans_manage_accounts_super_admin ON public.visit_plans
    FOR ALL TO authenticated USING (public.current_user_has_role('super-admin') OR public.current_user_has_role('accounts-team')) WITH CHECK (public.current_user_has_role('super-admin') OR public.current_user_has_role('accounts-team'));
CREATE POLICY mgmt_plans_manage_accounts_super_admin ON public.management_service_plans
    FOR ALL TO authenticated USING (public.current_user_has_role('super-admin') OR public.current_user_has_role('accounts-team')) WITH CHECK (public.current_user_has_role('super-admin') OR public.current_user_has_role('accounts-team'));
-- Users can see their own transactions and active visit/management plans.
CREATE POLICY transactions_select_own ON public.transactions FOR SELECT TO authenticated USING (user_id = auth.uid());
CREATE POLICY visit_plans_select_active_authenticated ON public.visit_plans FOR SELECT TO authenticated USING (is_active = TRUE);
CREATE POLICY mgmt_plans_select_active_authenticated ON public.management_service_plans FOR SELECT TO authenticated USING (is_active = TRUE);
CREATE POLICY visit_plans_select_active_anon ON public.visit_plans FOR SELECT TO anon USING (is_active = TRUE); -- If anon can see plans


--- ==== Policies for 'public.services', 'public.vendors', 'public.vendor_services' ====
-- Super-admin & Accounts team (or relevant operational role) full access.
CREATE POLICY services_manage_core_admin ON public.services
    FOR ALL TO authenticated USING (public.current_user_has_role('super-admin') OR public.current_user_has_role('accounts-team')) WITH CHECK (public.current_user_has_role('super-admin') OR public.current_user_has_role('accounts-team'));
CREATE POLICY vendors_manage_core_admin ON public.vendors
    FOR ALL TO authenticated USING (public.current_user_has_role('super-admin') OR public.current_user_has_role('accounts-team')) WITH CHECK (public.current_user_has_role('super-admin') OR public.current_user_has_role('accounts-team'));
CREATE POLICY vendor_services_manage_core_admin ON public.vendor_services
    FOR ALL TO authenticated USING (public.current_user_has_role('super-admin') OR public.current_user_has_role('accounts-team')) WITH CHECK (public.current_user_has_role('super-admin') OR public.current_user_has_role('accounts-team'));
-- Authenticated users (e.g. admins needing to select vendors for tickets) can list services/vendors.
CREATE POLICY services_select_authenticated ON public.services FOR SELECT TO authenticated USING (true);
CREATE POLICY vendors_select_authenticated ON public.vendors FOR SELECT TO authenticated USING (true);
CREATE POLICY vendor_services_select_authenticated ON public.vendor_services FOR SELECT TO authenticated USING (true);


--- ==== Policies for 'public.rent_records', 'public.rent_payments' ====
-- Super-admin & Accounts team full access.
CREATE POLICY rent_records_manage_accounts_super_admin ON public.rent_records
    FOR ALL TO authenticated USING (public.current_user_has_role('super-admin') OR public.current_user_has_role('accounts-team')) WITH CHECK (public.current_user_has_role('super-admin') OR public.current_user_has_role('accounts-team'));
CREATE POLICY rent_payments_manage_accounts_super_admin ON public.rent_payments
    FOR ALL TO authenticated USING (public.current_user_has_role('super-admin') OR public.current_user_has_role('accounts-team')) WITH CHECK (public.current_user_has_role('super-admin') OR public.current_user_has_role('accounts-team'));
-- Tenant can see their rent records/payments. Landlord (submitter) can see records/payments for their properties.
CREATE POLICY rent_records_select_tenant_landlord ON public.rent_records
    FOR SELECT TO authenticated USING (tenant_user_id = auth.uid() OR landlord_user_id = auth.uid());
CREATE POLICY rent_payments_select_tenant_landlord_payer ON public.rent_payments
    FOR SELECT TO authenticated
    USING (paid_by_user_id = auth.uid() OR EXISTS (SELECT 1 FROM public.rent_records rr WHERE rr.rent_record_id = rent_payments.rent_record_id AND (rr.tenant_user_id = auth.uid() OR rr.landlord_user_id = auth.uid())));


--- ==== Policies for 'public.tickets', 'public.ticket_images', 'public.ticket_comments' ====
-- Super-admin has full access.
CREATE POLICY tickets_all_access_super_admin ON public.tickets
    FOR ALL TO authenticated USING (public.current_user_has_role('super-admin')) WITH CHECK (public.current_user_has_role('super-admin'));
CREATE POLICY ticket_images_all_access_super_admin ON public.ticket_images
    FOR ALL TO authenticated USING (public.current_user_has_role('super-admin')) WITH CHECK (public.current_user_has_role('super-admin'));
CREATE POLICY ticket_comments_all_access_super_admin ON public.ticket_comments
    FOR ALL TO authenticated USING (public.current_user_has_role('super-admin')) WITH CHECK (public.current_user_has_role('super-admin'));

-- Users can access tickets based on helper function `check_user_can_access_ticket`.
-- This helper needs to be robust: checks if raiser, landlord, tenant of related property, or assigned admin.
CREATE POLICY tickets_access_based_on_helper ON public.tickets
    FOR SELECT TO authenticated USING (public.check_user_can_access_ticket(ticket_id, auth.uid()));
CREATE POLICY ticket_images_access_based_on_helper ON public.ticket_images
    FOR SELECT TO authenticated USING (public.check_user_can_access_ticket(ticket_id, auth.uid()));
CREATE POLICY ticket_comments_select_based_on_helper ON public.ticket_comments
    FOR SELECT TO authenticated USING (public.check_user_can_access_ticket(ticket_id, auth.uid()) AND (is_internal = FALSE OR public.current_user_is_admin())); -- Admins see internal too

-- Insertions via functions. RLS for direct insert:
CREATE POLICY tickets_insert_raiser ON public.tickets
    FOR INSERT TO authenticated WITH CHECK (raised_by_user_id = auth.uid());
CREATE POLICY ticket_images_insert_uploader_if_can_access ON public.ticket_images
    FOR INSERT TO authenticated WITH CHECK (uploaded_by = auth.uid() AND public.check_user_can_access_ticket(ticket_id, auth.uid()));
CREATE POLICY ticket_comments_insert_commenter_if_can_access ON public.ticket_comments
    FOR INSERT TO authenticated WITH CHECK (user_id = auth.uid() AND public.check_user_can_access_ticket(ticket_id, auth.uid()) AND (is_internal = FALSE OR public.current_user_is_admin()));

-- Updates (primarily status, assignment via functions). Direct update for limited fields by assigned admin/raiser.
CREATE POLICY tickets_update_assigned_admin_or_raiser ON public.tickets
    FOR UPDATE TO authenticated
    USING (public.check_user_can_access_ticket(ticket_id, auth.uid()) AND (assigned_support_admin_id = auth.uid() OR raised_by_user_id = auth.uid()))
    WITH CHECK (public.check_user_can_access_ticket(ticket_id, auth.uid()));

-- Delete for comments/images (by uploader/commenter or super-admin, via function ideally)
CREATE POLICY ticket_comments_delete_own ON public.ticket_comments
    FOR DELETE TO authenticated USING (user_id = auth.uid() AND public.check_user_can_access_ticket(ticket_id, auth.uid()));
CREATE POLICY ticket_images_delete_own ON public.ticket_images
    FOR DELETE TO authenticated USING (uploaded_by = auth.uid() AND public.check_user_can_access_ticket(ticket_id, auth.uid()));


--- ==== Policies for Assignment Tables ====
-- property_owner_contact_assignments, property_marketing_assignments, property_visit_assignments, property_visit_assignment_interactions

-- Super-admins full access.
CREATE POLICY poca_all_access_super_admin ON public.property_owner_contact_assignments
    FOR ALL TO authenticated USING (public.current_user_has_role('super-admin')) WITH CHECK (public.current_user_has_role('super-admin'));
CREATE POLICY pma_all_access_super_admin ON public.property_marketing_assignments
    FOR ALL TO authenticated USING (public.current_user_has_role('super-admin')) WITH CHECK (public.current_user_has_role('super-admin'));
CREATE POLICY pva_all_access_super_admin ON public.property_visit_assignments
    FOR ALL TO authenticated USING (public.current_user_has_role('super-admin')) WITH CHECK (public.current_user_has_role('super-admin'));
CREATE POLICY pvai_all_access_super_admin ON public.property_visit_assignment_interactions
    FOR ALL TO authenticated USING (public.current_user_has_role('super-admin')) WITH CHECK (public.current_user_has_role('super-admin'));

-- Assigned admin can see their assignments.
CREATE POLICY poca_select_assigned_admin ON public.property_owner_contact_assignments
    FOR SELECT TO authenticated USING (assigned_admin_id = auth.uid() AND public.current_user_has_role('telecalling-owner-team'));
CREATE POLICY pma_select_assigned_admin ON public.property_marketing_assignments
    FOR SELECT TO authenticated USING (assigned_admin_id = auth.uid() AND public.current_user_has_role('marketing-team'));
CREATE POLICY pva_select_assigned_admin ON public.property_visit_assignments
    FOR SELECT TO authenticated USING (assigned_sales_admin_id = auth.uid() AND public.current_user_has_role('sales-team'));
CREATE POLICY pvai_select_related_to_assigned_pva ON public.property_visit_assignment_interactions
    FOR SELECT TO authenticated
    USING (EXISTS (SELECT 1 FROM public.property_visit_assignments pva WHERE pva.visit_assignment_id = property_visit_assignment_interactions.visit_assignment_id AND pva.assigned_sales_admin_id = auth.uid() AND public.current_user_has_role('sales-team')));

-- Insert/Delete primarily via functions.
-- RLS for direct operations on assignment tables for relevant admin roles.

-- Policies for property_owner_contact_assignments
CREATE POLICY poca_insert_telecalling_owner_team ON public.property_owner_contact_assignments
    FOR INSERT TO authenticated
    WITH CHECK (public.current_user_has_role('telecalling-owner-team') AND assigned_admin_id = auth.uid()); -- Can only assign to self directly

CREATE POLICY poca_delete_telecalling_owner_team ON public.property_owner_contact_assignments
    FOR DELETE TO authenticated
    USING (public.current_user_has_role('telecalling-owner-team') AND assigned_admin_id = auth.uid()); -- Can only delete self-assignments directly

-- Policies for property_marketing_assignments
CREATE POLICY pma_insert_marketing_team ON public.property_marketing_assignments
    FOR INSERT TO authenticated
    WITH CHECK (public.current_user_has_role('marketing-team') AND assigned_admin_id = auth.uid()); -- Can only assign to self directly

CREATE POLICY pma_delete_marketing_team ON public.property_marketing_assignments
    FOR DELETE TO authenticated
    USING (public.current_user_has_role('marketing-team') AND assigned_admin_id = auth.uid()); -- Can only delete self-assignments directly

-- Policy: Super-admins can manage this table
CREATE POLICY round_robin_state_all_access_super_admin ON public.round_robin_state
    FOR ALL TO authenticated
    USING (public.current_user_has_role('super-admin'))
    WITH CHECK (public.current_user_has_role('super-admin'));
