-------------------------------------------------------------------------------
-- File: 02_indexes.sql
-- Description: Defines indexes for performance on the schema (Post-Upgrade Plan).
-------------------------------------------------------------------------------

-- Admins table
CREATE INDEX IF NOT EXISTS idx_admins_roles_gin ON public.admins USING GIN (roles);
CREATE INDEX IF NOT EXISTS idx_admins_served_pincodes_gin ON public.admins USING GIN (served_pincodes);
CREATE INDEX IF NOT EXISTS idx_admins_is_active ON public.admins(is_active);

-- Management Service Plans
CREATE INDEX IF NOT EXISTS idx_management_service_plans_is_active ON public.management_service_plans(is_active);

-- Properties table
CREATE INDEX IF NOT EXISTS idx_properties_property_type ON public.properties(property_type);
CREATE INDEX IF NOT EXISTS idx_properties_listing_type ON public.properties(listing_type);
CREATE INDEX IF NOT EXISTS idx_properties_locality ON public.properties(locality);
CREATE INDEX IF NOT EXISTS idx_properties_city ON public.properties(city);
CREATE INDEX IF NOT EXISTS idx_properties_price ON public.properties(price);
CREATE INDEX IF NOT EXISTS idx_properties_area ON public.properties(area);
CREATE INDEX IF NOT EXISTS idx_properties_details_gin ON public.properties USING GIN (details);
CREATE INDEX IF NOT EXISTS idx_properties_inventory_details_gin ON public.properties USING GIN (inventory_details);
CREATE INDEX IF NOT EXISTS idx_properties_admin_status ON public.properties(admin_status);
CREATE INDEX IF NOT EXISTS idx_properties_is_featured ON public.properties(is_featured);
CREATE INDEX IF NOT EXISTS idx_properties_is_exclusive ON public.properties(is_exclusive);
CREATE INDEX IF NOT EXISTS idx_properties_rent_due_day ON public.properties(rent_due_day);
CREATE INDEX IF NOT EXISTS idx_properties_submitter ON public.properties(submitter);
CREATE INDEX IF NOT EXISTS idx_properties_tenant ON public.properties(tenant);
CREATE INDEX IF NOT EXISTS idx_properties_submitter_type ON public.properties(submitter_type);
CREATE INDEX IF NOT EXISTS idx_properties_submitted_at ON public.properties(submitted_at);
CREATE INDEX IF NOT EXISTS idx_properties_availability_status ON public.properties(availability_status);
CREATE INDEX IF NOT EXISTS idx_properties_management_plan_id ON public.properties(management_plan_id);
CREATE INDEX IF NOT EXISTS idx_properties_pincode ON public.properties(pincode);
CREATE INDEX IF NOT EXISTS idx_properties_is_listed ON public.properties(is_listed);

-- Property Images table (Unchanged from original, but ensure these are present)
CREATE INDEX IF NOT EXISTS idx_property_images_property_id_display_order ON public.property_images(property_id, display_order);
CREATE INDEX IF NOT EXISTS idx_property_images_is_internal_image ON public.property_images(is_internal_image);
CREATE INDEX IF NOT EXISTS idx_property_images_uploaded_by ON public.property_images(uploaded_by);

-- Customers table
CREATE INDEX IF NOT EXISTS idx_customers_expiry_date ON public.customers(expiry_date);
CREATE INDEX IF NOT EXISTS idx_customers_profile_details_gin ON public.customers USING GIN (profile_details);

-- Customer Interactions table
CREATE INDEX IF NOT EXISTS idx_customers_interaction_user_id ON public.customers_interaction(user_id);
CREATE INDEX IF NOT EXISTS idx_customers_interaction_property_id ON public.customers_interaction(property_id);
CREATE INDEX IF NOT EXISTS idx_customers_interaction_status ON public.customers_interaction(status);
CREATE INDEX IF NOT EXISTS idx_customers_interaction_assigned_tenant_telecaller_id ON public.customers_interaction(assigned_tenant_telecaller_id);
CREATE INDEX IF NOT EXISTS idx_customers_interaction_assigned_sales_admin_id ON public.customers_interaction(assigned_sales_admin_id);
CREATE INDEX IF NOT EXISTS idx_customers_interaction_scheduled_for ON public.customers_interaction(scheduled_for);


-- Visit Plans table
CREATE INDEX IF NOT EXISTS idx_visit_plans_is_active ON public.visit_plans(is_active);
CREATE INDEX IF NOT EXISTS idx_visit_plans_price ON public.visit_plans(price);

-- Transactions table
CREATE INDEX IF NOT EXISTS idx_transactions_user_id ON public.transactions(user_id);
CREATE INDEX IF NOT EXISTS idx_transactions_plan_id ON public.transactions(plan_id);
CREATE INDEX IF NOT EXISTS idx_transactions_status ON public.transactions(status);
CREATE INDEX IF NOT EXISTS idx_transactions_razorpay_order_id ON public.transactions(razorpay_order_id);
CREATE INDEX IF NOT EXISTS idx_transactions_created_at ON public.transactions(created_at);

-- Services table
CREATE INDEX IF NOT EXISTS idx_services_category ON public.services(category);

-- Vendors table
CREATE INDEX IF NOT EXISTS idx_vendors_status ON public.vendors(status);
CREATE INDEX IF NOT EXISTS idx_vendors_company_name ON public.vendors(company_name);

-- Vendor Services junction table
CREATE INDEX IF NOT EXISTS idx_vendor_services_service_id ON public.vendor_services(service_id);

-- Rent Records table
CREATE INDEX IF NOT EXISTS idx_rent_records_property_id ON public.rent_records(property_id);
CREATE INDEX IF NOT EXISTS idx_rent_records_tenant_user_id ON public.rent_records(tenant_user_id);
CREATE INDEX IF NOT EXISTS idx_rent_records_landlord_user_id ON public.rent_records(landlord_user_id);
CREATE INDEX IF NOT EXISTS idx_rent_records_due_date ON public.rent_records(due_date);
CREATE INDEX IF NOT EXISTS idx_rent_records_status ON public.rent_records(status);

-- Rent Payments table
CREATE INDEX IF NOT EXISTS idx_rent_payments_rent_record_id ON public.rent_payments(rent_record_id);
CREATE INDEX IF NOT EXISTS idx_rent_payments_paid_by_user_id ON public.rent_payments(paid_by_user_id);
CREATE INDEX IF NOT EXISTS idx_rent_payments_payment_date ON public.rent_payments(payment_date);

-- Tickets table
CREATE INDEX IF NOT EXISTS idx_tickets_property_id ON public.tickets(property_id);
CREATE INDEX IF NOT EXISTS idx_tickets_raised_by_user_id ON public.tickets(raised_by_user_id);
CREATE INDEX IF NOT EXISTS idx_tickets_status ON public.tickets(status);
CREATE INDEX IF NOT EXISTS idx_tickets_priority ON public.tickets(priority);
CREATE INDEX IF NOT EXISTS idx_tickets_category ON public.tickets(category);
CREATE INDEX IF NOT EXISTS idx_tickets_assigned_to_vendor_id ON public.tickets(assigned_to_vendor_id);
CREATE INDEX IF NOT EXISTS idx_tickets_assigned_support_admin_id ON public.tickets(assigned_support_admin_id);
CREATE INDEX IF NOT EXISTS idx_tickets_created_at ON public.tickets(created_at);

-- Ticket Images table
CREATE INDEX IF NOT EXISTS idx_ticket_images_ticket_id ON public.ticket_images(ticket_id);
CREATE INDEX IF NOT EXISTS idx_ticket_images_uploaded_by ON public.ticket_images(uploaded_by);

-- Ticket Comments table
CREATE INDEX IF NOT EXISTS idx_ticket_comments_ticket_id ON public.ticket_comments(ticket_id);
CREATE INDEX IF NOT EXISTS idx_ticket_comments_user_id ON public.ticket_comments(user_id);
CREATE INDEX IF NOT EXISTS idx_ticket_comments_created_at ON public.ticket_comments(created_at);

-- Property Documents table
CREATE INDEX IF NOT EXISTS idx_property_documents_property_id ON public.property_documents(property_id);
CREATE INDEX IF NOT EXISTS idx_property_documents_document_type ON public.property_documents(document_type);
CREATE INDEX IF NOT EXISTS idx_property_documents_uploaded_by ON public.property_documents(uploaded_by);

-- Customer Documents table
CREATE INDEX IF NOT EXISTS idx_customer_documents_user_id ON public.customer_documents(user_id);
CREATE INDEX IF NOT EXISTS idx_customer_documents_document_type ON public.customer_documents(document_type);
CREATE INDEX IF NOT EXISTS idx_customer_documents_uploaded_by ON public.customer_documents(uploaded_by);

-- Property Owner Contact Assignments table
CREATE INDEX IF NOT EXISTS idx_property_owner_contact_assignments_assigned_admin_id ON public.property_owner_contact_assignments(assigned_admin_id);

-- Property Marketing Assignments table
CREATE INDEX IF NOT EXISTS idx_property_marketing_assignments_assigned_admin_id ON public.property_marketing_assignments(assigned_admin_id);

-- Property Visit Assignments table
CREATE INDEX IF NOT EXISTS idx_property_visit_assignments_user_id ON public.property_visit_assignments(user_id);
CREATE INDEX IF NOT EXISTS idx_property_visit_assignments_visit_date ON public.property_visit_assignments(visit_date);
CREATE INDEX IF NOT EXISTS idx_property_visit_assignments_assigned_sales_admin_id ON public.property_visit_assignments(assigned_sales_admin_id);
-- Note: UNIQUE constraint on (user_id, visit_date) already creates an index.

-- Property Visit Assignment Interactions table
-- PK (visit_assignment_id, interaction_id) is auto-indexed.
CREATE INDEX IF NOT EXISTS idx_property_visit_assignment_interactions_interaction_id ON public.property_visit_assignment_interactions(interaction_id);


-- OTP Sent Log table
CREATE INDEX IF NOT EXISTS idx_otp_sent_log_phone_number ON public.otp_sent_log(phone_number);
CREATE INDEX IF NOT EXISTS idx_otp_sent_log_sent_at ON public.otp_sent_log(sent_at);

-- rental applications
CREATE INDEX IF NOT EXISTS idx_rental_applications_property_id ON public.rental_applications(property_id);
CREATE INDEX IF NOT EXISTS idx_rental_applications_user_id ON public.rental_applications(user_id);
CREATE INDEX IF NOT EXISTS idx_rental_applications_landlord_user_id ON public.rental_applications(landlord_user_id);
CREATE INDEX IF NOT EXISTS idx_rental_applications_interaction_id ON public.rental_applications(interaction_id);
CREATE INDEX IF NOT EXISTS idx_rental_applications_status ON public.rental_applications(status);
CREATE INDEX IF NOT EXISTS idx_rental_applications_assigned_admin_id ON public.rental_applications(assigned_admin_id);
CREATE INDEX IF NOT EXISTS idx_rental_applications_submitted_at ON public.rental_applications(submitted_at);
CREATE INDEX IF NOT EXISTS idx_rental_applications_status_updated_at ON public.rental_applications(status_updated_at);

-- Service SMS Log table
CREATE INDEX IF NOT EXISTS idx_service_sms_log_status ON public.service_sms_log(status);
CREATE INDEX IF NOT EXISTS idx_service_sms_log_created_at ON public.service_sms_log(created_at);
CREATE INDEX IF NOT EXISTS idx_service_sms_log_sms_type ON public.service_sms_log(sms_type);