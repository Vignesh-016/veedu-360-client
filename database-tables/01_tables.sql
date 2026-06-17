-------------------------------------------------------------------------------
-- File: 01_tables.sql
-- Description: Defines all table structures (Post-Upgrade Plan).
-------------------------------------------------------------------------------

-- Admin Users table (replaces user_roles, agents)
CREATE TABLE IF NOT EXISTS public.admins (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    roles public.admin_role_enum[] NOT NULL,
    served_pincodes INTEGER[],
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);
COMMENT ON TABLE public.admins IS 'Stores admin users, their multiple roles, and served pincodes.';
COMMENT ON COLUMN public.admins.roles IS 'Array of roles assigned to the admin.';
COMMENT ON COLUMN public.admins.served_pincodes IS 'Array of pincodes this admin serves, relevant for marketing/sales.';

-- Management Service Plans table
CREATE TABLE IF NOT EXISTS public.management_service_plans (
    plan_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL UNIQUE,
    percentage DECIMAL(5, 2) NOT NULL CHECK (percentage >= 0 AND percentage <= 100),
    description TEXT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

-- Unified Properties table
CREATE TABLE IF NOT EXISTS public.properties (
    property_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    property_type property_type_enum NOT NULL,
    listing_type listing_type_enum NOT NULL,

    price DECIMAL(12,2) NOT NULL CHECK (price > 0),
    area DECIMAL(10,2) NOT NULL CHECK (area > 0),
    area_unit area_unit_enum NOT NULL,

    year_built INTEGER CHECK (year_built > 1800 AND year_built <= date_part('year', CURRENT_DATE) + 10),
    description TEXT,
    details JSONB NOT NULL, -- Specifics for house_type, land_type, building_type
    youtube_url TEXT NULL,

    -- Location
    locality TEXT NOT NULL,
    city TEXT NOT NULL,
    address TEXT NOT NULL,
    pincode INTEGER,
    latitude DECIMAL(9,6),
    longitude DECIMAL(9,6),

    -- Proximity Fields
    nearest_hospital DECIMAL(5,1),
    nearest_busstop DECIMAL(5,1),
    nearest_gym DECIMAL(5,1),
    nearest_park DECIMAL(5,1),
    nearest_school DECIMAL(5,1),
    nearest_swimmingpool DECIMAL(5,1),
    proximity_unit proximity_unit_enum DEFAULT 'KM',

    -- Admin/Internal
    admin_notes TEXT, -- Internal notes by any admin
    inventory_details JSONB DEFAULT '{}'::jsonb NOT NULL,

    -- Status & Flags
    admin_status property_admin_status_enum NOT NULL DEFAULT 'SUBMITTED', -- RENAMED & NEW ENUM
    is_listed BOOLEAN NOT NULL DEFAULT FALSE,
    is_featured BOOLEAN DEFAULT FALSE NOT NULL,
    is_exclusive BOOLEAN DEFAULT FALSE NOT NULL,

    -- Rental Specific
    advance_amount DECIMAL(10,2),
    rent_due_day INTEGER CHECK (rent_due_day >= 1 AND rent_due_day <= 28),

    -- Submitter Details
    submitter UUID REFERENCES auth.users(id) ON DELETE SET NULL, -- The user who owns/submitted the property
    submitter_type submitter_type_enum, -- Using updated enum
    submitter_notes TEXT, -- Notes from the submitter
    submitted_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    availability_status availability_status_enum, -- e.g. Under Construction, Ready to Move
    can_reachout BOOLEAN DEFAULT TRUE NOT NULL, -- If owner/submitter can be contacted

    -- Occupancy & Management
    tenant UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    management_plan_id UUID REFERENCES public.management_service_plans(plan_id) ON DELETE SET NULL,

    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);
COMMENT ON COLUMN public.properties.admin_status IS 'Internal workflow status of the property, managed by admins.';
COMMENT ON COLUMN public.properties.is_listed IS 'Controls if the property is publicly visible to customers.';
COMMENT ON COLUMN public.properties.pincode IS 'Pincode of the property location.';
COMMENT ON COLUMN public.properties.advance_amount IS 'Advance or security deposit amount for rentals.';


-- Unified Property Images table (uploaded_by references auth.users)
CREATE TABLE IF NOT EXISTS public.property_images (
    image_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    property_id UUID NOT NULL REFERENCES public.properties(property_id) ON DELETE CASCADE,
    image_url TEXT NOT NULL,
    description TEXT,
    display_order INTEGER NOT NULL DEFAULT 0,
    is_internal_image BOOLEAN NOT NULL DEFAULT FALSE, -- e.g., images showing damage, for admin eyes only
    uploaded_by UUID REFERENCES auth.users(id) ON DELETE SET NULL, -- User (owner/submitter OR admin acting on behalf)
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

-- Customers table
CREATE TABLE IF NOT EXISTS public.customers (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    visit_balance INTEGER NOT NULL DEFAULT 5 CHECK (visit_balance >= 0),
    expiry_date DATE NOT NULL DEFAULT (CURRENT_DATE + INTERVAL '30 days'),
    profile_details JSONB DEFAULT '{}'::jsonb NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

-- Customer interactions table
CREATE TABLE IF NOT EXISTS public.customers_interaction (
    interaction_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.customers(user_id) ON DELETE CASCADE,
    property_id UUID NOT NULL REFERENCES public.properties(property_id) ON DELETE CASCADE,
    status interaction_status_enum NOT NULL DEFAULT 'WISHLISTED',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    scheduled_for DATE,
    visited_at TIMESTAMP WITH TIME ZONE,
    admin_notes TEXT, -- Notes by any admin regarding this interaction

    assigned_tenant_telecaller_id UUID REFERENCES public.admins(user_id) ON DELETE SET NULL,
    telecaller_assigned_at TIMESTAMP WITH TIME ZONE,
    assigned_sales_admin_id UUID REFERENCES public.admins(user_id) ON DELETE SET NULL -- Admin from sales-team handling the visit
);
COMMENT ON COLUMN public.customers_interaction.assigned_tenant_telecaller_id IS 'Admin from telecalling-tenant-team assigned to this interaction.';
COMMENT ON COLUMN public.customers_interaction.assigned_sales_admin_id IS 'Admin from sales-team assigned to conduct the visit for this interaction.';


-- Visit Plans table
CREATE TABLE IF NOT EXISTS public.visit_plans (
    plan_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL UNIQUE,
    description TEXT,
    visits INTEGER NOT NULL CHECK (visits > 0),
    price DECIMAL(10, 2) NOT NULL CHECK (price >= 0),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

-- Transactions table
CREATE TABLE IF NOT EXISTS public.transactions (
    transaction_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.customers(user_id) ON DELETE CASCADE,
    plan_id UUID NOT NULL REFERENCES public.visit_plans(plan_id),
    razorpay_order_id TEXT UNIQUE,
    razorpay_payment_id TEXT UNIQUE,
    razorpay_signature TEXT,
    amount DECIMAL(10, 2) NOT NULL,
    status TEXT NOT NULL, -- e.g., 'created', 'paid', 'failed'
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    error_message TEXT,
    admin_notes TEXT -- New column for admin notes
);
COMMENT ON TABLE public.transactions IS 'Stores details of visit plan purchases.';
COMMENT ON COLUMN public.transactions.razorpay_order_id IS 'Order ID generated by Razorpay before payment.';
COMMENT ON COLUMN public.transactions.razorpay_payment_id IS 'Payment ID from Razorpay after successful payment.';
COMMENT ON COLUMN public.transactions.razorpay_signature IS 'Signature from Razorpay for webhook verification.';
COMMENT ON COLUMN public.transactions.status IS 'Status of the transaction (e.g., created, paid, failed).';
COMMENT ON COLUMN public.transactions.error_message IS 'Error message if the transaction failed.';
COMMENT ON COLUMN public.transactions.admin_notes IS 'Internal notes added by an admin regarding this transaction.';

-- Services table
CREATE TABLE IF NOT EXISTS public.services (
    service_id SERIAL PRIMARY KEY,
    service_name TEXT NOT NULL UNIQUE,
    description TEXT,
    category public.service_category_enum,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

-- Vendors table
CREATE TABLE IF NOT EXISTS public.vendors (
    vendor_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_name TEXT NOT NULL,
    contact_name TEXT,
    phone TEXT,
    email TEXT UNIQUE CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'),
    address TEXT,
    status vendor_status_enum NOT NULL DEFAULT 'ACTIVE',
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

-- Vendor Services junction table
CREATE TABLE IF NOT EXISTS public.vendor_services (
    vendor_id UUID NOT NULL REFERENCES public.vendors(vendor_id) ON DELETE CASCADE,
    service_id INTEGER NOT NULL REFERENCES public.services(service_id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    PRIMARY KEY (vendor_id, service_id)
);

-- Rent Records table
CREATE TABLE IF NOT EXISTS public.rent_records (
    rent_record_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    property_id UUID NOT NULL REFERENCES public.properties(property_id) ON DELETE RESTRICT,
    tenant_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
    landlord_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
    due_date DATE NOT NULL,
    period_start_date DATE NOT NULL,
    period_end_date DATE NOT NULL,
    amount_due DECIMAL(10, 2) NOT NULL CHECK (amount_due > 0),
    amount_paid DECIMAL(10, 2) NOT NULL DEFAULT 0.00 CHECK (amount_paid >= 0),
    status rent_status_enum NOT NULL DEFAULT 'DUE',
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    UNIQUE (property_id, due_date),
    CHECK (period_end_date >= period_start_date),
    CHECK (due_date >= period_start_date)
);

-- Rent Payments table
CREATE TABLE IF NOT EXISTS public.rent_payments (
    payment_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    rent_record_id UUID NOT NULL REFERENCES public.rent_records(rent_record_id) ON DELETE CASCADE,
    paid_by_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
    amount DECIMAL(10, 2) NOT NULL CHECK (amount > 0),
    payment_date TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    payment_method TEXT,
    transaction_ref TEXT,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

-- Tickets table
CREATE TABLE IF NOT EXISTS public.tickets (
    ticket_id BIGSERIAL PRIMARY KEY,
    property_id UUID NOT NULL REFERENCES public.properties(property_id) ON DELETE CASCADE,
    raised_by_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
    subject TEXT NOT NULL CHECK (TRIM(subject) <> ''),
    description TEXT NOT NULL CHECK (TRIM(description) <> ''),
    category ticket_category_enum NOT NULL,
    priority ticket_priority_enum NOT NULL DEFAULT 'MEDIUM',
    status ticket_status_enum NOT NULL DEFAULT 'NEW',
    assigned_to_vendor_id UUID REFERENCES public.vendors(vendor_id) ON DELETE SET NULL,
    assigned_support_admin_id UUID REFERENCES public.admins(user_id) ON DELETE SET NULL, -- RENAMED from assigned_to_agent_id
    resolution_notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    resolved_at TIMESTAMP WITH TIME ZONE,
    closed_at TIMESTAMP WITH TIME ZONE
);
COMMENT ON COLUMN public.tickets.assigned_support_admin_id IS 'Admin user assigned to handle this support ticket.';

-- Ticket Images table (uploaded_by references auth.users for consistency with property_images if user self-serves)
CREATE TABLE IF NOT EXISTS public.ticket_images (
    image_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ticket_id BIGINT NOT NULL REFERENCES public.tickets(ticket_id) ON DELETE CASCADE,
    uploaded_by UUID NOT NULL REFERENCES auth.users(id) ON DELETE SET NULL, -- User who uploaded image (tenant, landlord, or admin)
    image_url TEXT NOT NULL,
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

-- Ticket Comments table (user_id references auth.users)
CREATE TABLE IF NOT EXISTS public.ticket_comments (
    comment_id BIGSERIAL PRIMARY KEY,
    ticket_id BIGINT NOT NULL REFERENCES public.tickets(ticket_id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT, -- User who made the comment
    comment_text TEXT NOT NULL CHECK (TRIM(comment_text) <> ''),
    is_internal BOOLEAN NOT NULL DEFAULT FALSE, -- For admin-only comments
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

-- Property Documents
CREATE TABLE IF NOT EXISTS public.property_documents (
    document_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    property_id UUID NOT NULL REFERENCES public.properties(property_id) ON DELETE CASCADE,
    document_type TEXT NOT NULL,
    document_url TEXT NOT NULL,
    file_name TEXT,
    description TEXT,
    uploaded_by UUID REFERENCES public.admins(user_id) ON DELETE SET NULL,
    uploaded_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);
COMMENT ON TABLE public.property_documents IS 'Stores documents related to properties.';
COMMENT ON COLUMN public.property_documents.document_type IS 'Type of document, e.g., Sale Deed, EC, Plan Approval.';
COMMENT ON COLUMN public.property_documents.uploaded_by IS 'Admin user who uploaded the document.';

-- Customer Documents
CREATE TABLE IF NOT EXISTS public.customer_documents (
    document_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    document_type TEXT NOT NULL,
    document_url TEXT NOT NULL,
    file_name TEXT,
    description TEXT,
    uploaded_by UUID REFERENCES public.admins(user_id) ON DELETE SET NULL,
    uploaded_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);
COMMENT ON TABLE public.customer_documents IS 'Stores documents related to customers/users.';
COMMENT ON COLUMN public.customer_documents.document_type IS 'Type of document, e.g., Aadhaar, PAN, Rental Agreement.';
COMMENT ON COLUMN public.customer_documents.uploaded_by IS 'Admin user who uploaded the document.';

-- Property Owner Contact Assignments (telecalling-owner-team)
CREATE TABLE IF NOT EXISTS public.property_owner_contact_assignments (
    property_id UUID PRIMARY KEY REFERENCES public.properties(property_id) ON DELETE CASCADE,
    assigned_admin_id UUID NOT NULL REFERENCES public.admins(user_id) ON DELETE RESTRICT,
    assigned_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);
COMMENT ON TABLE public.property_owner_contact_assignments IS 'Tracks assignment of properties to telecalling-owner-team members.';

-- Property Marketing Assignments (marketing-team)
CREATE TABLE IF NOT EXISTS public.property_marketing_assignments (
    property_id UUID PRIMARY KEY REFERENCES public.properties(property_id) ON DELETE CASCADE,
    assigned_admin_id UUID NOT NULL REFERENCES public.admins(user_id) ON DELETE RESTRICT,
    assigned_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);
COMMENT ON TABLE public.property_marketing_assignments IS 'Tracks assignment of properties to marketing-team members.';

-- Property Visit Assignments (sales-team daily grouping)
CREATE TABLE IF NOT EXISTS public.property_visit_assignments (
    visit_assignment_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE, -- The customer for whom visits are grouped
    visit_date DATE NOT NULL,
    assigned_sales_admin_id UUID REFERENCES public.admins(user_id) ON DELETE SET NULL, -- Admin from sales-team
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    UNIQUE (user_id, visit_date)
);
COMMENT ON TABLE public.property_visit_assignments IS 'Groups multiple property visits for a single customer on a given day, assigned to a sales admin.';

-- Property Visit Assignment Interactions (Junction table)
CREATE TABLE IF NOT EXISTS public.property_visit_assignment_interactions (
    visit_assignment_id UUID NOT NULL REFERENCES public.property_visit_assignments(visit_assignment_id) ON DELETE CASCADE,
    interaction_id UUID NOT NULL REFERENCES public.customers_interaction(interaction_id) ON DELETE CASCADE,
    PRIMARY KEY (visit_assignment_id, interaction_id)
);
COMMENT ON TABLE public.property_visit_assignment_interactions IS 'Links specific customer interactions (property visits) to a daily visit assignment group.';


CREATE TABLE IF NOT EXISTS public.round_robin_state (
    assignment_group TEXT PRIMARY KEY,
    last_assigned_admin_id UUID REFERENCES public.admins(user_id) ON DELETE SET NULL,
    last_assigned_at TIMESTAMP WITH TIME ZONE,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE public.round_robin_state IS 'Stores state for round-robin assignments, e.g., last admin assigned for a specific task group.';
COMMENT ON COLUMN public.round_robin_state.assignment_group IS 'A unique key identifying the group for round-robin (e.g., MARKETING_PINCODE_600001, MARKETING_GLOBAL).';
COMMENT ON COLUMN public.round_robin_state.last_assigned_admin_id IS 'The UUID of the admin last assigned a task in this group.';
COMMENT ON COLUMN public.round_robin_state.last_assigned_at IS 'Timestamp of the last assignment in this group.';

-- OTP Sent Log Table
CREATE TABLE IF NOT EXISTS public.otp_sent_log (
    id BIGSERIAL PRIMARY KEY,
    phone_number TEXT NOT NULL,
    sent_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);
COMMENT ON TABLE public.otp_sent_log IS 'Logs OTP sending attempts for rate limiting and auditing.';
COMMENT ON COLUMN public.otp_sent_log.phone_number IS 'The phone number to which the OTP was sent.';
COMMENT ON COLUMN public.otp_sent_log.sent_at IS 'Timestamp of when the OTP sending was attempted.';

-- Rental Applications table
CREATE TABLE IF NOT EXISTS public.rental_applications (
    application_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    property_id UUID NOT NULL REFERENCES public.properties(property_id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    interaction_id UUID NOT NULL REFERENCES public.customers_interaction(interaction_id) ON DELETE CASCADE,
    landlord_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
    application_data JSONB NOT NULL, -- e.g., {"move_in_date": "YYYY-MM-DD", "occupants": 2, "applicant_notes": "..."}
    status public.rental_application_status_enum NOT NULL DEFAULT 'SUBMITTED',
    admin_notes TEXT,
    assigned_admin_id UUID REFERENCES public.admins(user_id) ON DELETE SET NULL,
    submitted_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    status_updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    -- Constraint to prevent multiple active applications for the same property by the same user.
    -- A basic unique constraint on (property_id, user_id) could be added if a user can only have ONE application (active or not) per property.
    -- UNIQUE (property_id, user_id)
    CONSTRAINT check_application_data_is_object CHECK (jsonb_typeof(application_data) = 'object')
);

COMMENT ON TABLE public.rental_applications IS 'Stores rental applications submitted by customers.';
COMMENT ON COLUMN public.rental_applications.property_id IS 'The property being applied for.';
COMMENT ON COLUMN public.rental_applications.user_id IS 'The user (customer) submitting the application.';
COMMENT ON COLUMN public.rental_applications.interaction_id IS 'The customer_interaction record related to the property visit that led to this application.';
COMMENT ON COLUMN public.rental_applications.landlord_user_id IS 'The owner of the property (from properties.submitter).';
COMMENT ON COLUMN public.rental_applications.application_data IS 'JSONB blob containing application form responses like proposed move-in date, occupants, etc.';
COMMENT ON COLUMN public.rental_applications.status IS 'Current status of the rental application.';
COMMENT ON COLUMN public.rental_applications.admin_notes IS 'Internal notes and logs maintained by admins regarding this application.';
COMMENT ON COLUMN public.rental_applications.assigned_admin_id IS 'The admin currently responsible for processing this application.';
COMMENT ON COLUMN public.rental_applications.status_updated_at IS 'Timestamp of when the application status was last changed.';

-- Service SMS Log table
CREATE TABLE IF NOT EXISTS public.service_sms_log (
    id BIGSERIAL PRIMARY KEY,
    sms_type public.sms_type_enum NOT NULL,
    to_phone_number TEXT NOT NULL,
    variables TEXT[] DEFAULT '{}'::TEXT[],
    status public.sms_status_enum NOT NULL DEFAULT 'NOT_SENT',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);
COMMENT ON TABLE public.service_sms_log IS 'Tracks service-related SMS messages to be sent.';
COMMENT ON COLUMN public.service_sms_log.sms_type IS 'The type of event that triggered this SMS.';
COMMENT ON COLUMN public.service_sms_log.to_phone_number IS 'The recipient''s phone number.';
COMMENT ON COLUMN public.service_sms_log.variables IS 'An array of text variables to be injected into the SMS template (e.g., property name, customer name).';
COMMENT ON COLUMN public.service_sms_log.status IS 'The sending status of the SMS.';