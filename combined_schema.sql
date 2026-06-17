-- Enum for Admin Roles
CREATE TYPE public.admin_role_enum AS ENUM (
    'super-admin',
    'telecalling-owner-team',
    'marketing-team',
    'telecalling-tenant-team',
    'sales-team',
    'accounts-team'
);

-- Enum for Property Admin Status
CREATE TYPE public.property_admin_status_enum AS ENUM (
    'SUBMITTED',
    'OWNER_CONTACT_PENDING',
    'OWNER_VERIFIED',
    'MARKETING_VISIT_PENDING',
    'MARKETING_VERIFIED',
    'AWAITING_LISTING',
    'REJECTED',
    'SUSPENDED',
    'RENTED',
    'SOLD'
);

-- Interaction Status Enum
CREATE TYPE public.interaction_status_enum AS ENUM (
    'WISHLISTED',
    'VISIT_PENDING',
    'VISIT_CONFIRMED_PENDING_SALES',
    'VISIT_SCHEDULED_WITH_SALES',
    'VISIT_COMPLETED',
    'VISIT_CANCELLED',
    'RENTAL_APPLICATION_SUBMITTED',
    'LEASE_CONVERTED'
);

-- Submitter Type Enum
CREATE TYPE public.submitter_type_enum AS ENUM (
    'OWNER',
    'BUILDER',
    'AGENT'
);

-- Ticket Status Enum
CREATE TYPE public.ticket_status_enum AS ENUM (
    'NEW',
    'OPEN',
    'ASSIGNED',
    'WAITING_TENANT_RESPONSE',
    'WAITING_OWNER_RESPONSE',
    'IN_PROGRESS',
    'RESOLVED',
    'CLOSED',
    'CANCELLED'
);

-- Existing Enums
CREATE TYPE public.property_type_enum AS ENUM ('LAND', 'HOUSE', 'BUILDING');
CREATE TYPE public.listing_type_enum AS ENUM ('RENTAL', 'SALE');
CREATE TYPE public.area_unit_enum AS ENUM ('SQ_FT', 'CENTS', 'ACRES');
CREATE TYPE public.direction_enum AS ENUM ('NORTH', 'SOUTH', 'EAST', 'WEST');
CREATE TYPE public.house_type_enum AS ENUM ('APARTMENT_FLAT', 'INDEPENDENT_VILLA', 'HOSTEL_PG');
CREATE TYPE public.land_type_enum AS ENUM ('RESIDENTIAL', 'COMMERCIAL', 'AGRICULTURAL');
CREATE TYPE public.building_type_enum AS ENUM ('OFFICE', 'WAREHOUSE', 'RETAIL', 'INDUSTRIAL', 'HOSPITALITY');
CREATE TYPE public.furnished_status_enum AS ENUM ('UNFURNISHED', 'SEMI_FURNISHED', 'FULLY_FURNISHED');
CREATE TYPE public.availability_status_enum AS ENUM ('UNDER_CONSTRUCTION', 'READY_TO_MOVE');
CREATE TYPE public.proximity_unit_enum AS ENUM ('KM', 'METERS', 'MINUTES_WALK', 'MINUTES_DRIVE');
CREATE TYPE public.water_source_enum AS ENUM ('BOREWELL', 'MUNICIPAL', 'BOTH');
CREATE TYPE public.power_backup_enum AS ENUM ('NONE', 'PARTIAL', 'FULL');
CREATE TYPE public.ticket_priority_enum AS ENUM ('LOW', 'MEDIUM', 'HIGH');
CREATE TYPE public.vendor_status_enum AS ENUM ('ACTIVE', 'INACTIVE', 'UNDER_REVIEW');
CREATE TYPE public.service_category_enum AS ENUM (
    'MAINTENANCE', 'REPAIR', 'CONSTRUCTION', 'DESIGN', 'CLEANING', 'SECURITY', 'LANDSCAPING', 'POOL', 'PEST_CONTROL', 'UTILITIES', 'OTHER'
);
CREATE TYPE public.rent_status_enum AS ENUM (
    'DUE',
    'PAID',
    'PARTIALLY_PAID',
    'OVERDUE',
    'CANCELLED'
);
CREATE TYPE public.ticket_category_enum AS ENUM (
    'MAINTENANCE_REPAIR',
    'PLUMBING',
    'ELECTRICAL',
    'APPLIANCE',
    'CLEANING',
    'LANDSCAPING',
    'PEST_CONTROL',
    'NOISE_COMPLAINT',
    'LEASE_QUERY',
    'PAYMENT_QUERY',
    'GENERAL_INQUIRY',
    'OTHER'
);

-- rental application statuses
CREATE TYPE public.rental_application_status_enum AS ENUM (
    'SUBMITTED',
    'REVIEW_IN_PROGRESS',
    'AWAITING_LANDLORD_CONTACT',
    'LANDLORD_INFO_PENDING',
    'LANDLORD_APPROVED',
    'LANDLORD_REJECTED',
    'DOCUMENTS_REQUESTED',
    'DOCUMENTS_VERIFIED',
    'APPROVED_AWAITING_PAYMENT',
    'PAYMENT_CONFIRMED',
    'LEASE_FINALIZED',
    'TENANCY_ACTIVE',
    'APPLICATION_WITHDRAWN_CUSTOMER',
    'CANCELLED_ADMIN'
);

-- Enum for SMS Type
CREATE TYPE public.sms_type_enum AS ENUM (
    'POST_SUBMITTED',
    'MARKETING_ASSIGNED_TO_MARKETER',
    'MARKETING_ASSIGNED_TO_CUSTOMER',
    'MARKETING_REASSIGNED_TO_CUSTOMER',
    'RENT_APPROVAL_TO_CUSTOMER',
    'RENTED_APPROVAL_TO_OWNER',
    'TICKET_CREATED',
    'TICKET_CLOSED',
    'CREDITS_PURCHASED',
    'RENT_DUE',
    'VISIT_BOOKING_TO_OWNER',
    'VISIT_BOOKING_TO_TENANT',
    'TICKET_ASSIGNED_TO_VENDOR',
    'TICKET_VENDOR_DETAILS_TO_RAISER'
);

-- Enum for SMS Status
CREATE TYPE public.sms_status_enum AS ENUM (
    'NOT_SENT',
    'SENT',
    'FAILED'
);


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


-- FILE NAME: 03_01_system_functions.sql
-- Description: System-level functions, often called by backend services or webhooks.
-------------------------------------------------------------------------------

-- Function to complete a purchase: updates customer's visit balance and expiry date.
-- Called internally after a transaction is confirmed as 'paid'.
CREATE OR REPLACE FUNCTION public.complete_purchase(
    p_razorpay_order_id TEXT
) RETURNS VOID AS $$
DECLARE
    v_transaction RECORD;
    v_plan RECORD;
    v_customer RECORD;
BEGIN
    -- This function should be called by trusted roles, e.g., service_role via update_transaction_status
    IF current_setting('role', true) <> 'service_role' THEN
        RAISE EXCEPTION 'Unauthorized: This function can only be called by service_role.';
    END IF;

    SELECT user_id, plan_id, status
    INTO v_transaction
    FROM public.transactions
    WHERE razorpay_order_id = p_razorpay_order_id;

    IF NOT FOUND THEN
        RAISE WARNING 'Transaction with Razorpay Order ID % not found in complete_purchase.', p_razorpay_order_id;
        RETURN;
    END IF;

    IF v_transaction.status <> 'paid' THEN
        RAISE WARNING 'Transaction % is not marked as paid. Cannot complete purchase.', p_razorpay_order_id;
        RETURN;
    END IF;

    SELECT visits
    INTO v_plan
    FROM public.visit_plans
    WHERE plan_id = v_transaction.plan_id;

    IF NOT FOUND THEN
        RAISE WARNING 'Visit plan % for transaction % not found.', v_transaction.plan_id, p_razorpay_order_id;
        RETURN;
    END IF;

    SELECT user_id, expiry_date
    INTO v_customer
    FROM public.customers
    WHERE user_id = v_transaction.user_id;

    IF NOT FOUND THEN
         -- This should ideally not happen if the user_created trigger for customers works.
        RAISE WARNING 'Customer profile for user ID % not found. Cannot update visit balance.', v_transaction.user_id;
        -- Attempt to create a minimal customer record to apply the plan to.
        INSERT INTO public.customers (user_id, visit_balance, expiry_date)
        VALUES (v_transaction.user_id, v_plan.visits, (CURRENT_DATE + INTERVAL '30 days'))
        ON CONFLICT (user_id) DO NOTHING; -- If created concurrently, do nothing.

        -- Re-fetch customer data if it was just inserted.
        SELECT user_id, expiry_date
        INTO v_customer
        FROM public.customers
        WHERE user_id = v_transaction.user_id;

        IF NOT FOUND THEN
             RAISE EXCEPTION 'Failed to create or find customer profile for user ID % after attempting insert.', v_transaction.user_id;
        END IF;
    END IF;
    
    UPDATE public.customers
    SET visit_balance = visit_balance + v_plan.visits,
        expiry_date = GREATEST(COALESCE(v_customer.expiry_date, CURRENT_DATE - INTERVAL '1 day'), CURRENT_DATE) + INTERVAL '30 days', -- Assumes each plan purchase grants a 30-day validity extension from the later of current expiry or today.
        updated_at = CURRENT_TIMESTAMP
    WHERE user_id = v_transaction.user_id;

    RAISE NOTICE 'Purchase completed for Razorpay Order ID %: User % visits updated.', p_razorpay_order_id, v_transaction.user_id;

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
-- Grant execute to service_role is typically done in 10_revoke_permissions.sql or via Supabase dashboard.


-- Function to update transaction status, typically called by a payment gateway webhook.
CREATE OR REPLACE FUNCTION public.update_transaction_status(
    p_razorpay_order_id TEXT,
    p_status TEXT,
    p_razorpay_payment_id TEXT DEFAULT NULL,
    p_razorpay_signature TEXT DEFAULT NULL,
    p_error_message TEXT DEFAULT NULL
) RETURNS VOID AS $$
DECLARE
    v_transaction_id UUID;
BEGIN
    -- This function is intended to be called by a trusted backend service/webhook (e.g. Supabase Edge Function)
    -- The calling context MUST be switched to 'service_role' before invoking this.
    IF current_setting('role', true) <> 'service_role' THEN
        RAISE EXCEPTION 'Unauthorized: This function can only be called by service_role.';
    END IF;

    UPDATE public.transactions
    SET status = p_status,
        razorpay_payment_id = COALESCE(p_razorpay_payment_id, razorpay_payment_id),
        razorpay_signature = COALESCE(p_razorpay_signature, razorpay_signature),
        error_message = COALESCE(p_error_message, error_message),
        updated_at = CURRENT_TIMESTAMP
    WHERE razorpay_order_id = p_razorpay_order_id
    RETURNING transaction_id INTO v_transaction_id;

    IF NOT FOUND THEN
        RAISE WARNING 'Transaction with Razorpay Order ID % not found. Status not updated.', p_razorpay_order_id;
        RETURN;
    END IF;

    IF p_status = 'paid' THEN
        -- Call complete_purchase to update customer's visit balance
        PERFORM public.complete_purchase(p_razorpay_order_id);
    END IF;

    RAISE NOTICE 'Transaction % (Razorpay Order ID: %) status updated to %.', v_transaction_id, p_razorpay_order_id, p_status;

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
-- Grant execute to service_role is typically done in 10_revoke_permissions.sql or via Supabase dashboard.


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


-- Description: Functions for customers to browse and view publicly listed properties.
-------------------------------------------------------------------------------

-- Function to get listed properties with filters for customers
CREATE OR REPLACE FUNCTION public.get_properties_customer(
    p_property_types public.property_type_enum[] DEFAULT NULL,
    p_listing_types public.listing_type_enum[] DEFAULT NULL,
    p_pincodes INTEGER[] DEFAULT NULL,
    p_price_min DECIMAL DEFAULT NULL,
    p_price_max DECIMAL DEFAULT NULL,
    p_area_min DECIMAL DEFAULT NULL,
    p_area_max DECIMAL DEFAULT NULL,
    p_area_unit public.area_unit_enum DEFAULT NULL,
    p_location_search TEXT DEFAULT NULL, -- Searches locality, city, address, pincode, AND post titles
    p_city TEXT DEFAULT NULL,
    p_is_featured BOOLEAN DEFAULT NULL,
    p_house_types public.house_type_enum[] DEFAULT NULL,
    p_num_bedrooms_min INTEGER DEFAULT NULL,
    p_num_bedrooms_max INTEGER DEFAULT NULL,
    p_furnished_statuses public.furnished_status_enum[] DEFAULT NULL,
    p_facing_directions public.direction_enum[] DEFAULT NULL,
    p_land_types public.land_type_enum[] DEFAULT NULL,
    p_building_types public.building_type_enum[] DEFAULT NULL,
    p_offset INTEGER DEFAULT 0,
    p_limit INTEGER DEFAULT 10,
    p_sort_by TEXT DEFAULT 'updated_at',
    p_sort_direction TEXT DEFAULT 'DESC'
) RETURNS TABLE (
    property_id UUID,
    property_type public.property_type_enum,
    listing_type public.listing_type_enum,
    price DECIMAL,
    advance_amount DECIMAL,
    area DECIMAL,
    area_unit public.area_unit_enum,
    year_built INTEGER,
    description TEXT,
    details JSONB,
    youtube_url TEXT,
    locality TEXT,
    city TEXT,
    pincode INTEGER,
    latitude DECIMAL(9,6),
    longitude DECIMAL(9,6),
    nearest_hospital DECIMAL,
    nearest_busstop DECIMAL,
    nearest_gym DECIMAL,
    nearest_park DECIMAL,
    nearest_school DECIMAL,
    nearest_swimmingpool DECIMAL,
    proximity_unit public.proximity_unit_enum,
    is_featured BOOLEAN,
    property_images JSONB,
    updated_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE,
    is_in_wishlist BOOLEAN,
    interaction_status public.interaction_status_enum,
    interaction_id UUID,
    property_name TEXT,
    total_count BIGINT
) AS $$
DECLARE
    v_sql TEXT;
    v_order_by_clause TEXT;
    v_final_sort_by TEXT;
    v_final_sort_direction TEXT;
    v_allowed_sort_columns TEXT[] := ARRAY['price', 'area', 'updated_at', 'created_at', 'locality', 'city', 'year_built', 'pincode'];
    v_current_user_id UUID := auth.uid();
BEGIN
    IF p_sort_by IS NOT NULL AND p_sort_by = ANY(v_allowed_sort_columns) THEN
        v_final_sort_by := 'pwc.' || quote_ident(p_sort_by);
    ELSE
        v_final_sort_by := 'pwc.updated_at';
    END IF;

    IF p_sort_direction IS NOT NULL AND upper(p_sort_direction) IN ('ASC', 'DESC') THEN
        v_final_sort_direction := upper(p_sort_direction);
    ELSE
        v_final_sort_direction := 'DESC';
    END IF;

    v_order_by_clause := format('ORDER BY pwc.is_featured DESC, %s %s, pwc.property_id ASC', v_final_sort_by, v_final_sort_direction);

    v_sql := $QUERY$
        WITH props_base AS (
            SELECT
                p.property_id, p.property_type, p.listing_type, p.price, p.advance_amount, p.area, p.area_unit, p.year_built,
                p.description, p.details, p.youtube_url, p.locality, p.city, p.pincode, p.latitude, p.longitude,
                p.nearest_hospital, p.nearest_busstop, p.nearest_gym, p.nearest_park, p.nearest_school, p.nearest_swimmingpool,
                p.proximity_unit, p.is_featured, p.updated_at, p.created_at,
                COALESCE(p.details->>'house_name', p.details->>'building_name', p.details->>'land_name', p.locality) AS derived_property_name,
                (
                    SELECT COALESCE(jsonb_agg(
                        jsonb_build_object(
                            'image_id', pi.image_id,
                            'image_url', pi.image_url,
                            'description', pi.description,
                            'display_order', pi.display_order
                        ) ORDER BY pi.display_order ASC
                    ), '[]'::jsonb)
                    FROM public.property_images pi
                    WHERE pi.property_id = p.property_id AND pi.is_internal_image = FALSE
                ) AS property_images_data,
                latest_ci.status AS current_interaction_status,
                latest_ci.interaction_id AS current_interaction_id,
                EXISTS (
                    SELECT 1 FROM public.customers_interaction ci_wishlist
                    WHERE ci_wishlist.property_id = p.property_id
                      AND ci_wishlist.user_id = $19
                      AND ci_wishlist.status = 'WISHLISTED'
                ) AS is_in_wishlist_flag
            FROM public.properties p
            LEFT JOIN LATERAL (
                SELECT ci.status, ci.interaction_id
                FROM public.customers_interaction ci
                WHERE ci.property_id = p.property_id AND ci.user_id = $19
                ORDER BY ci.status DESC, ci.updated_at DESC
                LIMIT 1
            ) latest_ci ON true
            WHERE p.is_listed = TRUE
                AND ($1 IS NULL OR p.property_type = ANY($1))
                AND ($2 IS NULL OR p.listing_type = ANY($2))
                AND ($3 IS NULL OR p.pincode = ANY($3))
                AND ($4 IS NULL OR p.price >= $4)
                AND ($5 IS NULL OR p.price <= $5)
                AND ($6 IS NULL OR p.area >= $6)
                AND ($7 IS NULL OR p.area <= $7)
                AND ($8 IS NULL OR p.area_unit = $8)
                AND ($9 IS NULL OR (
                    p.locality ILIKE '%' || $9 || '%' OR
                    p.address ILIKE '%' || $9 || '%' OR
                    p.city ILIKE '%' || $9 || '%' OR
                    p.pincode::TEXT ILIKE '%' || $9 || '%' OR
                    COALESCE(p.details->>'house_name', '') ILIKE '%' || $9 || '%' OR
                    COALESCE(p.details->>'building_name', '') ILIKE '%' || $9 || '%' OR
                    COALESCE(p.details->>'land_name', '') ILIKE '%' || $9 || '%'
                ))
                AND ($10 IS NULL OR p.city ILIKE $10)
                AND ($11 IS NULL OR p.is_featured = $11)
                AND (p.property_type <> 'HOUSE' OR (
                    ($12 IS NULL OR (p.details->>'house_type')::public.house_type_enum = ANY($12))
                    AND ($13 IS NULL OR (p.details->>'num_bedrooms')::INTEGER >= $13)
                    AND ($14 IS NULL OR (p.details->>'num_bedrooms')::INTEGER <= $14)
                    AND ($15 IS NULL OR (p.details->>'furnished_status')::public.furnished_status_enum = ANY($15))
                    AND ($16 IS NULL OR (p.details->>'facing_direction')::public.direction_enum = ANY($16))
                ))
                AND (p.property_type <> 'LAND' OR (($17 IS NULL OR (p.details->>'land_type')::public.land_type_enum = ANY($17))))
                AND (p.property_type <> 'BUILDING' OR (($18 IS NULL OR (p.details->>'building_type')::public.building_type_enum = ANY($18))))
        ),
        props_with_count AS (
            SELECT *, COUNT(*) OVER() AS total_rows FROM props_base
        )
        SELECT
            pwc.property_id, pwc.property_type, pwc.listing_type, pwc.price, pwc.advance_amount, pwc.area, pwc.area_unit, pwc.year_built,
            pwc.description, pwc.details, pwc.youtube_url, pwc.locality, pwc.city, pwc.pincode, pwc.latitude, pwc.longitude,
            pwc.nearest_hospital, pwc.nearest_busstop, pwc.nearest_gym, pwc.nearest_park, pwc.nearest_school, pwc.nearest_swimmingpool,
            pwc.proximity_unit, pwc.is_featured, pwc.property_images_data AS property_images,
            pwc.updated_at, pwc.created_at,
            pwc.is_in_wishlist_flag AS is_in_wishlist,
            pwc.current_interaction_status AS interaction_status,
            pwc.current_interaction_id AS interaction_id,
            pwc.derived_property_name AS property_name,
            pwc.total_rows AS total_count
        FROM props_with_count pwc
    $QUERY$;

    v_sql := v_sql || ' ' || v_order_by_clause || ' OFFSET $20 LIMIT $21';

    RETURN QUERY EXECUTE v_sql
        USING p_property_types, p_listing_types, p_pincodes, p_price_min, p_price_max, p_area_min, p_area_max, p_area_unit,
              p_location_search, p_city, p_is_featured, p_house_types, p_num_bedrooms_min, p_num_bedrooms_max,
              p_furnished_statuses, p_facing_directions, p_land_types, p_building_types,
              v_current_user_id,
              p_offset, p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;
GRANT EXECUTE ON FUNCTION public.get_properties_customer(public.property_type_enum[], public.listing_type_enum[], INTEGER[], DECIMAL, DECIMAL, DECIMAL, DECIMAL, public.area_unit_enum, TEXT, TEXT, BOOLEAN, public.house_type_enum[], INTEGER, INTEGER, public.furnished_status_enum[], public.direction_enum[], public.land_type_enum[], public.building_type_enum[], INTEGER, INTEGER, TEXT, TEXT) TO anon, authenticated;

-- Function to get a single property by ID for customers (public view)
CREATE OR REPLACE FUNCTION public.get_property_from_id_customer(
    p_requested_property_id UUID
) RETURNS TABLE (
    property_id UUID,
    property_type public.property_type_enum,
    listing_type public.listing_type_enum,
    price DECIMAL,
    advance_amount DECIMAL,
    area DECIMAL,
    area_unit public.area_unit_enum,
    year_built INTEGER,
    description TEXT,
    details JSONB,
    youtube_url TEXT,
    locality TEXT,
    city TEXT,
    address TEXT,
    pincode INTEGER,
    latitude DECIMAL(9,6),
    longitude DECIMAL(9,6),
    nearest_hospital DECIMAL,
    nearest_busstop DECIMAL,
    nearest_gym DECIMAL,
    nearest_park DECIMAL,
    nearest_school DECIMAL,
    nearest_swimmingpool DECIMAL,
    proximity_unit public.proximity_unit_enum,
    is_featured BOOLEAN,
    property_images JSONB,
    updated_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE,
    is_in_wishlist BOOLEAN,
    interaction_status public.interaction_status_enum,
    interaction_id UUID,
    property_name TEXT,
    submitter_info JSONB
) AS $$
DECLARE
    v_current_user_id UUID := auth.uid();
BEGIN
    RETURN QUERY
    SELECT
        p.property_id, p.property_type, p.listing_type, p.price, p.advance_amount, p.area, p.area_unit, p.year_built,
        p.description, p.details, p.youtube_url, p.locality, p.city, p.address, p.pincode, p.latitude, p.longitude,
        p.nearest_hospital, p.nearest_busstop, p.nearest_gym, p.nearest_park, p.nearest_school, p.nearest_swimmingpool,
        p.proximity_unit, p.is_featured,
        (
            SELECT COALESCE(jsonb_agg(
                jsonb_build_object(
                    'image_id', pi.image_id,
                    'image_url', pi.image_url,
                    'description', pi.description,
                    'display_order', pi.display_order
                ) ORDER BY pi.display_order ASC
            ), '[]'::jsonb)
            FROM public.property_images pi
            WHERE pi.property_id = p.property_id AND pi.is_internal_image = FALSE
        ) AS property_images_data,
        p.updated_at, p.created_at,
        EXISTS (
            SELECT 1 FROM public.customers_interaction ci_wishlist
            WHERE ci_wishlist.property_id = p.property_id
              AND ci_wishlist.user_id = v_current_user_id
              AND ci_wishlist.status = 'WISHLISTED'
        ) AS is_in_wishlist_flag,
        latest_ci.status AS current_interaction_status,
        latest_ci.interaction_id AS current_interaction_id,
        COALESCE(p.details->>'house_name', p.details->>'building_name', p.details->>'land_name', p.locality) AS derived_property_name,
        CASE
            WHEN p.can_reachout = TRUE AND u_submitter.id IS NOT NULL THEN
                jsonb_build_object(
                    'name', u_submitter.raw_user_meta_data->>'full_name'
                )
            ELSE NULL
        END AS submitter_info_data
    FROM public.properties p
    LEFT JOIN LATERAL (
        SELECT ci.status, ci.interaction_id
        FROM public.customers_interaction ci
        WHERE ci.property_id = p.property_id AND ci.user_id = v_current_user_id
        ORDER BY ci.status DESC, ci.updated_at DESC
        LIMIT 1
    ) latest_ci ON true
    LEFT JOIN auth.users u_submitter ON p.submitter = u_submitter.id
    WHERE p.property_id = p_requested_property_id
      AND p.is_listed = TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;
GRANT EXECUTE ON FUNCTION public.get_property_from_id_customer(UUID) TO anon, authenticated;


-- Description: Functions for property owners to submit and manage their properties.
-------------------------------------------------------------------------------

-- Function for customers to insert a new property submission
CREATE OR REPLACE FUNCTION public.insert_property_customer(
    p_property_type public.property_type_enum,
    p_listing_type public.listing_type_enum,
    p_price DECIMAL,
    p_area DECIMAL,
    p_area_unit public.area_unit_enum,
    p_details JSONB,
    p_locality TEXT,
    p_city TEXT,
    p_address TEXT,
    p_pincode INTEGER,
    p_submitter_type public.submitter_type_enum,
    p_year_built INTEGER DEFAULT NULL,
    p_description TEXT DEFAULT NULL,
    p_youtube_url TEXT DEFAULT NULL,
    p_latitude DECIMAL(9,6) DEFAULT NULL,
    p_longitude DECIMAL(9,6) DEFAULT NULL,
    p_nearest_hospital DECIMAL(5,1) DEFAULT NULL,
    p_nearest_busstop DECIMAL(5,1) DEFAULT NULL,
    p_nearest_gym DECIMAL(5,1) DEFAULT NULL,
    p_nearest_park DECIMAL(5,1) DEFAULT NULL,
    p_nearest_school DECIMAL(5,1) DEFAULT NULL,
    p_nearest_swimmingpool DECIMAL(5,1) DEFAULT NULL,
    p_proximity_unit public.proximity_unit_enum DEFAULT 'KM',
    p_inventory_details JSONB DEFAULT '{}'::jsonb,
    p_is_exclusive BOOLEAN DEFAULT FALSE,
    p_submitter_notes TEXT DEFAULT NULL,
    p_availability_status public.availability_status_enum DEFAULT NULL,
    p_can_reachout BOOLEAN DEFAULT TRUE,
    p_management_plan_id UUID DEFAULT NULL,
    p_advance_amount DECIMAL(10,2) DEFAULT NULL,
    p_rent_due_day INTEGER DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
    v_property_id UUID;
    v_user_id UUID := auth.uid();
BEGIN
    IF auth.role() <> 'authenticated' THEN
        RAISE EXCEPTION 'Authentication required.';
    END IF;

    IF p_details IS NULL THEN
        RAISE EXCEPTION 'Property details (JSONB) cannot be null.';
    END IF;

    IF p_property_type = 'HOUSE' THEN
        IF NOT (p_details ? 'house_name') OR TRIM(p_details->>'house_name') = '' THEN
            RAISE EXCEPTION 'Post Title (house_name) is required for House properties within details.';
        END IF;
    ELSIF p_property_type = 'LAND' THEN
        IF NOT (p_details ? 'land_name') OR TRIM(p_details->>'land_name') = '' THEN
            RAISE EXCEPTION 'Post Title (land_name) is required for Land properties within details.';
        END IF;
    ELSIF p_property_type = 'BUILDING' THEN
        IF NOT (p_details ? 'building_name') OR TRIM(p_details->>'building_name') = '' THEN
            RAISE EXCEPTION 'Post Title (building_name) is required for Building properties within details.';
        END IF;
    END IF;

    IF p_management_plan_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public.management_service_plans WHERE plan_id = p_management_plan_id AND is_active = TRUE) THEN
        RAISE EXCEPTION 'Invalid or inactive management plan ID: %', p_management_plan_id;
    END IF;

    IF p_listing_type = 'RENTAL' AND p_rent_due_day IS NOT NULL AND (p_rent_due_day < 1 OR p_rent_due_day > 28) THEN
        RAISE EXCEPTION 'Rent due day must be between 1 and 28 for rentals.';
    END IF;
    IF p_listing_type = 'SALE' THEN
        p_rent_due_day := NULL;
        p_advance_amount := NULL;
    END IF;

    INSERT INTO public.properties (
        property_type, listing_type, price, area, area_unit, year_built, description, details, youtube_url,
        locality, city, address, pincode, latitude, longitude,
        nearest_hospital, nearest_busstop, nearest_gym, nearest_park, nearest_school, nearest_swimmingpool, proximity_unit,
        inventory_details, is_exclusive, submitter_notes, availability_status, can_reachout, management_plan_id,
        advance_amount, rent_due_day,
        submitter, submitter_type, submitted_at, admin_status, is_listed, is_featured
    ) VALUES (
        p_property_type, p_listing_type, p_price, p_area, p_area_unit, p_year_built, p_description, p_details, p_youtube_url,
        p_locality, p_city, p_address, p_pincode, p_latitude, p_longitude,
        p_nearest_hospital, p_nearest_busstop, p_nearest_gym, p_nearest_park, p_nearest_school, p_nearest_swimmingpool, p_proximity_unit,
        COALESCE(p_inventory_details, '{}'::jsonb), p_is_exclusive, p_submitter_notes, p_availability_status, p_can_reachout, p_management_plan_id,
        p_advance_amount, p_rent_due_day,
        v_user_id, p_submitter_type, CURRENT_TIMESTAMP, 'SUBMITTED', FALSE, FALSE
    ) RETURNING property_id INTO v_property_id;

    RETURN v_property_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.insert_property_customer(public.property_type_enum, public.listing_type_enum, DECIMAL, DECIMAL, public.area_unit_enum, JSONB, TEXT, TEXT, TEXT, INTEGER, public.submitter_type_enum, INTEGER, TEXT, TEXT, DECIMAL(9,6), DECIMAL(9,6), DECIMAL(5,1), DECIMAL(5,1), DECIMAL(5,1), DECIMAL(5,1), DECIMAL(5,1), DECIMAL(5,1), public.proximity_unit_enum, JSONB, BOOLEAN, TEXT, public.availability_status_enum, BOOLEAN, UUID, DECIMAL(10,2), INTEGER) TO authenticated;

-- Function for customers to update their property submission
CREATE OR REPLACE FUNCTION public.update_property_customer(
    p_property_id UUID,
    p_property_type public.property_type_enum,
    p_listing_type public.listing_type_enum,
    p_price DECIMAL,
    p_area DECIMAL,
    p_area_unit public.area_unit_enum,
    p_details JSONB,
    p_locality TEXT,
    p_city TEXT,
    p_address TEXT,
    p_pincode INTEGER,
    p_submitter_type public.submitter_type_enum,
    p_year_built INTEGER DEFAULT NULL,
    p_description TEXT DEFAULT NULL,
    p_youtube_url TEXT DEFAULT NULL,
    p_latitude DECIMAL(9,6) DEFAULT NULL,
    p_longitude DECIMAL(9,6) DEFAULT NULL,
    p_nearest_hospital DECIMAL(5,1) DEFAULT NULL,
    p_nearest_busstop DECIMAL(5,1) DEFAULT NULL,
    p_nearest_gym DECIMAL(5,1) DEFAULT NULL,
    p_nearest_park DECIMAL(5,1) DEFAULT NULL,
    p_nearest_school DECIMAL(5,1) DEFAULT NULL,
    p_nearest_swimmingpool DECIMAL(5,1) DEFAULT NULL,
    p_proximity_unit public.proximity_unit_enum DEFAULT 'KM',
    p_inventory_details JSONB DEFAULT NULL,
    p_is_exclusive BOOLEAN DEFAULT FALSE,
    p_submitter_notes TEXT DEFAULT NULL,
    p_availability_status public.availability_status_enum DEFAULT NULL,
    p_can_reachout BOOLEAN DEFAULT TRUE,
    p_management_plan_id UUID DEFAULT NULL,
    p_advance_amount DECIMAL(10,2) DEFAULT NULL,
    p_rent_due_day INTEGER DEFAULT NULL
) RETURNS VOID AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_current_admin_status public.property_admin_status_enum;
BEGIN
    IF auth.role() <> 'authenticated' THEN
        RAISE EXCEPTION 'Authentication required.';
    END IF;

    SELECT admin_status INTO v_current_admin_status FROM public.properties
    WHERE property_id = p_property_id AND submitter = v_user_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Property not found or you do not have permission to update it.';
    END IF;

    IF v_current_admin_status NOT IN ('SUBMITTED', 'REJECTED', 'SUSPENDED') THEN
        RAISE EXCEPTION 'Property cannot be edited by owner in its current state: %', v_current_admin_status;
    END IF;

    IF p_details IS NULL THEN
        RAISE EXCEPTION 'Property details (JSONB) cannot be null.';
    END IF;

    -- Validate mandatory "Post Title" within p_details based on property type
    IF p_property_type = 'HOUSE' THEN
        IF NOT (p_details ? 'house_name') OR TRIM(p_details->>'house_name') = '' THEN
            RAISE EXCEPTION 'Post Title (house_name) is required for House properties within details.';
        END IF;
    ELSIF p_property_type = 'LAND' THEN
        IF NOT (p_details ? 'land_name') OR TRIM(p_details->>'land_name') = '' THEN
            RAISE EXCEPTION 'Post Title (land_name) is required for Land properties within details.';
        END IF;
    ELSIF p_property_type = 'BUILDING' THEN
        IF NOT (p_details ? 'building_name') OR TRIM(p_details->>'building_name') = '' THEN
            RAISE EXCEPTION 'Post Title (building_name) is required for Building properties within details.';
        END IF;
    END IF;

    IF p_management_plan_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public.management_service_plans WHERE plan_id = p_management_plan_id AND is_active = TRUE) THEN
        RAISE EXCEPTION 'Invalid or inactive management plan ID: %', p_management_plan_id;
    END IF;

    IF p_listing_type = 'RENTAL' AND p_rent_due_day IS NOT NULL AND (p_rent_due_day < 1 OR p_rent_due_day > 28) THEN
        RAISE EXCEPTION 'Rent due day must be between 1 and 28 for rentals.';
    END IF;

    UPDATE public.properties SET
        property_type = p_property_type,
        listing_type = p_listing_type,
        price = p_price,
        area = p_area,
        area_unit = p_area_unit,
        year_built = p_year_built,
        description = p_description,
        details = p_details,
        youtube_url = p_youtube_url,
        locality = p_locality,
        city = p_city,
        address = p_address,
        pincode = p_pincode,
        latitude = p_latitude,
        longitude = p_longitude,
        nearest_hospital = p_nearest_hospital,
        nearest_busstop = p_nearest_busstop,
        nearest_gym = p_nearest_gym,
        nearest_park = p_nearest_park,
        nearest_school = p_nearest_school,
        nearest_swimmingpool = p_nearest_swimmingpool,
        proximity_unit = p_proximity_unit,
        inventory_details = COALESCE(p_inventory_details, inventory_details),
        is_exclusive = p_is_exclusive,
        submitter_notes = p_submitter_notes,
        submitter_type = p_submitter_type,
        availability_status = p_availability_status,
        can_reachout = p_can_reachout,
        management_plan_id = p_management_plan_id,
        advance_amount = CASE WHEN p_listing_type = 'SALE' THEN NULL ELSE p_advance_amount END,
        rent_due_day = CASE WHEN p_listing_type = 'SALE' THEN NULL ELSE p_rent_due_day END,
        admin_status = 'SUBMITTED',
        is_listed = FALSE,
        updated_at = CURRENT_TIMESTAMP
    WHERE property_id = p_property_id AND submitter = v_user_id;

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.update_property_customer(UUID, public.property_type_enum, public.listing_type_enum, DECIMAL, DECIMAL, public.area_unit_enum, JSONB, TEXT, TEXT, TEXT, INTEGER, public.submitter_type_enum, INTEGER, TEXT, TEXT, DECIMAL(9,6), DECIMAL(9,6), DECIMAL(5,1), DECIMAL(5,1), DECIMAL(5,1), DECIMAL(5,1), DECIMAL(5,1), DECIMAL(5,1), public.proximity_unit_enum, JSONB, BOOLEAN, TEXT, public.availability_status_enum, BOOLEAN, UUID, DECIMAL(10,2), INTEGER) TO authenticated;

-- Function for customer to view their submitted/managed properties
CREATE OR REPLACE FUNCTION public.get_my_properties_customer(
    p_offset INTEGER DEFAULT 0,
    p_limit INTEGER DEFAULT 10
)
RETURNS TABLE (
    property_id UUID,
    property_type public.property_type_enum,
    listing_type public.listing_type_enum,
    price DECIMAL,
    advance_amount DECIMAL,
    area DECIMAL,
    area_unit public.area_unit_enum,
    year_built INTEGER,
    description TEXT,
    details JSONB,
    youtube_url TEXT,
    locality TEXT,
    city TEXT,
    address TEXT,
    pincode INTEGER,
    latitude DECIMAL(9,6),
    longitude DECIMAL(9,6),
    nearest_hospital DECIMAL,
    nearest_busstop DECIMAL,
    nearest_gym DECIMAL,
    nearest_park DECIMAL,
    nearest_school DECIMAL,
    nearest_swimmingpool DECIMAL,
    proximity_unit public.proximity_unit_enum,
    is_featured BOOLEAN,
    is_exclusive BOOLEAN,
    admin_status public.property_admin_status_enum,
    is_listed BOOLEAN,
    interaction_count BIGINT,
    inventory_details JSONB,
    submitter_type public.submitter_type_enum,
    submitter_notes TEXT,
    submitted_at TIMESTAMP WITH TIME ZONE,
    availability_status public.availability_status_enum,
    can_reachout BOOLEAN,
    management_plan_id UUID,
    management_plan_name TEXT,
    property_images JSONB,
    tenant_info JSONB,
    updated_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE,
    total_count BIGINT
) AS $$
DECLARE
    v_current_user_id UUID := auth.uid();
BEGIN
    IF auth.role() <> 'authenticated' THEN
        RAISE EXCEPTION 'Authentication required.';
    END IF;

    RETURN QUERY
    WITH my_props_base AS (
        SELECT
            p.*,
            msp.name as management_plan_name_val,
            (
                SELECT COALESCE(jsonb_agg(
                    jsonb_build_object(
                        'image_id', pi.image_id,
                        'image_url', pi.image_url,
                        'description', pi.description,
                        'display_order', pi.display_order,
                        'is_internal_image', pi.is_internal_image
                    ) ORDER BY pi.display_order ASC
                ), '[]'::jsonb)
                FROM public.property_images pi
                WHERE pi.property_id = p.property_id
            ) AS all_property_images_data,
            CASE
                WHEN p.tenant IS NOT NULL AND tenant_user.id IS NOT NULL THEN jsonb_build_object(
                    'user_id', tenant_user.id,
                    'name', (tenant_user.raw_user_meta_data ->> 'full_name')::TEXT,
                    'email', tenant_user.email::TEXT,
                    'phone', tenant_user.phone::TEXT
                )
                ELSE NULL
            END AS tenant_data,
            (SELECT COUNT(*) FROM public.customers_interaction ci WHERE ci.property_id = p.property_id) AS interaction_count_val
        FROM public.properties p
        LEFT JOIN public.management_service_plans msp ON p.management_plan_id = msp.plan_id
        LEFT JOIN auth.users tenant_user ON p.tenant = tenant_user.id
        WHERE p.submitter = v_current_user_id
    ),
    props_with_total_count AS (
        SELECT *, COUNT(*) OVER() as total_rows FROM my_props_base
    )
    SELECT
        pwc.property_id, pwc.property_type, pwc.listing_type, pwc.price, pwc.advance_amount, pwc.area, pwc.area_unit, pwc.year_built,
        pwc.description, pwc.details, pwc.youtube_url, pwc.locality, pwc.city, pwc.address, pwc.pincode, pwc.latitude, pwc.longitude,
        pwc.nearest_hospital, pwc.nearest_busstop, pwc.nearest_gym, pwc.nearest_park, pwc.nearest_school, pwc.nearest_swimmingpool,
        pwc.proximity_unit, pwc.is_featured, pwc.is_exclusive, pwc.admin_status, pwc.is_listed,
        pwc.interaction_count_val,
        pwc.inventory_details, pwc.submitter_type, pwc.submitter_notes, pwc.submitted_at,
        pwc.availability_status, pwc.can_reachout, pwc.management_plan_id, pwc.management_plan_name_val,
        pwc.all_property_images_data AS property_images,
        pwc.tenant_data AS tenant_info,
        pwc.updated_at, pwc.created_at, pwc.total_rows AS total_count
    FROM props_with_total_count pwc
    ORDER BY pwc.updated_at DESC
    OFFSET p_offset
    LIMIT p_limit;

END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;
GRANT EXECUTE ON FUNCTION public.get_my_properties_customer(INTEGER, INTEGER) TO authenticated;

-- Function for customer to view a single one of their submitted/managed properties by ID
CREATE OR REPLACE FUNCTION public.get_my_property_with_id_customer(
    p_property_id_input UUID
)
RETURNS TABLE (
    property_id UUID,
    property_type public.property_type_enum,
    listing_type public.listing_type_enum,
    price DECIMAL,
    advance_amount DECIMAL,
    area DECIMAL,
    area_unit public.area_unit_enum,
    year_built INTEGER,
    description TEXT,
    details JSONB,
    youtube_url TEXT,
    locality TEXT,
    city TEXT,
    address TEXT,
    pincode INTEGER,
    latitude DECIMAL(9,6),
    longitude DECIMAL(9,6),
    nearest_hospital DECIMAL,
    nearest_busstop DECIMAL,
    nearest_gym DECIMAL,
    nearest_park DECIMAL,
    nearest_school DECIMAL,
    nearest_swimmingpool DECIMAL,
    proximity_unit public.proximity_unit_enum,
    is_featured BOOLEAN,
    is_exclusive BOOLEAN,
    admin_status public.property_admin_status_enum,
    is_listed BOOLEAN,
    interaction_count BIGINT,
    inventory_details JSONB,
    submitter_type public.submitter_type_enum,
    submitter_notes TEXT,
    submitted_at TIMESTAMP WITH TIME ZONE,
    availability_status public.availability_status_enum,
    can_reachout BOOLEAN,
    management_plan_id UUID,
    management_plan_name TEXT,
    property_images JSONB,
    tenant_info JSONB,
    updated_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE
) AS $$
DECLARE
    v_current_user_id UUID := auth.uid();
BEGIN
    IF auth.role() <> 'authenticated' THEN
        RAISE EXCEPTION 'Authentication required.';
    END IF;

    RETURN QUERY
    SELECT
        p.property_id, p.property_type, p.listing_type, p.price, p.advance_amount, p.area, p.area_unit, p.year_built,
        p.description, p.details, p.youtube_url, p.locality, p.city, p.address, p.pincode, p.latitude, p.longitude,
        p.nearest_hospital, p.nearest_busstop, p.nearest_gym, p.nearest_park, p.nearest_school, p.nearest_swimmingpool,
        p.proximity_unit, p.is_featured, p.is_exclusive, p.admin_status, p.is_listed,
        (SELECT COUNT(*) FROM public.customers_interaction ci WHERE ci.property_id = p.property_id) AS interaction_count_val,
        p.inventory_details, p.submitter_type, p.submitter_notes, p.submitted_at,
        p.availability_status, p.can_reachout, p.management_plan_id, msp.name AS management_plan_name_val,
        (
            SELECT COALESCE(jsonb_agg(
                jsonb_build_object(
                    'image_id', pi.image_id,
                    'image_url', pi.image_url,
                    'description', pi.description,
                    'display_order', pi.display_order,
                    'is_internal_image', pi.is_internal_image
                ) ORDER BY pi.display_order ASC
            ), '[]'::jsonb)
            FROM public.property_images pi
            WHERE pi.property_id = p.property_id
        ) AS all_property_images_data,
        CASE
            WHEN p.tenant IS NOT NULL AND tenant_user.id IS NOT NULL THEN jsonb_build_object(
                'user_id', tenant_user.id,
                'name', (tenant_user.raw_user_meta_data ->> 'full_name')::TEXT,
                'email', tenant_user.email::TEXT,
                'phone', tenant_user.phone::TEXT
            )
            ELSE NULL
        END AS tenant_data,
        p.updated_at, p.created_at
    FROM public.properties p
    LEFT JOIN public.management_service_plans msp ON p.management_plan_id = msp.plan_id
    LEFT JOIN auth.users tenant_user ON p.tenant = tenant_user.id
    WHERE p.property_id = p_property_id_input AND p.submitter = v_current_user_id;

END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;
GRANT EXECUTE ON FUNCTION public.get_my_property_with_id_customer(UUID) TO authenticated;

-- Function for a customer to delete one of their property images
CREATE OR REPLACE FUNCTION public.delete_property_image_customer(p_image_id UUID, p_property_id UUID)
RETURNS VOID AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_property_admin_status public.property_admin_status_enum;
BEGIN
    IF auth.role() <> 'authenticated' THEN
        RAISE EXCEPTION 'Authentication required.';
    END IF;

    SELECT admin_status INTO v_property_admin_status
    FROM public.properties
    WHERE property_id = p_property_id AND submitter = v_user_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Property not found or you do not have permission to modify its images.';
    END IF;

    IF v_property_admin_status NOT IN ('SUBMITTED', 'REJECTED') THEN
        RAISE EXCEPTION 'Images can only be deleted if the property submission status is SUBMITTED or REJECTED.';
    END IF;

    DELETE FROM public.property_images
    WHERE image_id = p_image_id AND property_id = p_property_id;

    IF NOT FOUND THEN
        RAISE WARNING 'Image ID % not found for property ID %.', p_image_id, p_property_id;
    END IF;

    UPDATE public.properties SET updated_at = CURRENT_TIMESTAMP, admin_status = 'SUBMITTED', is_listed = FALSE
    WHERE property_id = p_property_id;

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.delete_property_image_customer(UUID, UUID) TO authenticated;


-- Function for a customer to edit one of their property images
CREATE OR REPLACE FUNCTION public.edit_property_image_customer(
    p_image_id UUID,
    p_property_id UUID,
    p_description TEXT DEFAULT NULL,
    p_display_order INTEGER DEFAULT NULL,
    p_is_internal_image BOOLEAN DEFAULT NULL
)
RETURNS VOID AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_property_admin_status public.property_admin_status_enum;
BEGIN
    IF auth.role() <> 'authenticated' THEN
        RAISE EXCEPTION 'Authentication required.';
    END IF;

    SELECT admin_status INTO v_property_admin_status
    FROM public.properties
    WHERE property_id = p_property_id AND submitter = v_user_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Property not found or you do not have permission to modify its images.';
    END IF;

    IF v_property_admin_status NOT IN ('SUBMITTED', 'REJECTED', 'SUSPENDED') THEN
        RAISE EXCEPTION 'Image details can only be edited if the property submission status is SUBMITTED or REJECTED.';
    END IF;

    UPDATE public.property_images SET
        description = COALESCE(p_description, description),
        display_order = COALESCE(p_display_order, display_order),
        is_internal_image = COALESCE(p_is_internal_image, is_internal_image)
    WHERE image_id = p_image_id AND property_id = p_property_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Image ID % not found for property ID %.', p_image_id, p_property_id;
    END IF;

    UPDATE public.properties SET updated_at = CURRENT_TIMESTAMP, admin_status = 'SUBMITTED', is_listed = FALSE
    WHERE property_id = p_property_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.edit_property_image_customer(UUID, UUID, TEXT, INTEGER, BOOLEAN) TO authenticated;

-- Function for customers to list active management service plans
CREATE OR REPLACE FUNCTION public.list_management_plans_customer()
RETURNS TABLE (
    plan_id UUID,
    name TEXT,
    percentage DECIMAL(5, 2),
    description TEXT
) AS $$
BEGIN
    -- IF auth.role() <> 'authenticated' THEN
    --     RAISE EXCEPTION 'Authentication required to list management plans.';
    -- END IF;

    RETURN QUERY
    SELECT
        msp.plan_id,
        msp.name,
        msp.percentage,
        msp.description
    FROM
        public.management_service_plans msp
    WHERE
        msp.is_active = TRUE
    ORDER BY
        msp.percentage ASC, msp.name ASC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;
GRANT EXECUTE ON FUNCTION public.list_management_plans_customer() TO authenticated;


-- Description: Functions for customers to manage their interactions with properties (wishlist, visits).
-------------------------------------------------------------------------------

-- Function to get interaction count for the current user (e.g., wishlist size, active visits)
CREATE OR REPLACE FUNCTION public.get_my_interaction_summary_customer()
RETURNS JSONB AS $$
DECLARE
    v_summary JSONB;
    v_current_user_id UUID := auth.uid();
BEGIN
    IF v_current_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.';
    END IF;

    SELECT jsonb_build_object(
        'wishlist_count', COUNT(*) FILTER (WHERE status = 'WISHLISTED'),
        'visit_pending_count', COUNT(*) FILTER (WHERE status = 'VISIT_PENDING'),
        'visit_scheduled_count', COUNT(*) FILTER (WHERE status IN ('VISIT_CONFIRMED_PENDING_SALES', 'VISIT_SCHEDULED_WITH_SALES')),
        'visit_completed_count', COUNT(*) FILTER (WHERE status = 'VISIT_COMPLETED')
    )
    INTO v_summary
    FROM public.customers_interaction
    WHERE user_id = v_current_user_id;

    RETURN COALESCE(v_summary, '{}'::jsonb);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;
GRANT EXECUTE ON FUNCTION public.get_my_interaction_summary_customer() TO authenticated;


-- Function to get all interactions for the current customer (wishlist, visits, etc.)
CREATE OR REPLACE FUNCTION public.get_my_interactions_customer(
    p_statuses public.interaction_status_enum[] DEFAULT NULL,
    p_offset INTEGER DEFAULT 0,
    p_limit INTEGER DEFAULT 10
)
RETURNS TABLE (
    interaction_id UUID,
    property_id UUID,
    interaction_status public.interaction_status_enum,
    created_at TIMESTAMP WITH TIME ZONE,
    updated_at TIMESTAMP WITH TIME ZONE,
    scheduled_for DATE,
    visited_at TIMESTAMP WITH TIME ZONE,
    property_type public.property_type_enum,
    listing_type public.listing_type_enum,
    price DECIMAL,
    advance_amount DECIMAL,
    property_name TEXT, -- e.g. house_name or locality
    locality TEXT,
    city TEXT,
    pincode INTEGER,
    property_main_image_url TEXT,
    assigned_sales_admin_name TEXT,
    assigned_sales_admin_email TEXT,
    assigned_sales_admin_phone TEXT,
    total_count BIGINT
) AS $$
DECLARE
    v_current_user_id UUID := auth.uid();
BEGIN
    IF v_current_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.';
    END IF;

    RETURN QUERY
    WITH user_interactions AS (
        SELECT
            ci.interaction_id, ci.property_id, ci.status, ci.created_at, ci.updated_at,
            ci.scheduled_for, ci.visited_at,
            p.property_type, p.listing_type, p.price, p.advance_amount,
            COALESCE(p.details->>'house_name', p.details->>'building_name', p.details->>'land_name', p.locality) AS prop_name,
            p.locality AS prop_locality, p.city AS prop_city, p.pincode AS prop_pincode,
            (SELECT pi.image_url FROM public.property_images pi
             WHERE pi.property_id = p.property_id AND pi.is_internal_image = FALSE
             ORDER BY pi.display_order LIMIT 1) AS main_image_url,
            sales_admin_user.raw_user_meta_data->>'full_name' AS sales_admin_full_name,
            sales_admin_user.email::TEXT AS sales_admin_email_val,
            sales_admin_user.phone::TEXT AS sales_admin_phone_val
        FROM public.customers_interaction ci
        JOIN public.properties p ON ci.property_id = p.property_id
        LEFT JOIN public.admins sales_admin ON ci.assigned_sales_admin_id = sales_admin.user_id AND sales_admin.is_active = TRUE
        LEFT JOIN auth.users sales_admin_user ON sales_admin.user_id = sales_admin_user.id
        WHERE ci.user_id = v_current_user_id
        --   AND p.is_listed = TRUE
          AND (p_statuses IS NULL OR ci.status = ANY(p_statuses))
    ),
    interactions_with_count AS (
        SELECT *, COUNT(*) OVER() AS total_rows FROM user_interactions
    )
    SELECT
        iwc.interaction_id, iwc.property_id, iwc.status AS interaction_status, iwc.created_at, iwc.updated_at,
        iwc.scheduled_for, iwc.visited_at,
        iwc.property_type, iwc.listing_type, iwc.price, iwc.advance_amount,
        iwc.prop_name AS property_name,
        iwc.prop_locality AS locality, iwc.prop_city AS city, iwc.prop_pincode AS pincode,
        iwc.main_image_url AS property_main_image_url,
        iwc.sales_admin_full_name AS assigned_sales_admin_name,
        iwc.sales_admin_email_val AS assigned_sales_admin_email,
        iwc.sales_admin_phone_val AS assigned_sales_admin_phone,
        iwc.total_rows AS total_count
    FROM interactions_with_count iwc
    ORDER BY iwc.updated_at DESC
    OFFSET p_offset
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;
GRANT EXECUTE ON FUNCTION public.get_my_interactions_customer(public.interaction_status_enum[], INTEGER, INTEGER) TO authenticated;

-- Function to add a property to wishlist (creates or updates interaction to WISHLISTED)
CREATE OR REPLACE FUNCTION public.add_to_wishlist_customer(p_property_id UUID)
RETURNS UUID AS $$
DECLARE
    v_interaction_id UUID;
    v_current_user_id UUID := auth.uid();
BEGIN
    IF v_current_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM public.properties WHERE property_id = p_property_id AND is_listed = TRUE) THEN
        RAISE EXCEPTION 'Property not found or not listed.';
    END IF;

    -- First, try to find an existing 'WISHLISTED' interaction
    SELECT interaction_id INTO v_interaction_id
    FROM public.customers_interaction
    WHERE user_id = v_current_user_id
      AND property_id = p_property_id
      AND status = 'WISHLISTED';

    -- If one is found, return its ID to ensure idempotency
    IF FOUND THEN
        RETURN v_interaction_id;
    END IF;

    -- If not found, attempt to insert a new one
    BEGIN
        INSERT INTO public.customers_interaction (user_id, property_id, status)
        VALUES (v_current_user_id, p_property_id, 'WISHLISTED')
        RETURNING interaction_id INTO v_interaction_id;
        
        RETURN v_interaction_id;
    EXCEPTION
        -- Handle the race condition where another transaction inserted the row
        -- between our SELECT and INSERT. The unique index will raise an error.
        WHEN unique_violation THEN
            -- The record was created by a concurrent transaction. We can now safely select it.
            SELECT interaction_id INTO v_interaction_id
            FROM public.customers_interaction
            WHERE user_id = v_current_user_id
              AND property_id = p_property_id
              AND status = 'WISHLISTED';
            
            RETURN v_interaction_id;
    END;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.add_to_wishlist_customer(UUID) TO authenticated;

-- Function to remove an interaction (e.g. from wishlist or cancel a pending visit if allowed by status)
-- NOTE: With multiple interactions possible, this function is now interpreted to ONLY remove the 'WISHLISTED' entry.
-- It does not affect any visit-related interactions. To cancel a specific visit, a different mechanism/function call is required.
CREATE OR REPLACE FUNCTION public.remove_interaction_customer(p_property_id UUID)
RETURNS VOID AS $$
DECLARE
    v_current_user_id UUID := auth.uid();
BEGIN
    IF v_current_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.';
    END IF;

    -- This function now only removes the property from the user's wishlist.
    DELETE FROM public.customers_interaction
    WHERE property_id = p_property_id
      AND user_id = v_current_user_id
      AND status = 'WISHLISTED';

    IF NOT FOUND THEN
        RAISE WARNING 'Property % was not in your wishlist. No interaction was removed.', p_property_id;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.remove_interaction_customer(UUID) TO authenticated;


-- Function for customer to request a property visit
CREATE OR REPLACE FUNCTION public.request_visit_customer(
    p_property_id UUID,
    p_preferred_date DATE
)
RETURNS UUID AS $$
DECLARE
    v_interaction_id UUID;
    v_user_id UUID := auth.uid();
    v_visit_balance INTEGER;
    v_expiry_date DATE;
    v_wishlisted_interaction_id UUID;
BEGIN
    IF v_user_id IS NULL THEN RAISE EXCEPTION 'Authentication required.'; END IF;

    SELECT c.visit_balance, c.expiry_date
    INTO v_visit_balance, v_expiry_date
    FROM public.customers c WHERE c.user_id = v_user_id;

    IF NOT FOUND THEN RAISE EXCEPTION 'Customer profile not found.'; END IF;
    IF v_visit_balance <= 0 OR v_expiry_date < CURRENT_DATE THEN
        RAISE EXCEPTION 'Insufficient visit balance or plan expired. Please recharge.';
    END IF;

    IF p_preferred_date <= CURRENT_DATE THEN
        RAISE EXCEPTION 'Visit must be scheduled for a future date (tomorrow or later).';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM public.properties WHERE property_id = p_property_id AND is_listed = TRUE) THEN
        RAISE EXCEPTION 'Property not found or not available for visits.';
    END IF;

    -- Prevent user from scheduling multiple open visits for the same property on the same day.
    IF EXISTS (
        SELECT 1 FROM public.customers_interaction
        WHERE user_id = v_user_id
          AND property_id = p_property_id
          AND scheduled_for = p_preferred_date
          AND status IN ('VISIT_PENDING', 'VISIT_CONFIRMED_PENDING_SALES', 'VISIT_SCHEDULED_WITH_SALES')
    ) THEN
        RAISE EXCEPTION 'You already have a visit requested or scheduled for this property on this date.';
    END IF;

    -- Look for an existing 'WISHLISTED' interaction to update.
    SELECT interaction_id INTO v_wishlisted_interaction_id
    FROM public.customers_interaction
    WHERE user_id = v_user_id
      AND property_id = p_property_id
      AND status = 'WISHLISTED'
    LIMIT 1;

    IF v_wishlisted_interaction_id IS NOT NULL THEN
        -- Found a wishlisted item, so update it to a visit request.
        UPDATE public.customers_interaction
        SET status = 'VISIT_PENDING',
            scheduled_for = p_preferred_date,
            updated_at = CURRENT_TIMESTAMP
        WHERE interaction_id = v_wishlisted_interaction_id
        RETURNING interaction_id INTO v_interaction_id;
    ELSE
        INSERT INTO public.customers_interaction (user_id, property_id, status, scheduled_for)
        VALUES (v_user_id, p_property_id, 'VISIT_PENDING', p_preferred_date)
        RETURNING interaction_id INTO v_interaction_id;
    END IF;

    -- Decrement visit balance since a new visit has been requested.
    UPDATE public.customers SET visit_balance = visit_balance - 1 WHERE user_id = v_user_id;

    RETURN v_interaction_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.request_visit_customer(UUID, DATE) TO authenticated;


-- FILE NAME: 05_04_customer_account_management_functions.sql
-- Description: Functions for customers to manage their account, visits, transactions.
-------------------------------------------------------------------------------

-- Function to get customer's visit balance and expiry date
CREATE OR REPLACE FUNCTION public.get_visit_status_customer()
RETURNS TABLE (visit_balance INTEGER, expiry_date DATE) AS $$
DECLARE
    v_user_id UUID := auth.uid();
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.';
    END IF;

    RETURN QUERY
    SELECT
        c.visit_balance,
        c.expiry_date
    FROM public.customers c
    WHERE c.user_id = v_user_id;

    -- If customer record doesn't exist (shouldn't happen due to trigger), return 0/null
    IF NOT FOUND THEN
        RETURN QUERY SELECT 0, CAST(NULL AS DATE);
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;
GRANT EXECUTE ON FUNCTION public.get_visit_status_customer() TO authenticated;

-- Function to get active visit plans available for purchase
CREATE OR REPLACE FUNCTION public.get_visit_plans_customer()
RETURNS TABLE (
    plan_id UUID,
    name TEXT,
    description TEXT,
    visits INTEGER,
    price DECIMAL
) AS $$
BEGIN
    -- No explicit auth check needed if RLS allows authenticated to select from visit_plans.
    -- Assuming RLS: CREATE POLICY visit_plans_select_active_authenticated ON public.visit_plans FOR SELECT TO authenticated USING (is_active = TRUE);
    RETURN QUERY
    SELECT vp.plan_id, vp.name, vp.description, vp.visits, vp.price
    FROM public.visit_plans vp
    WHERE vp.is_active = TRUE
    ORDER BY vp.price ASC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE; -- Or VOLATILE if it depends on auth.uid() in a more complex way for filtering
GRANT EXECUTE ON FUNCTION public.get_visit_plans_customer() TO authenticated;

-- Function to create a transaction record (called before redirecting to payment gateway)
CREATE OR REPLACE FUNCTION public.create_transaction_customer(
    p_plan_id UUID,
    p_razorpay_order_id TEXT -- Or any payment gateway order ID
)
RETURNS UUID AS $$
DECLARE
    v_transaction_id UUID;
    v_user_id UUID := auth.uid();
    v_amount DECIMAL;
    v_plan_is_active BOOLEAN;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.';
    END IF;

    SELECT price, is_active INTO v_amount, v_plan_is_active
    FROM public.visit_plans
    WHERE plan_id = p_plan_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Visit Plan ID % not found.', p_plan_id;
    END IF;
    IF v_plan_is_active = FALSE THEN
        RAISE EXCEPTION 'Visit Plan ID % is not active.', p_plan_id;
    END IF;

    IF p_razorpay_order_id IS NULL OR TRIM(p_razorpay_order_id) = '' THEN
        RAISE EXCEPTION 'Payment gateway Order ID cannot be null or empty.';
    END IF;

    INSERT INTO public.transactions (user_id, plan_id, amount, razorpay_order_id, status)
    VALUES (v_user_id, p_plan_id, v_amount, p_razorpay_order_id, 'created')
    RETURNING transaction_id INTO v_transaction_id;

    RETURN v_transaction_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.create_transaction_customer(UUID, TEXT) TO authenticated;

-- Function to get the current user's transaction history
CREATE OR REPLACE FUNCTION public.get_my_transactions_customer(
    p_offset INTEGER DEFAULT 0,
    p_limit INTEGER DEFAULT 10
) RETURNS TABLE (
    transaction_id UUID,
    plan_id UUID,
    plan_name TEXT,
    amount DECIMAL,
    status TEXT,
    razorpay_order_id TEXT,
    razorpay_payment_id TEXT,
    error_message TEXT,
    created_at TIMESTAMP WITH TIME ZONE,
    updated_at TIMESTAMP WITH TIME ZONE,
    total_count BIGINT
) AS $$
DECLARE
    v_current_user_id UUID := auth.uid();
BEGIN
    IF v_current_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.';
    END IF;

    RETURN QUERY
    WITH user_transactions AS (
        SELECT
            t.transaction_id, t.plan_id, vp.name AS plan_name_val, t.amount, t.status,
            t.razorpay_order_id, t.razorpay_payment_id, t.error_message,
            t.created_at, t.updated_at
        FROM public.transactions t
        LEFT JOIN public.visit_plans vp ON t.plan_id = vp.plan_id
        WHERE t.user_id = v_current_user_id
    ),
    transactions_with_count AS (
        SELECT *, COUNT(*) OVER() AS total_rows FROM user_transactions
    )
    SELECT
        twc.transaction_id, twc.plan_id, twc.plan_name_val, twc.amount, twc.status,
        twc.razorpay_order_id, twc.razorpay_payment_id, twc.error_message,
        twc.created_at, twc.updated_at,
        twc.total_rows
    FROM transactions_with_count twc
    ORDER BY twc.created_at DESC
    OFFSET p_offset
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;
GRANT EXECUTE ON FUNCTION public.get_my_transactions_customer(INTEGER, INTEGER) TO authenticated;


-- FILE NAME: 05_05_customer_rent_management_functions.sql
-- Description: Functions for tenants and landlords regarding rent.
-------------------------------------------------------------------------------

-- Function for Tenants to view properties they currently occupy
CREATE OR REPLACE FUNCTION public.get_my_occupied_properties_customer(
    p_offset INTEGER DEFAULT 0,
    p_limit INTEGER DEFAULT 10
)
RETURNS TABLE (
    property_id UUID,
    property_type public.property_type_enum,
    listing_type public.listing_type_enum, -- Should be 'RENTAL'
    -- price DECIMAL, -- This is monthly rent for rentals
    monthly_rent DECIMAL,
    advance_amount DECIMAL,
    area DECIMAL,
    area_unit public.area_unit_enum,
    year_built INTEGER,
    description TEXT,
    details JSONB,
    youtube_url TEXT,
    locality TEXT,
    city TEXT,
    address TEXT,
    pincode INTEGER,
    property_images JSONB, -- Array of {image_id, image_url, description, display_order} non-internal
    landlord_user_id UUID,
    landlord_name TEXT,
    landlord_email TEXT,
    landlord_phone TEXT,
    rent_due_day INTEGER,
    latest_rent_record_id UUID,
    latest_rent_amount_due DECIMAL,
    latest_rent_status public.rent_status_enum,
    latest_rent_due_date DATE,
    updated_at TIMESTAMP WITH TIME ZONE, -- Property updated_at
    total_count BIGINT
) AS $$
DECLARE
    v_current_user_id UUID := auth.uid();
BEGIN
     IF v_current_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.';
    END IF;

    RETURN QUERY
    WITH occupied_props_base AS (
        SELECT
            p.property_id, p.property_type, p.listing_type, p.price AS monthly_rent_val, p.advance_amount, p.area, p.area_unit, p.year_built,
            p.description, p.details, p.youtube_url, p.locality, p.city, p.address, p.pincode,
            (
                SELECT COALESCE(jsonb_agg(
                    jsonb_build_object(
                        'image_id', pi.image_id,
                        'image_url', pi.image_url,
                        'description', pi.description,
                        'display_order', pi.display_order
                    ) ORDER BY pi.display_order ASC
                ), '[]'::jsonb)
                FROM public.property_images pi
                WHERE pi.property_id = p.property_id AND pi.is_internal_image = FALSE
            ) AS property_images_data,
            p.submitter AS landlord_user_id_val,
            (landlord_auth_user.raw_user_meta_data ->> 'full_name')::TEXT AS landlord_name_val,
            landlord_auth_user.email::TEXT AS landlord_email_val,
            landlord_auth_user.phone::TEXT AS landlord_phone_val,
            p.rent_due_day AS rent_due_day_val,
            lr.rent_record_id AS latest_rent_record_id_val,
            lr.amount_due AS latest_rent_amount_due_val,
            lr.status AS latest_rent_status_val,
            lr.due_date AS latest_rent_due_date_val,
            p.updated_at AS property_updated_at
        FROM public.properties p
        JOIN auth.users landlord_auth_user ON p.submitter = landlord_auth_user.id -- Landlord is the submitter
        LEFT JOIN LATERAL (
            SELECT rr.rent_record_id, rr.amount_due, rr.status, rr.due_date
            FROM public.rent_records rr
            WHERE rr.property_id = p.property_id AND rr.tenant_user_id = v_current_user_id
            ORDER BY rr.due_date DESC
            LIMIT 1
        ) lr ON true
        WHERE p.tenant = v_current_user_id
          AND p.listing_type = 'RENTAL'
          -- AND p.is_listed = TRUE -- Tenant should see their occupied property even if admin temporarily unlisted it for some reason.
                                -- Or, if is_listed=FALSE means the tenancy ended, then this filter is fine.
                                -- For now, assuming tenant can always see properties they are marked as tenant for.
          AND p.admin_status NOT IN ('SOLD', 'REJECTED', 'SUSPENDED') -- Filter out definitively inactive states
    ),
    props_with_total_count AS (
        SELECT *, COUNT(*) OVER() as total_rows FROM occupied_props_base
    )
    SELECT
        pwc.property_id, pwc.property_type, pwc.listing_type, pwc.monthly_rent_val, pwc.advance_amount, pwc.area, pwc.area_unit, pwc.year_built,
        pwc.description, pwc.details, pwc.youtube_url, pwc.locality, pwc.city, pwc.address, pwc.pincode,
        pwc.property_images_data,
        pwc.landlord_user_id_val, pwc.landlord_name_val, pwc.landlord_email_val, pwc.landlord_phone_val,
        pwc.rent_due_day_val, pwc.latest_rent_record_id_val, pwc.latest_rent_amount_due_val, pwc.latest_rent_status_val, pwc.latest_rent_due_date_val,
        pwc.property_updated_at, pwc.total_rows
    FROM props_with_total_count pwc
    ORDER BY pwc.property_updated_at DESC
    OFFSET p_offset
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;
GRANT EXECUTE ON FUNCTION public.get_my_occupied_properties_customer(INTEGER, INTEGER) TO authenticated;

-- Function for Tenants to view their outstanding rent dues
CREATE OR REPLACE FUNCTION public.get_my_rent_dues_customer(
    p_offset INTEGER DEFAULT 0,
    p_limit INTEGER DEFAULT 10
)
RETURNS TABLE (
    rent_record_id UUID,
    property_id UUID,
    property_address TEXT,
    property_locality TEXT,
    property_city TEXT,
    landlord_user_id UUID,
    landlord_name TEXT,
    landlord_email TEXT,
    landlord_phone TEXT,
    due_date DATE,
    period_start_date DATE,
    period_end_date DATE,
    amount_due DECIMAL,
    amount_paid DECIMAL,
    status public.rent_status_enum,
    total_count BIGINT
) AS $$
DECLARE
    v_current_user_id UUID := auth.uid();
BEGIN
    IF v_current_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.';
    END IF;

    RETURN QUERY
    WITH my_dues AS (
        SELECT
            rr.rent_record_id,
            rr.property_id,
            p.address AS prop_address,
            p.locality AS prop_locality,
            p.city AS prop_city,
            rr.landlord_user_id,
            (landlord_auth_user.raw_user_meta_data ->> 'full_name')::TEXT AS landlord_name_val,
            landlord_auth_user.email::TEXT AS landlord_email_val,
            landlord_auth_user.phone::TEXT AS landlord_phone_val,
            rr.due_date,
            rr.period_start_date,
            rr.period_end_date,
            rr.amount_due,
            rr.amount_paid,
            rr.status
        FROM public.rent_records rr
        JOIN public.properties p ON rr.property_id = p.property_id
        JOIN auth.users landlord_auth_user ON rr.landlord_user_id = landlord_auth_user.id
        WHERE rr.tenant_user_id = v_current_user_id
          AND rr.status IN ('DUE', 'OVERDUE', 'PARTIALLY_PAID')
    ),
    dues_with_count AS (
        SELECT *, COUNT(*) OVER() AS total_rows FROM my_dues
    )
    SELECT
        dwc.rent_record_id, dwc.property_id, dwc.prop_address, dwc.prop_locality, dwc.prop_city,
        dwc.landlord_user_id, dwc.landlord_name_val, dwc.landlord_email_val, dwc.landlord_phone_val,
        dwc.due_date, dwc.period_start_date, dwc.period_end_date,
        dwc.amount_due, dwc.amount_paid, dwc.status,
        dwc.total_rows
    FROM dues_with_count dwc
    ORDER BY dwc.due_date ASC
    OFFSET p_offset
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;
GRANT EXECUTE ON FUNCTION public.get_my_rent_dues_customer(INTEGER, INTEGER) TO authenticated;

-- Function for Landlords (property submitters) to view rent dues for their properties
CREATE OR REPLACE FUNCTION public.get_property_rent_dues_landlord(
    p_property_id_filter UUID DEFAULT NULL, -- Optional filter by specific property
    p_offset INTEGER DEFAULT 0,
    p_limit INTEGER DEFAULT 10
)
RETURNS TABLE (
    rent_record_id UUID,
    property_id UUID,
    property_address TEXT,
    property_locality TEXT,
    property_city TEXT,
    tenant_user_id UUID,
    tenant_name TEXT,
    tenant_email TEXT,
    tenant_phone TEXT,
    due_date DATE,
    period_start_date DATE,
    period_end_date DATE,
    amount_due DECIMAL,
    amount_paid DECIMAL,
    status public.rent_status_enum,
    total_count BIGINT
) AS $$
DECLARE
    v_current_user_id UUID := auth.uid();
BEGIN
    IF v_current_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.';
    END IF;

    RETURN QUERY
    WITH landlord_dues AS (
        SELECT
            rr.rent_record_id,
            rr.property_id,
            p.address AS prop_address,
            p.locality AS prop_locality,
            p.city AS prop_city,
            rr.tenant_user_id,
            (tenant_auth_user.raw_user_meta_data ->> 'full_name')::TEXT AS tenant_name_val,
            tenant_auth_user.email::TEXT AS tenant_email_val,
            tenant_auth_user.phone::TEXT AS tenant_phone_val,
            rr.due_date,
            rr.period_start_date,
            rr.period_end_date,
            rr.amount_due,
            rr.amount_paid,
            rr.status
        FROM public.rent_records rr
        JOIN public.properties p ON rr.property_id = p.property_id
        JOIN auth.users tenant_auth_user ON rr.tenant_user_id = tenant_auth_user.id
        WHERE rr.landlord_user_id = v_current_user_id -- Landlord is the one who created the rent record
          AND p.submitter = v_current_user_id         -- And also the submitter of the property
          AND (p_property_id_filter IS NULL OR rr.property_id = p_property_id_filter)
          AND rr.status IN ('DUE', 'OVERDUE', 'PARTIALLY_PAID')
    ),
    dues_with_count AS (
        SELECT *, COUNT(*) OVER() AS total_rows FROM landlord_dues
    )
    SELECT
        dwc.rent_record_id, dwc.property_id, dwc.prop_address, dwc.prop_locality, dwc.prop_city,
        dwc.tenant_user_id, dwc.tenant_name_val, dwc.tenant_email_val, dwc.tenant_phone_val,
        dwc.due_date, dwc.period_start_date, dwc.period_end_date,
        dwc.amount_due, dwc.amount_paid, dwc.status,
        dwc.total_rows
    FROM dues_with_count dwc
    ORDER BY dwc.due_date ASC
    OFFSET p_offset
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;
GRANT EXECUTE ON FUNCTION public.get_property_rent_dues_landlord(UUID, INTEGER, INTEGER) TO authenticated;

-- Get payment history for a specific property (Landlord access)
CREATE OR REPLACE FUNCTION public.get_property_payment_history_landlord(
    p_property_id_input UUID,
    p_offset INTEGER DEFAULT 0,
    p_limit INTEGER DEFAULT 10
) RETURNS TABLE (
    payment_id UUID,
    rent_record_id UUID,
    payment_date TIMESTAMP WITH TIME ZONE,
    amount_paid DECIMAL,
    payment_method TEXT,
    transaction_ref TEXT,
    rent_due_date DATE,
    rent_period_start_date DATE,
    rent_period_end_date DATE,
    tenant_user_id UUID,
    tenant_name TEXT,
    tenant_email TEXT,
    tenant_phone TEXT,
    total_count BIGINT
) AS $$
DECLARE
    v_current_user_id UUID := auth.uid();
BEGIN
    IF v_current_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.';
    END IF;

    IF NOT public.check_user_is_property_submitter(p_property_id_input, v_current_user_id) THEN
        RAISE EXCEPTION 'User % does not have permission to view payment history for property %.', v_current_user_id, p_property_id_input;
    END IF;

    RETURN QUERY
    WITH payment_history AS (
        SELECT
            rp.payment_id, rp.rent_record_id, rp.payment_date, rp.amount AS amt_paid,
            rp.payment_method, rp.transaction_ref,
            rr.due_date AS rent_due, rr.period_start_date AS rent_period_start, rr.period_end_date AS rent_period_end,
            rr.tenant_user_id AS ten_user_id,
            (tenant_auth_user.raw_user_meta_data ->> 'full_name')::TEXT AS ten_name,
            tenant_auth_user.email::TEXT AS ten_email,
            tenant_auth_user.phone::TEXT AS ten_phone
        FROM public.rent_payments rp
        JOIN public.rent_records rr ON rp.rent_record_id = rr.rent_record_id
        JOIN auth.users tenant_auth_user ON rr.tenant_user_id = tenant_auth_user.id
        WHERE rr.property_id = p_property_id_input
          AND rr.landlord_user_id = v_current_user_id -- Ensure payments are for landlord's records
    ),
    history_with_count AS (
        SELECT *, COUNT(*) OVER() AS total_rows FROM payment_history
    )
    SELECT
        hwc.payment_id, hwc.rent_record_id, hwc.payment_date, hwc.amt_paid,
        hwc.payment_method, hwc.transaction_ref,
        hwc.rent_due, hwc.rent_period_start, hwc.rent_period_end,
        hwc.ten_user_id, hwc.ten_name, hwc.ten_email, hwc.ten_phone,
        hwc.total_rows
    FROM history_with_count hwc
    ORDER BY hwc.payment_date DESC
    OFFSET p_offset
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;
GRANT EXECUTE ON FUNCTION public.get_property_payment_history_landlord(UUID, INTEGER, INTEGER) TO authenticated;


-- FILE NAME: 05_06_customer_ticket_management_functions.sql
-- Description: Functions for customers (tenants, landlords) to manage support tickets.
-------------------------------------------------------------------------------

-- Function for Customers (usually Tenants) to create a ticket
CREATE OR REPLACE FUNCTION public.create_ticket_customer(
    p_property_id UUID,
    p_subject TEXT,
    p_description TEXT,
    p_category public.ticket_category_enum,
    p_priority public.ticket_priority_enum DEFAULT 'MEDIUM'
) RETURNS BIGINT AS $$
DECLARE
    v_ticket_id BIGINT;
    v_user_id UUID := auth.uid();
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.';
    END IF;

    -- The check_ticket_raiser_is_tenant trigger (in 04_triggers.sql) will validate
    -- if the user is the tenant or owner of the property.
    -- This trigger needs to use `public.properties.tenant` and `public.properties.submitter`.

    INSERT INTO public.tickets (
        property_id, raised_by_user_id, subject, description, category, priority, status
    ) VALUES (
        p_property_id, v_user_id, p_subject, p_description, p_category, p_priority, 'NEW'
    ) RETURNING ticket_id INTO v_ticket_id;

    RETURN v_ticket_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.create_ticket_customer(UUID, TEXT, TEXT, public.ticket_category_enum, public.ticket_priority_enum) TO authenticated;

-- Function for Customers to list their own raised tickets
CREATE OR REPLACE FUNCTION public.get_my_raised_tickets_customer(
    p_status_filter public.ticket_status_enum[] DEFAULT NULL,
    p_offset INTEGER DEFAULT 0,
    p_limit INTEGER DEFAULT 10
) RETURNS TABLE (
    ticket_id BIGINT,
    property_id UUID,
    property_address TEXT,
    property_locality TEXT,
    property_city TEXT,
    subject TEXT,
    category public.ticket_category_enum,
    priority public.ticket_priority_enum,
    status public.ticket_status_enum,
    assigned_support_admin_name TEXT, -- Name of admin if assigned
    created_at TIMESTAMP WITH TIME ZONE,
    updated_at TIMESTAMP WITH TIME ZONE,
    resolved_at TIMESTAMP WITH TIME ZONE,
    closed_at TIMESTAMP WITH TIME ZONE,
    total_count BIGINT
) AS $$
DECLARE
    v_current_user_id UUID := auth.uid();
BEGIN
    IF v_current_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.';
    END IF;

    RETURN QUERY
    WITH my_tickets_base AS (
        SELECT
            t.ticket_id,
            t.property_id,
            p.address AS prop_address,
            p.locality AS prop_locality,
            p.city AS prop_city,
            t.subject,
            t.category,
            t.priority,
            t.status,
            assignee_auth_user.raw_user_meta_data->>'full_name' AS assignee_name,
            t.created_at,
            t.updated_at,
            t.resolved_at,
            t.closed_at
        FROM public.tickets t
        JOIN public.properties p ON t.property_id = p.property_id
        LEFT JOIN public.admins assignee_admin ON t.assigned_support_admin_id = assignee_admin.user_id
        LEFT JOIN auth.users assignee_auth_user ON assignee_admin.user_id = assignee_auth_user.id
        WHERE t.raised_by_user_id = v_current_user_id
          AND (p_status_filter IS NULL OR t.status = ANY(p_status_filter))
    ),
    tickets_with_count AS (
        SELECT *, COUNT(*) OVER() as total_rows FROM my_tickets_base
    )
    SELECT
        twc.ticket_id, twc.property_id, twc.prop_address, twc.prop_locality, twc.prop_city,
        twc.subject, twc.category, twc.priority, twc.status,
        twc.assignee_name,
        twc.created_at, twc.updated_at, twc.resolved_at, twc.closed_at,
        twc.total_rows
    FROM tickets_with_count twc
    ORDER BY twc.updated_at DESC, twc.created_at DESC
    OFFSET p_offset
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;
GRANT EXECUTE ON FUNCTION public.get_my_raised_tickets_customer(public.ticket_status_enum[], INTEGER, INTEGER) TO authenticated;


-- Function for Landlords (property submitters) to list tickets related to their properties
CREATE OR REPLACE FUNCTION public.get_property_tickets_landlord(
    p_property_id_filter UUID DEFAULT NULL,
    p_status_filter public.ticket_status_enum[] DEFAULT NULL,
    p_offset INTEGER DEFAULT 0,
    p_limit INTEGER DEFAULT 10
) RETURNS TABLE (
    ticket_id BIGINT,
    property_id UUID,
    property_address TEXT,
    property_locality TEXT,
    property_city TEXT,
    subject TEXT,
    category public.ticket_category_enum,
    priority public.ticket_priority_enum,
    status public.ticket_status_enum,
    raised_by_user_id UUID,
    raiser_name TEXT,
    raiser_email TEXT,
    raiser_phone TEXT,
    assigned_support_admin_name TEXT,
    created_at TIMESTAMP WITH TIME ZONE,
    updated_at TIMESTAMP WITH TIME ZONE,
    resolved_at TIMESTAMP WITH TIME ZONE,
    closed_at TIMESTAMP WITH TIME ZONE,
    total_count BIGINT
) AS $$
DECLARE
    v_current_user_id UUID := auth.uid();
BEGIN
    IF v_current_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.';
    END IF;

    RETURN QUERY
    WITH landlord_tickets_base AS (
        SELECT
            t.ticket_id,
            t.property_id,
            p.address AS prop_address,
            p.locality AS prop_locality,
            p.city AS prop_city,
            t.subject,
            t.category,
            t.priority,
            t.status,
            t.raised_by_user_id,
            (raiser_auth_user.raw_user_meta_data ->> 'full_name')::TEXT AS raiser_name_val,
            raiser_auth_user.email::TEXT AS raiser_email_val,
            raiser_auth_user.phone::TEXT AS raiser_phone_val,
            assignee_auth_user.raw_user_meta_data->>'full_name' AS assignee_name,
            t.created_at,
            t.updated_at,
            t.resolved_at,
            t.closed_at
        FROM public.tickets t
        JOIN public.properties p ON t.property_id = p.property_id
        JOIN auth.users raiser_auth_user ON t.raised_by_user_id = raiser_auth_user.id
        LEFT JOIN public.admins assignee_admin ON t.assigned_support_admin_id = assignee_admin.user_id
        LEFT JOIN auth.users assignee_auth_user ON assignee_admin.user_id = assignee_auth_user.id
        WHERE p.submitter = v_current_user_id -- Property owner is the current user
          AND (p_property_id_filter IS NULL OR t.property_id = p_property_id_filter)
          AND (p_status_filter IS NULL OR t.status = ANY(p_status_filter))
    ),
    tickets_with_count AS (
        SELECT *, COUNT(*) OVER() as total_rows FROM landlord_tickets_base
    )
    SELECT
        twc.ticket_id, twc.property_id, twc.prop_address, twc.prop_locality, twc.prop_city,
        twc.subject, twc.category, twc.priority, twc.status,
        twc.raised_by_user_id, twc.raiser_name_val, twc.raiser_email_val, twc.raiser_phone_val,
        twc.assignee_name,
        twc.created_at, twc.updated_at, twc.resolved_at, twc.closed_at,
        twc.total_rows
    FROM tickets_with_count twc
    ORDER BY twc.updated_at DESC, twc.created_at DESC
    OFFSET p_offset
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;
GRANT EXECUTE ON FUNCTION public.get_property_tickets_landlord(UUID, public.ticket_status_enum[], INTEGER, INTEGER) TO authenticated;

-- Function for Customers (Tenant/Landlord) to get details of a specific ticket they can access
CREATE OR REPLACE FUNCTION public.get_ticket_details_customer(p_ticket_id_input BIGINT)
RETURNS TABLE (
    ticket_id BIGINT,
    subject TEXT,
    description TEXT,
    property_id UUID,
    property_address TEXT,
    property_locality TEXT,
    property_city TEXT,
    raised_by_user_id UUID,
    raiser_name TEXT,
    raiser_email TEXT,
    raiser_phone TEXT,
    category public.ticket_category_enum,
    priority public.ticket_priority_enum,
    status public.ticket_status_enum,
    assigned_support_admin_name TEXT,
    resolution_notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE,
    updated_at TIMESTAMP WITH TIME ZONE,
    resolved_at TIMESTAMP WITH TIME ZONE,
    closed_at TIMESTAMP WITH TIME ZONE,
    images JSONB, -- Array of {image_id, image_url, description, uploaded_by_name, created_at}
    comments JSONB -- Array of {comment_id, user_id, user_name, comment_text, created_at} non-internal
) AS $$
DECLARE
    v_current_user_id UUID := auth.uid();
    v_can_access BOOLEAN;
BEGIN
    IF v_current_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.';
    END IF;

    SELECT public.check_user_can_access_ticket(p_ticket_id_input, v_current_user_id) INTO v_can_access;

    IF NOT v_can_access THEN
        RAISE EXCEPTION 'You do not have permission to view this ticket or ticket not found.';
    END IF;

    RETURN QUERY
    SELECT
        t.ticket_id, t.subject, t.description, t.property_id,
        p.address AS prop_address, p.locality AS prop_locality, p.city AS prop_city,
        t.raised_by_user_id,
        (raiser_auth_user.raw_user_meta_data ->> 'full_name')::TEXT AS raiser_name_val,
        raiser_auth_user.email::TEXT AS raiser_email_val,
        raiser_auth_user.phone::TEXT AS raiser_phone_val,
        t.category, t.priority, t.status,
        assignee_auth_user.raw_user_meta_data->>'full_name' AS assignee_name,
        t.resolution_notes,
        t.created_at, t.updated_at, t.resolved_at, t.closed_at,
        COALESCE(
            (SELECT jsonb_agg(
                jsonb_build_object(
                    'image_id', ti.image_id,
                    'image_url', ti.image_url,
                    'description', ti.description,
                    'uploaded_by_name', (uploader_auth_user.raw_user_meta_data->>'full_name')::TEXT,
                    'created_at', ti.created_at
                ) ORDER BY ti.created_at ASC
            )
            FROM public.ticket_images ti
            JOIN auth.users uploader_auth_user ON ti.uploaded_by = uploader_auth_user.id
            WHERE ti.ticket_id = t.ticket_id),
            '[]'::jsonb
        ) AS ticket_images_data,
        COALESCE(
            (SELECT jsonb_agg(
                jsonb_build_object(
                    'comment_id', tc.comment_id,
                    'user_id', tc.user_id,
                    'user_name', (commenter_auth_user.raw_user_meta_data->>'full_name')::TEXT,
                    'comment_text', tc.comment_text,
                    'created_at', tc.created_at
                ) ORDER BY tc.created_at ASC
            )
            FROM public.ticket_comments tc
            JOIN auth.users commenter_auth_user ON tc.user_id = commenter_auth_user.id
            WHERE tc.ticket_id = t.ticket_id AND tc.is_internal = FALSE), -- Customers only see non-internal comments
            '[]'::jsonb
        ) AS ticket_comments_data
    FROM public.tickets t
    JOIN public.properties p ON t.property_id = p.property_id
    JOIN auth.users raiser_auth_user ON t.raised_by_user_id = raiser_auth_user.id
    LEFT JOIN public.admins assignee_admin ON t.assigned_support_admin_id = assignee_admin.user_id
    LEFT JOIN auth.users assignee_auth_user ON assignee_admin.user_id = assignee_auth_user.id
    WHERE t.ticket_id = p_ticket_id_input;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;
GRANT EXECUTE ON FUNCTION public.get_ticket_details_customer(BIGINT) TO authenticated;

-- Function for Customers (Tenant/Landlord) to add a non-internal comment to a ticket they can access
CREATE OR REPLACE FUNCTION public.add_ticket_comment_customer(
    p_ticket_id_input BIGINT,
    p_comment_text TEXT
) RETURNS VOID AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_can_access BOOLEAN;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.';
    END IF;

    SELECT public.check_user_can_access_ticket(p_ticket_id_input, v_user_id) INTO v_can_access;

    IF NOT v_can_access THEN
        RAISE EXCEPTION 'You do not have permission to comment on this ticket or ticket not found.';
    END IF;

    IF p_comment_text IS NULL OR TRIM(p_comment_text) = '' THEN
        RAISE EXCEPTION 'Comment text cannot be empty.';
    END IF;

    INSERT INTO public.ticket_comments (ticket_id, user_id, comment_text, is_internal)
    VALUES (p_ticket_id_input, v_user_id, p_comment_text, FALSE); -- Customer comments are never internal
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.add_ticket_comment_customer(BIGINT, TEXT) TO authenticated;


-- Description: Functions for customers to submit and manage their rental applications.
-------------------------------------------------------------------------------

-- Function for a customer to submit a new rental application
CREATE OR REPLACE FUNCTION public.customer_submit_rental_application(
    p_property_id UUID,
    p_interaction_id UUID,
    p_application_data JSONB -- Expected: {"move_in_date": "YYYY-MM-DD", "num_occupants": integer, "applicant_notes": "text"}
) RETURNS UUID AS $$ -- Returns the new application_id
DECLARE
    v_current_user_id UUID := auth.uid();
    v_interaction_details RECORD;
    v_property_owner_id UUID;
    v_new_application_id UUID;
BEGIN
    IF v_current_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required to submit an application.';
    END IF;

    -- Validate application_data structure
    IF NOT (p_application_data ? 'move_in_date' AND jsonb_typeof(p_application_data->'move_in_date') = 'string' AND
            p_application_data ? 'num_occupants' AND jsonb_typeof(p_application_data->'num_occupants') = 'number') THEN
        RAISE EXCEPTION 'Application data must include a valid move_in_date (YYYY-MM-DD string) and num_occupants (number).';
    END IF;
    -- Validate move_in_date format (basic check, more robust on client/server)
    BEGIN
        PERFORM (p_application_data->>'move_in_date')::DATE;
    EXCEPTION WHEN invalid_datetime_format THEN
        RAISE EXCEPTION 'Invalid move_in_date format. Please use YYYY-MM-DD.';
    END;
    IF (p_application_data->>'num_occupants')::INTEGER <= 0 THEN
        RAISE EXCEPTION 'Number of occupants must be a positive integer.';
    END IF;


    -- Verify the interaction exists, belongs to the user and property, and is in 'VISIT_COMPLETED' state
    SELECT ci.user_id, ci.property_id, ci.status
    INTO v_interaction_details
    FROM public.customers_interaction ci
    WHERE ci.interaction_id = p_interaction_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Interaction ID % not found.', p_interaction_id;
    END IF;

    IF v_interaction_details.user_id <> v_current_user_id THEN
        RAISE EXCEPTION 'Interaction does not belong to the current user.';
    END IF;

    IF v_interaction_details.property_id <> p_property_id THEN
        RAISE EXCEPTION 'Interaction does not match the specified property.';
    END IF;

    IF v_interaction_details.status <> 'VISIT_COMPLETED' THEN
        RAISE EXCEPTION 'Rental application can only be submitted after a property visit is marked as completed. Current visit status: %', v_interaction_details.status;
    END IF;

    -- Check if property is still available for rental applications (e.g., not RENTED or SOLD)
    IF NOT EXISTS (
        SELECT 1 FROM public.properties prop
        WHERE prop.property_id = p_property_id
          AND prop.listing_type = 'RENTAL'
          AND prop.admin_status NOT IN ('RENTED', 'SOLD', 'REJECTED', 'SUSPENDED')
    ) THEN
        RAISE EXCEPTION 'This property is currently not available for rental applications.';
    END IF;

    -- Get the property owner (landlord)
    SELECT submitter INTO v_property_owner_id
    FROM public.properties
    WHERE property_id = p_property_id;

    IF v_property_owner_id IS NULL THEN
        RAISE EXCEPTION 'Property owner information not found for property ID %.', p_property_id;
    END IF;

    -- Insert the new rental application
    INSERT INTO public.rental_applications (
        property_id,
        user_id,
        interaction_id,
        landlord_user_id,
        application_data,
        status -- Default is 'SUBMITTED'
    ) VALUES (
        p_property_id,
        v_current_user_id,
        p_interaction_id,
        v_property_owner_id,
        p_application_data,
        'SUBMITTED'
    ) RETURNING application_id INTO v_new_application_id;

    -- Update the customer interaction status
    UPDATE public.customers_interaction
    SET status = 'RENTAL_APPLICATION_SUBMITTED',
        updated_at = CURRENT_TIMESTAMP
    WHERE interaction_id = p_interaction_id;

    RETURN v_new_application_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.customer_submit_rental_application(UUID, UUID, JSONB) TO authenticated;


-- Function for a customer to get a list of their rental applications
CREATE OR REPLACE FUNCTION public.customer_get_my_rental_applications(
    p_offset INTEGER DEFAULT 0,
    p_limit INTEGER DEFAULT 10
) RETURNS TABLE (
    application_id UUID,
    property_id UUID,
    property_name TEXT, -- Derived from property details or locality
    property_address TEXT,
    property_locality TEXT,
    property_city TEXT,
    property_main_image_url TEXT,
    landlord_name TEXT, -- Name of the property owner
    application_status public.rental_application_status_enum,
    submitted_at TIMESTAMP WITH TIME ZONE,
    status_updated_at TIMESTAMP WITH TIME ZONE,
    total_count BIGINT
) AS $$
DECLARE
    v_current_user_id UUID := auth.uid();
BEGIN
    IF v_current_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required to view applications.';
    END IF;

    RETURN QUERY
    WITH user_apps_base AS (
        SELECT
            ra.application_id,
            ra.property_id,
            COALESCE(p.details->>'house_name', p.details->>'building_name', p.details->>'land_name', p.locality) AS derived_property_name,
            p.address AS prop_address,
            p.locality AS prop_locality,
            p.city AS prop_city,
            (SELECT pi.image_url FROM public.property_images pi
             WHERE pi.property_id = p.property_id AND pi.is_internal_image = FALSE
             ORDER BY pi.display_order ASC LIMIT 1) AS main_image,
            landlord_auth.raw_user_meta_data->>'full_name' AS landlord_full_name,
            ra.status,
            ra.submitted_at,
            ra.status_updated_at
        FROM public.rental_applications ra
        JOIN public.properties p ON ra.property_id = p.property_id
        JOIN auth.users landlord_auth ON ra.landlord_user_id = landlord_auth.id
        WHERE ra.user_id = v_current_user_id
    ),
    apps_with_count AS (
        SELECT *, COUNT(*) OVER() as total_rows FROM user_apps_base
    )
    SELECT
        awc.application_id,
        awc.property_id,
        awc.derived_property_name,
        awc.prop_address,
        awc.prop_locality,
        awc.prop_city,
        awc.main_image,
        awc.landlord_full_name,
        awc.status,
        awc.submitted_at,
        awc.status_updated_at,
        awc.total_rows
    FROM apps_with_count awc
    ORDER BY awc.submitted_at DESC
    OFFSET p_offset
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;
GRANT EXECUTE ON FUNCTION public.customer_get_my_rental_applications(INTEGER, INTEGER) TO authenticated;


-- Function for a customer to get details of a specific rental application
CREATE OR REPLACE FUNCTION public.customer_get_rental_application_details(
    p_application_id UUID
) RETURNS TABLE (
    application_id UUID,
    property_id UUID,
    property_name TEXT,
    property_address TEXT,
    property_locality TEXT,
    property_city TEXT,
    property_pincode INTEGER,
    property_main_image_url TEXT,
    property_listing_type public.listing_type_enum,
    property_price DECIMAL,
    property_advance_amount DECIMAL,
    landlord_user_id UUID,
    landlord_name TEXT,
    landlord_email TEXT, -- Only if landlord allows contact (future enhancement, for now, always null for customer)
    landlord_phone TEXT, -- Only if landlord allows contact (future enhancement, for now, always null for customer)
    application_data JSONB,
    application_status public.rental_application_status_enum,
    submitted_at TIMESTAMP WITH TIME ZONE,
    status_updated_at TIMESTAMP WITH TIME ZONE,
    admin_notes_for_customer TEXT -- Potentially a filtered/public version of admin notes, or null
) AS $$
DECLARE
    v_current_user_id UUID := auth.uid();
BEGIN
    IF v_current_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.';
    END IF;

    RETURN QUERY
    SELECT
        ra.application_id,
        ra.property_id,
        COALESCE(p.details->>'house_name', p.details->>'building_name', p.details->>'land_name', p.locality) AS derived_property_name,
        p.address AS prop_address,
        p.locality AS prop_locality,
        p.city AS prop_city,
        p.pincode AS prop_pincode,
        (SELECT pi.image_url FROM public.property_images pi
         WHERE pi.property_id = p.property_id AND pi.is_internal_image = FALSE
         ORDER BY pi.display_order ASC LIMIT 1) AS main_image,
        p.listing_type AS prop_listing_type,
        p.price AS prop_price,
        p.advance_amount AS prop_advance_amount,
        ra.landlord_user_id,
        landlord_auth.raw_user_meta_data->>'full_name' AS landlord_full_name,
        NULL::TEXT AS landlord_contact_email, -- Masked for customer view for now
        NULL::TEXT AS landlord_contact_phone, -- Masked for customer view for now
        ra.application_data,
        ra.status,
        ra.submitted_at,
        ra.status_updated_at,
        NULL::TEXT AS notes_for_customer -- Admin notes are internal; this could be a future field for public remarks
    FROM public.rental_applications ra
    JOIN public.properties p ON ra.property_id = p.property_id
    JOIN auth.users landlord_auth ON ra.landlord_user_id = landlord_auth.id
    WHERE ra.application_id = p_application_id
      AND ra.user_id = v_current_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;
GRANT EXECUTE ON FUNCTION public.customer_get_rental_application_details(UUID) TO authenticated;


-- Function for a customer to withdraw their rental application
CREATE OR REPLACE FUNCTION public.customer_withdraw_rental_application(
    p_application_id UUID
) RETURNS VOID AS $$
DECLARE
    v_current_user_id UUID := auth.uid();
    v_application_status public.rental_application_status_enum;
    v_interaction_id_to_update UUID;
BEGIN
    IF v_current_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.';
    END IF;

    SELECT status, interaction_id
    INTO v_application_status, v_interaction_id_to_update
    FROM public.rental_applications
    WHERE application_id = p_application_id AND user_id = v_current_user_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Application not found or you do not have permission to withdraw it.';
    END IF;

    -- Define statuses from which a customer can withdraw
    IF v_application_status NOT IN (
        'SUBMITTED', 'REVIEW_IN_PROGRESS', 'AWAITING_LANDLORD_CONTACT',
        'LANDLORD_INFO_PENDING', 'DOCUMENTS_REQUESTED'
    ) THEN
        RAISE EXCEPTION 'Application cannot be withdrawn in its current state: %', v_application_status;
    END IF;

    UPDATE public.rental_applications
    SET status = 'APPLICATION_WITHDRAWN_CUSTOMER',
        admin_notes = COALESCE(admin_notes || E'\n\n', '') || 'Application withdrawn by customer on ' || TO_CHAR(CURRENT_TIMESTAMP, 'YYYY-MM-DD HH24:MI:SS'),
        updated_at = CURRENT_TIMESTAMP,
        status_updated_at = CURRENT_TIMESTAMP
    WHERE application_id = p_application_id;

    -- Optionally, revert the original customer_interaction status
    IF v_interaction_id_to_update IS NOT NULL THEN
        UPDATE public.customers_interaction
        SET status = 'VISIT_COMPLETED', -- Or 'WISHLISTED' if that makes more sense
            updated_at = CURRENT_TIMESTAMP
        WHERE interaction_id = v_interaction_id_to_update;
    END IF;

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.customer_withdraw_rental_application(UUID) TO authenticated;


-- FILE NAME: 06_01_admin_staff_management_functions.sql
-- Description: Functions for super-admins to manage other admin staff.
-------------------------------------------------------------------------------

-- Function for super-admin to add a role to an admin staff member or create them
CREATE OR REPLACE FUNCTION public.add_admin_role(
    p_user_id UUID,
    p_role_to_add public.admin_role_enum
) RETURNS VOID AS $$
DECLARE
    v_existing_roles public.admin_role_enum[];
BEGIN
    IF NOT public.current_user_has_role('super-admin') THEN
        RAISE EXCEPTION 'Unauthorized: Only super-admins can modify admin roles.';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM auth.users WHERE id = p_user_id) THEN
        RAISE EXCEPTION 'User ID % not found in auth.users.', p_user_id;
    END IF;

    SELECT roles INTO v_existing_roles FROM public.admins WHERE user_id = p_user_id;

    IF v_existing_roles IS NULL THEN
        -- Admin doesn't exist, create them with this role
        INSERT INTO public.admins (user_id, roles, is_active)
        VALUES (p_user_id, ARRAY[p_role_to_add], TRUE);
    ELSE
        -- Admin exists, add role if not already present
        IF NOT (p_role_to_add = ANY(v_existing_roles)) THEN
            UPDATE public.admins
            SET roles = array_append(v_existing_roles, p_role_to_add),
                is_active = TRUE -- Ensure admin is active when a role is added
            WHERE user_id = p_user_id;
        ELSE
             -- If role already exists, ensure admin is active
            UPDATE public.admins SET is_active = TRUE WHERE user_id = p_user_id AND is_active = FALSE;
        END IF;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.add_admin_role(UUID, public.admin_role_enum) TO authenticated;

-- Function for super-admin to remove a role from an admin staff member
CREATE OR REPLACE FUNCTION public.remove_admin_role(
    p_user_id UUID,
    p_role_to_remove public.admin_role_enum
) RETURNS VOID AS $$
DECLARE
    v_current_roles public.admin_role_enum[];
    v_new_roles public.admin_role_enum[];
BEGIN
    IF NOT public.current_user_has_role('super-admin') THEN
        RAISE EXCEPTION 'Unauthorized: Only super-admins can modify admin roles.';
    END IF;

    IF p_user_id = auth.uid() AND p_role_to_remove = 'super-admin' THEN
        RAISE EXCEPTION 'Super-admins cannot remove their own super-admin role.';
    END IF;

    SELECT roles INTO v_current_roles FROM public.admins WHERE user_id = p_user_id;

    IF v_current_roles IS NULL THEN
        RAISE WARNING 'Admin with User ID % not found.', p_user_id;
        RETURN;
    END IF;

    v_new_roles := array_remove(v_current_roles, p_role_to_remove);

    IF array_length(v_new_roles, 1) IS NULL OR array_length(v_new_roles, 1) = 0 THEN
        -- All roles removed, delete the admin record
        DELETE FROM public.admins WHERE user_id = p_user_id;
    ELSE
        UPDATE public.admins
        SET roles = v_new_roles
        WHERE user_id = p_user_id;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.remove_admin_role(UUID, public.admin_role_enum) TO authenticated;

-- Function for super-admin to set the exact list of roles for an admin staff member
CREATE OR REPLACE FUNCTION public.set_admin_roles(
    p_user_id UUID,
    p_roles public.admin_role_enum[]
) RETURNS VOID AS $$
BEGIN
    IF NOT public.current_user_has_role('super-admin') THEN
        RAISE EXCEPTION 'Unauthorized: Only super-admins can set admin roles.';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM auth.users WHERE id = p_user_id) THEN
        RAISE EXCEPTION 'User ID % not found in auth.users.', p_user_id;
    END IF;

    IF p_user_id = auth.uid() AND NOT ('super-admin' = ANY(COALESCE(p_roles, '{}'::public.admin_role_enum[]))) THEN
        RAISE EXCEPTION 'Super-admins cannot remove their own super-admin role by setting roles to an empty set or a set without super-admin.';
    END IF;

    IF p_roles IS NULL OR array_length(p_roles, 1) IS NULL OR array_length(p_roles, 1) = 0 THEN
        -- No roles provided, delete the admin record
        DELETE FROM public.admins WHERE user_id = p_user_id;
    ELSE
        INSERT INTO public.admins (user_id, roles, is_active)
        VALUES (p_user_id, p_roles, TRUE)
        ON CONFLICT (user_id) DO UPDATE
        SET roles = EXCLUDED.roles,
            is_active = TRUE; -- Ensure admin is active when roles are set/updated
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.set_admin_roles(UUID, public.admin_role_enum[]) TO authenticated;

-- Function for super-admin to update served pincodes for an admin
CREATE OR REPLACE FUNCTION public.update_admin_pincodes(
    p_user_id UUID,
    p_pincodes INTEGER[]
) RETURNS VOID AS $$
BEGIN
    IF NOT public.current_user_has_role('super-admin') THEN
        RAISE EXCEPTION 'Unauthorized: Only super-admins can update pincodes.';
    END IF;

    UPDATE public.admins
    SET served_pincodes = p_pincodes
    WHERE user_id = p_user_id;

    IF NOT FOUND THEN
        RAISE WARNING 'Admin with User ID % not found. Pincodes not updated.', p_user_id;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.update_admin_pincodes(UUID, INTEGER[]) TO authenticated;

-- Function for super-admin to activate an admin
CREATE OR REPLACE FUNCTION public.activate_admin(p_user_id UUID)
RETURNS VOID AS $$
BEGIN
    IF NOT public.current_user_has_role('super-admin') THEN
        RAISE EXCEPTION 'Unauthorized: Only super-admins can activate admins.';
    END IF;
    UPDATE public.admins SET is_active = TRUE WHERE user_id = p_user_id;
    IF NOT FOUND THEN RAISE WARNING 'Admin % not found for activation.', p_user_id; END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.activate_admin(UUID) TO authenticated;

-- Function for super-admin to deactivate an admin
CREATE OR REPLACE FUNCTION public.deactivate_admin(p_user_id UUID)
RETURNS VOID AS $$
BEGIN
    IF NOT public.current_user_has_role('super-admin') THEN
        RAISE EXCEPTION 'Unauthorized: Only super-admins can deactivate admins.';
    END IF;
    IF p_user_id = auth.uid() THEN
        RAISE EXCEPTION 'Cannot deactivate your own admin account.';
    END IF;
    UPDATE public.admins SET is_active = FALSE WHERE user_id = p_user_id;
    IF NOT FOUND THEN RAISE WARNING 'Admin % not found for deactivation.', p_user_id; END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.deactivate_admin(UUID) TO authenticated;

-- Function for super-admin to list admin staff members
CREATE OR REPLACE FUNCTION public.list_admins(
    p_role_filter public.admin_role_enum DEFAULT NULL,
    p_is_active_filter BOOLEAN DEFAULT NULL,
    p_search_term TEXT DEFAULT NULL,
    p_offset INTEGER DEFAULT 0,
    p_limit INTEGER DEFAULT 25
) RETURNS TABLE (
    user_id UUID,
    email TEXT,
    full_name TEXT,
    phone TEXT,
    roles public.admin_role_enum[],
    served_pincodes INTEGER[],
    is_active BOOLEAN,
    created_at TIMESTAMP WITH TIME ZONE,
    updated_at TIMESTAMP WITH TIME ZONE,
    total_count BIGINT
) AS $$
BEGIN
    IF NOT public.current_user_has_role('super-admin') THEN
        RAISE EXCEPTION 'Unauthorized: Only super-admins can list admins.';
    END IF;

    RETURN QUERY
    WITH admin_users AS (
        SELECT
            a.user_id,
            u.email::TEXT,
            u.raw_user_meta_data->>'full_name' AS user_full_name,
            u.phone::TEXT,
            a.roles,
            a.served_pincodes,
            a.is_active,
            a.created_at,
            a.updated_at
        FROM public.admins a
        JOIN auth.users u ON a.user_id = u.id
        WHERE (p_role_filter IS NULL OR p_role_filter = ANY(a.roles))
          AND (p_is_active_filter IS NULL OR a.is_active = p_is_active_filter)
          AND (p_search_term IS NULL OR (
                u.email ILIKE '%' || p_search_term || '%' OR
                u.raw_user_meta_data->>'full_name' ILIKE '%' || p_search_term || '%' OR
                u.phone ILIKE '%' || p_search_term || '%' OR
                a.user_id::TEXT ILIKE '%' || p_search_term || '%'
              ))
    ),
    admins_with_count AS (
        SELECT *, COUNT(*) OVER() AS total_rows FROM admin_users
    )
    SELECT
        awc.user_id,
        awc.email,
        awc.user_full_name,
        awc.phone,
        awc.roles,
        awc.served_pincodes,
        awc.is_active,
        awc.created_at,
        awc.updated_at,
        awc.total_rows
    FROM admins_with_count awc
    ORDER BY awc.user_full_name ASC, awc.created_at DESC
    OFFSET p_offset
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;
GRANT EXECUTE ON FUNCTION public.list_admins(public.admin_role_enum, BOOLEAN, TEXT, INTEGER, INTEGER) TO authenticated;


-- Function for super-admin to get details of a specific admin staff member
CREATE OR REPLACE FUNCTION public.get_admin_details(p_admin_user_id UUID)
RETURNS TABLE (
    user_id UUID,
    email TEXT,
    full_name TEXT,
    phone TEXT,
    roles public.admin_role_enum[],
    served_pincodes INTEGER[],
    is_active BOOLEAN,
    created_at TIMESTAMP WITH TIME ZONE, -- admin record created_at
    updated_at TIMESTAMP WITH TIME ZONE, -- admin record updated_at
    auth_user_created_at TIMESTAMP WITH TIME ZONE -- auth.users record created_at
) AS $$
BEGIN
    IF NOT public.current_user_has_role('super-admin') THEN
        RAISE EXCEPTION 'Unauthorized: Only super-admins can view admin details.';
    END IF;

    RETURN QUERY
    SELECT
        a.user_id,
        u.email::TEXT,
        u.raw_user_meta_data->>'full_name' AS user_full_name,
        u.phone::TEXT,
        a.roles,
        a.served_pincodes,
        a.is_active,
        a.created_at,
        a.updated_at,
        u.created_at AS auth_user_created_at_val
    FROM public.admins a
    JOIN auth.users u ON a.user_id = u.id
    WHERE a.user_id = p_admin_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;
GRANT EXECUTE ON FUNCTION public.get_admin_details(UUID) TO authenticated;


-- User-facing functions (formerly in admin_user_management) like get_customer_details_admin
-- will be moved to a more general admin function file or a customer-specific admin file,
-- as this file is now focused on *staff* (admins table) management.
-- For instance, `get_user_details_admin` would become `get_customer_full_details_admin` and
-- would be accessible by various admin roles, not just super-admin for staff management.


-- Description: Functions for admins to manage properties, including CRUD and status changes.
-------------------------------------------------------------------------------

-- Function for admins to get properties with extensive filters
CREATE OR REPLACE FUNCTION public.get_properties_admin(
    p_property_types public.property_type_enum[] DEFAULT NULL,
    p_listing_types public.listing_type_enum[] DEFAULT NULL,
    p_admin_statuses public.property_admin_status_enum[] DEFAULT NULL,
    p_is_listed_filter BOOLEAN DEFAULT NULL,
    p_pincodes INTEGER[] DEFAULT NULL,
    p_price_min DECIMAL DEFAULT NULL,
    p_price_max DECIMAL DEFAULT NULL,
    p_city TEXT DEFAULT NULL,
    p_is_featured BOOLEAN DEFAULT NULL,
    p_is_exclusive BOOLEAN DEFAULT NULL,
    p_submitter_id UUID DEFAULT NULL,
    p_tenant_id UUID DEFAULT NULL,
    p_management_plan_id UUID DEFAULT NULL,
    p_property_search TEXT DEFAULT NULL,
    p_owner_contact_assignment_status TEXT DEFAULT NULL,
    p_owner_contact_assigned_to_admin_id UUID DEFAULT NULL,
    p_marketing_assignment_status TEXT DEFAULT NULL,
    p_marketing_assigned_to_admin_id UUID DEFAULT NULL,
    p_offset INTEGER DEFAULT 0,
    p_limit INTEGER DEFAULT 10,
    p_sort_by TEXT DEFAULT 'updated_at',
    p_sort_direction TEXT DEFAULT 'DESC'
)
RETURNS TABLE (
    property_id UUID,
    property_type public.property_type_enum,
    listing_type public.listing_type_enum,
    price DECIMAL,
    advance_amount DECIMAL,
    area DECIMAL,
    area_unit public.area_unit_enum,
    year_built INTEGER,
    description TEXT,
    details JSONB,
    youtube_url TEXT,
    locality TEXT,
    city TEXT,
    address TEXT,
    pincode INTEGER,
    latitude DECIMAL(9,6),
    longitude DECIMAL(9,6),
    admin_notes TEXT,
    inventory_details JSONB,
    admin_status public.property_admin_status_enum,
    is_listed BOOLEAN,
    is_featured BOOLEAN,
    is_exclusive BOOLEAN,
    rent_due_day INTEGER,
    submitter_type public.submitter_type_enum,
    submitter_notes TEXT,
    submitted_at TIMESTAMP WITH TIME ZONE,
    availability_status public.availability_status_enum,
    can_reachout BOOLEAN,
    property_name TEXT,
    property_images JSONB,
    submitter_info JSONB,
    tenant_info JSONB,
    management_plan_info JSONB,
    owner_contact_assigned_admin_id UUID,
    owner_contact_assigned_admin_name TEXT,
    owner_contact_assigned_at TIMESTAMPTZ,
    marketing_assigned_admin_id UUID,
    marketing_assigned_admin_name TEXT,
    marketing_assigned_at TIMESTAMPTZ,
    created_at TIMESTAMP WITH TIME ZONE,
    updated_at TIMESTAMP WITH TIME ZONE,
    total_count BIGINT
)
AS $$
DECLARE
    v_sql TEXT;
    v_order_by_clause TEXT;
    v_final_sort_by TEXT;
    v_final_sort_direction TEXT;
    v_allowed_sort_columns TEXT[] := ARRAY['price', 'area', 'updated_at', 'created_at', 'locality', 'city', 'year_built', 'admin_status', 'submitted_at', 'pincode'];
    v_calling_admin_id UUID := auth.uid(); 
BEGIN
    IF NOT public.current_user_is_admin() THEN
        RAISE EXCEPTION 'Unauthorized: Admin access required.';
    END IF;

    IF p_sort_by IS NOT NULL AND p_sort_by = ANY(v_allowed_sort_columns) THEN
        v_final_sort_by := 'pwc.' || quote_ident(p_sort_by);
    ELSE
        v_final_sort_by := 'pwc.updated_at';
    END IF;

    IF p_sort_direction IS NOT NULL AND upper(p_sort_direction) IN ('ASC', 'DESC') THEN
        v_final_sort_direction := upper(p_sort_direction);
    ELSE
        v_final_sort_direction := 'DESC';
    END IF;
    v_order_by_clause := format('ORDER BY %s %s NULLS LAST, pwc.property_id ASC', v_final_sort_by, v_final_sort_direction);

    v_sql := $QUERY$
    WITH properties_base AS (
        SELECT
            p.property_id, p.property_type, p.listing_type, p.price, p.advance_amount, p.area, p.area_unit, p.year_built,
            p.description, p.details, p.youtube_url, p.locality, p.city, p.address, p.pincode, p.latitude, p.longitude,
            p.admin_notes, p.inventory_details, p.admin_status, p.is_listed, p.is_featured, p.is_exclusive, p.rent_due_day,
            p.submitter_type, p.submitter_notes, p.submitted_at, p.availability_status, p.can_reachout,
            p.created_at, p.updated_at,
            p.submitter AS submitter_user_id, p.tenant AS tenant_user_id, p.management_plan_id AS mgmt_plan_id,
            poca.assigned_admin_id AS oca_admin_id, poca.assigned_at AS oca_assigned_at,
            pma.assigned_admin_id AS pma_admin_id, pma.assigned_at AS pma_assigned_at,
            COALESCE(p.details->>'house_name', p.details->>'building_name', p.details->>'land_name', p.locality) AS derived_property_name
        FROM public.properties p
        LEFT JOIN public.property_owner_contact_assignments poca ON p.property_id = poca.property_id
        LEFT JOIN public.property_marketing_assignments pma ON p.property_id = pma.property_id
        WHERE
            ($1 IS NULL OR p.property_type = ANY($1)) AND
            ($2 IS NULL OR p.listing_type = ANY($2)) AND
            ($3 IS NULL OR p.admin_status = ANY($3)) AND
            ($4 IS NULL OR p.is_listed = $4) AND
            ($5 IS NULL OR p.pincode = ANY($5)) AND
            ($6 IS NULL OR p.price >= $6) AND
            ($7 IS NULL OR p.price <= $7) AND
            ($8 IS NULL OR p.city ILIKE $8) AND
            ($9 IS NULL OR p.is_featured = $9) AND
            ($10 IS NULL OR p.is_exclusive = $10) AND
            ($11 IS NULL OR p.submitter = $11) AND
            ($12 IS NULL OR p.tenant = $12) AND
            ($13 IS NULL OR p.management_plan_id = $13) AND
            ($14 IS NULL OR (
                p.locality ILIKE '%' || $14 || '%' OR
                p.city ILIKE '%' || $14 || '%' OR
                p.address ILIKE '%' || $14 || '%' OR
                p.description ILIKE '%' || $14 || '%' OR
                p.admin_notes ILIKE '%' || $14 || '%' OR
                p.submitter_notes ILIKE '%' || $14 || '%' OR
                p.property_id::text ILIKE '%' || $14 || '%' OR
                p.pincode::text ILIKE '%' || $14 || '%' OR
                COALESCE(p.details->>'house_name', '') ILIKE '%' || $14 || '%' OR
                COALESCE(p.details->>'building_name', '') ILIKE '%' || $14 || '%' OR
                COALESCE(p.details->>'land_name', '') ILIKE '%' || $14 || '%'
            )) AND
            ($15 IS NULL OR
                ($15 = 'ASSIGNED' AND poca.property_id IS NOT NULL AND ($16 IS NULL OR poca.assigned_admin_id = $16)) OR
                ($15 = 'UNASSIGNED' AND poca.property_id IS NULL)
            ) AND
            -- Marketing assignment filters ($17 for status, $18 for admin_id) with role-based restrictions
            (
                CASE
                    WHEN (public.current_user_has_role('marketing-team') AND 
                          NOT public.current_user_has_role('super-admin') AND
                          NOT public.current_user_has_role('telecalling-owner-team')) THEN
                        (
                            pma.assigned_admin_id = auth.uid() AND -- Property must be assigned to current marketing admin
                            ($17 IS NULL OR $17 = 'ASSIGNED') AND -- Filter status must be ASSIGNED or not provided
                            ($18 IS NULL OR $18 = auth.uid())     -- Filter admin must be current admin or not provided
                        )
                    ELSE
                        -- Original logic for super-admins, telecalling-owner-team, or other roles
                        (
                            $17 IS NULL OR
                            ($17 = 'ASSIGNED' AND pma.property_id IS NOT NULL AND ($18 IS NULL OR pma.assigned_admin_id = $18)) OR
                            ($17 = 'UNASSIGNED' AND pma.property_id IS NULL)
                        )
                END
            )
    ),
    enriched_properties AS (
      SELECT
        pb.*,
        (
            SELECT COALESCE(jsonb_agg(
                jsonb_build_object(
                    'image_id', pi.image_id, 'image_url', pi.image_url, 'description', pi.description,
                    'display_order', pi.display_order, 'is_internal_image', pi.is_internal_image,
                    'uploaded_by_name', u_img_uploader.raw_user_meta_data->>'full_name'
                ) ORDER BY pi.display_order ASC, pi.created_at ASC
            ), '[]'::jsonb)
            FROM public.property_images pi
            LEFT JOIN public.admins admin_uploader ON pi.uploaded_by = admin_uploader.user_id
            LEFT JOIN auth.users u_img_uploader ON admin_uploader.user_id = u_img_uploader.id
            WHERE pi.property_id = pb.property_id
        ) AS property_images_data,
        CASE WHEN pb.submitter_user_id IS NOT NULL THEN jsonb_build_object(
            'user_id', u_submitter.id, 'name', u_submitter.raw_user_meta_data->>'full_name',
            'email', u_submitter.email, 'phone', u_submitter.phone
        ) ELSE NULL END AS submitter_info_data,
        CASE WHEN pb.tenant_user_id IS NOT NULL THEN jsonb_build_object(
            'user_id', u_tenant.id, 'name', u_tenant.raw_user_meta_data->>'full_name',
            'email', u_tenant.email, 'phone', u_tenant.phone
        ) ELSE NULL END AS tenant_info_data,
        CASE WHEN pb.mgmt_plan_id IS NOT NULL THEN jsonb_build_object(
            'plan_id', msp.plan_id, 'name', msp.name, 'percentage', msp.percentage
        ) ELSE NULL END AS management_plan_info_data,
        u_oca.raw_user_meta_data->>'full_name' AS oca_admin_name_val,
        u_pma.raw_user_meta_data->>'full_name' AS pma_admin_name_val
      FROM properties_base pb
      LEFT JOIN auth.users u_submitter ON pb.submitter_user_id = u_submitter.id
      LEFT JOIN auth.users u_tenant ON pb.tenant_user_id = u_tenant.id
      LEFT JOIN public.management_service_plans msp ON pb.mgmt_plan_id = msp.plan_id
      LEFT JOIN public.admins admin_oca ON pb.oca_admin_id = admin_oca.user_id
      LEFT JOIN auth.users u_oca ON admin_oca.user_id = u_oca.id
      LEFT JOIN public.admins admin_pma ON pb.pma_admin_id = admin_pma.user_id
      LEFT JOIN auth.users u_pma ON admin_pma.user_id = u_pma.id
    ),
    properties_with_count AS (
        SELECT *, COUNT(*) OVER() AS total_rows FROM enriched_properties
    )
    SELECT
        pwc.property_id, pwc.property_type, pwc.listing_type, pwc.price, pwc.advance_amount, pwc.area, pwc.area_unit, pwc.year_built,
        pwc.description, pwc.details, pwc.youtube_url, pwc.locality, pwc.city, pwc.address, pwc.pincode, pwc.latitude, pwc.longitude,
        pwc.admin_notes, pwc.inventory_details, pwc.admin_status, pwc.is_listed, pwc.is_featured, pwc.is_exclusive, pwc.rent_due_day,
        pwc.submitter_type, pwc.submitter_notes, pwc.submitted_at, pwc.availability_status, pwc.can_reachout,
        pwc.derived_property_name,
        pwc.property_images_data, pwc.submitter_info_data, pwc.tenant_info_data, pwc.management_plan_info_data,
        pwc.oca_admin_id AS owner_contact_assigned_admin_id,
        pwc.oca_admin_name_val AS owner_contact_assigned_admin_name,
        pwc.oca_assigned_at AS owner_contact_assigned_at,
        pwc.pma_admin_id AS marketing_assigned_admin_id,
        pwc.pma_admin_name_val AS marketing_assigned_admin_name,
        pwc.pma_assigned_at AS marketing_assigned_at,
        pwc.created_at, pwc.updated_at, pwc.total_rows
    FROM properties_with_count pwc
    $QUERY$;

    v_sql := v_sql || ' ' || v_order_by_clause || ' OFFSET $19 LIMIT $20';

    RETURN QUERY EXECUTE v_sql
        USING p_property_types, p_listing_types, p_admin_statuses, p_is_listed_filter, p_pincodes,
              p_price_min, p_price_max, p_city, p_is_featured, p_is_exclusive,
              p_submitter_id, p_tenant_id, p_management_plan_id, p_property_search,
              p_owner_contact_assignment_status, p_owner_contact_assigned_to_admin_id,
              p_marketing_assignment_status, p_marketing_assigned_to_admin_id,
              p_offset, p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;
GRANT EXECUTE ON FUNCTION public.get_properties_admin(
    public.property_type_enum[], public.listing_type_enum[], public.property_admin_status_enum[],
    BOOLEAN, INTEGER[], DECIMAL, DECIMAL, TEXT, BOOLEAN, BOOLEAN,
    UUID, UUID, UUID, TEXT,
    TEXT, UUID, TEXT, UUID,
    INTEGER, INTEGER, TEXT, TEXT
) TO authenticated;

-- Function for admins to get a single property by ID with full details
CREATE OR REPLACE FUNCTION public.get_property_details_admin(
    p_property_id_input UUID
)
RETURNS TABLE (
    property_id UUID, property_type public.property_type_enum, listing_type public.listing_type_enum,
    price DECIMAL, advance_amount DECIMAL, area DECIMAL, area_unit public.area_unit_enum, year_built INTEGER,
    description TEXT, details JSONB, youtube_url TEXT,
    locality TEXT, city TEXT, address TEXT, pincode INTEGER, latitude DECIMAL(9,6), longitude DECIMAL(9,6),
    nearest_hospital DECIMAL, nearest_busstop DECIMAL, nearest_gym DECIMAL, nearest_park DECIMAL, nearest_school DECIMAL, nearest_swimmingpool DECIMAL, proximity_unit public.proximity_unit_enum,
    admin_notes TEXT, inventory_details JSONB,
    admin_status public.property_admin_status_enum, is_listed BOOLEAN, is_featured BOOLEAN, is_exclusive BOOLEAN,
    rent_due_day INTEGER,
    submitter_type public.submitter_type_enum, submitter_notes TEXT, submitted_at TIMESTAMP WITH TIME ZONE,
    availability_status public.availability_status_enum, can_reachout BOOLEAN,
    created_at TIMESTAMP WITH TIME ZONE, updated_at TIMESTAMP WITH TIME ZONE,
    property_name TEXT,
    property_images JSONB,
    property_documents JSONB,
    submitter_info JSONB, tenant_info JSONB, management_plan_info JSONB,
    owner_contact_assignment JSONB,
    marketing_assignment JSONB
)
AS $$
BEGIN
    IF NOT public.current_user_is_admin() THEN
        RAISE EXCEPTION 'Unauthorized: Admin access required.';
    END IF;

    RETURN QUERY
    SELECT
        p.property_id, p.property_type, p.listing_type,
        p.price, p.advance_amount, p.area, p.area_unit, p.year_built,
        p.description, p.details, p.youtube_url,
        p.locality, p.city, p.address, p.pincode, p.latitude, p.longitude,
        p.nearest_hospital, p.nearest_busstop, p.nearest_gym, p.nearest_park, p.nearest_school, p.nearest_swimmingpool, p.proximity_unit,
        p.admin_notes, p.inventory_details,
        p.admin_status, p.is_listed, p.is_featured, p.is_exclusive,
        p.rent_due_day,
        p.submitter_type, p.submitter_notes, p.submitted_at,
        p.availability_status, p.can_reachout,
        p.created_at, p.updated_at,
        COALESCE(p.details->>'house_name', p.details->>'building_name', p.details->>'land_name', p.locality) AS derived_property_name,
        (SELECT COALESCE(jsonb_agg(jsonb_build_object(
            'image_id', pi.image_id, 'image_url', pi.image_url, 'description', pi.description,
            'display_order', pi.display_order, 'is_internal_image', pi.is_internal_image,
            'uploaded_by_name', u_img_uploader.raw_user_meta_data->>'full_name', 'uploaded_at', pi.created_at
            ) ORDER BY pi.display_order ASC, pi.created_at ASC), '[]'::jsonb)
         FROM public.property_images pi
         LEFT JOIN public.admins admin_img_uploader ON pi.uploaded_by = admin_img_uploader.user_id
         LEFT JOIN auth.users u_img_uploader ON admin_img_uploader.user_id = u_img_uploader.id
         WHERE pi.property_id = p.property_id
        ) AS property_images_data,
        (SELECT COALESCE(jsonb_agg(jsonb_build_object(
            'document_id', pd.document_id, 'document_type', pd.document_type, 'document_url', pd.document_url,
            'file_name', pd.file_name, 'description', pd.description,
            'uploaded_by_name', u_doc_uploader.raw_user_meta_data->>'full_name', 'uploaded_at', pd.uploaded_at
            ) ORDER BY pd.uploaded_at ASC), '[]'::jsonb)
         FROM public.property_documents pd
         LEFT JOIN public.admins admin_doc_uploader ON pd.uploaded_by = admin_doc_uploader.user_id
         LEFT JOIN auth.users u_doc_uploader ON admin_doc_uploader.user_id = u_doc_uploader.id
         WHERE pd.property_id = p.property_id
        ) AS property_documents_data,
        CASE WHEN p.submitter IS NOT NULL THEN jsonb_build_object('user_id', u_s.id, 'name', u_s.raw_user_meta_data->>'full_name', 'email', u_s.email, 'phone', u_s.phone) ELSE NULL END,
        CASE WHEN p.tenant IS NOT NULL THEN jsonb_build_object('user_id', u_t.id, 'name', u_t.raw_user_meta_data->>'full_name', 'email', u_t.email, 'phone', u_t.phone) ELSE NULL END,
        CASE WHEN p.management_plan_id IS NOT NULL THEN jsonb_build_object('plan_id', msp.plan_id, 'name', msp.name, 'percentage', msp.percentage) ELSE NULL END,
        (SELECT jsonb_build_object('assigned_admin_id', oca.assigned_admin_id, 'assigned_admin_name', u_oca.raw_user_meta_data->>'full_name', 'assigned_at', oca.assigned_at)
         FROM public.property_owner_contact_assignments oca JOIN public.admins a_oca ON oca.assigned_admin_id = a_oca.user_id JOIN auth.users u_oca ON a_oca.user_id = u_oca.id
         WHERE oca.property_id = p.property_id) AS owner_contact_assignment_data,
        (SELECT jsonb_build_object('assigned_admin_id', pma.assigned_admin_id, 'assigned_admin_name', u_pma.raw_user_meta_data->>'full_name', 'assigned_at', pma.assigned_at)
         FROM public.property_marketing_assignments pma JOIN public.admins a_pma ON pma.assigned_admin_id = a_pma.user_id JOIN auth.users u_pma ON a_pma.user_id = u_pma.id
         WHERE pma.property_id = p.property_id) AS marketing_assignment_data
    FROM public.properties p
    LEFT JOIN auth.users u_s ON p.submitter = u_s.id
    LEFT JOIN auth.users u_t ON p.tenant = u_t.id
    LEFT JOIN public.management_service_plans msp ON p.management_plan_id = msp.plan_id
    WHERE p.property_id = p_property_id_input;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;
GRANT EXECUTE ON FUNCTION public.get_property_details_admin(UUID) TO authenticated;

-- Function for admins to insert a new property
CREATE OR REPLACE FUNCTION public.insert_property_admin(
    p_property_type public.property_type_enum,
    p_listing_type public.listing_type_enum,
    p_price DECIMAL,
    p_area DECIMAL,
    p_area_unit public.area_unit_enum,
    p_details JSONB,
    p_locality TEXT,
    p_city TEXT,
    p_address TEXT,
    p_pincode INTEGER,
    p_year_built INTEGER DEFAULT NULL,
    p_description TEXT DEFAULT NULL,
    p_youtube_url TEXT DEFAULT NULL,
    p_latitude DECIMAL(9,6) DEFAULT NULL,
    p_longitude DECIMAL(9,6) DEFAULT NULL,
    p_nearest_hospital DECIMAL(5,1) DEFAULT NULL,
    p_nearest_busstop DECIMAL(5,1) DEFAULT NULL,
    p_nearest_gym DECIMAL(5,1) DEFAULT NULL,
    p_nearest_park DECIMAL(5,1) DEFAULT NULL,
    p_nearest_school DECIMAL(5,1) DEFAULT NULL,
    p_nearest_swimmingpool DECIMAL(5,1) DEFAULT NULL,
    p_proximity_unit public.proximity_unit_enum DEFAULT 'KM',
    p_admin_notes TEXT DEFAULT NULL,
    p_inventory_details JSONB DEFAULT '{}'::jsonb,
    p_admin_status public.property_admin_status_enum DEFAULT 'SUBMITTED',
    p_is_listed BOOLEAN DEFAULT FALSE,
    p_is_featured BOOLEAN DEFAULT FALSE,
    p_is_exclusive BOOLEAN DEFAULT FALSE,
    p_advance_amount DECIMAL(10,2) DEFAULT NULL,
    p_rent_due_day INTEGER DEFAULT NULL,
    p_submitter UUID DEFAULT NULL,
    p_submitter_type public.submitter_type_enum DEFAULT NULL,
    p_submitter_notes TEXT DEFAULT NULL,
    p_availability_status public.availability_status_enum DEFAULT NULL,
    p_can_reachout BOOLEAN DEFAULT TRUE,
    p_tenant UUID DEFAULT NULL,
    p_management_plan_id UUID DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
    v_property_id UUID;
    v_final_submitter UUID;
BEGIN
   IF NOT public.current_user_is_admin() THEN
       RAISE EXCEPTION 'Unauthorized: Admin access required.';
   END IF;

   IF p_details IS NULL THEN RAISE EXCEPTION 'Property details (JSONB) cannot be null.'; END IF;

   IF p_property_type = 'HOUSE' THEN
       IF NOT (p_details ? 'house_name') OR TRIM(p_details->>'house_name') = '' THEN
           RAISE EXCEPTION 'Post Title (house_name) is required for House properties within details.';
       END IF;
   ELSIF p_property_type = 'LAND' THEN
       IF NOT (p_details ? 'land_name') OR TRIM(p_details->>'land_name') = '' THEN
           RAISE EXCEPTION 'Post Title (land_name) is required for Land properties within details.';
       END IF;
   ELSIF p_property_type = 'BUILDING' THEN
       IF NOT (p_details ? 'building_name') OR TRIM(p_details->>'building_name') = '' THEN
           RAISE EXCEPTION 'Post Title (building_name) is required for Building properties within details.';
       END IF;
   END IF;

   IF p_inventory_details IS NULL THEN p_inventory_details := '{}'::jsonb; END IF;

   IF p_listing_type = 'RENTAL' AND p_rent_due_day IS NOT NULL AND (p_rent_due_day < 1 OR p_rent_due_day > 28) THEN
       RAISE EXCEPTION 'Rent Due Day must be between 1 and 28 for rentals.';
   END IF;
   IF p_listing_type = 'SALE' THEN
       p_rent_due_day := NULL;
       p_advance_amount := NULL;
   END IF;

   IF p_submitter IS NOT NULL AND NOT EXISTS (SELECT 1 FROM auth.users WHERE id = p_submitter) THEN RAISE EXCEPTION 'Submitter User ID % does not exist.', p_submitter; END IF;
   IF p_tenant IS NOT NULL AND NOT EXISTS (SELECT 1 FROM auth.users WHERE id = p_tenant) THEN RAISE EXCEPTION 'Tenant User ID % does not exist.', p_tenant; END IF;
   IF p_management_plan_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public.management_service_plans WHERE plan_id = p_management_plan_id) THEN RAISE EXCEPTION 'Management Plan ID % does not exist.', p_management_plan_id; END IF;

   v_final_submitter := COALESCE(p_submitter, auth.uid());

   INSERT INTO public.properties (
        property_type, listing_type, price, area, area_unit, year_built, description, details, youtube_url,
        locality, city, address, pincode, latitude, longitude,
        nearest_hospital, nearest_busstop, nearest_gym, nearest_park, nearest_school, nearest_swimmingpool, proximity_unit,
        admin_notes, inventory_details, admin_status, is_listed, is_featured, is_exclusive,
        advance_amount, rent_due_day,
        submitter, submitter_type, submitter_notes, submitted_at, availability_status, can_reachout,
        tenant, management_plan_id
    ) VALUES (
        p_property_type, p_listing_type, p_price, p_area, p_area_unit, p_year_built, p_description, p_details, p_youtube_url,
        p_locality, p_city, p_address, p_pincode, p_latitude, p_longitude,
        p_nearest_hospital, p_nearest_busstop, p_nearest_gym, p_nearest_park, p_nearest_school, p_nearest_swimmingpool, p_proximity_unit,
        p_admin_notes, p_inventory_details, p_admin_status, p_is_listed, p_is_featured, p_is_exclusive,
        p_advance_amount, p_rent_due_day,
        v_final_submitter, p_submitter_type, p_submitter_notes, CURRENT_TIMESTAMP, p_availability_status, p_can_reachout,
        p_tenant, p_management_plan_id
    ) RETURNING property_id INTO v_property_id;

   RETURN v_property_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.insert_property_admin(public.property_type_enum, public.listing_type_enum, DECIMAL, DECIMAL, public.area_unit_enum, JSONB, TEXT, TEXT, TEXT, INTEGER, INTEGER, TEXT, TEXT, DECIMAL(9,6), DECIMAL(9,6), DECIMAL(5,1), DECIMAL(5,1), DECIMAL(5,1), DECIMAL(5,1), DECIMAL(5,1), DECIMAL(5,1), public.proximity_unit_enum, TEXT, JSONB, public.property_admin_status_enum, BOOLEAN, BOOLEAN, BOOLEAN, DECIMAL(10,2), INTEGER, UUID, public.submitter_type_enum, TEXT, public.availability_status_enum, BOOLEAN, UUID, UUID) TO authenticated;


-- Function for admins to update a property
CREATE OR REPLACE FUNCTION public.update_property_admin(
    p_property_id UUID,
    p_property_type public.property_type_enum DEFAULT NULL,
    p_listing_type public.listing_type_enum DEFAULT NULL,
    p_price DECIMAL DEFAULT NULL,
    p_advance_amount DECIMAL DEFAULT NULL,
    p_area DECIMAL DEFAULT NULL,
    p_area_unit public.area_unit_enum DEFAULT NULL,
    p_details JSONB DEFAULT NULL,
    p_locality TEXT DEFAULT NULL,
    p_city TEXT DEFAULT NULL,
    p_address TEXT DEFAULT NULL,
    p_pincode INTEGER DEFAULT NULL,
    p_year_built INTEGER DEFAULT NULL,
    p_description TEXT DEFAULT NULL,
    p_youtube_url TEXT DEFAULT NULL,
    p_latitude DECIMAL(9,6) DEFAULT NULL,
    p_longitude DECIMAL(9,6) DEFAULT NULL,
    p_nearest_hospital DECIMAL(5,1) DEFAULT NULL,
    p_nearest_busstop DECIMAL(5,1) DEFAULT NULL,
    p_nearest_gym DECIMAL(5,1) DEFAULT NULL,
    p_nearest_park DECIMAL(5,1) DEFAULT NULL,
    p_nearest_school DECIMAL(5,1) DEFAULT NULL,
    p_nearest_swimmingpool DECIMAL(5,1) DEFAULT NULL,
    p_proximity_unit public.proximity_unit_enum DEFAULT NULL,
    p_admin_notes TEXT DEFAULT NULL,
    p_inventory_details JSONB DEFAULT NULL,
    p_admin_status public.property_admin_status_enum DEFAULT NULL,
    p_is_listed BOOLEAN DEFAULT NULL,
    p_is_featured BOOLEAN DEFAULT NULL,
    p_is_exclusive BOOLEAN DEFAULT NULL,
    p_rent_due_day INTEGER DEFAULT NULL,
    p_submitter UUID DEFAULT NULL,
    p_submitter_type public.submitter_type_enum DEFAULT NULL,
    p_submitter_notes TEXT DEFAULT NULL,
    p_availability_status public.availability_status_enum DEFAULT NULL,
    p_can_reachout BOOLEAN DEFAULT NULL,
    p_tenant UUID DEFAULT NULL,
    p_management_plan_id UUID DEFAULT NULL
) RETURNS VOID AS $$
DECLARE
    v_current_listing_type public.listing_type_enum;
    v_current_property_type public.property_type_enum;
    v_final_rent_due_day INTEGER;
    v_final_advance_amount DECIMAL;
    v_can_edit BOOLEAN := FALSE;
    v_calling_admin_id UUID := auth.uid();
BEGIN
    IF NOT public.current_user_is_admin() THEN
        RAISE EXCEPTION 'Unauthorized: Admin access required.';
    END IF;

    -- Authorization Check Block
    IF public.current_user_has_role('super-admin') THEN
        v_can_edit := TRUE;
    ELSE
        IF public.current_user_has_role('telecalling-owner-team') THEN
            SELECT EXISTS (
                SELECT 1 FROM public.property_owner_contact_assignments poca
                WHERE poca.property_id = p_property_id AND poca.assigned_admin_id = v_calling_admin_id
            ) INTO v_can_edit;
        END IF;

        IF NOT v_can_edit AND public.current_user_has_role('marketing-team') THEN
            SELECT EXISTS (
                SELECT 1 FROM public.property_marketing_assignments pma
                WHERE pma.property_id = p_property_id AND pma.assigned_admin_id = v_calling_admin_id
            ) INTO v_can_edit;
        END IF;
    END IF;

    IF NOT v_can_edit THEN
        RAISE EXCEPTION 'Unauthorized: You do not have permission to update this property (ID: %). Ensure it is assigned to you if you are on the telecalling-owner or marketing team, or you are a super-admin.', p_property_id;
    END IF;

    -- Fetch current property details
    SELECT listing_type, property_type, rent_due_day, advance_amount
    INTO v_current_listing_type, v_current_property_type, v_final_rent_due_day, v_final_advance_amount
    FROM public.properties WHERE property_id = p_property_id;

    IF NOT FOUND THEN RAISE EXCEPTION 'Property with ID % not found.', p_property_id; END IF;

    -- Apply defaults for listing type and property type if not provided in parameters
    v_current_listing_type := COALESCE(p_listing_type, v_current_listing_type);
    v_current_property_type := COALESCE(p_property_type, v_current_property_type);

    -- Validate details based on property type if details are being updated
    IF p_details IS NOT NULL THEN
        IF v_current_property_type = 'HOUSE' THEN
           IF NOT (p_details ? 'house_name') OR TRIM(p_details->>'house_name') = '' THEN
               RAISE EXCEPTION 'Post Title (house_name) is required for House properties within details when details are updated.';
           END IF;
        ELSIF v_current_property_type = 'LAND' THEN
           IF NOT (p_details ? 'land_name') OR TRIM(p_details->>'land_name') = '' THEN
               RAISE EXCEPTION 'Post Title (land_name) is required for Land properties within details when details are updated.';
           END IF;
        ELSIF v_current_property_type = 'BUILDING' THEN
           IF NOT (p_details ? 'building_name') OR TRIM(p_details->>'building_name') = '' THEN
               RAISE EXCEPTION 'Post Title (building_name) is required for Building properties within details when details are updated.';
           END IF;
        END IF;
    END IF;

    -- Validate rent_due_day for rentals
    IF v_current_listing_type = 'RENTAL' THEN
        IF p_rent_due_day IS NOT NULL AND (p_rent_due_day < 1 OR p_rent_due_day > 28) THEN
            RAISE EXCEPTION 'Rent Due Day must be between 1 and 28 for rentals.';
        END IF;
        v_final_rent_due_day := COALESCE(p_rent_due_day, v_final_rent_due_day);
        v_final_advance_amount := COALESCE(p_advance_amount, v_final_advance_amount);
    ELSIF v_current_listing_type = 'SALE' THEN
        v_final_rent_due_day := NULL;
        v_final_advance_amount := NULL;
    END IF;


    UPDATE public.properties SET
        property_type = COALESCE(p_property_type, property_type),
        listing_type = COALESCE(p_listing_type, listing_type),
        price = COALESCE(p_price, price),
        advance_amount = v_final_advance_amount,
        area = COALESCE(p_area, area),
        area_unit = COALESCE(p_area_unit, area_unit),
        details = COALESCE(p_details, details),
        locality = COALESCE(p_locality, locality),
        city = COALESCE(p_city, city),
        address = COALESCE(p_address, address),
        pincode = COALESCE(p_pincode, pincode),
        year_built = COALESCE(p_year_built, year_built),
        description = COALESCE(p_description, description),
        youtube_url = COALESCE(p_youtube_url, youtube_url),
        latitude = COALESCE(p_latitude, latitude),
        longitude = COALESCE(p_longitude, longitude),
        nearest_hospital = COALESCE(p_nearest_hospital, nearest_hospital),
        nearest_busstop = COALESCE(p_nearest_busstop, nearest_busstop),
        nearest_gym = COALESCE(p_nearest_gym, nearest_gym),
        nearest_park = COALESCE(p_nearest_park, nearest_park),
        nearest_school = COALESCE(p_nearest_school, nearest_school),
        nearest_swimmingpool = COALESCE(p_nearest_swimmingpool, nearest_swimmingpool),
        proximity_unit = COALESCE(p_proximity_unit, proximity_unit),
        admin_notes = COALESCE(p_admin_notes, admin_notes),
        inventory_details = COALESCE(p_inventory_details, inventory_details),
        admin_status = COALESCE(p_admin_status, admin_status),
        is_listed = COALESCE(p_is_listed, is_listed),
        is_featured = COALESCE(p_is_featured, is_featured),
        is_exclusive = COALESCE(p_is_exclusive, is_exclusive),
        rent_due_day = v_final_rent_due_day,
        submitter = COALESCE(p_submitter, submitter),
        submitter_type = COALESCE(p_submitter_type, submitter_type),
        submitter_notes = COALESCE(p_submitter_notes, submitter_notes),
        availability_status = COALESCE(p_availability_status, availability_status),
        can_reachout = COALESCE(p_can_reachout, can_reachout),
        tenant = p_tenant,
        management_plan_id = COALESCE(p_management_plan_id, management_plan_id),
        updated_at = CURRENT_TIMESTAMP
    WHERE property_id = p_property_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.update_property_admin(UUID, public.property_type_enum, public.listing_type_enum, DECIMAL, DECIMAL, DECIMAL, public.area_unit_enum, JSONB, TEXT, TEXT, TEXT, INTEGER, INTEGER, TEXT, TEXT, DECIMAL(9,6), DECIMAL(9,6), DECIMAL(5,1), DECIMAL(5,1), DECIMAL(5,1), DECIMAL(5,1), DECIMAL(5,1), DECIMAL(5,1), public.proximity_unit_enum, TEXT, JSONB, public.property_admin_status_enum, BOOLEAN, BOOLEAN, BOOLEAN, INTEGER, UUID, public.submitter_type_enum, TEXT, public.availability_status_enum, BOOLEAN, UUID, UUID) TO authenticated;

-- Function for super-admin to delete a property (use with caution)
CREATE OR REPLACE FUNCTION public.delete_property_admin(p_property_id UUID)
RETURNS VOID AS $$
BEGIN
    IF NOT public.current_user_has_role('super-admin') THEN
        RAISE EXCEPTION 'Unauthorized: Only super-admins can delete properties.';
    END IF;
    DELETE FROM public.properties WHERE property_id = p_property_id;
    IF NOT FOUND THEN RAISE WARNING 'Property with ID % not found for deletion.', p_property_id; END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.delete_property_admin(UUID) TO authenticated;


-- Function for admins to delete a property image by image_id
CREATE OR REPLACE FUNCTION public.delete_property_image_admin(p_image_id UUID)
RETURNS VOID AS $$
DECLARE
    v_property_id UUID;
BEGIN
    IF NOT public.current_user_is_admin() THEN
        RAISE EXCEPTION 'Unauthorized: Admin access required.';
    END IF;

    SELECT property_id INTO v_property_id FROM public.property_images WHERE image_id = p_image_id;
    IF NOT FOUND THEN RAISE WARNING 'Property image with ID % not found.', p_image_id; RETURN; END IF;

    DELETE FROM public.property_images WHERE image_id = p_image_id;

    UPDATE public.properties
    SET admin_status = 'SUBMITTED', is_listed = FALSE, updated_at = CURRENT_TIMESTAMP
    WHERE property_id = v_property_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.delete_property_image_admin(UUID) TO authenticated;

-- Function for admins to update property image details
CREATE OR REPLACE FUNCTION public.update_property_image_admin(
    p_image_id UUID,
    p_description TEXT DEFAULT NULL,
    p_display_order INTEGER DEFAULT NULL,
    p_is_internal_image BOOLEAN DEFAULT NULL
) RETURNS VOID AS $$
DECLARE
    v_property_id UUID;
BEGIN
    IF NOT public.current_user_is_admin() THEN
        RAISE EXCEPTION 'Unauthorized: Admin access required.';
    END IF;

    SELECT property_id INTO v_property_id FROM public.property_images WHERE image_id = p_image_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'Property image with ID % not found.', p_image_id; END IF;

    UPDATE public.property_images SET
        description = COALESCE(p_description, description),
        display_order = COALESCE(p_display_order, display_order),
        is_internal_image = COALESCE(p_is_internal_image, is_internal_image),
        updated_at = CURRENT_TIMESTAMP
    WHERE image_id = p_image_id;

    UPDATE public.properties
    SET admin_status = 'SUBMITTED', is_listed = FALSE, updated_at = CURRENT_TIMESTAMP
    WHERE property_id = v_property_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.update_property_image_admin(UUID, TEXT, INTEGER, BOOLEAN) TO authenticated;

CREATE OR REPLACE FUNCTION public.record_property_image_upload_admin(
    p_property_id UUID,
    p_image_url TEXT,
    p_description TEXT DEFAULT NULL,
    p_display_order INTEGER DEFAULT 0,
    p_is_internal_image BOOLEAN DEFAULT FALSE
) RETURNS UUID AS $$
DECLARE
    v_image_id UUID;
    v_uploader_admin_id UUID := auth.uid();
BEGIN
    IF NOT public.current_user_is_admin() THEN
        RAISE EXCEPTION 'Unauthorized: Admin access required.';
    END IF;
    IF NOT (public.current_user_has_role('marketing-team') OR public.current_user_has_role('telecalling-owner-team') OR public.current_user_has_role('super-admin')) THEN
        RAISE EXCEPTION 'Unauthorized: Insufficient role privileges to upload property images.';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM public.properties WHERE property_id = p_property_id) THEN
        RAISE EXCEPTION 'Property ID % not found.', p_property_id;
    END IF;

    INSERT INTO public.property_images (property_id, image_url, description, display_order, is_internal_image, uploaded_by)
    VALUES (p_property_id, p_image_url, p_description, p_display_order, p_is_internal_image, v_uploader_admin_id)
    RETURNING image_id INTO v_image_id;

    UPDATE public.properties
    SET admin_status = 'SUBMITTED', is_listed = FALSE, updated_at = CURRENT_TIMESTAMP
    WHERE property_id = p_property_id;

    RETURN v_image_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.record_property_image_upload_admin(UUID, TEXT, TEXT, INTEGER, BOOLEAN) TO authenticated;


CREATE OR REPLACE FUNCTION public.record_property_document_upload_admin(
    p_property_id UUID,
    p_document_type TEXT,
    p_document_url TEXT,
    p_file_name TEXT DEFAULT NULL,
    p_description TEXT DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
    v_document_id UUID;
    v_uploader_admin_id UUID := auth.uid();
BEGIN
    IF NOT public.current_user_is_admin() THEN
        RAISE EXCEPTION 'Unauthorized: Admin access required.';
    END IF;
    IF NOT (public.current_user_has_role('telecalling-owner-team') OR public.current_user_has_role('marketing-team') OR public.current_user_has_role('super-admin')) THEN
        RAISE EXCEPTION 'Unauthorized: Insufficient privileges to manage property documents.';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM public.properties WHERE property_id = p_property_id) THEN
        RAISE EXCEPTION 'Property ID % not found.', p_property_id;
    END IF;

    INSERT INTO public.property_documents(property_id, document_type, document_url, file_name, description, uploaded_by, uploaded_at)
    VALUES (p_property_id, p_document_type, p_document_url, p_file_name, p_description, v_uploader_admin_id, CURRENT_TIMESTAMP)
    RETURNING document_id INTO v_document_id;

    UPDATE public.properties
    SET admin_status = 'SUBMITTED', is_listed = FALSE, updated_at = CURRENT_TIMESTAMP
    WHERE property_id = p_property_id;

    RETURN v_document_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.record_property_document_upload_admin(UUID, TEXT, TEXT, TEXT, TEXT) TO authenticated;

CREATE OR REPLACE FUNCTION public.delete_property_document_admin(p_document_id UUID)
RETURNS VOID AS $$
DECLARE
    v_property_id UUID;
BEGIN
    IF NOT public.current_user_is_admin() THEN
        RAISE EXCEPTION 'Unauthorized: Admin access required.';
    END IF;
     IF NOT (public.current_user_has_role('telecalling-owner-team') OR public.current_user_has_role('marketing-team') OR public.current_user_has_role('super-admin')) THEN
        RAISE EXCEPTION 'Unauthorized: Insufficient privileges to manage property documents.';
    END IF;

    SELECT property_id INTO v_property_id FROM public.property_documents WHERE document_id = p_document_id;
    IF NOT FOUND THEN RAISE WARNING 'Property document % not found.', p_document_id; RETURN; END IF;

    DELETE FROM public.property_documents WHERE document_id = p_document_id;

    UPDATE public.properties
    SET admin_status = 'SUBMITTED', is_listed = FALSE, updated_at = CURRENT_TIMESTAMP
    WHERE property_id = v_property_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.delete_property_document_admin(UUID) TO authenticated;


CREATE OR REPLACE FUNCTION public.record_customer_document_upload_admin(
    p_customer_user_id UUID,
    p_document_type TEXT,
    p_document_url TEXT,
    p_file_name TEXT DEFAULT NULL,
    p_description TEXT DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
    v_document_id UUID;
    v_uploader_admin_id UUID := auth.uid();
BEGIN
    IF NOT public.current_user_is_admin() THEN
        RAISE EXCEPTION 'Unauthorized: Admin access required.';
    END IF;
    IF NOT (public.current_user_has_role('telecalling-owner-team') OR public.current_user_has_role('telecalling-tenant-team') OR public.current_user_has_role('super-admin')) THEN
        RAISE EXCEPTION 'Unauthorized: Insufficient privileges to manage customer documents.';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM auth.users WHERE id = p_customer_user_id) THEN
        RAISE EXCEPTION 'Customer User ID % not found.', p_customer_user_id;
    END IF;

    INSERT INTO public.customer_documents(user_id, document_type, document_url, file_name, description, uploaded_by, uploaded_at)
    VALUES (p_customer_user_id, p_document_type, p_document_url, p_file_name, p_description, v_uploader_admin_id, CURRENT_TIMESTAMP)
    RETURNING document_id INTO v_document_id;
    RETURN v_document_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.record_customer_document_upload_admin(UUID, TEXT, TEXT, TEXT, TEXT) TO authenticated;

CREATE OR REPLACE FUNCTION public.delete_customer_document_admin(p_document_id UUID)
RETURNS VOID AS $$
BEGIN
    IF NOT public.current_user_is_admin() THEN
        RAISE EXCEPTION 'Unauthorized: Admin access required.';
    END IF;
     IF NOT (public.current_user_has_role('telecalling-owner-team') OR public.current_user_has_role('telecalling-tenant-team') OR public.current_user_has_role('super-admin')) THEN
        RAISE EXCEPTION 'Unauthorized: Insufficient privileges to manage customer documents.';
    END IF;
    DELETE FROM public.customer_documents WHERE document_id = p_document_id;
    IF NOT FOUND THEN RAISE WARNING 'Customer document % not found.', p_document_id; END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.delete_customer_document_admin(UUID) TO authenticated;


CREATE OR REPLACE FUNCTION public.get_full_property_details_admin(p_property_id_input UUID)
RETURNS TABLE (
    property_id UUID,
    property_type public.property_type_enum,
    listing_type public.listing_type_enum,
    price DECIMAL,
    area DECIMAL,
    area_unit public.area_unit_enum,
    description TEXT,
    details JSONB,
    locality TEXT,
    city TEXT,
    address TEXT,
    pincode INTEGER,
    youtube_url TEXT,
    latitude DECIMAL(9,6),
    longitude DECIMAL(9,6),
    year_built INTEGER,
    nearest_hospital DECIMAL(5,1),
    nearest_busstop DECIMAL(5,1),
    nearest_gym DECIMAL(5,1),
    nearest_park DECIMAL(5,1),
    nearest_school DECIMAL(5,1),
    nearest_swimmingpool DECIMAL(5,1),
    proximity_unit public.proximity_unit_enum,
    admin_notes TEXT,
    inventory_details JSONB,
    admin_status public.property_admin_status_enum,
    is_listed BOOLEAN,
    is_featured BOOLEAN,
    is_exclusive BOOLEAN,
    advance_amount DECIMAL(10,2),
    rent_due_day INTEGER,
    submitter_type public.submitter_type_enum,
    submitter_notes TEXT,
    submitted_at TIMESTAMP WITH TIME ZONE,
    availability_status public.availability_status_enum,
    can_reachout BOOLEAN,
    created_at TIMESTAMP WITH TIME ZONE,
    updated_at TIMESTAMP WITH TIME ZONE,
    images JSONB,
    property_documents JSONB,
    submitter JSONB,
    tenant JSONB,
    management_plan JSONB,
    owner_contact_assignment JSONB,
    marketing_assignment JSONB,
    customer_interactions JSONB,
    rent_records JSONB,
    tickets JSONB
) AS $$
BEGIN
    IF NOT public.current_user_is_admin() THEN
        RAISE EXCEPTION 'Unauthorized: Admin access required to access full property details.';
    END IF;

    RETURN QUERY
    WITH property_base AS (
        SELECT p.*
        FROM public.properties p
        WHERE p.property_id = p_property_id_input
    ),
    submitter_info_cte AS (
        SELECT
            pb.property_id,
            jsonb_build_object(
                'id', u.id,
                'name', (u.raw_user_meta_data ->> 'full_name')::TEXT,
                'email', u.email::TEXT,
                'phone', u.phone::TEXT,
                'visit_balance', c.visit_balance,
                'expiry_date', c.expiry_date,
                'profile_details', c.profile_details,
                'created_at', u.created_at,
                'updated_at', u.updated_at
            ) AS submitter_data
        FROM property_base pb
        JOIN auth.users u ON pb.submitter = u.id
        LEFT JOIN public.customers c ON pb.submitter = c.user_id
        WHERE pb.submitter IS NOT NULL
    ),
    tenant_info_cte AS (
        SELECT
            pb.property_id,
            jsonb_build_object(
                'id', u.id,
                'name', (u.raw_user_meta_data ->> 'full_name')::TEXT,
                'email', u.email::TEXT,
                'phone', u.phone::TEXT,
                'visit_balance', c.visit_balance,
                'expiry_date', c.expiry_date,
                'profile_details', c.profile_details,
                'created_at', u.created_at,
                'updated_at', u.updated_at
            ) AS tenant_data
        FROM property_base pb
        JOIN auth.users u ON pb.tenant = u.id
        LEFT JOIN public.customers c ON pb.tenant = c.user_id
        WHERE pb.tenant IS NOT NULL
    ),
    management_plan_info_cte AS (
        SELECT
            pb.property_id,
            jsonb_build_object(
                'plan_id', msp.plan_id,
                'name', msp.name,
                'percentage', msp.percentage,
                'description', msp.description,
                'is_active', msp.is_active,
                'created_at', msp.created_at,
                'updated_at', msp.updated_at
            ) AS management_plan_data
        FROM property_base pb
        JOIN public.management_service_plans msp ON pb.management_plan_id = msp.plan_id
        WHERE pb.management_plan_id IS NOT NULL
    ),
    aggregated_property_images_cte AS (
        SELECT
            pi.property_id,
            jsonb_agg(
                jsonb_build_object(
                    'image_id', pi.image_id,
                    'image_url', pi.image_url,
                    'description', pi.description,
                    'display_order', pi.display_order,
                    'is_internal_image', pi.is_internal_image,
                    'uploaded_by', CASE
                        WHEN uploader_admin.user_id IS NOT NULL THEN jsonb_build_object(
                            'id', uploader_admin.user_id,
                            'name', (uploader_auth_user.raw_user_meta_data->>'full_name')::TEXT,
                            'email', uploader_auth_user.email::TEXT
                        )
                        ELSE NULL
                    END,
                    'created_at', pi.created_at
                ) ORDER BY pi.display_order ASC, pi.created_at ASC
            ) AS images_data
        FROM public.property_images pi
        LEFT JOIN public.admins uploader_admin ON pi.uploaded_by = uploader_admin.user_id
        LEFT JOIN auth.users uploader_auth_user ON uploader_admin.user_id = uploader_auth_user.id
        WHERE pi.property_id = p_property_id_input
        GROUP BY pi.property_id
    ),
    aggregated_property_documents_cte AS (
        SELECT
            pd.property_id,
            jsonb_agg(
                jsonb_build_object(
                    'document_id', pd.document_id,
                    'document_type', pd.document_type,
                    'document_url', pd.document_url,
                    'file_name', pd.file_name,
                    'description', pd.description,
                    'uploaded_by_name', (uploader_auth_user.raw_user_meta_data->>'full_name')::TEXT,
                    'uploaded_at', pd.uploaded_at
                ) ORDER BY pd.uploaded_at ASC
            ) AS property_documents_data
        FROM public.property_documents pd
        LEFT JOIN public.admins uploader_admin ON pd.uploaded_by = uploader_admin.user_id
        LEFT JOIN auth.users uploader_auth_user ON uploader_admin.user_id = uploader_auth_user.id
        WHERE pd.property_id = p_property_id_input
        GROUP BY pd.property_id
    ),
    owner_contact_assignment_info_cte AS (
        SELECT
            poca.property_id,
            jsonb_build_object(
                'assigned_admin_id', poca.assigned_admin_id,
                'assigned_admin_name', (assignee_auth_user.raw_user_meta_data->>'full_name')::TEXT,
                'assigned_at', poca.assigned_at
            ) AS owner_contact_assignment_data
        FROM public.property_owner_contact_assignments poca
        JOIN public.admins assignee_admin ON poca.assigned_admin_id = assignee_admin.user_id
        JOIN auth.users assignee_auth_user ON assignee_admin.user_id = assignee_auth_user.id
        WHERE poca.property_id = p_property_id_input
    ),
    marketing_assignment_info_cte AS (
        SELECT
            pma.property_id,
            jsonb_build_object(
                'assigned_admin_id', pma.assigned_admin_id,
                'assigned_admin_name', (assignee_auth_user.raw_user_meta_data->>'full_name')::TEXT,
                'assigned_at', pma.assigned_at
            ) AS marketing_assignment_data
        FROM public.property_marketing_assignments pma
        JOIN public.admins assignee_admin ON pma.assigned_admin_id = assignee_admin.user_id
        JOIN auth.users assignee_auth_user ON assignee_admin.user_id = assignee_auth_user.id
        WHERE pma.property_id = p_property_id_input
    ),
    aggregated_customer_interactions_cte AS (
        SELECT
            ci.property_id,
            jsonb_agg(
                jsonb_build_object(
                    'interaction_id', ci.interaction_id,
                    'user', jsonb_build_object(
                        'id', u.id,
                        'name', (u.raw_user_meta_data->>'full_name')::TEXT,
                        'email', u.email::TEXT
                    ),
                    'assigned_sales_admin', CASE
                        WHEN sales_admin.user_id IS NOT NULL THEN jsonb_build_object(
                            'id', sales_admin.user_id,
                            'name', (sales_admin_auth_user.raw_user_meta_data->>'full_name')::TEXT
                        )
                        ELSE NULL
                    END,
                    'status', ci.status,
                    'created_at', ci.created_at,
                    'scheduled_for', ci.scheduled_for,
                    'visited_at', ci.visited_at,
                    'admin_notes', ci.admin_notes
                ) ORDER BY ci.created_at DESC
            ) AS interactions_data
        FROM public.customers_interaction ci
        LEFT JOIN auth.users u ON ci.user_id = u.id
        LEFT JOIN public.admins sales_admin ON ci.assigned_sales_admin_id = sales_admin.user_id
        LEFT JOIN auth.users sales_admin_auth_user ON sales_admin.user_id = sales_admin_auth_user.id
        WHERE ci.property_id = p_property_id_input
        GROUP BY ci.property_id
    ),
    aggregated_rent_records_cte AS (
        SELECT
            rr.property_id,
            jsonb_agg(
                jsonb_build_object(
                    'rent_record_id', rr.rent_record_id,
                    'tenant', jsonb_build_object(
                        'id', t_user.id,
                        'name', (t_user.raw_user_meta_data->>'full_name')::TEXT,
                        'email', t_user.email::TEXT
                    ),
                    'landlord', jsonb_build_object(
                        'id', l_user.id,
                        'name', (l_user.raw_user_meta_data->>'full_name')::TEXT,
                        'email', l_user.email::TEXT
                    ),
                    'due_date', rr.due_date,
                    'period_start_date', rr.period_start_date,
                    'period_end_date', rr.period_end_date,
                    'amount_due', rr.amount_due,
                    'amount_paid', rr.amount_paid,
                    'status', rr.status,
                    'notes', rr.notes,
                    'created_at', rr.created_at
                ) ORDER BY rr.due_date DESC
            ) AS rent_records_data
        FROM public.rent_records rr
        LEFT JOIN auth.users t_user ON rr.tenant_user_id = t_user.id
        LEFT JOIN auth.users l_user ON rr.landlord_user_id = l_user.id
        WHERE rr.property_id = p_property_id_input
        GROUP BY rr.property_id
    ),
    aggregated_tickets_cte AS (
        SELECT
            t.property_id,
            jsonb_agg(
                jsonb_build_object(
                    'ticket_id', t.ticket_id,
                    'raised_by', jsonb_build_object(
                        'id', r_user.id,
                        'name', (r_user.raw_user_meta_data->>'full_name')::TEXT,
                        'email', r_user.email::TEXT
                    ),
                    'subject', t.subject,
                    'description', t.description,
                    'category', t.category,
                    'priority', t.priority,
                    'status', t.status,
                    'assigned_vendor', CASE
                        WHEN v.vendor_id IS NOT NULL THEN jsonb_build_object(
                            'vendor_id', v.vendor_id,
                            'company_name', v.company_name
                        )
                        ELSE NULL
                    END,
                    'assigned_support_admin', CASE
                        WHEN support_admin.user_id IS NOT NULL THEN jsonb_build_object(
                            'admin_id', support_admin.user_id,
                            'name', (support_admin_auth_user.raw_user_meta_data->>'full_name')::TEXT
                        )
                        ELSE NULL
                    END,
                    'resolution_notes', t.resolution_notes,
                    'created_at', t.created_at,
                    'images', COALESCE((
                        SELECT jsonb_agg(jsonb_build_object(
                            'image_id', ti.image_id,
                            'ticket_id', ti.ticket_id,
                            'image_url', ti.image_url,
                            'description', ti.description,
                            'uploaded_by', ti.uploaded_by::TEXT,
                            'created_at', ti.created_at
                        ) ORDER BY ti.created_at ASC)
                        FROM public.ticket_images ti WHERE ti.ticket_id = t.ticket_id
                    ), '[]'::jsonb),
                    'comments', COALESCE((
                        SELECT jsonb_agg(jsonb_build_object(
                            'comment_id', tc.comment_id,
                            'ticket_id', tc.ticket_id,
                            'comment_text', tc.comment_text,
                            'is_internal', tc.is_internal,
                            'user_id', tc.user_id::TEXT,
                            'created_at', tc.created_at
                        ) ORDER BY tc.created_at ASC)
                        FROM public.ticket_comments tc WHERE tc.ticket_id = t.ticket_id
                    ), '[]'::jsonb)
                ) ORDER BY t.created_at DESC
            ) AS tickets_data
        FROM public.tickets t
        LEFT JOIN auth.users r_user ON t.raised_by_user_id = r_user.id
        LEFT JOIN public.vendors v ON t.assigned_to_vendor_id = v.vendor_id
        LEFT JOIN public.admins support_admin ON t.assigned_support_admin_id = support_admin.user_id
        LEFT JOIN auth.users support_admin_auth_user ON support_admin.user_id = support_admin_auth_user.id
        WHERE t.property_id = p_property_id_input
        GROUP BY t.property_id
    )
    SELECT
        pb.property_id,
        pb.property_type,
        pb.listing_type,
        pb.price,
        pb.area,
        pb.area_unit,
        pb.description,
        pb.details,
        pb.locality,
        pb.city,
        pb.address,
        pb.pincode,
        pb.youtube_url,
        pb.latitude,
        pb.longitude,
        pb.year_built,
        pb.nearest_hospital,
        pb.nearest_busstop,
        pb.nearest_gym,
        pb.nearest_park,
        pb.nearest_school,
        pb.nearest_swimmingpool,
        pb.proximity_unit,
        pb.admin_notes,
        pb.inventory_details,
        pb.admin_status,
        pb.is_listed,
        pb.is_featured,
        pb.is_exclusive,
        pb.advance_amount,
        pb.rent_due_day,
        pb.submitter_type,
        pb.submitter_notes,
        pb.submitted_at,
        pb.availability_status,
        pb.can_reachout,
        pb.created_at,
        pb.updated_at,
        COALESCE(img_cte.images_data, '[]'::jsonb),
        COALESCE(docs_cte.property_documents_data, '[]'::jsonb),
        s_info_cte.submitter_data,
        t_info_cte.tenant_data,
        mp_info_cte.management_plan_data,
        oca_info_cte.owner_contact_assignment_data,
        mka_info_cte.marketing_assignment_data,
        COALESCE(inter_cte.interactions_data, '[]'::jsonb),
        COALESCE(rent_cte.rent_records_data, '[]'::jsonb),
        COALESCE(ticket_cte.tickets_data, '[]'::jsonb)
    FROM property_base pb
    LEFT JOIN submitter_info_cte s_info_cte ON pb.property_id = s_info_cte.property_id
    LEFT JOIN tenant_info_cte t_info_cte ON pb.property_id = t_info_cte.property_id
    LEFT JOIN management_plan_info_cte mp_info_cte ON pb.property_id = mp_info_cte.property_id
    LEFT JOIN aggregated_property_images_cte img_cte ON pb.property_id = img_cte.property_id
    LEFT JOIN aggregated_property_documents_cte docs_cte ON pb.property_id = docs_cte.property_id
    LEFT JOIN owner_contact_assignment_info_cte oca_info_cte ON pb.property_id = oca_info_cte.property_id
    LEFT JOIN marketing_assignment_info_cte mka_info_cte ON pb.property_id = mka_info_cte.property_id
    LEFT JOIN aggregated_customer_interactions_cte inter_cte ON pb.property_id = inter_cte.property_id
    LEFT JOIN aggregated_rent_records_cte rent_cte ON pb.property_id = rent_cte.property_id
    LEFT JOIN aggregated_tickets_cte ticket_cte ON pb.property_id = ticket_cte.property_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

GRANT EXECUTE ON FUNCTION public.get_full_property_details_admin(UUID) TO authenticated;


-- Description: Functions for admins to manage customer profiles, interactions, and visit plans/transactions.
-------------------------------------------------------------------------------

-- Function for admins to search and list customer profiles
CREATE OR REPLACE FUNCTION public.search_customers_admin(
    p_search_term TEXT,
    p_has_active_plan BOOLEAN DEFAULT NULL, -- Filter by customers with active visit plans
    p_offset INTEGER DEFAULT 0,
    p_limit INTEGER DEFAULT 10
) RETURNS TABLE (
    user_id UUID,
    full_name TEXT,
    email TEXT,
    phone TEXT,
    visit_balance INTEGER,
    expiry_date DATE,
    profile_details JSONB,
    created_at TIMESTAMPTZ, -- auth.users created_at
    customer_record_updated_at TIMESTAMPTZ, -- public.customers updated_at
    total_count BIGINT
) AS $$
BEGIN
    IF NOT public.current_user_is_admin() THEN
        RAISE EXCEPTION 'Unauthorized: Admin access required.';
    END IF;
    -- Further role checks can be added (e.g., only telecalling teams, accounts, super-admin)

    RETURN QUERY
    WITH customer_base AS (
        SELECT
            u.id AS user_id_val,
            u.raw_user_meta_data->>'full_name' AS full_name_val,
            u.email::TEXT AS email_val,
            u.phone::TEXT AS phone_val,
            c.visit_balance,
            c.expiry_date,
            c.profile_details,
            u.created_at AS auth_created_at,
            c.updated_at AS customer_updated_at
        FROM auth.users u
        LEFT JOIN public.customers c ON u.id = c.user_id
        WHERE (p_search_term IS NULL OR p_search_term = '' OR
               u.email ILIKE '%' || p_search_term || '%' OR
               u.phone ILIKE '%' || p_search_term || '%' OR
               (u.raw_user_meta_data->>'full_name') ILIKE '%' || p_search_term || '%' OR
               u.id::TEXT ILIKE '%' || p_search_term || '%')
          AND (p_has_active_plan IS NULL OR
               (p_has_active_plan = TRUE AND c.visit_balance > 0 AND c.expiry_date >= CURRENT_DATE) OR
               (p_has_active_plan = FALSE AND (c.visit_balance <= 0 OR c.expiry_date < CURRENT_DATE OR c.user_id IS NULL)))
    ),
    customers_with_count AS (
      SELECT *, COUNT(*) OVER() AS total_rows FROM customer_base
    )
    SELECT
        cwc.user_id_val, cwc.full_name_val, cwc.email_val, cwc.phone_val,
        cwc.visit_balance, cwc.expiry_date, cwc.profile_details,
        cwc.auth_created_at, cwc.customer_updated_at,
        cwc.total_rows
    FROM customers_with_count cwc
    ORDER BY cwc.full_name_val ASC
    OFFSET p_offset
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;
GRANT EXECUTE ON FUNCTION public.search_customers_admin(TEXT, BOOLEAN, INTEGER, INTEGER) TO authenticated;

-- Function for admins to get comprehensive details for a specific customer
CREATE OR REPLACE FUNCTION public.get_customer_full_details_admin(p_customer_user_id UUID)
RETURNS TABLE (
    user_id UUID,
    full_name TEXT,
    email TEXT,
    phone TEXT,
    visit_balance INTEGER,
    expiry_date DATE,
    profile_details JSONB,
    auth_created_at TIMESTAMPTZ,
    customer_updated_at TIMESTAMPTZ,
    customer_documents JSONB,
    interactions JSONB,
    owned_properties JSONB,
    tenant_in_properties JSONB,
    transactions JSONB,
    raised_tickets JSONB,
    landlord_rent_records JSONB,
    tenant_rent_records JSONB
) AS $$
BEGIN
    -- Authorization Check
    IF NOT (
        public.current_user_has_role('super-admin') OR
        public.current_user_has_role('telecalling-owner-team') OR
        public.current_user_has_role('telecalling-tenant-team')
    ) THEN
        RAISE EXCEPTION 'Unauthorized: Insufficient privileges to access full customer details.';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM auth.users WHERE id = p_customer_user_id) THEN
        RAISE EXCEPTION 'User with ID % not found.', p_customer_user_id;
    END IF;

    RETURN QUERY
    WITH base_user_info AS (
        SELECT
            u.id AS user_id_val,
            (u.raw_user_meta_data ->> 'full_name')::TEXT AS full_name_val,
            u.email::TEXT AS email_val,
            u.phone::TEXT AS phone_val,
            c.visit_balance,
            c.expiry_date,
            c.profile_details,
            u.created_at AS auth_created_at_val,
            c.updated_at AS customer_updated_at_val
        FROM auth.users u
        LEFT JOIN public.customers c ON u.id = c.user_id
        WHERE u.id = p_customer_user_id
    ),
    agg_customer_documents AS (
        SELECT
            cd.user_id,
            jsonb_agg(
                jsonb_build_object(
                    'document_id', cd.document_id,
                    'document_type', cd.document_type,
                    'document_url', cd.document_url,
                    'file_name', cd.file_name,
                    'description', cd.description,
                    'uploaded_by_name', uploader_auth_user.raw_user_meta_data->>'full_name',
                    'uploaded_at', cd.uploaded_at
                ) ORDER BY cd.uploaded_at DESC
            ) AS docs_data
        FROM public.customer_documents cd
        LEFT JOIN public.admins uploader_admin ON cd.uploaded_by = uploader_admin.user_id
        LEFT JOIN auth.users uploader_auth_user ON uploader_admin.user_id = uploader_auth_user.id
        WHERE cd.user_id = p_customer_user_id
        GROUP BY cd.user_id
    ),
    agg_interactions AS (
        SELECT
            ci.user_id,
            jsonb_agg(
                jsonb_build_object(
                    'interaction_id', ci.interaction_id,
                    'property_id', ci.property_id,
                    'property_address', p.address,
                    'property_locality', p.locality,
                    'status', ci.status,
                    'assigned_tenant_telecaller_name', tt_admin_user.raw_user_meta_data->>'full_name',
                    'assigned_sales_admin_name', sales_admin_user.raw_user_meta_data->>'full_name',
                    'created_at', ci.created_at,
                    'scheduled_for', ci.scheduled_for,
                    'visited_at', ci.visited_at,
                    'admin_notes', ci.admin_notes
                ) ORDER BY ci.updated_at DESC
            ) AS interactions_data
        FROM public.customers_interaction ci
        JOIN public.properties p ON ci.property_id = p.property_id
        LEFT JOIN public.admins tt_admin ON ci.assigned_tenant_telecaller_id = tt_admin.user_id
        LEFT JOIN auth.users tt_admin_user ON tt_admin.user_id = tt_admin_user.id
        LEFT JOIN public.admins sales_admin ON ci.assigned_sales_admin_id = sales_admin.user_id
        LEFT JOIN auth.users sales_admin_user ON sales_admin.user_id = sales_admin_user.id
        WHERE ci.user_id = p_customer_user_id
        GROUP BY ci.user_id
    ),
    agg_owned_properties AS (
        SELECT
            p.submitter as user_id,
            jsonb_agg(
                jsonb_strip_nulls(jsonb_build_object(
                    'property_id', p.property_id,
                    'property_type', p.property_type,
                    'listing_type', p.listing_type,
                    'price', p.price,
                    'address', p.address,
                    'locality', p.locality,
                    'city', p.city,
                    'pincode', p.pincode,
                    'admin_status', p.admin_status,
                    'is_listed', p.is_listed,
                    'images', COALESCE(
                        (SELECT jsonb_agg(
                                    jsonb_build_object(
                                        'image_id', img.image_id,
                                        'image_url', img.image_url,
                                        'description', img.description,
                                        'display_order', img.display_order,
                                        'is_internal_image', img.is_internal_image
                                    ) ORDER BY img.display_order ASC
                                )
                           FROM public.property_images img
                          WHERE img.property_id = p.property_id
                        ), '[]'::jsonb
                    ),
                    'tenant_info', CASE
                                      WHEN t_user.id IS NOT NULL THEN jsonb_build_object(
                                          'user_id', t_user.id,
                                          'name', (t_user.raw_user_meta_data ->> 'full_name')::TEXT,
                                          'email', t_user.email::TEXT,
                                          'phone', t_user.phone::TEXT
                                      )
                                      ELSE NULL
                                   END
                )) ORDER BY p.updated_at DESC
            ) AS owned_props_data
        FROM public.properties p
        LEFT JOIN auth.users t_user ON p.tenant = t_user.id
        WHERE p.submitter = p_customer_user_id
        GROUP BY p.submitter
    ),
    agg_tenant_in_properties AS (
        SELECT
            p.tenant as user_id,
            jsonb_agg(
                jsonb_strip_nulls(jsonb_build_object(
                    'property_id', p.property_id,
                    'property_type', p.property_type,
                    'listing_type', p.listing_type,
                    'price', p.price,
                    'address', p.address,
                    'locality', p.locality,
                    'city', p.city,
                    'pincode', p.pincode,
                    'admin_status', p.admin_status,
                    'is_listed', p.is_listed,
                    'owner_details', CASE
                                       WHEN owner_user.id IS NOT NULL THEN jsonb_build_object(
                                           'user_id', owner_user.id,
                                           'name', (owner_user.raw_user_meta_data ->> 'full_name')::TEXT,
                                           'email', owner_user.email::TEXT,
                                           'phone', owner_user.phone::TEXT
                                       )
                                       ELSE NULL
                                     END,
                    'images', COALESCE(
                        (SELECT jsonb_agg(
                                    jsonb_build_object(
                                        'image_id', img.image_id,
                                        'image_url', img.image_url,
                                        'description', img.description,
                                        'display_order', img.display_order,
                                        'is_internal_image', img.is_internal_image
                                    ) ORDER BY img.display_order ASC
                                )
                           FROM public.property_images img
                          WHERE img.property_id = p.property_id AND img.is_internal_image = FALSE -- Only public images for this view
                        ), '[]'::jsonb
                    )
                )) ORDER BY p.updated_at DESC
            ) AS tenant_props_data
        FROM public.properties p
        LEFT JOIN auth.users owner_user ON p.submitter = owner_user.id
        WHERE p.tenant = p_customer_user_id
        GROUP BY p.tenant
    ),
    agg_transactions AS (
        SELECT
            t.user_id,
            jsonb_agg(
                jsonb_build_object(
                    'transaction_id', t.transaction_id,
                    'plan_name', vp.name,
                    'amount', t.amount,
                    'status', t.status,
                    'created_at', t.created_at
                ) ORDER BY t.created_at DESC
            ) AS transactions_data
        FROM public.transactions t
        LEFT JOIN public.visit_plans vp ON t.plan_id = vp.plan_id
        WHERE t.user_id = p_customer_user_id
        GROUP BY t.user_id
    ),
    agg_raised_tickets AS (
        SELECT
            t.raised_by_user_id as user_id,
            jsonb_agg(
                jsonb_build_object(
                    'ticket_id', t.ticket_id,
                    'property_id', t.property_id,
                    'property_address', p.address,
                    'subject', t.subject,
                    'category', t.category,
                    'priority', t.priority,
                    'status', t.status,
                    'created_at', t.created_at
                ) ORDER BY t.created_at DESC
            ) AS tickets_data
        FROM public.tickets t
        LEFT JOIN public.properties p ON t.property_id = p.property_id
        WHERE t.raised_by_user_id = p_customer_user_id
        GROUP BY t.raised_by_user_id
    ),
    agg_landlord_rent_records AS (
        SELECT
            rr.landlord_user_id as user_id,
            jsonb_agg(
                jsonb_build_object(
                    'rent_record_id', rr.rent_record_id,
                    'property_id', p.property_id,
                    'property_address', p.address,
                    'tenant_name', tenant_auth_user.raw_user_meta_data->>'full_name',
                    'tenant_email', tenant_auth_user.email,
                    'tenant_phone', tenant_auth_user.phone,
                    'due_date', rr.due_date,
                    'period_start_date', rr.period_start_date,
                    'period_end_date', rr.period_end_date,
                    'amount_due', rr.amount_due,
                    'amount_paid', rr.amount_paid,
                    'status', rr.status
                ) ORDER BY rr.due_date DESC
            ) AS landlord_rent_data
        FROM public.rent_records rr
        JOIN public.properties p ON rr.property_id = p.property_id
        JOIN auth.users tenant_auth_user ON rr.tenant_user_id = tenant_auth_user.id
        WHERE rr.landlord_user_id = p_customer_user_id
        GROUP BY rr.landlord_user_id
    ),
    agg_tenant_rent_records AS (
        SELECT
            rr.tenant_user_id as user_id,
            jsonb_agg(
                jsonb_build_object(
                    'rent_record_id', rr.rent_record_id,
                    'property_id', p.property_id,
                    'property_address', p.address,
                    'landlord_name', landlord_auth_user.raw_user_meta_data->>'full_name',
                    'landlord_email', landlord_auth_user.email,
                    'landlord_phone', landlord_auth_user.phone,
                    'due_date', rr.due_date,
                    'period_start_date', rr.period_start_date,
                    'period_end_date', rr.period_end_date,
                    'amount_due', rr.amount_due,
                    'amount_paid', rr.amount_paid,
                    'status', rr.status
                ) ORDER BY rr.due_date DESC
            ) AS tenant_rent_data
        FROM public.rent_records rr
        JOIN public.properties p ON rr.property_id = p.property_id
        JOIN auth.users landlord_auth_user ON rr.landlord_user_id = landlord_auth_user.id
        WHERE rr.tenant_user_id = p_customer_user_id
        GROUP BY rr.tenant_user_id
    )
    SELECT
        bui.user_id_val, bui.full_name_val, bui.email_val, bui.phone_val,
        bui.visit_balance, bui.expiry_date, bui.profile_details,
        bui.auth_created_at_val, bui.customer_updated_at_val,
        COALESCE(adoc.docs_data, '[]'::jsonb),
        COALESCE(ai.interactions_data, '[]'::jsonb),
        COALESCE(aop.owned_props_data, '[]'::jsonb),
        COALESCE(atip.tenant_props_data, '[]'::jsonb),
        COALESCE(atran.transactions_data, '[]'::jsonb),
        COALESCE(atck.tickets_data, '[]'::jsonb),
        COALESCE(alrr.landlord_rent_data, '[]'::jsonb),
        COALESCE(atrr.tenant_rent_data, '[]'::jsonb)
    FROM base_user_info bui
    LEFT JOIN agg_customer_documents adoc ON bui.user_id_val = adoc.user_id
    LEFT JOIN agg_interactions ai ON bui.user_id_val = ai.user_id
    LEFT JOIN agg_owned_properties aop ON bui.user_id_val = aop.user_id
    LEFT JOIN agg_tenant_in_properties atip ON bui.user_id_val = atip.user_id
    LEFT JOIN agg_transactions atran ON bui.user_id_val = atran.user_id
    LEFT JOIN agg_raised_tickets atck ON bui.user_id_val = atck.user_id
    LEFT JOIN agg_landlord_rent_records alrr ON bui.user_id_val = alrr.user_id
    LEFT JOIN agg_tenant_rent_records atrr ON bui.user_id_val = atrr.user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION public.get_customer_full_details_admin(UUID) TO authenticated;

-- Function for admins to update customer's visit balance and expiry (Super Admin or Accounts Team)
CREATE OR REPLACE FUNCTION public.update_customer_visits_admin(
    p_customer_user_id UUID,
    p_new_visit_balance INTEGER,
    p_new_expiry_date DATE
) RETURNS VOID AS $$
BEGIN
    IF NOT (public.current_user_has_role('super-admin') OR public.current_user_has_role('accounts-team')) THEN
        RAISE EXCEPTION 'Unauthorized: Insufficient privileges to modify visit balances.';
    END IF;

    IF p_new_visit_balance < 0 THEN
        RAISE EXCEPTION 'Visit balance cannot be negative.';
    END IF;

    UPDATE public.customers
    SET visit_balance = p_new_visit_balance,
        expiry_date = p_new_expiry_date,
        updated_at = CURRENT_TIMESTAMP
    WHERE user_id = p_customer_user_id;

    IF NOT FOUND THEN
        -- Create customer record if it doesn't exist (e.g. user signed up but no customer record yet)
        INSERT INTO public.customers (user_id, visit_balance, expiry_date)
        VALUES (p_customer_user_id, p_new_visit_balance, p_new_expiry_date)
        ON CONFLICT (user_id) DO NOTHING; -- Should ideally not happen if trigger is working

        -- Re-check if insert happened due to conflict or user really not found in auth.users
        IF NOT EXISTS(SELECT 1 FROM public.customers WHERE user_id = p_customer_user_id) THEN
             IF NOT EXISTS(SELECT 1 FROM auth.users WHERE id = p_customer_user_id) THEN
                RAISE EXCEPTION 'User ID % not found in auth.users.', p_customer_user_id;
             ELSE
                RAISE WARNING 'Customer record for User ID % was missing and could not be created cleanly by update_customer_visits_admin. Check trigger.', p_customer_user_id;
             END IF;
        END IF;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.update_customer_visits_admin(UUID, INTEGER, DATE) TO authenticated;

-- Function for admins to update customer profile details (e.g., by telecalling teams)
CREATE OR REPLACE FUNCTION public.update_customer_profile_details_admin(
    p_customer_user_id UUID,
    p_profile_details JSONB,
    p_full_name TEXT DEFAULT NULL, -- To update auth.users.raw_user_meta_data
    p_phone TEXT DEFAULT NULL      -- To update auth.users.phone
) RETURNS VOID AS $$
DECLARE
    v_current_meta JSONB;
    v_new_meta JSONB;
BEGIN
    IF NOT public.current_user_is_admin() THEN
        RAISE EXCEPTION 'Unauthorized: Admin access required.';
    END IF;
    IF NOT (public.current_user_has_role('telecalling-owner-team') OR
            public.current_user_has_role('telecalling-tenant-team') OR
            public.current_user_has_role('super-admin')) THEN
        RAISE EXCEPTION 'Unauthorized: Insufficient role privileges.';
    END IF;

    IF jsonb_typeof(p_profile_details) IS NULL OR jsonb_typeof(p_profile_details) <> 'object' THEN
         RAISE EXCEPTION 'Invalid input: p_profile_details must be a valid JSON object.';
    END IF;

    UPDATE public.customers
    SET profile_details = p_profile_details,
        updated_at = CURRENT_TIMESTAMP
    WHERE user_id = p_customer_user_id;

    IF NOT FOUND THEN
        RAISE WARNING 'Customer record for User ID % not found. Profile details not updated in public.customers.', p_customer_user_id;
    END IF;

    -- Update auth.users metadata if changes are provided
    IF p_full_name IS NOT NULL OR p_phone IS NOT NULL THEN
        IF NOT public.current_user_has_role('super-admin') THEN
             RAISE EXCEPTION 'Unauthorized: Only super-admins can modify auth user details directly.';
        END IF;
        -- This part typically requires elevated privileges (service_role or specific Supabase admin API call)
        -- For a SECURITY DEFINER function owned by postgres, this can work.
        SELECT raw_user_meta_data INTO v_current_meta FROM auth.users WHERE id = p_customer_user_id;
        v_new_meta := COALESCE(v_current_meta, '{}'::jsonb);

        IF p_full_name IS NOT NULL THEN
            v_new_meta := jsonb_set(v_new_meta, '{full_name}', to_jsonb(p_full_name));
        END IF;
        -- Add other meta fields if needed

        UPDATE auth.users
        SET raw_user_meta_data = v_new_meta,
            phone = COALESCE(p_phone, phone) -- Only update phone if provided
        WHERE id = p_customer_user_id;

        IF NOT FOUND THEN
             RAISE EXCEPTION 'User ID % not found in auth.users. Auth details not updated.', p_customer_user_id;
        END IF;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER; -- CAUTION: Ensure this function owner is 'postgres' for auth.users update
GRANT EXECUTE ON FUNCTION public.update_customer_profile_details_admin(UUID, JSONB, TEXT, TEXT) TO authenticated;


-- Function for admins to list all customer interactions
CREATE OR REPLACE FUNCTION public.get_all_customer_interactions_admin(
    p_property_id_filter UUID DEFAULT NULL,
    p_interaction_statuses public.interaction_status_enum[] DEFAULT NULL,
    p_customer_user_id_filter UUID DEFAULT NULL,
    p_assigned_tt_admin_id_filter UUID DEFAULT NULL,
    p_assigned_sales_admin_id_filter UUID DEFAULT NULL,
    p_scheduled_for_start DATE DEFAULT NULL,
    p_scheduled_for_end DATE DEFAULT NULL,
    p_customer_search TEXT DEFAULT NULL, -- Search name, email, phone of customer
    p_property_search TEXT DEFAULT NULL, -- Search address, locality of property
    p_offset INTEGER DEFAULT 0,
    p_limit INTEGER DEFAULT 10
) RETURNS TABLE (
    interaction_id UUID,
    customer_user_id UUID,
    customer_name TEXT,
    customer_email TEXT,
    customer_phone TEXT,
    property_id UUID,
    property_address TEXT,
    property_locality TEXT,
    property_pincode INTEGER,
    property_admin_status public.property_admin_status_enum,
    interaction_status public.interaction_status_enum,
    scheduled_for DATE,
    visited_at TIMESTAMPTZ,
    admin_notes TEXT, -- Interaction specific admin notes
    assigned_tenant_telecaller_id UUID,
    assigned_tenant_telecaller_name TEXT,
    assigned_sales_admin_id UUID,
    assigned_sales_admin_name TEXT,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ,
    total_count BIGINT
) AS $$
BEGIN
    IF NOT public.current_user_is_admin() THEN
        RAISE EXCEPTION 'Unauthorized: Admin access required.';
    END IF;

    RETURN QUERY
    WITH interactions_base AS (
        SELECT
            ci.interaction_id,
            ci.user_id AS cust_user_id,
            cust_user.raw_user_meta_data->>'full_name' AS cust_name,
            cust_user.email::TEXT AS cust_email,
            cust_user.phone::TEXT AS cust_phone,
            ci.property_id AS prop_id,
            p.address AS prop_address,
            p.locality AS prop_locality,
            p.pincode AS prop_pincode,
            p.admin_status AS prop_admin_status,
            ci.status AS int_status,
            ci.scheduled_for AS sched_for,
            ci.visited_at AS vis_at,
            ci.admin_notes AS int_admin_notes,
            ci.assigned_tenant_telecaller_id AS tt_admin_id,
            tt_admin_user.raw_user_meta_data->>'full_name' AS tt_admin_name,
            ci.assigned_sales_admin_id AS sales_admin_id,
            sales_admin_user.raw_user_meta_data->>'full_name' AS sales_admin_name,
            ci.created_at AS int_created_at,
            ci.updated_at AS int_updated_at
        FROM public.customers_interaction ci
        JOIN auth.users cust_user ON ci.user_id = cust_user.id
        JOIN public.properties p ON ci.property_id = p.property_id
        LEFT JOIN public.admins tt_admin ON ci.assigned_tenant_telecaller_id = tt_admin.user_id
        LEFT JOIN auth.users tt_admin_user ON tt_admin.user_id = tt_admin_user.id
        LEFT JOIN public.admins sales_admin ON ci.assigned_sales_admin_id = sales_admin.user_id
        LEFT JOIN auth.users sales_admin_user ON sales_admin.user_id = sales_admin_user.id
        WHERE (p_property_id_filter IS NULL OR ci.property_id = p_property_id_filter)
          AND (p_interaction_statuses IS NULL OR ci.status = ANY(p_interaction_statuses))
          AND (p_customer_user_id_filter IS NULL OR ci.user_id = p_customer_user_id_filter)
          AND (p_assigned_tt_admin_id_filter IS NULL OR ci.assigned_tenant_telecaller_id = p_assigned_tt_admin_id_filter)
          AND (p_assigned_sales_admin_id_filter IS NULL OR ci.assigned_sales_admin_id = p_assigned_sales_admin_id_filter)
          AND (p_scheduled_for_start IS NULL OR ci.scheduled_for >= p_scheduled_for_start)
          AND (p_scheduled_for_end IS NULL OR ci.scheduled_for <= p_scheduled_for_end)
          AND (p_customer_search IS NULL OR (
                cust_user.raw_user_meta_data->>'full_name' ILIKE '%' || p_customer_search || '%' OR
                cust_user.email ILIKE '%' || p_customer_search || '%' OR
                cust_user.phone ILIKE '%' || p_customer_search || '%'
              ))
          AND (p_property_search IS NULL OR (
                p.address ILIKE '%' || p_property_search || '%' OR
                p.locality ILIKE '%' || p_property_search || '%' OR
                p.pincode::TEXT ILIKE '%' || p_property_search || '%'
              ))
    ),
    interactions_with_count AS (
        SELECT *, COUNT(*) OVER() AS total_rows FROM interactions_base
    )
    SELECT
        iwc.interaction_id, iwc.cust_user_id, iwc.cust_name, iwc.cust_email, iwc.cust_phone,
        iwc.prop_id, iwc.prop_address, iwc.prop_locality, iwc.prop_pincode, iwc.prop_admin_status,
        iwc.int_status, iwc.sched_for, iwc.vis_at, iwc.int_admin_notes,
        iwc.tt_admin_id, iwc.tt_admin_name,
        iwc.sales_admin_id, iwc.sales_admin_name,
        iwc.int_created_at, iwc.int_updated_at,
        iwc.total_rows
    FROM interactions_with_count iwc
    ORDER BY iwc.int_updated_at DESC
    OFFSET p_offset
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;
GRANT EXECUTE ON FUNCTION public.get_all_customer_interactions_admin(UUID, public.interaction_status_enum[], UUID, UUID, UUID, DATE, DATE, TEXT, TEXT, INTEGER, INTEGER) TO authenticated;

-- Function for admins to update a customer interaction (status, notes, assignments)
CREATE OR REPLACE FUNCTION public.update_customer_interaction_admin(
    p_interaction_id UUID,
    p_new_status public.interaction_status_enum DEFAULT NULL,
    p_new_scheduled_for DATE DEFAULT NULL,
    p_new_admin_notes TEXT DEFAULT NULL,
    p_assign_tenant_telecaller_id UUID DEFAULT NULL,
    p_assign_sales_admin_id UUID DEFAULT NULL
) RETURNS VOID AS $$
DECLARE
    v_current_interaction public.customers_interaction%ROWTYPE;
    v_can_update BOOLEAN := FALSE;
    v_calling_admin_id UUID := auth.uid();
BEGIN
    IF NOT public.current_user_is_admin() THEN
        RAISE EXCEPTION 'Unauthorized: Admin access required.';
    END IF;

    SELECT * INTO v_current_interaction FROM public.customers_interaction WHERE interaction_id = p_interaction_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'Interaction ID % not found.', p_interaction_id; END IF;

    IF public.current_user_has_role('super-admin') THEN
        v_can_update := TRUE;
    ELSIF public.current_user_has_role('telecalling-tenant-team') THEN
        IF v_current_interaction.assigned_tenant_telecaller_id = v_calling_admin_id OR
           v_current_interaction.status IN ('VISIT_PENDING', 'VISIT_CONFIRMED_PENDING_SALES') OR
           p_new_status IN ('VISIT_PENDING', 'VISIT_CONFIRMED_PENDING_SALES') THEN
            v_can_update := TRUE;
        END IF;
    ELSIF public.current_user_has_role('sales-team') THEN
         IF v_current_interaction.assigned_sales_admin_id = v_calling_admin_id OR
            v_current_interaction.status IN ('VISIT_SCHEDULED_WITH_SALES', 'VISIT_COMPLETED', 'VISIT_CANCELLED') OR
            p_new_status IN ('VISIT_SCHEDULED_WITH_SALES', 'VISIT_COMPLETED', 'VISIT_CANCELLED') THEN
             v_can_update := TRUE;
         END IF;
    END IF;

    IF NOT v_can_update THEN
        RAISE EXCEPTION 'Unauthorized: Insufficient privileges or interaction not in a modifiable state for your role.';
    END IF;

    IF p_assign_tenant_telecaller_id IS NOT NULL AND NOT public.user_is_admin_with_role(p_assign_tenant_telecaller_id, 'telecalling-tenant-team') THEN
        RAISE EXCEPTION 'Invalid Admin ID % or user does not have telecalling-tenant-team role.', p_assign_tenant_telecaller_id;
    END IF;
    IF p_assign_sales_admin_id IS NOT NULL AND NOT public.user_is_admin_with_role(p_assign_sales_admin_id, 'sales-team') THEN
        RAISE EXCEPTION 'Invalid Admin ID % or user does not have sales-team role.', p_assign_sales_admin_id;
    END IF;

    UPDATE public.customers_interaction
    SET status = COALESCE(p_new_status, status),
        scheduled_for = COALESCE(p_new_scheduled_for, scheduled_for),
        admin_notes = COALESCE(p_new_admin_notes, admin_notes),
        assigned_tenant_telecaller_id = CASE
            WHEN p_assign_tenant_telecaller_id IS NOT DISTINCT FROM assigned_tenant_telecaller_id THEN assigned_tenant_telecaller_id
            ELSE p_assign_tenant_telecaller_id
            END,
        telecaller_assigned_at = CASE
            WHEN p_assign_tenant_telecaller_id IS NOT NULL AND p_assign_tenant_telecaller_id IS DISTINCT FROM assigned_tenant_telecaller_id THEN CURRENT_TIMESTAMP
            WHEN p_assign_tenant_telecaller_id IS NULL AND assigned_tenant_telecaller_id IS NOT NULL THEN NULL
            ELSE telecaller_assigned_at
            END,
        assigned_sales_admin_id = CASE
            WHEN p_assign_sales_admin_id IS NOT DISTINCT FROM assigned_sales_admin_id THEN assigned_sales_admin_id
            ELSE p_assign_sales_admin_id
            END,
        visited_at = CASE
            WHEN p_new_status = 'VISIT_COMPLETED' AND status <> 'VISIT_COMPLETED' THEN CURRENT_TIMESTAMP
            WHEN p_new_status IS NOT NULL AND p_new_status <> 'VISIT_COMPLETED' THEN NULL
            ELSE visited_at
            END,
        updated_at = CURRENT_TIMESTAMP
    WHERE interaction_id = p_interaction_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.update_customer_interaction_admin(UUID, public.interaction_status_enum, DATE, TEXT, UUID, UUID) TO authenticated;


-- FILE NAME: 06_04_admin_visit_transaction_plan_functions.sql
-- Description: Functions for admins to manage visit plans and transactions.
-------------------------------------------------------------------------------

-- Function for admins to get all visit plans (active and inactive)
CREATE OR REPLACE FUNCTION public.get_all_visit_plans_admin(
    p_is_active_filter BOOLEAN DEFAULT NULL
) RETURNS TABLE (
    plan_id UUID,
    name TEXT,
    description TEXT,
    visits INTEGER,
    price DECIMAL,
    is_active BOOLEAN,
    created_at TIMESTAMP WITH TIME ZONE,
    updated_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    IF NOT (public.current_user_has_role('super-admin') OR public.current_user_has_role('accounts-team')) THEN
        RAISE EXCEPTION 'Unauthorized: Insufficient privileges.';
    END IF;

    RETURN QUERY
    SELECT vp.plan_id, vp.name, vp.description, vp.visits, vp.price, vp.is_active, vp.created_at, vp.updated_at
    FROM public.visit_plans vp
    WHERE (p_is_active_filter IS NULL OR vp.is_active = p_is_active_filter)
    ORDER BY vp.price;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;
GRANT EXECUTE ON FUNCTION public.get_all_visit_plans_admin(BOOLEAN) TO authenticated;

-- Function for admins to update a visit plan
CREATE OR REPLACE FUNCTION public.update_visit_plan_admin(
    p_plan_id UUID,
    p_name TEXT,
    p_description TEXT,
    p_visits INTEGER,
    p_price DECIMAL,
    p_is_active BOOLEAN
) RETURNS VOID AS $$
BEGIN
    IF NOT (public.current_user_has_role('super-admin') OR public.current_user_has_role('accounts-team')) THEN
        RAISE EXCEPTION 'Unauthorized: Insufficient privileges.';
    END IF;

    IF p_visits <= 0 THEN RAISE EXCEPTION 'Visits must be positive.'; END IF;
    IF p_price < 0 THEN RAISE EXCEPTION 'Price cannot be negative.'; END IF;
    IF p_name IS NULL OR TRIM(p_name) = '' THEN RAISE EXCEPTION 'Plan name cannot be empty.'; END IF;

    UPDATE public.visit_plans
    SET name = TRIM(p_name),
        description = p_description,
        visits = p_visits,
        price = p_price,
        is_active = p_is_active,
        updated_at = CURRENT_TIMESTAMP
    WHERE plan_id = p_plan_id;

    IF NOT FOUND THEN RAISE EXCEPTION 'Visit Plan with ID % not found.', p_plan_id; END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.update_visit_plan_admin(UUID, TEXT, TEXT, INTEGER, DECIMAL, BOOLEAN) TO authenticated;

-- Function for admins to insert a new visit plan
CREATE OR REPLACE FUNCTION public.insert_visit_plan_admin(
    p_name TEXT,
    p_description TEXT,
    p_visits INTEGER,
    p_price DECIMAL,
    p_is_active BOOLEAN DEFAULT TRUE
) RETURNS UUID AS $$
DECLARE
    v_plan_id UUID;
BEGIN
    IF NOT (public.current_user_has_role('super-admin') OR public.current_user_has_role('accounts-team')) THEN
        RAISE EXCEPTION 'Unauthorized: Insufficient privileges to create visit plans.';
    END IF;

    IF p_visits <= 0 THEN RAISE EXCEPTION 'Visits must be positive.'; END IF;
    IF p_price < 0 THEN RAISE EXCEPTION 'Price cannot be negative.'; END IF;
    IF p_name IS NULL OR TRIM(p_name) = '' THEN RAISE EXCEPTION 'Plan name cannot be empty.'; END IF;

    INSERT INTO public.visit_plans (name, description, visits, price, is_active)
    VALUES (TRIM(p_name), p_description, p_visits, p_price, p_is_active)
    RETURNING plan_id INTO v_plan_id;

    RETURN v_plan_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.insert_visit_plan_admin(TEXT, TEXT, INTEGER, DECIMAL, BOOLEAN) TO authenticated;

-- Function for admins to list all transactions
CREATE OR REPLACE FUNCTION public.get_all_transactions_admin(
    p_customer_user_id_filter UUID DEFAULT NULL,
    p_plan_id_filter UUID DEFAULT NULL,
    p_statuses_filter TEXT[] DEFAULT NULL,
    p_razorpay_order_id_filter TEXT DEFAULT NULL,
    p_created_at_start TIMESTAMPTZ DEFAULT NULL,
    p_created_at_end TIMESTAMPTZ DEFAULT NULL,
    p_offset INTEGER DEFAULT 0,
    p_limit INTEGER DEFAULT 10
) RETURNS TABLE (
    transaction_id UUID,
    customer_user_id UUID,
    customer_name TEXT,
    customer_email TEXT,
    customer_phone TEXT,
    plan_id UUID,
    plan_name TEXT,
    amount DECIMAL,
    status TEXT,
    razorpay_order_id TEXT,
    razorpay_payment_id TEXT,
    razorpay_signature TEXT,
    error_message TEXT,
    admin_notes TEXT,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ,
    total_count BIGINT
) AS $$
BEGIN
    IF NOT (public.current_user_has_role('super-admin') OR public.current_user_has_role('accounts-team')) THEN
        RAISE EXCEPTION 'Unauthorized: Insufficient privileges.';
    END IF;

    RETURN QUERY
    WITH transactions_base AS (
        SELECT
            t.transaction_id, t.user_id AS cust_id,
            cust_user.raw_user_meta_data->>'full_name' AS cust_name,
            cust_user.email::TEXT AS cust_email,
            cust_user.phone::TEXT AS cust_phone,
            t.plan_id AS p_id, vp.name AS p_name, t.amount AS amt, t.status AS stat,
            t.razorpay_order_id AS rz_order_id, t.razorpay_payment_id AS rz_payment_id,
            t.razorpay_signature AS rz_sig, t.error_message AS err_msg,
            t.admin_notes AS adm_notes,
            t.created_at AS cr_at, t.updated_at AS upd_at
        FROM public.transactions t
        JOIN auth.users cust_user ON t.user_id = cust_user.id
        LEFT JOIN public.visit_plans vp ON t.plan_id = vp.plan_id
        WHERE (p_customer_user_id_filter IS NULL OR t.user_id = p_customer_user_id_filter)
          AND (p_plan_id_filter IS NULL OR t.plan_id = p_plan_id_filter)
          AND (p_statuses_filter IS NULL OR t.status = ANY(p_statuses_filter))
          AND (p_razorpay_order_id_filter IS NULL OR t.razorpay_order_id = p_razorpay_order_id_filter)
          AND (p_created_at_start IS NULL OR t.created_at >= p_created_at_start)
          AND (p_created_at_end IS NULL OR t.created_at <= p_created_at_end)
    ),
    transactions_with_count AS (
        SELECT *, COUNT(*) OVER() AS total_rows FROM transactions_base
    )
    SELECT
        twc.transaction_id, twc.cust_id, twc.cust_name, twc.cust_email, twc.cust_phone,
        twc.p_id, twc.p_name, twc.amt, twc.stat,
        twc.rz_order_id, twc.rz_payment_id, twc.rz_sig, twc.err_msg,
        twc.adm_notes,
        twc.cr_at, twc.upd_at, twc.total_rows
    FROM transactions_with_count twc
    ORDER BY twc.cr_at DESC
    OFFSET p_offset
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;
GRANT EXECUTE ON FUNCTION public.get_all_transactions_admin(UUID, UUID, TEXT[], TEXT, TIMESTAMPTZ, TIMESTAMPTZ, INTEGER, INTEGER) TO authenticated;

-- Function for admins to manually update a transaction's status and add notes.
CREATE OR REPLACE FUNCTION public.update_transaction_status_admin(
    p_transaction_id UUID,
    p_new_status TEXT,
    p_admin_notes TEXT DEFAULT NULL
) RETURNS VOID AS $$
DECLARE
    v_existing_admin_notes TEXT;
BEGIN
    IF NOT public.current_user_is_admin() THEN
        RAISE EXCEPTION 'Unauthorized: Admin access required.';
    END IF;
    -- Further role checks can be added if only specific admin roles (e.g., accounts-team, super-admin) can do this.
    IF NOT (public.current_user_has_role('accounts-team') OR public.current_user_has_role('super-admin')) THEN
        RAISE EXCEPTION 'Unauthorized: Insufficient privileges to update transaction status manually.';
    END IF;

    SELECT admin_notes INTO v_existing_admin_notes
    FROM public.transactions
    WHERE transaction_id = p_transaction_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Transaction with ID % not found.', p_transaction_id;
    END IF;

    IF p_admin_notes IS NOT NULL AND TRIM(p_admin_notes) <> '' THEN
        v_existing_admin_notes := COALESCE(v_existing_admin_notes || E'\n\n', '') ||
                                  '--- Admin Update (' || (SELECT COALESCE(raw_user_meta_data->>'full_name', auth.uid()::TEXT) FROM auth.users WHERE id = auth.uid()) || ' @ ' || TO_CHAR(CURRENT_TIMESTAMP, 'YYYY-MM-DD HH24:MI') || ') ---\n' ||
                                  TRIM(p_admin_notes);
    END IF;

    UPDATE public.transactions
    SET status = p_new_status,
        admin_notes = v_existing_admin_notes, -- Use the appended notes
        updated_at = CURRENT_TIMESTAMP
    WHERE transaction_id = p_transaction_id;

    -- Note: This admin function does NOT automatically call complete_purchase.
    -- If a manual update to 'paid' should trigger visit balance updates,
    -- the admin would need to use `update_customer_visits_admin` or
    -- a super-admin might call `complete_purchase` if the `razorpay_order_id` is known.
    -- For now, this function only updates the status and notes.

    RAISE NOTICE 'Transaction % status updated to % by admin %.', p_transaction_id, p_new_status, auth.uid();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.update_transaction_status_admin(UUID, TEXT, TEXT) TO authenticated;


-- FILE NAME: 06_05_admin_service_vendor_management_functions.sql
-- Description: Functions for admins to manage services and vendors.
-------------------------------------------------------------------------------

-- ==== Service Management Functions ====

-- Function for admins (e.g., super-admin, specific operational roles) to create a new service
CREATE OR REPLACE FUNCTION public.create_service_admin(
    p_service_name TEXT,
    p_description TEXT DEFAULT NULL,
    p_category public.service_category_enum DEFAULT NULL
) RETURNS INTEGER AS $$
DECLARE
    v_service_id INTEGER;
BEGIN
    IF NOT (public.current_user_has_role('super-admin') OR public.current_user_has_role('accounts-team')) THEN -- Example roles
        RAISE EXCEPTION 'Unauthorized: Insufficient privileges to create services.';
    END IF;

    IF p_service_name IS NULL OR TRIM(p_service_name) = '' THEN
        RAISE EXCEPTION 'Service name cannot be empty.';
    END IF;

    INSERT INTO public.services (service_name, description, category)
    VALUES (TRIM(p_service_name), p_description, p_category)
    RETURNING service_id INTO v_service_id;

    RETURN v_service_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.create_service_admin(TEXT, TEXT, public.service_category_enum) TO authenticated;

-- Function for admins to update an existing service
CREATE OR REPLACE FUNCTION public.update_service_admin(
    p_service_id INTEGER,
    p_service_name TEXT,
    p_description TEXT DEFAULT NULL,
    p_category public.service_category_enum DEFAULT NULL
) RETURNS VOID AS $$
BEGIN
    IF NOT (public.current_user_has_role('super-admin') OR public.current_user_has_role('accounts-team')) THEN
        RAISE EXCEPTION 'Unauthorized: Insufficient privileges to update services.';
    END IF;

    IF p_service_name IS NULL OR TRIM(p_service_name) = '' THEN
        RAISE EXCEPTION 'Service name cannot be empty.';
    END IF;

    UPDATE public.services
    SET service_name = TRIM(p_service_name),
        description = p_description,
        category = p_category
        -- updated_at trigger handles timestamp
    WHERE service_id = p_service_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Service with ID % not found.', p_service_id;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.update_service_admin(INTEGER, TEXT, TEXT, public.service_category_enum) TO authenticated;

-- Function for admins to delete a service
CREATE OR REPLACE FUNCTION public.delete_service_admin(p_service_id INTEGER)
RETURNS VOID AS $$
BEGIN
    IF NOT (public.current_user_has_role('super-admin') OR public.current_user_has_role('accounts-team')) THEN
        RAISE EXCEPTION 'Unauthorized: Insufficient privileges to delete services.';
    END IF;

    -- Consider implications: what happens to vendor_services or tickets using this service?
    -- For now, direct delete. Could add checks or cascade.
    DELETE FROM public.services WHERE service_id = p_service_id;

    IF NOT FOUND THEN
        RAISE WARNING 'Service with ID % not found for deletion.', p_service_id;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.delete_service_admin(INTEGER) TO authenticated;

-- Function for admins to list services
CREATE OR REPLACE FUNCTION public.list_services_admin(
    p_category_filter public.service_category_enum DEFAULT NULL,
    p_search_term TEXT DEFAULT NULL,
    p_offset INTEGER DEFAULT 0,
    p_limit INTEGER DEFAULT 25
) RETURNS TABLE (
    service_id INTEGER,
    service_name TEXT,
    description TEXT,
    category public.service_category_enum,
    created_at TIMESTAMP WITH TIME ZONE,
    total_count BIGINT
) AS $$
BEGIN
    IF NOT public.current_user_is_admin() THEN -- Any admin can list services
        RAISE EXCEPTION 'Unauthorized: Admin access required.';
    END IF;

    RETURN QUERY
    WITH services_base AS (
      SELECT s.service_id, s.service_name, s.description, s.category, s.created_at
      FROM public.services s
      WHERE (p_category_filter IS NULL OR s.category = p_category_filter)
        AND (p_search_term IS NULL OR (
              s.service_name ILIKE '%' || p_search_term || '%' OR
              s.description ILIKE '%' || p_search_term || '%'
            ))
    ),
    services_with_count AS (
      SELECT *, COUNT(*) OVER() AS total_rows FROM services_base
    )
    SELECT swc.*
    FROM services_with_count swc
    ORDER BY swc.service_name
    OFFSET p_offset
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;
GRANT EXECUTE ON FUNCTION public.list_services_admin(public.service_category_enum, TEXT, INTEGER, INTEGER) TO authenticated;


-- ==== Vendor Management Functions ====

-- Function for admins to create a new vendor
CREATE OR REPLACE FUNCTION public.create_vendor_admin(
    p_company_name TEXT,
    p_contact_name TEXT DEFAULT NULL,
    p_phone TEXT DEFAULT NULL,
    p_email TEXT DEFAULT NULL,
    p_address TEXT DEFAULT NULL,
    p_status vendor_status_enum DEFAULT 'ACTIVE',
    p_notes TEXT DEFAULT NULL,
    p_service_ids INTEGER[] DEFAULT NULL -- Optional: assign services upon creation
) RETURNS UUID AS $$
DECLARE
    v_vendor_id UUID;
    service_id_item INTEGER;
BEGIN
    IF NOT (public.current_user_has_role('super-admin') OR public.current_user_has_role('accounts-team')) THEN -- Example roles
        RAISE EXCEPTION 'Unauthorized: Insufficient privileges to create vendors.';
    END IF;

    IF p_company_name IS NULL OR TRIM(p_company_name) = '' THEN
        RAISE EXCEPTION 'Company name cannot be empty.';
    END IF;
    IF p_email IS NOT NULL AND p_email !~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$' THEN
        RAISE EXCEPTION 'Invalid email format for vendor.';
    END IF;

    INSERT INTO public.vendors (company_name, contact_name, phone, email, address, status, notes)
    VALUES (TRIM(p_company_name), p_contact_name, p_phone, p_email, p_address, p_status, p_notes)
    RETURNING vendor_id INTO v_vendor_id;

    IF p_service_ids IS NOT NULL THEN
        FOREACH service_id_item IN ARRAY p_service_ids LOOP
            IF EXISTS (SELECT 1 FROM public.services s WHERE s.service_id = service_id_item) THEN
                INSERT INTO public.vendor_services (vendor_id, service_id)
                VALUES (v_vendor_id, service_id_item)
                ON CONFLICT (vendor_id, service_id) DO NOTHING;
            ELSE
                RAISE WARNING 'Service ID % provided for new vendor does not exist and was skipped.', service_id_item;
            END IF;
        END LOOP;
    END IF;

    RETURN v_vendor_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.create_vendor_admin(TEXT, TEXT, TEXT, TEXT, TEXT, vendor_status_enum, TEXT, INTEGER[]) TO authenticated;

-- Function for admins to update an existing vendor's details
CREATE OR REPLACE FUNCTION public.update_vendor_admin(
    p_vendor_id UUID,
    p_company_name TEXT DEFAULT NULL,
    p_contact_name TEXT DEFAULT NULL,
    p_phone TEXT DEFAULT NULL,
    p_email TEXT DEFAULT NULL,
    p_address TEXT DEFAULT NULL,
    p_status vendor_status_enum DEFAULT NULL,
    p_notes TEXT DEFAULT NULL
) RETURNS VOID AS $$
BEGIN
    IF NOT (public.current_user_has_role('super-admin') OR public.current_user_has_role('accounts-team')) THEN
        RAISE EXCEPTION 'Unauthorized: Insufficient privileges to update vendors.';
    END IF;

    IF p_email IS NOT NULL AND p_email !~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$' THEN
        RAISE EXCEPTION 'Invalid email format for vendor update.';
    END IF;

    UPDATE public.vendors
    SET company_name = COALESCE(TRIM(p_company_name), company_name),
        contact_name = COALESCE(p_contact_name, contact_name),
        phone = COALESCE(p_phone, phone),
        email = COALESCE(p_email, email),
        address = COALESCE(p_address, address),
        status = COALESCE(p_status, status),
        notes = COALESCE(p_notes, notes)
        -- updated_at trigger handles timestamp
    WHERE vendor_id = p_vendor_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Vendor with ID % not found.', p_vendor_id;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.update_vendor_admin(UUID, TEXT, TEXT, TEXT, TEXT, TEXT, vendor_status_enum, TEXT) TO authenticated;

-- Function for admins to get details of a specific vendor, including their services
CREATE OR REPLACE FUNCTION public.get_vendor_details_admin(p_vendor_id_input UUID)
RETURNS TABLE (
    vendor_id UUID,
    company_name TEXT,
    contact_name TEXT,
    phone TEXT,
    email TEXT,
    address TEXT,
    status vendor_status_enum,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE,
    updated_at TIMESTAMP WITH TIME ZONE,
    services JSONB -- Array of {service_id, service_name, category}
) AS $$
BEGIN
    IF NOT public.current_user_is_admin() THEN
        RAISE EXCEPTION 'Unauthorized: Admin access required.';
    END IF;

    RETURN QUERY
    SELECT
        v.vendor_id, v.company_name, v.contact_name, v.phone, v.email, v.address, v.status, v.notes,
        v.created_at, v.updated_at,
        COALESCE(
            (SELECT jsonb_agg(jsonb_build_object(
                'service_id', s.service_id,
                'service_name', s.service_name,
                'category', s.category
             ) ORDER BY s.service_name)
            FROM public.vendor_services vs
            JOIN public.services s ON vs.service_id = s.service_id
            WHERE vs.vendor_id = v.vendor_id),
            '[]'::jsonb
        ) AS services_data
    FROM public.vendors v
    WHERE v.vendor_id = p_vendor_id_input;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;
GRANT EXECUTE ON FUNCTION public.get_vendor_details_admin(UUID) TO authenticated;

-- Function for admins to delete a vendor
CREATE OR REPLACE FUNCTION public.delete_vendor_admin(p_vendor_id UUID)
RETURNS VOID AS $$
BEGIN
    IF NOT (public.current_user_has_role('super-admin') OR public.current_user_has_role('accounts-team')) THEN
        RAISE EXCEPTION 'Unauthorized: Insufficient privileges to delete vendors.';
    END IF;

    -- Consider implications: tickets assigned to this vendor? Set to NULL or restrict.
    -- For now, direct delete.
    DELETE FROM public.vendors WHERE vendor_id = p_vendor_id;

    IF NOT FOUND THEN
        RAISE WARNING 'Vendor with ID % not found for deletion.', p_vendor_id;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.delete_vendor_admin(UUID) TO authenticated;

-- Function for admins to assign a service to a vendor
CREATE OR REPLACE FUNCTION public.assign_service_to_vendor_admin(
    p_vendor_id_input UUID,
    p_service_id_input INTEGER
) RETURNS VOID AS $$
BEGIN
    IF NOT (public.current_user_has_role('super-admin') OR public.current_user_has_role('accounts-team')) THEN
        RAISE EXCEPTION 'Unauthorized: Insufficient privileges.';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM public.vendors WHERE vendor_id = p_vendor_id_input) THEN
        RAISE EXCEPTION 'Vendor with ID % not found.', p_vendor_id_input;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM public.services WHERE service_id = p_service_id_input) THEN
        RAISE EXCEPTION 'Service with ID % not found.', p_service_id_input;
    END IF;

    INSERT INTO public.vendor_services (vendor_id, service_id)
    VALUES (p_vendor_id_input, p_service_id_input)
    ON CONFLICT (vendor_id, service_id) DO NOTHING;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.assign_service_to_vendor_admin(UUID, INTEGER) TO authenticated;

-- Function for admins to remove a service from a vendor
CREATE OR REPLACE FUNCTION public.remove_service_from_vendor_admin(
    p_vendor_id_input UUID,
    p_service_id_input INTEGER
) RETURNS VOID AS $$
BEGIN
    IF NOT (public.current_user_has_role('super-admin') OR public.current_user_has_role('accounts-team')) THEN
        RAISE EXCEPTION 'Unauthorized: Insufficient privileges.';
    END IF;

    DELETE FROM public.vendor_services
    WHERE vendor_id = p_vendor_id_input AND service_id = p_service_id_input;
    -- No error if not found, it's idempotent.
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.remove_service_from_vendor_admin(UUID, INTEGER) TO authenticated;

-- Function for admins to list vendors with filters
CREATE OR REPLACE FUNCTION public.list_vendors_admin(
    p_status_filter vendor_status_enum DEFAULT NULL,
    p_service_id_filter INTEGER DEFAULT NULL, -- Filter by vendors offering a specific service
    p_search_term TEXT DEFAULT NULL,
    p_offset INTEGER DEFAULT 0,
    p_limit INTEGER DEFAULT 25
) RETURNS TABLE (
    vendor_id UUID,
    company_name TEXT,
    contact_name TEXT,
    phone TEXT,
    email TEXT,
    status vendor_status_enum,
    notes TEXT,
    services_summary TEXT, -- Comma-separated list of service names
    total_count BIGINT
) AS $$
BEGIN
    IF NOT public.current_user_is_admin() THEN
        RAISE EXCEPTION 'Unauthorized: Admin access required.';
    END IF;

    RETURN QUERY
    WITH vendors_base AS (
        SELECT
            v.vendor_id, v.company_name, v.contact_name, v.phone, v.email, v.status, v.notes,
            (SELECT string_agg(s.service_name, ', ')
             FROM public.vendor_services vs
             JOIN public.services s ON vs.service_id = s.service_id
             WHERE vs.vendor_id = v.vendor_id
            ) AS services_list_summary
        FROM public.vendors v
        WHERE (p_status_filter IS NULL OR v.status = p_status_filter)
          AND (p_service_id_filter IS NULL OR EXISTS (
                SELECT 1 FROM public.vendor_services vs_filter
                WHERE vs_filter.vendor_id = v.vendor_id AND vs_filter.service_id = p_service_id_filter
              ))
          AND (p_search_term IS NULL OR (
                v.company_name ILIKE '%' || p_search_term || '%' OR
                v.contact_name ILIKE '%' || p_search_term || '%' OR
                v.email ILIKE '%' || p_search_term || '%' OR
                v.phone ILIKE '%' || p_search_term || '%' OR
                v.notes ILIKE '%' || p_search_term || '%'
              ))
    ),
    vendors_with_count AS (
      SELECT *, COUNT(*) OVER() AS total_rows FROM vendors_base
    )
    SELECT vwc.*
    FROM vendors_with_count vwc
    ORDER BY vwc.company_name
    OFFSET p_offset
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;
GRANT EXECUTE ON FUNCTION public.list_vendors_admin(vendor_status_enum, INTEGER, TEXT, INTEGER, INTEGER) TO authenticated;


-- FILE NAME: 06_06_admin_team_assignment_workflow_functions.sql
-- Description: Functions to manage team-specific assignments and workflows.
-------------------------------------------------------------------------------

-- ==== Telecalling-Owner-Team Workflow Functions ====

-- Function for telecalling-owner-team or super-admin to list properties assignable for owner contact
CREATE OR REPLACE FUNCTION public.get_assignable_owner_contact_properties_admin(
    p_city_filter TEXT DEFAULT NULL,
    p_pincode_filter INTEGER DEFAULT NULL,
    p_offset INTEGER DEFAULT 0,
    p_limit INTEGER DEFAULT 10
) RETURNS TABLE (
    property_id UUID,
    address TEXT,
    locality TEXT,
    city TEXT,
    pincode INTEGER,
    submitter_name TEXT,
    submitter_phone TEXT,
    submitted_at TIMESTAMP WITH TIME ZONE,
    total_count BIGINT
) AS $$
BEGIN
    IF NOT (public.current_user_has_role('telecalling-owner-team') OR public.current_user_has_role('super-admin')) THEN
        RAISE EXCEPTION 'Unauthorized: Insufficient privileges.';
    END IF;

    RETURN QUERY
    WITH assignable_props AS (
        SELECT
            p.property_id, p.address, p.locality, p.city, p.pincode,
            u_submitter.raw_user_meta_data->>'full_name' AS s_name,
            u_submitter.phone AS s_phone,
            p.submitted_at
        FROM public.properties p
        JOIN auth.users u_submitter ON p.submitter = u_submitter.id
        LEFT JOIN public.property_owner_contact_assignments poca ON p.property_id = poca.property_id
        WHERE p.admin_status = 'SUBMITTED'
          AND poca.property_id IS NULL -- Not already assigned
          AND (p_city_filter IS NULL OR p.city ILIKE p_city_filter)
          AND (p_pincode_filter IS NULL OR p.pincode = p_pincode_filter)
    ),
    props_with_count AS (
        SELECT *, COUNT(*) OVER() AS total_rows FROM assignable_props
    )
    SELECT pwc.* FROM props_with_count pwc
    ORDER BY pwc.submitted_at ASC
    OFFSET p_offset
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;
GRANT EXECUTE ON FUNCTION public.get_assignable_owner_contact_properties_admin(TEXT, INTEGER, INTEGER, INTEGER) TO authenticated;

-- Function for a telecalling-owner-team member to self-assign a property
CREATE OR REPLACE FUNCTION public.self_assign_property_for_owner_contact_admin(
    p_property_id UUID
) RETURNS VOID AS $$
DECLARE
    v_admin_id UUID := auth.uid();
BEGIN
    IF NOT (public.current_user_has_role('telecalling-owner-team') OR public.current_user_has_role('super-admin')) THEN
        RAISE EXCEPTION 'Unauthorized: Only telecalling-owner-team members can self-assign properties.';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM public.properties WHERE property_id = p_property_id AND admin_status = 'SUBMITTED') THEN
        RAISE EXCEPTION 'Property % is not in SUBMITTED state or does not exist.', p_property_id;
    END IF;

    INSERT INTO public.property_owner_contact_assignments (property_id, assigned_admin_id)
    VALUES (p_property_id, v_admin_id)
    ON CONFLICT (property_id) DO NOTHING; -- Avoid error if already assigned (though UI should prevent this)

    IF NOT FOUND AND NOT EXISTS(SELECT 1 FROM public.property_owner_contact_assignments WHERE property_id = p_property_id AND assigned_admin_id = v_admin_id) THEN
         -- This case means another admin just assigned it.
         RAISE EXCEPTION 'Property % was just assigned to another admin. Please select a different property.', p_property_id;
    END IF;

    UPDATE public.properties
    SET admin_status = 'OWNER_CONTACT_PENDING', updated_at = CURRENT_TIMESTAMP
    WHERE property_id = p_property_id AND admin_status = 'SUBMITTED'; -- Ensure status changes only if it was SUBMITTED
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.self_assign_property_for_owner_contact_admin(UUID) TO authenticated;

-- Function for super-admin to assign a property to a specific telecalling-owner-team member
CREATE OR REPLACE FUNCTION public.assign_property_to_owner_telecaller_admin(
    p_property_id UUID,
    p_target_admin_id UUID
) RETURNS VOID AS $$
BEGIN
    IF NOT public.current_user_has_role('super-admin') THEN
        RAISE EXCEPTION 'Unauthorized: Only super-admins can perform this assignment.';
    END IF;

    IF NOT public.user_is_admin_with_role(p_target_admin_id, 'telecalling-owner-team') THEN
        RAISE EXCEPTION 'Target user % is not an active member of telecalling-owner-team.', p_target_admin_id;
    END IF;

    UPDATE public.properties
    SET admin_status = 'OWNER_CONTACT_PENDING', updated_at = CURRENT_TIMESTAMP
    WHERE property_id = p_property_id AND admin_status IN ('SUBMITTED', 'OWNER_CONTACT_PENDING'); -- Allow re-assignment

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Property % not found or not in a state to be assigned.', p_property_id;
    END IF;

    INSERT INTO public.property_owner_contact_assignments (property_id, assigned_admin_id)
    VALUES (p_property_id, p_target_admin_id)
    ON CONFLICT (property_id) DO UPDATE
    SET assigned_admin_id = EXCLUDED.assigned_admin_id, assigned_at = CURRENT_TIMESTAMP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.assign_property_to_owner_telecaller_admin(UUID, UUID) TO authenticated;

-- Function for an admin to unassign a property from owner telecalling
CREATE OR REPLACE FUNCTION public.unassign_property_from_owner_telecaller_admin(p_property_id UUID)
RETURNS VOID AS $$
DECLARE
    v_calling_admin_id UUID := auth.uid();
    v_assigned_admin_id UUID;
BEGIN
    SELECT assigned_admin_id INTO v_assigned_admin_id
    FROM public.property_owner_contact_assignments WHERE property_id = p_property_id;

    IF NOT FOUND THEN
        RAISE WARNING 'Property % is not currently assigned for owner contact.', p_property_id;
        RETURN;
    END IF;

    IF NOT (public.current_user_has_role('super-admin') OR v_assigned_admin_id = v_calling_admin_id) THEN
        RAISE EXCEPTION 'Unauthorized: Only super-admins or the assigned admin can unassign.';
    END IF;

    DELETE FROM public.property_owner_contact_assignments WHERE property_id = p_property_id;

    UPDATE public.properties
    SET admin_status = 'SUBMITTED', updated_at = CURRENT_TIMESTAMP
    WHERE property_id = p_property_id AND admin_status = 'OWNER_CONTACT_PENDING';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.unassign_property_from_owner_telecaller_admin(UUID) TO authenticated;

-- Function for telecalling-owner-team to mark property owner as verified,
-- make listing active, AND unassign from owner telecalling.
CREATE OR REPLACE FUNCTION public.mark_property_owner_verified_admin(
    p_property_id UUID,
    p_verification_notes TEXT DEFAULT NULL
) RETURNS VOID AS $$
DECLARE
    v_admin_id UUID := auth.uid();
    v_update_successful BOOLEAN := FALSE;
BEGIN
    IF NOT (public.current_user_has_role('telecalling-owner-team') OR public.current_user_has_role('super-admin')) THEN
        RAISE EXCEPTION 'Unauthorized: Only telecalling-owner-team can mark owner verified.';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM public.property_owner_contact_assignments WHERE property_id = p_property_id AND assigned_admin_id = v_admin_id) THEN
        RAISE EXCEPTION 'Property % is not assigned to you for owner contact, or assignment record does not exist.', p_property_id;
    END IF;

    UPDATE public.properties
    SET admin_status = 'OWNER_VERIFIED',
        is_listed = TRUE,
        admin_notes = COALESCE(admin_notes || E'\n--- Owner Verification & Auto-Listed (' || v_admin_id || ' @ ' || TO_CHAR(CURRENT_TIMESTAMP, 'YYYY-MM-DD HH24:MI') || ') ---\n' || p_verification_notes, admin_notes),
        updated_at = CURRENT_TIMESTAMP
    WHERE property_id = p_property_id AND admin_status = 'OWNER_CONTACT_PENDING'
    RETURNING TRUE INTO v_update_successful;

    IF NOT v_update_successful THEN
        RAISE EXCEPTION 'Property % could not be updated. Ensure it is in OWNER_CONTACT_PENDING state and assigned to you.', p_property_id;
    ELSE
        RAISE NOTICE 'Property % marked as OWNER_VERIFIED and listed by admin %.', p_property_id, v_admin_id;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.mark_property_owner_verified_admin(UUID, TEXT) TO authenticated;


-- ==== Marketing-Team Workflow Functions ====

-- Function for marketing-team or super-admin to list properties assignable for marketing visit
CREATE OR REPLACE FUNCTION public.get_assignable_marketing_properties_admin(
    p_city_filter TEXT DEFAULT NULL,
    p_pincode_filter INTEGER DEFAULT NULL,
    p_offset INTEGER DEFAULT 0,
    p_limit INTEGER DEFAULT 10
) RETURNS TABLE (
    property_id UUID,
    address TEXT,
    locality TEXT,
    city TEXT,
    pincode INTEGER,
    submitter_name TEXT,
    owner_verified_at TIMESTAMP WITH TIME ZONE, -- Approximated by property updated_at when status changed
    total_count BIGINT
) AS $$
BEGIN
    IF NOT (public.current_user_has_role('marketing-team') OR public.current_user_has_role('super-admin')) THEN
        RAISE EXCEPTION 'Unauthorized: Insufficient privileges.';
    END IF;

    RETURN QUERY
    WITH assignable_props AS (
        SELECT
            p.property_id, p.address, p.locality, p.city, p.pincode,
            u_submitter.raw_user_meta_data->>'full_name' AS s_name,
            p.updated_at AS status_changed_at -- Approximation of verification time
        FROM public.properties p
        JOIN auth.users u_submitter ON p.submitter = u_submitter.id
        LEFT JOIN public.property_marketing_assignments pma ON p.property_id = pma.property_id
        WHERE p.admin_status = 'OWNER_VERIFIED'
          AND pma.property_id IS NULL -- Not already assigned
          AND (p_city_filter IS NULL OR p.city ILIKE p_city_filter)
          AND (p_pincode_filter IS NULL OR p.pincode = p_pincode_filter)
    ),
    props_with_count AS (
        SELECT *, COUNT(*) OVER() AS total_rows FROM assignable_props
    )
    SELECT pwc.* FROM props_with_count pwc
    ORDER BY pwc.status_changed_at ASC
    OFFSET p_offset
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;
GRANT EXECUTE ON FUNCTION public.get_assignable_marketing_properties_admin(TEXT, INTEGER, INTEGER, INTEGER) TO authenticated;


-- Function for super-admin or an automated process to assign a property to marketing team
CREATE OR REPLACE FUNCTION public.assign_property_to_marketer_admin(
    p_property_id UUID,
    p_target_admin_id UUID -- Can be determined by round-robin/pincode logic externally or passed directly
) RETURNS VOID AS $$
BEGIN
    IF NOT public.current_user_has_role('super-admin') THEN -- Or a service role if automated
        RAISE EXCEPTION 'Unauthorized: Only super-admins or designated service can perform this assignment.';
    END IF;

    IF NOT public.user_is_admin_with_role(p_target_admin_id, 'marketing-team') THEN
        RAISE EXCEPTION 'Target user % is not an active member of marketing-team.', p_target_admin_id;
    END IF;

    UPDATE public.properties
    SET admin_status = 'MARKETING_VISIT_PENDING', updated_at = CURRENT_TIMESTAMP
    WHERE property_id = p_property_id AND admin_status = 'OWNER_VERIFIED';

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Property % not found or not in OWNER_VERIFIED state.', p_property_id;
    END IF;

    INSERT INTO public.property_marketing_assignments (property_id, assigned_admin_id)
    VALUES (p_property_id, p_target_admin_id)
    ON CONFLICT (property_id) DO UPDATE
    SET assigned_admin_id = EXCLUDED.assigned_admin_id, assigned_at = CURRENT_TIMESTAMP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.assign_property_to_marketer_admin(UUID, UUID) TO authenticated;

-- Function for an admin to unassign a property from marketing
CREATE OR REPLACE FUNCTION public.unassign_property_from_marketer_admin(p_property_id UUID)
RETURNS VOID AS $$
DECLARE
    v_calling_admin_id UUID := auth.uid();
    v_assigned_admin_id UUID;
BEGIN
    SELECT assigned_admin_id INTO v_assigned_admin_id
    FROM public.property_marketing_assignments WHERE property_id = p_property_id;

    IF NOT FOUND THEN
        RAISE WARNING 'Property % is not currently assigned for marketing.', p_property_id;
        RETURN;
    END IF;

    IF NOT (public.current_user_has_role('super-admin') OR v_assigned_admin_id = v_calling_admin_id) THEN
        RAISE EXCEPTION 'Unauthorized: Only super-admins or the assigned admin can unassign.';
    END IF;

    DELETE FROM public.property_marketing_assignments WHERE property_id = p_property_id;

    UPDATE public.properties
    SET admin_status = 'OWNER_VERIFIED', updated_at = CURRENT_TIMESTAMP
    WHERE property_id = p_property_id AND admin_status = 'MARKETING_VISIT_PENDING';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.unassign_property_from_marketer_admin(UUID) TO authenticated;


-- Function for marketing-team to mark property as marketing verified
CREATE OR REPLACE FUNCTION public.mark_property_marketing_verified_admin(
    p_property_id UUID,
    p_marketing_notes TEXT DEFAULT NULL -- Optional notes from the marketer
) RETURNS VOID AS $$
DECLARE
    v_admin_id UUID := auth.uid();
BEGIN
    IF NOT public.current_user_has_role('marketing-team') THEN
        RAISE EXCEPTION 'Unauthorized: Only marketing-team can mark marketing verified.';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM public.property_marketing_assignments WHERE property_id = p_property_id AND assigned_admin_id = v_admin_id) THEN
        RAISE EXCEPTION 'Property % is not assigned to you or does not exist in marketing assignments.', p_property_id;
    END IF;

    UPDATE public.properties
    SET admin_status = 'MARKETING_VERIFIED', -- Or 'AWAITING_LISTING' if that's the next step
        admin_notes = COALESCE(admin_notes || E'\n--- Marketing Verification (' || v_admin_id || ' @ ' || TO_CHAR(CURRENT_TIMESTAMP, 'YYYY-MM-DD HH24:MI') || ') ---\n' || p_marketing_notes, admin_notes),
        updated_at = CURRENT_TIMESTAMP
    WHERE property_id = p_property_id AND admin_status = 'MARKETING_VISIT_PENDING';

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Property % could not be updated. Ensure it is in MARKETING_VISIT_PENDING state and assigned to you.', p_property_id;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.mark_property_marketing_verified_admin(UUID, TEXT) TO authenticated;

-- Function for Super-Admin to set the public listing status of a property
CREATE OR REPLACE FUNCTION public.set_property_listing_status_admin(
    p_property_id UUID,
    p_make_listed BOOLEAN,
    p_new_admin_status public.property_admin_status_enum DEFAULT NULL
) RETURNS VOID AS $$
DECLARE
    v_current_admin_status public.property_admin_status_enum;
    v_current_is_listed BOOLEAN;
    v_auth_user_id UUID := auth.uid();
    v_can_perform_action BOOLEAN := FALSE;
BEGIN
    -- Authorization Check
    SELECT EXISTS (
        SELECT 1 FROM public.admins a
        WHERE a.user_id = v_auth_user_id
          AND a.is_active = TRUE
          AND (
            'super-admin' = ANY(a.roles) OR
            'telecalling-owner-team' = ANY(a.roles) OR
            'telecalling-tenant-team' = ANY(a.roles)
          )
    ) INTO v_can_perform_action;

    IF NOT v_can_perform_action THEN
        RAISE EXCEPTION 'Unauthorized: Insufficient privileges to change public listing status.';
    END IF;

    SELECT admin_status, is_listed INTO v_current_admin_status, v_current_is_listed FROM public.properties WHERE property_id = p_property_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'Property % not found.', p_property_id; END IF;

    -- Prevent redundant updates
    IF v_current_is_listed = p_make_listed AND (p_new_admin_status IS NULL OR p_new_admin_status = v_current_admin_status) THEN
        RAISE WARNING 'Property % already has the desired listing status and admin status. No changes made.', p_property_id;
        RETURN;
    END IF;

    -- Logic for appropriate admin_status based on listing action
    IF p_make_listed THEN
        IF v_current_admin_status NOT IN ('OWNER_VERIFIED', 'MARKETING_VERIFIED', 'AWAITING_LISTING', 'SUSPENDED', 'RENTED') THEN
             RAISE WARNING 'Property % (admin_status: %) is being listed. Ensure this is an intended transition.', p_property_id, v_current_admin_status;
        END IF;
        UPDATE public.properties
        SET is_listed = TRUE,
            admin_status = COALESCE(
                p_new_admin_status,
                CASE
                    WHEN v_current_admin_status IN ('OWNER_VERIFIED', 'MARKETING_VERIFIED', 'SUSPENDED') THEN 'AWAITING_LISTING'::public.property_admin_status_enum
                    ELSE admin_status
                END
            ),
            updated_at = CURRENT_TIMESTAMP
        WHERE property_id = p_property_id;
    ELSE -- Unlisting
        UPDATE public.properties
        SET is_listed = FALSE,
            admin_status = COALESCE(
                p_new_admin_status,
                CASE
                    WHEN v_current_admin_status NOT IN ('REJECTED', 'SOLD', 'RENTED') THEN 'SUSPENDED'::public.property_admin_status_enum
                    ELSE admin_status
                END
            ),
            updated_at = CURRENT_TIMESTAMP
        WHERE property_id = p_property_id;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.set_property_listing_status_admin(UUID, BOOLEAN, public.property_admin_status_enum) TO authenticated;

CREATE OR REPLACE FUNCTION public.auto_assign_marketing_tasks_cron_worker()
RETURNS JSONB AS $$
DECLARE
    unassigned_prop RECORD;
    
    chosen_admin_id UUID;
    chosen_assignment_group TEXT;
    
    last_assigned_for_group_admin_id UUID;
    
    admin_candidate_ids_array UUID[]; -- Stores UUIDs of admin candidates for a group
    
    selected_candidate_idx INTEGER;
    admin_loop_idx INTEGER;
    
    assigned_count INTEGER := 0;
    skipped_no_admin_count INTEGER := 0;
    processed_properties_count INTEGER := 0;
    
    current_loop_property_id UUID;
    
    max_properties_to_process_per_run INTEGER := 20;

BEGIN
    RAISE NOTICE '[MARKETING_ASSIGN_CRON] Starting auto-assignment at %', clock_timestamp();

    FOR unassigned_prop IN
        SELECT
            p.property_id,
            p.pincode
        FROM public.properties p
        WHERE p.admin_status = 'OWNER_VERIFIED'
          AND NOT EXISTS (
              SELECT 1 FROM public.property_marketing_assignments pma
              WHERE pma.property_id = p.property_id
          )
        ORDER BY p.updated_at ASC
        LIMIT max_properties_to_process_per_run
    LOOP
        processed_properties_count := processed_properties_count + 1;
        current_loop_property_id := unassigned_prop.property_id;
        chosen_admin_id := NULL;
        chosen_assignment_group := NULL;
        admin_candidate_ids_array := ARRAY[]::UUID[];

        -- 1. Attempt pincode-specific assignment
        IF unassigned_prop.pincode IS NOT NULL THEN
            chosen_assignment_group := 'MARKETING_PINCODE_' || unassigned_prop.pincode::TEXT;

            -- Get admins serving this specific pincode, ordered for consistent round-robin
            SELECT array_agg(adm.user_id ORDER BY adm.user_id)
            INTO admin_candidate_ids_array
            FROM public.admins adm
            WHERE adm.is_active = TRUE
              AND 'marketing-team' = ANY(adm.roles)
              AND adm.served_pincodes @> ARRAY[unassigned_prop.pincode];

            IF array_length(admin_candidate_ids_array, 1) > 0 THEN
                -- Get last assigned for this pincode group
                SELECT rrs.last_assigned_admin_id INTO last_assigned_for_group_admin_id
                FROM public.round_robin_state rrs
                WHERE rrs.assignment_group = chosen_assignment_group;

                selected_candidate_idx := NULL;
                IF last_assigned_for_group_admin_id IS NOT NULL THEN
                    FOR admin_loop_idx IN 1..array_length(admin_candidate_ids_array, 1) LOOP
                        IF admin_candidate_ids_array[admin_loop_idx] = last_assigned_for_group_admin_id THEN
                            selected_candidate_idx := admin_loop_idx % array_length(admin_candidate_ids_array, 1) + 1;
                            EXIT;
                        END IF;
                    END LOOP;
                END IF;
                
                IF selected_candidate_idx IS NULL THEN -- No last assignment or last assigned not in current list
                    chosen_admin_id := admin_candidate_ids_array[1];
                ELSE
                    chosen_admin_id := admin_candidate_ids_array[selected_candidate_idx];
                END IF;
            END IF;
        END IF;

        -- 2. Fallback to global round-robin if no pincode match or property has no pincode
        IF chosen_admin_id IS NULL THEN
            chosen_assignment_group := 'MARKETING_GLOBAL';
            
            -- Get all active marketing admins, ordered for consistent round-robin
            SELECT array_agg(adm.user_id ORDER BY adm.user_id)
            INTO admin_candidate_ids_array
            FROM public.admins adm
            WHERE adm.is_active = TRUE
              AND 'marketing-team' = ANY(adm.roles);

            IF array_length(admin_candidate_ids_array, 1) IS NULL OR array_length(admin_candidate_ids_array, 1) = 0 THEN
                RAISE WARNING '[MARKETING_ASSIGN_CRON] No active marketing admins found for global assignment. Skipping property %.', unassigned_prop.property_id;
                skipped_no_admin_count := skipped_no_admin_count + 1;
                CONTINUE; -- Skip to next property
            END IF;

            -- Get last assigned for global marketing group
            SELECT rrs.last_assigned_admin_id INTO last_assigned_for_group_admin_id
            FROM public.round_robin_state rrs
            WHERE rrs.assignment_group = chosen_assignment_group;

            selected_candidate_idx := NULL;
            IF last_assigned_for_group_admin_id IS NOT NULL THEN
                 FOR admin_loop_idx IN 1..array_length(admin_candidate_ids_array, 1) LOOP
                    IF admin_candidate_ids_array[admin_loop_idx] = last_assigned_for_group_admin_id THEN
                        selected_candidate_idx := admin_loop_idx % array_length(admin_candidate_ids_array, 1) + 1;
                        EXIT;
                    END IF;
                END LOOP;
            END IF;

            IF selected_candidate_idx IS NULL THEN
                chosen_admin_id := admin_candidate_ids_array[1];
            ELSE
                chosen_admin_id := admin_candidate_ids_array[selected_candidate_idx];
            END IF;
        END IF;

        -- 3. Perform assignment if an admin was chosen
        IF chosen_admin_id IS NOT NULL AND chosen_assignment_group IS NOT NULL THEN
            BEGIN
                INSERT INTO public.property_marketing_assignments (property_id, assigned_admin_id, assigned_at)
                VALUES (unassigned_prop.property_id, chosen_admin_id, CURRENT_TIMESTAMP);

                UPDATE public.properties
                SET admin_status = 'MARKETING_VISIT_PENDING',
                    updated_at = CURRENT_TIMESTAMP
                WHERE property_id = unassigned_prop.property_id;

                INSERT INTO public.round_robin_state (assignment_group, last_assigned_admin_id, last_assigned_at)
                VALUES (chosen_assignment_group, chosen_admin_id, CURRENT_TIMESTAMP)
                ON CONFLICT (assignment_group) DO UPDATE
                SET last_assigned_admin_id = EXCLUDED.last_assigned_admin_id,
                    last_assigned_at = EXCLUDED.last_assigned_at,
                    updated_at = CURRENT_TIMESTAMP;
                
                assigned_count := assigned_count + 1;
                RAISE NOTICE '[MARKETING_ASSIGN_CRON] Assigned property % to admin % via group %', unassigned_prop.property_id, chosen_admin_id, chosen_assignment_group;

            EXCEPTION WHEN unique_violation THEN
                RAISE WARNING '[MARKETING_ASSIGN_CRON] Property % was likely assigned concurrently. Skipping.', unassigned_prop.property_id;
            WHEN OTHERS THEN
                RAISE WARNING '[MARKETING_ASSIGN_CRON] Error assigning property %: %', unassigned_prop.property_id, SQLERRM;
            END;
        ELSE
            skipped_no_admin_count := skipped_no_admin_count + 1;
            RAISE WARNING '[MARKETING_ASSIGN_CRON] No suitable admin ultimately chosen for property % (Pincode: %)', unassigned_prop.property_id, unassigned_prop.pincode;
        END IF;
        
    END LOOP;

    RAISE NOTICE '[MARKETING_ASSIGN_CRON] Finished. Processed: %, Assigned: %, Skipped (no admin): %', processed_properties_count, assigned_count, skipped_no_admin_count;

    RETURN jsonb_build_object(
        'status', 'Completed',
        'processed_properties_attempted', processed_properties_count,
        'assigned_count', assigned_count,
        'skipped_no_admin_count', skipped_no_admin_count
    );

END;
$$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.auto_assign_marketing_tasks_cron_worker() TO postgres;


-- Description: Functions to manage team-specific assignments and workflows (Tenant Telecalling, Sales).
-------------------------------------------------------------------------------

-- ==== Telecalling-Tenant-Team Workflow Functions ====

-- Function for telecalling-tenant-team or super-admin to list interactions assignable for tenant contact
CREATE OR REPLACE FUNCTION public.get_assignable_tenant_contact_interactions_admin(
    p_property_id_filter UUID DEFAULT NULL,
    p_customer_search_term TEXT DEFAULT NULL,
    p_offset INTEGER DEFAULT 0,
    p_limit INTEGER DEFAULT 10
) RETURNS TABLE (
    interaction_id UUID,
    property_id UUID,
    property_address TEXT,
    property_locality TEXT,
    customer_user_id UUID,
    customer_name TEXT,
    customer_phone TEXT,
    customer_email TEXT,
    requested_visit_time DATE,
    interaction_created_at TIMESTAMP WITH TIME ZONE,
    total_count BIGINT
) AS $$
BEGIN
    IF NOT (public.current_user_has_role('telecalling-tenant-team') OR public.current_user_has_role('super-admin')) THEN
        RAISE EXCEPTION 'Unauthorized: Insufficient privileges.';
    END IF;

    RETURN QUERY
    WITH assignable_interactions AS (
        SELECT
            ci.interaction_id, ci.property_id,
            p.address AS prop_addr, p.locality AS prop_loc,
            ci.user_id AS cust_id,
            u_cust.raw_user_meta_data->>'full_name' AS cust_name_val,
            u_cust.phone AS cust_phone_val,
            u_cust.email AS cust_email_val,
            ci.scheduled_for AS requested_time,
            ci.created_at AS int_created_at
        FROM public.customers_interaction ci
        JOIN public.properties p ON ci.property_id = p.property_id
        JOIN auth.users u_cust ON ci.user_id = u_cust.id
        WHERE ci.status = 'VISIT_PENDING'
          AND ci.assigned_tenant_telecaller_id IS NULL
          AND (p_property_id_filter IS NULL OR ci.property_id = p_property_id_filter)
          AND (p_customer_search_term IS NULL OR (
                u_cust.raw_user_meta_data->>'full_name' ILIKE '%' || p_customer_search_term || '%' OR
                u_cust.email ILIKE '%' || p_customer_search_term || '%' OR
                u_cust.phone ILIKE '%' || p_customer_search_term || '%'
              ))
    ),
    interactions_with_count AS (
        SELECT *, COUNT(*) OVER() AS total_rows FROM assignable_interactions
    )
    SELECT iwc.* FROM interactions_with_count iwc
    ORDER BY iwc.int_created_at ASC
    OFFSET p_offset
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;
GRANT EXECUTE ON FUNCTION public.get_assignable_tenant_contact_interactions_admin(UUID, TEXT, INTEGER, INTEGER) TO authenticated;

-- Function for a telecalling-tenant-team member to self-assign an interaction
CREATE OR REPLACE FUNCTION public.self_assign_interaction_for_tenant_contact_admin(
    p_interaction_id UUID
) RETURNS VOID AS $$
DECLARE
    v_admin_id UUID := auth.uid();
BEGIN
    IF NOT (public.current_user_has_role('telecalling-tenant-team') OR public.current_user_has_role('super-admin')) THEN
        RAISE EXCEPTION 'Unauthorized: Only telecalling-tenant-team members can self-assign interactions.';
    END IF;

    UPDATE public.customers_interaction
    SET assigned_tenant_telecaller_id = v_admin_id,
        telecaller_assigned_at = CURRENT_TIMESTAMP,
        updated_at = CURRENT_TIMESTAMP
        -- Status remains 'VISIT_PENDING' until telecaller verifies and moves it.
    WHERE interaction_id = p_interaction_id
      AND status = 'VISIT_PENDING'
      AND assigned_tenant_telecaller_id IS NULL;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Interaction % not found, not in VISIT_PENDING state, or already assigned.', p_interaction_id;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.self_assign_interaction_for_tenant_contact_admin(UUID) TO authenticated;

-- Function for super-admin to assign an interaction to a specific telecalling-tenant-team member
CREATE OR REPLACE FUNCTION public.assign_interaction_to_tenant_telecaller_admin(
    p_interaction_id UUID,
    p_target_admin_id UUID
) RETURNS VOID AS $$
BEGIN
    IF NOT public.current_user_has_role('super-admin') THEN
        RAISE EXCEPTION 'Unauthorized: Only super-admins can perform this assignment.';
    END IF;

    IF NOT public.user_is_admin_with_role(p_target_admin_id, 'telecalling-tenant-team') THEN
        RAISE EXCEPTION 'Target user % is not an active member of telecalling-tenant-team.', p_target_admin_id;
    END IF;

    UPDATE public.customers_interaction
    SET assigned_tenant_telecaller_id = p_target_admin_id,
        telecaller_assigned_at = CURRENT_TIMESTAMP,
        updated_at = CURRENT_TIMESTAMP
        -- Status could be VISIT_PENDING or already assigned to someone else.
    WHERE interaction_id = p_interaction_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Interaction % not found.', p_interaction_id;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.assign_interaction_to_tenant_telecaller_admin(UUID, UUID) TO authenticated;

-- Function for an admin to unassign an interaction from tenant telecalling
CREATE OR REPLACE FUNCTION public.unassign_interaction_from_tenant_telecaller_admin(p_interaction_id UUID)
RETURNS VOID AS $$
DECLARE
    v_calling_admin_id UUID := auth.uid();
    v_current_assignment public.customers_interaction%ROWTYPE;
BEGIN
    SELECT * INTO v_current_assignment FROM public.customers_interaction WHERE interaction_id = p_interaction_id;

    IF NOT FOUND THEN
        RAISE WARNING 'Interaction % not found.', p_interaction_id;
        RETURN;
    END IF;

    IF v_current_assignment.assigned_tenant_telecaller_id IS NULL THEN
        RAISE WARNING 'Interaction % is not currently assigned to a tenant telecaller.', p_interaction_id;
        RETURN;
    END IF;

    IF NOT (public.current_user_has_role('super-admin') OR v_current_assignment.assigned_tenant_telecaller_id = v_calling_admin_id) THEN
        RAISE EXCEPTION 'Unauthorized: Only super-admins or the assigned admin can unassign.';
    END IF;

    UPDATE public.customers_interaction
    SET assigned_tenant_telecaller_id = NULL,
        telecaller_assigned_at = NULL,
        updated_at = CURRENT_TIMESTAMP
        -- Status remains 'VISIT_PENDING' typically
    WHERE interaction_id = p_interaction_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.unassign_interaction_from_tenant_telecaller_admin(UUID) TO authenticated;

-- Function for telecalling-tenant-team to mark interaction as tenant verified and ready for sales assignment
CREATE OR REPLACE FUNCTION public.mark_interaction_tenant_verified_admin(
    p_interaction_id UUID,
    p_verification_notes TEXT DEFAULT NULL,
    p_updated_scheduled_for DATE DEFAULT NULL
) RETURNS VOID AS $$
DECLARE
    v_admin_id UUID := auth.uid();
BEGIN
    IF NOT (public.current_user_has_role('telecalling-tenant-team') OR public.current_user_has_role('super-admin')) THEN
        RAISE EXCEPTION 'Unauthorized: Only telecalling-tenant-team can mark tenant verified.';
    END IF;

    UPDATE public.customers_interaction
    SET status = 'VISIT_CONFIRMED_PENDING_SALES',
        admin_notes = COALESCE(admin_notes || E'\n--- Tenant Verification (' || v_admin_id || ' @ ' || TO_CHAR(CURRENT_TIMESTAMP, 'YYYY-MM-DD HH24:MI') || ') ---\n' || p_verification_notes, admin_notes),
        scheduled_for = COALESCE(p_updated_scheduled_for, scheduled_for), -- Will now be DATE
        updated_at = CURRENT_TIMESTAMP
    WHERE interaction_id = p_interaction_id
      AND status = 'VISIT_PENDING'
      AND assigned_tenant_telecaller_id = v_admin_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Interaction % could not be updated. Ensure it is in VISIT_PENDING state and assigned to you.', p_interaction_id;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.mark_interaction_tenant_verified_admin(UUID, TEXT, DATE) TO authenticated; 


-- ==== Sales-Team Workflow Functions ====

-- Function (could be called by cron) to assign pending sales visits
CREATE OR REPLACE FUNCTION public.assign_pending_sales_visits_admin()
RETURNS JSONB AS $$
DECLARE
    interaction_group RECORD;
    sales_admin_candidate RECORD;
    v_assignment_summary JSONB := '[]'::jsonb;
    v_visit_assignment_id UUID;
    v_interactions_for_assignment UUID[];
    v_property_pincodes INTEGER[];
    v_assigned_count INTEGER := 0;
    v_unassigned_groups INTEGER := 0;
    v_relevant_sales_admins UUID[];
    uuid_val UUID;
BEGIN
    RAISE NOTICE 'Starting sales visit assignment process at %', clock_timestamp();

    FOR interaction_group IN
        SELECT
            ci.user_id,
            ci.scheduled_for AS visit_date,
            array_agg(ci.interaction_id) AS interaction_ids,
            array_agg(DISTINCT p.pincode) FILTER (WHERE p.pincode IS NOT NULL) AS distinct_pincodes
        FROM public.customers_interaction ci
        JOIN public.properties p ON ci.property_id = p.property_id
        WHERE ci.status = 'VISIT_CONFIRMED_PENDING_SALES'
        GROUP BY ci.user_id, ci.scheduled_for
        HAVING COUNT(ci.interaction_id) > 0
    LOOP
        v_interactions_for_assignment := interaction_group.interaction_ids;
        v_property_pincodes := interaction_group.distinct_pincodes;
        sales_admin_candidate := NULL;

        SELECT adm.user_id INTO sales_admin_candidate
        FROM public.admins adm
        WHERE 'sales-team' = ANY(adm.roles) AND adm.is_active = TRUE
          AND (cardinality(COALESCE(v_property_pincodes, '{}')) = 0 OR adm.served_pincodes && v_property_pincodes)
        ORDER BY random()
        LIMIT 1;

        IF sales_admin_candidate IS NULL THEN
            SELECT adm.user_id INTO sales_admin_candidate
            FROM public.admins adm
            WHERE 'sales-team' = ANY(adm.roles) AND adm.is_active = TRUE
            ORDER BY random()
            LIMIT 1;
        END IF;

        IF sales_admin_candidate IS NOT NULL THEN
            INSERT INTO public.property_visit_assignments (user_id, visit_date, assigned_sales_admin_id)
            VALUES (interaction_group.user_id, interaction_group.visit_date, sales_admin_candidate.user_id)
            ON CONFLICT (user_id, visit_date) DO UPDATE
            SET assigned_sales_admin_id = EXCLUDED.assigned_sales_admin_id, updated_at = CURRENT_TIMESTAMP
            RETURNING visit_assignment_id INTO v_visit_assignment_id;

            FOREACH uuid_val IN ARRAY v_interactions_for_assignment
            LOOP
                INSERT INTO public.property_visit_assignment_interactions (visit_assignment_id, interaction_id)
                VALUES (v_visit_assignment_id, uuid_val)
                ON CONFLICT DO NOTHING;

                UPDATE public.customers_interaction
                SET status = 'VISIT_SCHEDULED_WITH_SALES',
                    assigned_sales_admin_id = sales_admin_candidate.user_id,
                    updated_at = CURRENT_TIMESTAMP
                WHERE interaction_id = uuid_val AND status = 'VISIT_CONFIRMED_PENDING_SALES';
            END LOOP;

            v_assignment_summary := v_assignment_summary || jsonb_build_object(
                'customer_id', interaction_group.user_id,
                'visit_date', interaction_group.visit_date,
                'assigned_sales_admin_id', sales_admin_candidate.user_id,
                'interaction_count', array_length(v_interactions_for_assignment, 1)
            );
            v_assigned_count := v_assigned_count + 1;
            RAISE NOTICE 'Assigned visits for customer %, date % to sales admin %', interaction_group.user_id, interaction_group.visit_date, sales_admin_candidate.user_id;
        ELSE
            v_unassigned_groups := v_unassigned_groups + 1;
            RAISE WARNING 'No suitable sales admin found for customer %, visit_date %.', interaction_group.user_id, interaction_group.visit_date;
        END IF;
    END LOOP;

    RAISE NOTICE 'Sales visit assignment process finished. Assigned groups: %, Unassigned groups: %', v_assigned_count, v_unassigned_groups;
    RETURN jsonb_build_object('assigned_groups_summary', v_assignment_summary, 'total_assigned_groups', v_assigned_count, 'total_unassigned_groups', v_unassigned_groups);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.assign_pending_sales_visits_admin() TO authenticated;

-- Function for a sales-team admin to view their assigned visits for a given date
CREATE OR REPLACE FUNCTION public.get_my_sales_visits_admin(
    p_visit_date DATE DEFAULT CURRENT_DATE
) RETURNS TABLE (
    visit_assignment_id UUID,
    customer_user_id UUID,
    customer_name TEXT,
    customer_phone TEXT,
    customer_email TEXT,
    property_visits JSONB
) AS $$
DECLARE
    v_sales_admin_id UUID := auth.uid();
BEGIN
    IF NOT (public.current_user_has_role('sales-team') OR public.current_user_has_role('super-admin')) THEN
        RAISE EXCEPTION 'Unauthorized: Only sales-team members can view their visits.';
    END IF;

    RETURN QUERY
    SELECT
        pva.visit_assignment_id,
        pva.user_id AS cust_id,
        (cust_user.raw_user_meta_data->>'full_name')::TEXT AS cust_name_val,
        cust_user.phone::TEXT AS cust_phone_val,
        cust_user.email::TEXT AS cust_email_val,
        (SELECT COALESCE(jsonb_agg(jsonb_build_object(
            'interaction_id', ci.interaction_id,
            'property_id', p.property_id,
            'address', p.address,
            'locality', p.locality,
            'pincode', p.pincode,
            'property_type', p.property_type,
            'latitude', p.latitude,
            'longitude', p.longitude,
            'interaction_status', ci.status,
            'scheduled_for_time', ci.scheduled_for,
            'owner_name', (owner_user.raw_user_meta_data->>'full_name')::TEXT,
            'owner_phone', owner_user.phone::TEXT
         ) ORDER BY ci.scheduled_for ASC), '[]'::jsonb)
         FROM public.property_visit_assignment_interactions pvai
         JOIN public.customers_interaction ci ON pvai.interaction_id = ci.interaction_id
         JOIN public.properties p ON ci.property_id = p.property_id
         LEFT JOIN auth.users owner_user ON p.submitter = owner_user.id
         WHERE pvai.visit_assignment_id = pva.visit_assignment_id
           AND ci.status IN ('VISIT_SCHEDULED_WITH_SALES', 'VISIT_COMPLETED')
        ) AS property_visits_data
    FROM public.property_visit_assignments pva
    JOIN auth.users cust_user ON pva.user_id = cust_user.id
    WHERE pva.assigned_sales_admin_id = v_sales_admin_id
      AND pva.visit_date = p_visit_date;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;
GRANT EXECUTE ON FUNCTION public.get_my_sales_visits_admin(DATE) TO authenticated;

-- Function for sales-team admin to mark an interaction (visit) as completed
CREATE OR REPLACE FUNCTION public.mark_interaction_visit_completed_sales_admin(
    p_interaction_id UUID,
    p_feedback TEXT DEFAULT NULL -- Feedback is optional
) RETURNS VOID AS $$
DECLARE
    v_sales_admin_id UUID := auth.uid();
    v_new_admin_notes TEXT;
BEGIN
    IF NOT public.current_user_has_role('sales-team') THEN
        RAISE EXCEPTION 'Unauthorized: Only sales-team members can mark visits completed.';
    END IF;

    -- Construct the admin_notes update logic carefully
    IF p_feedback IS NOT NULL AND TRIM(p_feedback) <> '' THEN
        -- If new feedback is provided, append it
        SELECT
            COALESCE(ci.admin_notes, '') ||
            (CASE WHEN ci.admin_notes IS NOT NULL AND ci.admin_notes <> '' THEN E'\n\n' ELSE '' END) ||
            E'--- Visit Feedback (' || v_sales_admin_id || ' @ ' || TO_CHAR(CURRENT_TIMESTAMP, 'YYYY-MM-DD HH24:MI') || ') ---\n' ||
            p_feedback
        INTO v_new_admin_notes
        FROM public.customers_interaction ci
        WHERE ci.interaction_id = p_interaction_id;
    ELSE
        SELECT ci.admin_notes
        INTO v_new_admin_notes
        FROM public.customers_interaction ci
        WHERE ci.interaction_id = p_interaction_id;
    END IF;

    UPDATE public.customers_interaction
    SET status = 'VISIT_COMPLETED',
        visited_at = CURRENT_TIMESTAMP,
        admin_notes = v_new_admin_notes,
        updated_at = CURRENT_TIMESTAMP
    WHERE interaction_id = p_interaction_id
      AND status = 'VISIT_SCHEDULED_WITH_SALES'
      AND assigned_sales_admin_id = v_sales_admin_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Interaction % could not be marked completed. Ensure it is scheduled with you and not already completed/cancelled, or interaction ID not found.', p_interaction_id;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION public.mark_interaction_visit_completed_sales_admin(UUID, TEXT) IS 
'Allows a sales-team admin to mark a customer interaction (visit) as completed. Updates status to VISIT_COMPLETED, sets visited_at, and appends optional feedback to admin_notes. Only works for interactions assigned to the calling sales admin and in VISIT_SCHEDULED_WITH_SALES status.';
GRANT EXECUTE ON FUNCTION public.mark_interaction_visit_completed_sales_admin(UUID, TEXT) TO authenticated;

-- Function for sales-team admin to mark an interaction (visit) as cancelled
CREATE OR REPLACE FUNCTION public.mark_interaction_visit_cancelled_sales_admin(
    p_interaction_id UUID,
    p_cancellation_reason TEXT -- Cancellation reason is mandatory
) RETURNS VOID AS $$
DECLARE
    v_sales_admin_id UUID := auth.uid();
    v_new_admin_notes TEXT;
    v_existing_admin_notes TEXT;
BEGIN
    IF NOT public.current_user_has_role('sales-team') THEN
        RAISE EXCEPTION 'Unauthorized: Only sales-team members can mark visits cancelled.';
    END IF;

    IF p_cancellation_reason IS NULL OR TRIM(p_cancellation_reason) = '' THEN
        RAISE EXCEPTION 'Cancellation reason is required and cannot be empty.';
    END IF;

    -- Fetch existing admin_notes first
    SELECT ci.admin_notes
    INTO v_existing_admin_notes
    FROM public.customers_interaction ci
    WHERE ci.interaction_id = p_interaction_id;

    -- If the interaction doesn't exist (unlikely if it passes the UPDATE's WHERE clause later, but good for safety)
    -- or if we just want to ensure the variable is initialized.
    IF NOT FOUND THEN
        -- This case should ideally be caught by the UPDATE statement's WHERE clause later if the ID is wrong.
        -- For constructing notes, if interaction_id was valid but admin_notes was NULL, v_existing_admin_notes would be NULL.
        v_existing_admin_notes := NULL; 
    END IF;

    -- Construct the new admin_notes string
    v_new_admin_notes :=
        COALESCE(v_existing_admin_notes, '') ||
        (CASE WHEN v_existing_admin_notes IS NOT NULL AND v_existing_admin_notes <> '' THEN E'\n\n' ELSE '' END) || -- Add separator
        E'--- Visit Cancellation (' || v_sales_admin_id || ' @ ' || TO_CHAR(CURRENT_TIMESTAMP, 'YYYY-MM-DD HH24:MI') || ') ---\nReason: ' ||
        TRIM(p_cancellation_reason); -- Ensure reason is trimmed

    UPDATE public.customers_interaction
    SET status = 'VISIT_CANCELLED',
        admin_notes = v_new_admin_notes, -- Use the constructed notes
        visited_at = NULL, -- Ensure visited_at is cleared if it was somehow set
        updated_at = CURRENT_TIMESTAMP
    WHERE interaction_id = p_interaction_id
      AND status = 'VISIT_SCHEDULED_WITH_SALES' -- Can only cancel if scheduled
      AND assigned_sales_admin_id = v_sales_admin_id; -- Must be assigned to this sales admin

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Interaction % could not be marked cancelled. Ensure it is scheduled with you and not already completed/cancelled, or interaction ID not found.', p_interaction_id;
    END IF;

    -- Consider if visit balance should be refunded upon cancellation.
    -- This depends on when it was debited and the cancellation policy.
    -- Example: IF a visit was debited, you might add:
    -- UPDATE public.customers SET visit_balance = visit_balance + 1 WHERE user_id = (SELECT user_id FROM public.customers_interaction WHERE interaction_id = p_interaction_id);
    -- This logic is business-specific and not included by default.
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION public.mark_interaction_visit_cancelled_sales_admin(UUID, TEXT) IS 
'Allows a sales-team admin to mark a customer interaction (visit) as cancelled. Updates status to VISIT_CANCELLED, appends the cancellation reason to admin_notes. Only works for interactions assigned to the calling sales admin and in VISIT_SCHEDULED_WITH_SALES status. Cancellation reason is mandatory.';
GRANT EXECUTE ON FUNCTION public.mark_interaction_visit_cancelled_sales_admin(UUID, TEXT) TO authenticated;


-- Description: Functions for admins (primarily Accounts Team, Super Admin) to manage rent records and payments.
-------------------------------------------------------------------------------

-- Function for admins to create a new rent record for a property
CREATE OR REPLACE FUNCTION public.create_rent_record_admin(
    p_property_id UUID,
    p_due_date DATE,
    p_period_start_date DATE,
    p_period_end_date DATE,
    p_amount_due DECIMAL,
    p_notes TEXT DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
    v_rent_record_id UUID;
    v_property_info RECORD;
BEGIN
    IF NOT (public.current_user_has_role('accounts-team') OR public.current_user_has_role('super-admin')) THEN
        RAISE EXCEPTION 'Unauthorized: Insufficient privileges to create rent records.';
    END IF;

    SELECT tenant, submitter, listing_type, price
    INTO v_property_info
    FROM public.properties WHERE property_id = p_property_id;

    IF NOT FOUND THEN RAISE EXCEPTION 'Property ID % not found.', p_property_id; END IF;
    IF v_property_info.listing_type <> 'RENTAL' THEN RAISE EXCEPTION 'Property % is not a rental property.', p_property_id; END IF;
    IF v_property_info.tenant IS NULL THEN RAISE EXCEPTION 'Property % is not currently occupied by a tenant.', p_property_id; END IF;
    IF v_property_info.submitter IS NULL THEN RAISE EXCEPTION 'Property % does not have a valid owner (submitter/landlord).', p_property_id; END IF;

    IF p_amount_due <= 0 THEN RAISE EXCEPTION 'Amount due must be positive.'; END IF;
    IF p_period_end_date < p_period_start_date THEN RAISE EXCEPTION 'Period end date cannot be before start date.'; END IF;
    IF p_due_date < p_period_start_date THEN RAISE EXCEPTION 'Due date cannot be before period start date.'; END IF;

    INSERT INTO public.rent_records (
        property_id, tenant_user_id, landlord_user_id, due_date,
        period_start_date, period_end_date, amount_due, status, notes
    ) VALUES (
        p_property_id, v_property_info.tenant, v_property_info.submitter, p_due_date,
        p_period_start_date, p_period_end_date, p_amount_due, 'DUE', p_notes
    ) RETURNING rent_record_id INTO v_rent_record_id;

    RETURN v_rent_record_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.create_rent_record_admin(UUID, DATE, DATE, DATE, DECIMAL, TEXT) TO authenticated;

-- Function for admins to update an existing rent record
CREATE OR REPLACE FUNCTION public.update_rent_record_admin(
    p_rent_record_id UUID,
    p_due_date DATE DEFAULT NULL,
    p_period_start_date DATE DEFAULT NULL,
    p_period_end_date DATE DEFAULT NULL,
    p_amount_due DECIMAL DEFAULT NULL,
    p_amount_paid DECIMAL DEFAULT NULL, -- Admins can directly set amount_paid too
    p_status rent_status_enum DEFAULT NULL,
    p_notes TEXT DEFAULT NULL
) RETURNS VOID AS $$
DECLARE
    v_current_record public.rent_records%ROWTYPE;
    v_final_status rent_status_enum;
    v_final_amount_paid DECIMAL;
    v_final_amount_due DECIMAL;
BEGIN
    IF NOT (public.current_user_has_role('accounts-team') OR public.current_user_has_role('super-admin')) THEN
        RAISE EXCEPTION 'Unauthorized: Insufficient privileges to update rent records.';
    END IF;

    SELECT * INTO v_current_record FROM public.rent_records WHERE rent_record_id = p_rent_record_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'Rent Record ID % not found.', p_rent_record_id; END IF;

    v_final_amount_paid := COALESCE(p_amount_paid, v_current_record.amount_paid);
    v_final_amount_due := COALESCE(p_amount_due, v_current_record.amount_due);

    IF p_status IS NULL THEN -- Auto-calculate status based on payments if not explicitly provided
        IF v_current_record.status = 'CANCELLED' THEN
             v_final_status = 'CANCELLED'; -- Cannot change status from CANCELLED implicitly
        ELSIF v_final_amount_paid >= v_final_amount_due THEN
            v_final_status = 'PAID';
        ELSIF v_final_amount_paid > 0 THEN
            v_final_status = 'PARTIALLY_PAID';
        ELSIF COALESCE(p_due_date, v_current_record.due_date) < CURRENT_DATE THEN
            v_final_status = 'OVERDUE';
        ELSE
            v_final_status = 'DUE';
        END IF;
    ELSE
        v_final_status = p_status;
    END IF;

    UPDATE public.rent_records
    SET due_date = COALESCE(p_due_date, due_date),
        period_start_date = COALESCE(p_period_start_date, period_start_date),
        period_end_date = COALESCE(p_period_end_date, period_end_date),
        amount_due = v_final_amount_due,
        amount_paid = v_final_amount_paid,
        status = v_final_status,
        notes = COALESCE(p_notes, notes),
        updated_at = CURRENT_TIMESTAMP
    WHERE rent_record_id = p_rent_record_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.update_rent_record_admin(UUID, DATE, DATE, DATE, DECIMAL, DECIMAL, rent_status_enum, TEXT) TO authenticated;

-- Function for admins to list rent records with filters
CREATE OR REPLACE FUNCTION public.list_rent_records_admin(
    p_property_id_filter UUID DEFAULT NULL,
    p_tenant_user_id_filter UUID DEFAULT NULL,
    p_landlord_user_id_filter UUID DEFAULT NULL,
    p_status_filter public.rent_status_enum DEFAULT NULL,
    p_due_date_start DATE DEFAULT NULL,
    p_due_date_end DATE DEFAULT NULL,
    p_offset INTEGER DEFAULT 0,
    p_limit INTEGER DEFAULT 25
) RETURNS TABLE (
    rent_record_id UUID,
    property_id UUID,
    property_address TEXT,
    property_locality TEXT,
    tenant_user_id UUID,
    tenant_name TEXT,
    tenant_email TEXT,
    tenant_phone TEXT,
    landlord_user_id UUID,
    landlord_name TEXT,
    landlord_email TEXT,
    landlord_phone TEXT,
    due_date DATE,
    period_start_date DATE,
    period_end_date DATE,
    amount_due DECIMAL,
    amount_paid DECIMAL,
    status public.rent_status_enum,
    notes TEXT,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ,
    total_count BIGINT
) AS $$
BEGIN
    IF NOT (public.current_user_has_role('accounts-team') OR public.current_user_has_role('super-admin')) THEN
        RAISE EXCEPTION 'Unauthorized: Insufficient privileges.';
    END IF;

    RETURN QUERY
    WITH rent_records_base AS (
        SELECT
            rr.rent_record_id,
            rr.property_id,
            p.address AS prop_addr,
            p.locality AS prop_loc,
            rr.tenant_user_id AS ten_id,
            tenant_user.raw_user_meta_data->>'full_name' AS ten_name,
            tenant_user.email::TEXT AS ten_email_val,
            tenant_user.phone::TEXT AS ten_phone,
            rr.landlord_user_id AS land_id,
            landlord_user.raw_user_meta_data->>'full_name' AS land_name,
            landlord_user.email::TEXT AS land_email_val,
            landlord_user.phone::TEXT AS land_phone,
            rr.due_date, rr.period_start_date, rr.period_end_date, rr.amount_due, rr.amount_paid, rr.status, rr.notes,
            rr.created_at, rr.updated_at
        FROM public.rent_records rr
        JOIN public.properties p ON rr.property_id = p.property_id
        JOIN auth.users tenant_user ON rr.tenant_user_id = tenant_user.id
        JOIN auth.users landlord_user ON rr.landlord_user_id = landlord_user.id
        WHERE (p_property_id_filter IS NULL OR rr.property_id = p_property_id_filter)
          AND (p_tenant_user_id_filter IS NULL OR rr.tenant_user_id = p_tenant_user_id_filter)
          AND (p_landlord_user_id_filter IS NULL OR rr.landlord_user_id = p_landlord_user_id_filter)
          AND (p_status_filter IS NULL OR rr.status = p_status_filter)
          AND (p_due_date_start IS NULL OR rr.due_date >= p_due_date_start)
          AND (p_due_date_end IS NULL OR rr.due_date <= p_due_date_end)
    ),
    records_with_count AS (
        SELECT *, COUNT(*) OVER() AS total_rows FROM rent_records_base
    )
    SELECT
           rwc.rent_record_id,
           rwc.property_id,
           rwc.prop_addr,
           rwc.prop_loc,
           rwc.ten_id,
           rwc.ten_name,
           rwc.ten_email_val,
           rwc.ten_phone,
           rwc.land_id,
           rwc.land_name,
           rwc.land_email_val,
           rwc.land_phone,
           rwc.due_date, rwc.period_start_date, rwc.period_end_date, rwc.amount_due, rwc.amount_paid,
           rwc.status, rwc.notes, rwc.created_at, rwc.updated_at, rwc.total_rows
    FROM records_with_count rwc
    ORDER BY rwc.due_date DESC, rwc.created_at DESC
    OFFSET p_offset
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;
GRANT EXECUTE ON FUNCTION public.list_rent_records_admin(UUID, UUID, UUID, public.rent_status_enum, DATE, DATE, INTEGER, INTEGER) TO authenticated;

-- Function for admins to get details of a specific rent record, including payments
CREATE OR REPLACE FUNCTION public.get_rent_record_details_admin(p_rent_record_id_input UUID)
RETURNS TABLE (
    rent_record_id UUID,
    property_id UUID,
    property_address TEXT,
    tenant_user_id UUID,
    tenant_name TEXT,
    tenant_phone TEXT,
    landlord_user_id UUID,
    landlord_name TEXT,
    landlord_phone TEXT,
    due_date DATE,
    period_start_date DATE,
    period_end_date DATE,
    amount_due DECIMAL,
    amount_paid DECIMAL,
    status public.rent_status_enum,
    notes TEXT,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ,
    payments JSONB
) AS $$
BEGIN
    IF NOT (public.current_user_has_role('accounts-team') OR public.current_user_has_role('super-admin')) THEN
        RAISE EXCEPTION 'Unauthorized: Insufficient privileges.';
    END IF;

    RETURN QUERY
    SELECT
        rr.rent_record_id,
        rr.property_id,
        p.address AS prop_addr,
        rr.tenant_user_id AS ten_id,
        tenant_user.raw_user_meta_data->>'full_name' AS ten_name,
        tenant_user.phone::TEXT AS ten_phone,
        rr.landlord_user_id AS land_id,
        landlord_user.raw_user_meta_data->>'full_name' AS land_name,
        landlord_user.phone::TEXT AS land_phone,
        rr.due_date, rr.period_start_date, rr.period_end_date, rr.amount_due, rr.amount_paid, rr.status, rr.notes,
        rr.created_at, rr.updated_at,
        COALESCE((
            SELECT jsonb_agg(jsonb_build_object(
                'payment_id', rp.payment_id,
                'paid_by_name', payer_user.raw_user_meta_data->>'full_name',
                'amount', rp.amount,
                'payment_date', rp.payment_date,
                'payment_method', rp.payment_method,
                'transaction_ref', rp.transaction_ref,
                'notes', rp.notes
            ) ORDER BY rp.payment_date DESC)
            FROM public.rent_payments rp
            JOIN auth.users payer_user ON rp.paid_by_user_id = payer_user.id
            WHERE rp.rent_record_id = rr.rent_record_id
        ), '[]'::jsonb) AS payments_data
    FROM public.rent_records rr
    JOIN public.properties p ON rr.property_id = p.property_id
    JOIN auth.users tenant_user ON rr.tenant_user_id = tenant_user.id
    JOIN auth.users landlord_user ON rr.landlord_user_id = landlord_user.id
    WHERE rr.rent_record_id = p_rent_record_id_input;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;
GRANT EXECUTE ON FUNCTION public.get_rent_record_details_admin(UUID) TO authenticated;

-- Function for admins to delete a rent record (and its payments)
CREATE OR REPLACE FUNCTION public.delete_rent_record_admin(p_rent_record_id UUID)
RETURNS VOID AS $$
BEGIN
    IF NOT (public.current_user_has_role('super-admin') OR public.current_user_has_role('accounts-team')) THEN
        RAISE EXCEPTION 'Unauthorized: Insufficient privileges.';
    END IF;
    RAISE WARNING 'Deleting rent record % - this will also delete associated payments due to CASCADE constraint on rent_payments table.', p_rent_record_id;
    DELETE FROM public.rent_records WHERE rent_record_id = p_rent_record_id;
    IF NOT FOUND THEN RAISE WARNING 'Rent Record ID % not found.', p_rent_record_id; END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.delete_rent_record_admin(UUID) TO authenticated;

-- Function for admins to manually record a rent payment
CREATE OR REPLACE FUNCTION public.record_rent_payment_admin(
    p_rent_record_id UUID,
    p_amount DECIMAL,
    p_paid_by_user_id UUID, -- Typically tenant, but admin specifies
    p_payment_date TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    p_payment_method TEXT DEFAULT 'MANUAL_ADMIN_ENTRY',
    p_transaction_ref TEXT DEFAULT NULL,
    p_notes TEXT DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
    v_payment_id UUID;
BEGIN
    IF NOT (public.current_user_has_role('accounts-team') OR public.current_user_has_role('super-admin')) THEN
        RAISE EXCEPTION 'Unauthorized: Insufficient privileges.';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM public.rent_records WHERE rent_record_id = p_rent_record_id) THEN
        RAISE EXCEPTION 'Rent Record ID % not found.', p_rent_record_id;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM auth.users WHERE id = p_paid_by_user_id) THEN
        RAISE EXCEPTION 'Paid By User ID % not found.', p_paid_by_user_id;
    END IF;
    IF p_amount <= 0 THEN RAISE EXCEPTION 'Payment amount must be positive.'; END IF;

    INSERT INTO public.rent_payments (rent_record_id, paid_by_user_id, amount, payment_date, payment_method, transaction_ref, notes)
    VALUES (p_rent_record_id, p_paid_by_user_id, p_amount, p_payment_date, p_payment_method, p_transaction_ref, p_notes)
    RETURNING payment_id INTO v_payment_id;
    -- The trigger on rent_payments will update the rent_records status and amount_paid.
    RETURN v_payment_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.record_rent_payment_admin(UUID, DECIMAL, UUID, TIMESTAMPTZ, TEXT, TEXT, TEXT) TO authenticated;

-- Function for admins to delete a specific rent payment
CREATE OR REPLACE FUNCTION public.delete_rent_payment_admin(p_payment_id UUID)
RETURNS VOID AS $$
DECLARE
    v_rent_record_id_affected UUID;
BEGIN
    IF NOT (public.current_user_has_role('super-admin') OR public.current_user_has_role('accounts-team')) THEN
        RAISE EXCEPTION 'Unauthorized: Insufficient privileges.';
    END IF;

    SELECT rent_record_id INTO v_rent_record_id_affected FROM public.rent_payments WHERE payment_id = p_payment_id;
    IF NOT FOUND THEN
        RAISE WARNING 'Payment ID % not found.', p_payment_id;
        RETURN;
    END IF;

    RAISE WARNING 'Deleting payment % for rent record %. This will trigger recalculation of the rent record status via trigger.', p_payment_id, v_rent_record_id_affected;
    DELETE FROM public.rent_payments WHERE payment_id = p_payment_id;
    -- The trigger `update_rent_record_on_payment` should handle recalculating parent `rent_records` status.
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.delete_rent_payment_admin(UUID) TO authenticated;

-- Function to generate upcoming rent records (called by cron or manually by admin)
CREATE OR REPLACE FUNCTION public.create_upcoming_rent_records_admin()
RETURNS TABLE (
    created_record_count INTEGER,
    skipped_existing_count INTEGER,
    skipped_no_tenant_count INTEGER,
    processed_eligible_property_count INTEGER
) AS $$
DECLARE
    prop RECORD;
    next_due_date DATE;
    period_start_date DATE;
    period_end_date DATE;
    today DATE := CURRENT_DATE;
    current_year INTEGER := date_part('year', today);
    current_month INTEGER := date_part('month', today);
    current_day INTEGER := date_part('day', today);
    next_due_month INTEGER;
    next_due_year INTEGER;
    v_created_count INTEGER := 0;
    v_skipped_existing INTEGER := 0;
    v_skipped_no_tenant INTEGER := 0;
    v_processed_eligible INTEGER := 0;
BEGIN
    -- Permission check: This should be callable by a super-admin or the postgres user for cron
    IF NOT (public.current_user_has_role('super-admin') OR current_user = 'postgres') THEN
        RAISE EXCEPTION 'Unauthorized to generate rent records.';
    END IF;

    RAISE NOTICE 'Starting create_upcoming_rent_records job at %', clock_timestamp();

    FOR prop IN
        SELECT
            p.property_id, p.tenant, p.submitter AS landlord_user_id, p.rent_due_day, p.price AS rent_amount
        FROM public.properties p
        WHERE p.listing_type = 'RENTAL'
          AND p.admin_status NOT IN ('SOLD', 'REJECTED', 'SUSPENDED', 'SUBMITTED') -- Only for active, non-sold/rejected rentals
          AND p.admin_status = 'RENTED'
          AND p.rent_due_day IS NOT NULL
          AND p.price IS NOT NULL AND p.price > 0
    LOOP
        IF prop.tenant IS NULL THEN
            v_skipped_no_tenant := v_skipped_no_tenant + 1;
            CONTINUE; -- Skip if no tenant
        END IF;

        v_processed_eligible := v_processed_eligible + 1;

        -- Calculate next due date (for the current or next month)
        IF current_day < prop.rent_due_day THEN
            next_due_month := current_month;
            next_due_year := current_year;
        ELSE
            IF current_month = 12 THEN
                next_due_month := 1;
                next_due_year := current_year + 1;
            ELSE
                next_due_month := current_month + 1;
                next_due_year := current_year;
            END IF;
        END IF;

        BEGIN
            next_due_date := make_date(next_due_year, next_due_month, prop.rent_due_day);
        EXCEPTION WHEN invalid_datetime_format THEN
            RAISE WARNING 'Invalid date %-%-% for property %, rent_due_day %. Using last day of month.', next_due_year, next_due_month, prop.rent_due_day, prop.property_id, prop.rent_due_day;
            next_due_date := (make_date(next_due_year, next_due_month, 1) + interval '1 month' - interval '1 day')::DATE;
        END;

        -- Calculate period start and end (assuming monthly rentals ending on due date - 1 day of next month logic)
        -- A common approach: if due_date is 5th, period is 5th of prev month to 4th of current month.
        -- Or, if due_date is 5th, period is 5th of current month to 4th of next month.
        -- Let's assume: period is for the month leading up to the due_date.
        -- If due_date is March 5th, period is Feb 5th to March 4th. Rent is for this period.
        period_end_date := next_due_date - INTERVAL '1 day';
        period_start_date := period_end_date - INTERVAL '1 month' + INTERVAL '1 day';


        IF NOT EXISTS (
            SELECT 1 FROM public.rent_records rr
            WHERE rr.property_id = prop.property_id
              AND rr.tenant_user_id = prop.tenant
              AND rr.due_date = next_due_date
        ) THEN
            BEGIN
                INSERT INTO public.rent_records (
                    property_id, tenant_user_id, landlord_user_id, due_date,
                    period_start_date, period_end_date, amount_due, status
                ) VALUES (
                    prop.property_id, prop.tenant, prop.landlord_user_id, next_due_date,
                    period_start_date, period_end_date, prop.rent_amount, 'DUE'
                );
                v_created_count := v_created_count + 1;
                RAISE NOTICE 'Created rent record for property % (Tenant: %, Due: %)', prop.property_id, prop.tenant, next_due_date;
            EXCEPTION WHEN others THEN
                RAISE WARNING 'Failed to insert rent record for property % (Tenant: %, Due: %): %', prop.property_id, prop.tenant, next_due_date, SQLERRM;
                -- Consider how to handle failures (e.g., log to another table)
            END;
        ELSE
            v_skipped_existing := v_skipped_existing + 1;
        END IF;
    END LOOP;
    RAISE NOTICE 'Finished create_upcoming_rent_records job. Processed Eligible: %, Created: %, Skipped (Existing): %, Skipped (No Tenant): %', v_processed_eligible, v_created_count, v_skipped_existing, v_skipped_no_tenant;
    RETURN QUERY SELECT v_created_count, v_skipped_existing, v_skipped_no_tenant, v_processed_eligible;
END;
$$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.create_upcoming_rent_records_admin() TO authenticated;
-- GRANT EXECUTE ON FUNCTION public.create_upcoming_rent_records_admin() TO postgres; -- For cron job execution


-- FILE NAME: 06_09_admin_ticket_management_functions.sql
-- Description: Functions for admins (Telecalling Teams, Super Admin) to manage support tickets.
-------------------------------------------------------------------------------

-- Function for admins to list tickets with extensive filters
CREATE OR REPLACE FUNCTION public.list_tickets_admin(
    p_property_id_filter UUID DEFAULT NULL,
    p_raised_by_user_id_filter UUID DEFAULT NULL,
    p_assigned_support_admin_id_filter UUID DEFAULT NULL,
    p_assigned_to_vendor_id_filter UUID DEFAULT NULL,
    p_status_filter public.ticket_status_enum[] DEFAULT NULL,
    p_priority_filter public.ticket_priority_enum[] DEFAULT NULL,
    p_category_filter public.ticket_category_enum[] DEFAULT NULL,
    p_created_at_start TIMESTAMPTZ DEFAULT NULL,
    p_created_at_end TIMESTAMPTZ DEFAULT NULL,
    p_search_term TEXT DEFAULT NULL,
    p_offset INTEGER DEFAULT 0,
    p_limit INTEGER DEFAULT 25
) RETURNS TABLE (
    ticket_id BIGINT,
    subject TEXT,
    property_id UUID,
    property_address TEXT,
    property_locality TEXT,
    raised_by_user_id UUID,
    raiser_name TEXT,
    raiser_email TEXT,
    raiser_phone TEXT,
    category public.ticket_category_enum,
    priority public.ticket_priority_enum,
    status public.ticket_status_enum,
    assigned_support_admin_id UUID,
    assigned_support_admin_name TEXT,
    assigned_to_vendor_id UUID,
    assigned_vendor_name TEXT,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ,
    resolved_at TIMESTAMPTZ,
    closed_at TIMESTAMPTZ,
    total_count BIGINT
) AS $$
BEGIN
    IF NOT (public.current_user_has_role('telecalling-owner-team') OR
            public.current_user_has_role('telecalling-tenant-team') OR
            public.current_user_has_role('super-admin')) THEN
        RAISE EXCEPTION 'Unauthorized: Insufficient privileges to list all tickets.';
    END IF;

    RETURN QUERY
    WITH tickets_base AS (
        SELECT
            t.ticket_id, t.subject, t.property_id, p.address AS prop_addr, p.locality AS prop_loc,
            t.raised_by_user_id AS raiser_id, raiser_user.raw_user_meta_data->>'full_name' AS r_name, raiser_user.email::TEXT AS r_email,
            raiser_user.phone::TEXT AS r_phone,
            t.category, t.priority, t.status,
            t.assigned_support_admin_id AS support_admin_id, support_admin_user.raw_user_meta_data->>'full_name' AS support_admin_name_val,
            t.assigned_to_vendor_id AS vendor_id, v.company_name AS vendor_name_val,
            t.created_at, t.updated_at, t.resolved_at, t.closed_at
        FROM public.tickets t
        JOIN public.properties p ON t.property_id = p.property_id
        JOIN auth.users raiser_user ON t.raised_by_user_id = raiser_user.id
        LEFT JOIN public.admins support_admin ON t.assigned_support_admin_id = support_admin.user_id
        LEFT JOIN auth.users support_admin_user ON support_admin.user_id = support_admin_user.id
        LEFT JOIN public.vendors v ON t.assigned_to_vendor_id = v.vendor_id
        WHERE (p_property_id_filter IS NULL OR t.property_id = p_property_id_filter)
          AND (p_raised_by_user_id_filter IS NULL OR t.raised_by_user_id = p_raised_by_user_id_filter)
          AND (p_assigned_support_admin_id_filter IS NULL OR t.assigned_support_admin_id = p_assigned_support_admin_id_filter)
          AND (p_assigned_to_vendor_id_filter IS NULL OR t.assigned_to_vendor_id = p_assigned_to_vendor_id_filter)
          AND (p_status_filter IS NULL OR t.status = ANY(p_status_filter))
          AND (p_priority_filter IS NULL OR t.priority = ANY(p_priority_filter))
          AND (p_category_filter IS NULL OR t.category = ANY(p_category_filter))
          AND (p_created_at_start IS NULL OR t.created_at >= p_created_at_start)
          AND (p_created_at_end IS NULL OR t.created_at <= p_created_at_end)
          AND (p_search_term IS NULL OR (
                t.subject ILIKE '%' || p_search_term || '%' OR
                t.description ILIKE '%' || p_search_term || '%' OR
                p.address ILIKE '%' || p_search_term || '%' OR
                p.locality ILIKE '%' || p_search_term || '%' OR
                raiser_user.raw_user_meta_data->>'full_name' ILIKE '%' || p_search_term || '%' OR
                raiser_user.email ILIKE '%' || p_search_term || '%' OR
                raiser_user.phone ILIKE '%' || p_search_term || '%' OR
                support_admin_user.raw_user_meta_data->>'full_name' ILIKE '%' || p_search_term || '%' OR
                v.company_name ILIKE '%' || p_search_term || '%' OR
                t.ticket_id::TEXT ILIKE '%' || p_search_term || '%'
              ))
    ),
    tickets_with_count AS (
        SELECT *, COUNT(*) OVER() AS total_rows FROM tickets_base
    )
    SELECT
        twc.ticket_id,
        twc.subject,
        twc.property_id,
        twc.prop_addr,
        twc.prop_loc,
        twc.raiser_id,
        twc.r_name,
        twc.r_email,
        twc.r_phone,
        twc.category,
        twc.priority,
        twc.status,
        twc.support_admin_id,
        twc.support_admin_name_val,
        twc.vendor_id,
        twc.vendor_name_val,
        twc.created_at,
        twc.updated_at,
        twc.resolved_at,
        twc.closed_at,
        twc.total_rows
    FROM tickets_with_count twc
    ORDER BY twc.updated_at DESC, twc.created_at DESC
    OFFSET p_offset
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;
GRANT EXECUTE ON FUNCTION public.list_tickets_admin(UUID, UUID, UUID, UUID, public.ticket_status_enum[], public.ticket_priority_enum[], public.ticket_category_enum[], TIMESTAMPTZ, TIMESTAMPTZ, TEXT, INTEGER, INTEGER) TO authenticated;

-- Function for admins to get full details of a specific ticket
CREATE OR REPLACE FUNCTION public.get_ticket_details_admin(p_ticket_id_input BIGINT)
RETURNS TABLE (
    ticket_id BIGINT, subject TEXT, description TEXT,
    property_id UUID, property_address TEXT, property_locality TEXT,
    raised_by_user_id UUID, raiser_name TEXT, raiser_email TEXT, raiser_phone TEXT,
    category public.ticket_category_enum, priority public.ticket_priority_enum, status public.ticket_status_enum,
    assigned_support_admin_id UUID, assigned_support_admin_name TEXT,
    assigned_to_vendor_id UUID, assigned_vendor_name TEXT, assigned_vendor_phone TEXT,
    resolution_notes TEXT,
    created_at TIMESTAMPTZ, updated_at TIMESTAMPTZ, resolved_at TIMESTAMPTZ, closed_at TIMESTAMPTZ,
    images JSONB, -- Array of {image_id, image_url, description, uploaded_by_name, created_at}
    comments JSONB -- Array of {comment_id, user_id, user_name, user_is_admin, comment_text, is_internal, created_at}
) AS $$
BEGIN
    IF NOT public.check_user_can_access_ticket(p_ticket_id_input, auth.uid()) THEN
         RAISE EXCEPTION 'Unauthorized: You do not have permission to view this ticket or ticket not found.';
    END IF;

    RETURN QUERY
    SELECT
        t.ticket_id, t.subject, t.description,
        t.property_id, p.address AS prop_addr, p.locality AS prop_loc,
        t.raised_by_user_id AS raiser_id, raiser_user.raw_user_meta_data->>'full_name' AS r_name, raiser_user.email::TEXT AS r_email, raiser_user.phone::TEXT AS r_phone,
        t.category, t.priority, t.status,
        t.assigned_support_admin_id AS support_admin_id, support_admin_auth_user.raw_user_meta_data->>'full_name' AS support_admin_name_val,
        t.assigned_to_vendor_id AS vendor_id, v.company_name AS vendor_name_val, v.phone::TEXT AS vendor_phone_val,
        t.resolution_notes,
        t.created_at, t.updated_at, t.resolved_at, t.closed_at,
        COALESCE((
            SELECT jsonb_agg(jsonb_build_object(
                'image_id', ti.image_id, 'image_url', ti.image_url, 'description', ti.description,
                'uploaded_by_name', img_uploader_user.raw_user_meta_data->>'full_name',
                'created_at', ti.created_at
            ) ORDER BY ti.created_at ASC)
            FROM public.ticket_images ti
            JOIN auth.users img_uploader_user ON ti.uploaded_by = img_uploader_user.id
            WHERE ti.ticket_id = t.ticket_id
        ), '[]'::jsonb) AS images_data,
        COALESCE((
            SELECT jsonb_agg(jsonb_build_object(
                'comment_id', tc.comment_id,
                'user_id', tc.user_id,
                'user_name', commenter_user.raw_user_meta_data->>'full_name',
                'user_is_admin', EXISTS(SELECT 1 FROM public.admins commenter_admin WHERE commenter_admin.user_id = tc.user_id),
                'comment_text', tc.comment_text,
                'is_internal', tc.is_internal,
                'created_at', tc.created_at
            ) ORDER BY tc.created_at ASC)
            FROM public.ticket_comments tc
            JOIN auth.users commenter_user ON tc.user_id = commenter_user.id
            WHERE tc.ticket_id = t.ticket_id
        ), '[]'::jsonb) AS comments_data
    FROM public.tickets t
    JOIN public.properties p ON t.property_id = p.property_id
    JOIN auth.users raiser_user ON t.raised_by_user_id = raiser_user.id
    LEFT JOIN public.admins support_admin ON t.assigned_support_admin_id = support_admin.user_id
    LEFT JOIN auth.users support_admin_auth_user ON support_admin.user_id = support_admin_auth_user.id
    LEFT JOIN public.vendors v ON t.assigned_to_vendor_id = v.vendor_id
    WHERE t.ticket_id = p_ticket_id_input;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;
GRANT EXECUTE ON FUNCTION public.get_ticket_details_admin(BIGINT) TO authenticated;


-- Function for admins to update a ticket's core details
CREATE OR REPLACE FUNCTION public.update_ticket_details_admin(
    p_ticket_id BIGINT,
    p_subject TEXT DEFAULT NULL,
    p_description TEXT DEFAULT NULL,
    p_category public.ticket_category_enum DEFAULT NULL,
    p_priority public.ticket_priority_enum DEFAULT NULL,
    p_status public.ticket_status_enum DEFAULT NULL,
    p_resolution_notes TEXT DEFAULT NULL
) RETURNS VOID AS $$
DECLARE
    v_can_update BOOLEAN := FALSE;
    v_calling_admin_id UUID := auth.uid();
    v_ticket_current_assignee UUID;
BEGIN
    IF NOT public.check_user_can_access_ticket(p_ticket_id, v_calling_admin_id) THEN
        RAISE EXCEPTION 'Unauthorized: You do not have permission to update this ticket or ticket not found.';
    END IF;

    SELECT assigned_support_admin_id INTO v_ticket_current_assignee FROM public.tickets WHERE ticket_id = p_ticket_id;

    IF public.current_user_has_role('super-admin') OR
       (public.current_user_has_role('telecalling-owner-team') AND (v_ticket_current_assignee IS NULL OR v_ticket_current_assignee = v_calling_admin_id)) OR
       (public.current_user_has_role('telecalling-tenant-team') AND (v_ticket_current_assignee IS NULL OR v_ticket_current_assignee = v_calling_admin_id)) THEN
        v_can_update := TRUE;
    END IF;

    IF NOT v_can_update THEN
        RAISE EXCEPTION 'Unauthorized: You can only update unassigned tickets or tickets assigned to you, unless you are a super-admin.';
    END IF;

    UPDATE public.tickets
    SET subject = COALESCE(p_subject, subject),
        description = COALESCE(p_description, description),
        category = COALESCE(p_category, category),
        priority = COALESCE(p_priority, priority),
        status = COALESCE(p_status, status), 
        resolution_notes = COALESCE(p_resolution_notes, resolution_notes),
        updated_at = CURRENT_TIMESTAMP
    WHERE ticket_id = p_ticket_id;

    IF NOT FOUND THEN RAISE EXCEPTION 'Ticket ID % not found (should not happen after access check).', p_ticket_id; END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.update_ticket_details_admin(BIGINT, TEXT, TEXT, public.ticket_category_enum, public.ticket_priority_enum, public.ticket_status_enum, TEXT) TO authenticated;

-- Function for telecalling teams or super-admin to assign a ticket to themselves or another admin
CREATE OR REPLACE FUNCTION public.assign_ticket_admin(
    p_ticket_id BIGINT,
    p_target_admin_id UUID 
) RETURNS VOID AS $$
DECLARE
    v_calling_admin_id UUID := auth.uid();
BEGIN
    IF NOT public.check_user_can_access_ticket(p_ticket_id, v_calling_admin_id) THEN
         RAISE EXCEPTION 'Unauthorized: You do not have permission to manage this ticket or ticket not found.';
    END IF;

    IF v_calling_admin_id <> p_target_admin_id AND NOT public.current_user_has_role('super-admin') THEN
        RAISE EXCEPTION 'Unauthorized: Only super-admins can assign tickets to other admins.';
    END IF;

    IF NOT (public.user_is_admin_with_role(p_target_admin_id, 'telecalling-owner-team') OR
            public.user_is_admin_with_role(p_target_admin_id, 'telecalling-tenant-team') OR
            public.user_is_admin_with_role(p_target_admin_id, 'super-admin')) THEN
        RAISE EXCEPTION 'Target admin % does not have a required role to be assigned a ticket.', p_target_admin_id;
    END IF;

    UPDATE public.tickets
    SET assigned_support_admin_id = p_target_admin_id,
        assigned_to_vendor_id = NULL, 
        status = CASE WHEN status = 'NEW' THEN 'OPEN' ELSE status END, 
        updated_at = CURRENT_TIMESTAMP
    WHERE ticket_id = p_ticket_id;

    IF NOT FOUND THEN RAISE EXCEPTION 'Ticket ID % not found.', p_ticket_id; END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.assign_ticket_admin(BIGINT, UUID) TO authenticated;


-- Function for admins to assign a ticket to a vendor
CREATE OR REPLACE FUNCTION public.assign_ticket_to_vendor_admin(
    p_ticket_id BIGINT,
    p_vendor_id UUID
) RETURNS VOID AS $$
BEGIN
    IF NOT public.check_user_can_access_ticket(p_ticket_id, auth.uid()) THEN
         RAISE EXCEPTION 'Unauthorized: You do not have permission to manage this ticket or ticket not found.';
    END IF;
    IF NOT (public.current_user_has_role('super-admin') OR public.current_user_has_role('telecalling-owner-team') OR public.current_user_has_role('telecalling-tenant-team')) THEN
        RAISE EXCEPTION 'Unauthorized: Insufficient privileges to assign tickets to vendors.';
    END IF;


    IF NOT EXISTS (SELECT 1 FROM public.vendors WHERE vendor_id = p_vendor_id) THEN
        RAISE EXCEPTION 'Vendor ID % does not exist.', p_vendor_id;
    END IF;

    UPDATE public.tickets
    SET assigned_to_vendor_id = p_vendor_id,
        assigned_support_admin_id = NULL, 
        status = 'ASSIGNED', 
        updated_at = CURRENT_TIMESTAMP
    WHERE ticket_id = p_ticket_id;

    IF NOT FOUND THEN RAISE EXCEPTION 'Ticket ID % not found.', p_ticket_id; END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.assign_ticket_to_vendor_admin(BIGINT, UUID) TO authenticated;


-- Function for admins to unassign a ticket (clears both admin and vendor assignment)
CREATE OR REPLACE FUNCTION public.unassign_ticket_admin(p_ticket_id BIGINT)
RETURNS VOID AS $$
DECLARE
    v_can_unassign BOOLEAN := FALSE;
    v_calling_admin_id UUID := auth.uid();
    v_ticket_current_assignee UUID;
BEGIN
    IF NOT public.check_user_can_access_ticket(p_ticket_id, v_calling_admin_id) THEN
         RAISE EXCEPTION 'Unauthorized: You do not have permission to manage this ticket or ticket not found.';
    END IF;

    SELECT assigned_support_admin_id INTO v_ticket_current_assignee FROM public.tickets WHERE ticket_id = p_ticket_id;

    IF public.current_user_has_role('super-admin') OR v_ticket_current_assignee = v_calling_admin_id THEN
        v_can_unassign := TRUE;
    END IF;

    IF NOT v_can_unassign THEN
        RAISE EXCEPTION 'Unauthorized: Only super-admins or the currently assigned admin can unassign this ticket.';
    END IF;

    UPDATE public.tickets
    SET assigned_support_admin_id = NULL,
        assigned_to_vendor_id = NULL,
        status = CASE WHEN status NOT IN ('NEW', 'RESOLVED', 'CLOSED', 'CANCELLED') THEN 'OPEN' ELSE status END, 
        updated_at = CURRENT_TIMESTAMP
    WHERE ticket_id = p_ticket_id;

    IF NOT FOUND THEN RAISE EXCEPTION 'Ticket ID % not found.', p_ticket_id; END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.unassign_ticket_admin(BIGINT) TO authenticated;

-- Function for admins to add a comment to a ticket (can be internal)
CREATE OR REPLACE FUNCTION public.add_ticket_comment_admin(
    p_ticket_id BIGINT,
    p_comment_text TEXT,
    p_is_internal BOOLEAN DEFAULT FALSE
) RETURNS VOID AS $$
DECLARE
    v_admin_id UUID := auth.uid();
BEGIN
    IF NOT public.check_user_can_access_ticket(p_ticket_id, v_admin_id) THEN
        RAISE EXCEPTION 'Unauthorized: You do not have permission to comment on this ticket or ticket not found.';
    END IF;

    IF p_comment_text IS NULL OR TRIM(p_comment_text) = '' THEN
        RAISE EXCEPTION 'Comment text cannot be empty.';
    END IF;

    INSERT INTO public.ticket_comments (ticket_id, user_id, comment_text, is_internal)
    VALUES (p_ticket_id, v_admin_id, p_comment_text, p_is_internal);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.add_ticket_comment_admin(BIGINT, TEXT, BOOLEAN) TO authenticated;

-- Function for admins to delete a ticket comment they made or any if super-admin
CREATE OR REPLACE FUNCTION public.delete_ticket_comment_admin(p_comment_id BIGINT)
RETURNS VOID AS $$
DECLARE
    v_comment_user_id UUID;
BEGIN
    IF NOT public.current_user_is_admin() THEN
        RAISE EXCEPTION 'Unauthorized: Admin access required.';
    END IF;

    SELECT user_id INTO v_comment_user_id FROM public.ticket_comments WHERE comment_id = p_comment_id;
    IF NOT FOUND THEN
        RAISE WARNING 'Ticket comment ID % not found.', p_comment_id;
        RETURN;
    END IF;

    IF NOT (public.current_user_has_role('super-admin') OR v_comment_user_id = auth.uid()) THEN
        RAISE EXCEPTION 'Unauthorized: Can only delete own comments or if super-admin.';
    END IF;

    DELETE FROM public.ticket_comments WHERE comment_id = p_comment_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.delete_ticket_comment_admin(BIGINT) TO authenticated;

-- Function for admins to delete a ticket image
CREATE OR REPLACE FUNCTION public.delete_ticket_image_admin(p_image_id UUID)
RETURNS VOID AS $$
DECLARE
    v_ticket_id BIGINT;
BEGIN
    IF NOT public.current_user_is_admin() THEN
        RAISE EXCEPTION 'Unauthorized: Admin access required.';
    END IF;

    SELECT ticket_id INTO v_ticket_id FROM public.ticket_images WHERE image_id = p_image_id;
    IF NOT FOUND THEN
        RAISE WARNING 'Ticket image ID % not found.', p_image_id;
        RETURN;
    END IF;

    IF NOT public.check_user_can_access_ticket(v_ticket_id, auth.uid()) THEN
        RAISE EXCEPTION 'Unauthorized: You do not have permission to manage images for this ticket.';
    END IF;

    DELETE FROM public.ticket_images WHERE image_id = p_image_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.delete_ticket_image_admin(UUID) TO authenticated;

-- Function for admins to record a ticket image upload
CREATE OR REPLACE FUNCTION public.record_ticket_image_upload_admin(
    p_ticket_id BIGINT,
    p_image_url TEXT,
    p_description TEXT DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
    v_image_id UUID;
    v_uploader_admin_id UUID := auth.uid();
BEGIN
    IF NOT public.check_user_can_access_ticket(p_ticket_id, v_uploader_admin_id) THEN
        RAISE EXCEPTION 'Unauthorized: You do not have permission to upload images for this ticket or ticket not found.';
    END IF;

    INSERT INTO public.ticket_images (ticket_id, uploaded_by, image_url, description)
    VALUES (p_ticket_id, v_uploader_admin_id, p_image_url, p_description)
    RETURNING image_id INTO v_image_id;

    RETURN v_image_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.record_ticket_image_upload_admin(BIGINT, TEXT, TEXT) TO authenticated;

CREATE OR REPLACE FUNCTION public.assign_ticket_to_self_telecaller(
    p_ticket_id BIGINT
) RETURNS VOID AS $$
DECLARE
    v_calling_admin_id UUID := auth.uid();
BEGIN
    IF NOT (public.current_user_has_role('telecalling-owner-team') OR
            public.current_user_has_role('telecalling-tenant-team') OR
            public.current_user_has_role('super-admin')) THEN
        RAISE EXCEPTION 'Unauthorized: Only telecalling teams or super-admins can assign tickets to themselves.';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM public.tickets t
        WHERE t.ticket_id = p_ticket_id
          AND t.assigned_support_admin_id IS NULL
          AND t.assigned_to_vendor_id IS NULL 
          AND t.status NOT IN ('RESOLVED', 'CLOSED', 'CANCELLED')
    ) THEN
        RAISE EXCEPTION 'Ticket ID % not found, is already assigned, or is in a final state (Resolved, Closed, Cancelled).', p_ticket_id;
    END IF;

    UPDATE public.tickets
    SET assigned_support_admin_id = v_calling_admin_id,
        status = CASE
                     WHEN status = 'NEW' THEN 'OPEN' 
                     ELSE status                         
                 END,
        updated_at = CURRENT_TIMESTAMP
    WHERE ticket_id = p_ticket_id
      AND assigned_support_admin_id IS NULL 
      AND assigned_to_vendor_id IS NULL;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Failed to assign ticket %. It might have been assigned by another admin concurrently.', p_ticket_id;
    END IF;

    RAISE NOTICE 'Ticket % successfully assigned to admin %', p_ticket_id, v_calling_admin_id;

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.assign_ticket_to_self_telecaller(BIGINT) TO authenticated;


-- FILE NAME: 06_10_admin_management_plan_functions.sql
-- Description: Functions for admins (primarily Accounts Team, Super Admin) to manage property management service plans.
-------------------------------------------------------------------------------

-- Function for admins to create a new management service plan
CREATE OR REPLACE FUNCTION public.create_management_plan_admin(
    p_name TEXT,
    p_percentage DECIMAL(5, 2), -- Percentage of rent/sale price, etc.
    p_description TEXT DEFAULT NULL,
    p_is_active BOOLEAN DEFAULT TRUE
) RETURNS UUID AS $$
DECLARE
    v_plan_id UUID;
BEGIN
    IF NOT (public.current_user_has_role('accounts-team') OR public.current_user_has_role('super-admin')) THEN
        RAISE EXCEPTION 'Unauthorized: Insufficient privileges to create management plans.';
    END IF;

    IF p_name IS NULL OR TRIM(p_name) = '' THEN
        RAISE EXCEPTION 'Management plan name cannot be empty.';
    END IF;
    IF p_percentage IS NULL OR p_percentage < 0 OR p_percentage > 100 THEN
        RAISE EXCEPTION 'Percentage must be between 0 and 100.';
    END IF;

    INSERT INTO public.management_service_plans (name, percentage, description, is_active)
    VALUES (TRIM(p_name), p_percentage, p_description, p_is_active)
    RETURNING plan_id INTO v_plan_id;

    RETURN v_plan_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.create_management_plan_admin(TEXT, DECIMAL(5,2), TEXT, BOOLEAN) TO authenticated;

-- Function for admins to update an existing management service plan
CREATE OR REPLACE FUNCTION public.update_management_plan_admin(
    p_plan_id UUID,
    p_name TEXT DEFAULT NULL,
    p_percentage DECIMAL(5, 2) DEFAULT NULL,
    p_description TEXT DEFAULT NULL,
    p_is_active BOOLEAN DEFAULT NULL
) RETURNS VOID AS $$
BEGIN
    IF NOT (public.current_user_has_role('accounts-team') OR public.current_user_has_role('super-admin')) THEN
        RAISE EXCEPTION 'Unauthorized: Insufficient privileges to update management plans.';
    END IF;

    IF p_name IS NOT NULL AND TRIM(p_name) = '' THEN
        RAISE EXCEPTION 'Management plan name cannot be empty if provided.';
    END IF;
    IF p_percentage IS NOT NULL AND (p_percentage < 0 OR p_percentage > 100) THEN
        RAISE EXCEPTION 'Percentage must be between 0 and 100 if provided.';
    END IF;

    UPDATE public.management_service_plans
    SET name = COALESCE(TRIM(p_name), name),
        percentage = COALESCE(p_percentage, percentage),
        description = COALESCE(p_description, description),
        is_active = COALESCE(p_is_active, is_active),
        updated_at = CURRENT_TIMESTAMP
    WHERE plan_id = p_plan_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Management Service Plan with ID % not found.', p_plan_id;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.update_management_plan_admin(UUID, TEXT, DECIMAL(5,2), TEXT, BOOLEAN) TO authenticated;

-- Function for admins to list management service plans
CREATE OR REPLACE FUNCTION public.list_management_plans_admin(
    p_is_active_filter BOOLEAN DEFAULT NULL,
    p_offset INTEGER DEFAULT 0,
    p_limit INTEGER DEFAULT 25
) RETURNS TABLE (
    plan_id UUID,
    name TEXT,
    percentage DECIMAL(5, 2),
    description TEXT,
    is_active BOOLEAN,
    created_at TIMESTAMP WITH TIME ZONE,
    updated_at TIMESTAMP WITH TIME ZONE,
    total_count BIGINT
) AS $$
BEGIN
    -- All admins might need to see these plans when associating with a property,
    -- but only Accounts/SuperAdmin can CRUD them.
    IF NOT public.current_user_is_admin() THEN
        RAISE EXCEPTION 'Unauthorized: Admin access required to list management plans.';
    END IF;

    RETURN QUERY
    WITH plans_base AS (
      SELECT msp.*
      FROM public.management_service_plans msp
      WHERE (p_is_active_filter IS NULL OR msp.is_active = p_is_active_filter)
    ),
    plans_with_count AS (
      SELECT *, COUNT(*) OVER() as total_rows FROM plans_base
    )
    SELECT
        pwc.plan_id, pwc.name, pwc.percentage, pwc.description, pwc.is_active,
        pwc.created_at, pwc.updated_at, pwc.total_rows
    FROM plans_with_count pwc
    ORDER BY pwc.is_active DESC, pwc.percentage ASC, pwc.name ASC
    OFFSET p_offset
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;
GRANT EXECUTE ON FUNCTION public.list_management_plans_admin(BOOLEAN, INTEGER, INTEGER) TO authenticated;


-- Function for admins to get details of a specific management service plan
CREATE OR REPLACE FUNCTION public.get_management_plan_details_admin(p_plan_id_input UUID)
RETURNS TABLE (
    plan_id UUID,
    name TEXT,
    percentage DECIMAL(5, 2),
    description TEXT,
    is_active BOOLEAN,
    created_at TIMESTAMP WITH TIME ZONE,
    updated_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    IF NOT public.current_user_is_admin() THEN
        RAISE EXCEPTION 'Unauthorized: Admin access required.';
    END IF;

    RETURN QUERY
    SELECT msp.*
    FROM public.management_service_plans msp
    WHERE msp.plan_id = p_plan_id_input;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;
GRANT EXECUTE ON FUNCTION public.get_management_plan_details_admin(UUID) TO authenticated;


-- FILE NAME: 06_11_admin_dashboard_reporting_functions.sql
-- Description: Functions for admins (primarily Super Admin) to get dashboard statistics and reports.
-------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.get_dashboard_stats_admin()
RETURNS JSONB AS $$
DECLARE
    stats JSONB;
    prop_stats JSONB;
    admin_staff_stats JSONB;
    customer_stats JSONB;
    interaction_stats JSONB;
    transaction_stats JSONB;
    service_stats JSONB;
    vendor_stats JSONB;
    ticket_stats JSONB;
    rent_stats JSONB;
    mgmt_plan_stats JSONB;
    visit_plan_stats JSONB;
BEGIN
    IF NOT public.current_user_has_role('super-admin') THEN
         RAISE EXCEPTION 'Unauthorized: Only super-admins can view dashboard stats.';
    END IF;

    -- Property Stats
    SELECT jsonb_object_agg(key, value) INTO prop_stats FROM (
      SELECT 'total_properties' as key, to_jsonb(count(*)) as value FROM public.properties UNION ALL
      SELECT 'publicly_listed_properties' as key, to_jsonb(count(*)) as value FROM public.properties WHERE is_listed = TRUE UNION ALL
      SELECT 'properties_by_admin_status' as key, COALESCE(jsonb_object_agg(admin_status, count), '{}'::jsonb) as value FROM (SELECT admin_status, COUNT(*) as count FROM public.properties GROUP BY admin_status) AS s UNION ALL
      SELECT 'rental_properties_is_listed' as key, to_jsonb(count(*)) as value FROM public.properties WHERE listing_type = 'RENTAL' AND is_listed = TRUE UNION ALL
      SELECT 'sale_properties_is_listed' as key, to_jsonb(count(*)) as value FROM public.properties WHERE listing_type = 'SALE' AND is_listed = TRUE UNION ALL
      SELECT 'occupied_rentals' as key, to_jsonb(count(*)) as value FROM public.properties WHERE listing_type = 'RENTAL' AND tenant IS NOT NULL AND admin_status = 'RENTED' UNION ALL -- Or other relevant active status
      SELECT 'properties_by_type' as key, COALESCE(jsonb_object_agg(property_type, count), '{}'::jsonb) as value FROM (SELECT property_type, COUNT(*) as count FROM public.properties GROUP BY property_type) AS pt
    ) AS prop;

    -- Admin Staff Stats
    SELECT jsonb_object_agg(key, value) INTO admin_staff_stats FROM (
        SELECT 'total_admin_staff' as key, to_jsonb(COUNT(*)) as value FROM public.admins UNION ALL
        SELECT 'active_admin_staff' as key, to_jsonb(COUNT(*)) as value FROM public.admins WHERE is_active = TRUE UNION ALL
        SELECT 'admin_staff_by_role' as key, COALESCE(jsonb_object_agg(role_name, count), '{}'::jsonb) as value FROM (
            SELECT unnest(roles) as role_name, COUNT(*) as count FROM public.admins WHERE is_active = TRUE GROUP BY role_name
        ) as r_counts
    ) AS adm_staff;

    -- Customer (User) Stats (from public.customers)
    SELECT jsonb_object_agg(key, value) INTO customer_stats FROM (
      SELECT 'total_registered_users' as key, to_jsonb(count(*)) as value FROM auth.users UNION ALL -- All users in the system
      SELECT 'customers_with_profiles' as key, to_jsonb(count(*)) as value FROM public.customers UNION ALL -- Users with a customer record
      SELECT 'customers_with_active_visits' as key, to_jsonb(count(*)) as value FROM public.customers WHERE visit_balance > 0 AND expiry_date >= CURRENT_DATE
    ) AS cust;

    -- Interaction Stats
    SELECT jsonb_object_agg(key, value) INTO interaction_stats FROM (
      SELECT 'total_interactions' as key, to_jsonb(COUNT(*)) as value FROM public.customers_interaction UNION ALL
      SELECT 'interactions_by_status' as key, COALESCE(jsonb_object_agg(status, count), '{}'::jsonb) as value FROM (
          SELECT status, COUNT(*) as count FROM public.customers_interaction GROUP BY status
      ) AS s
    ) AS intr;

    -- Transaction (Visit Plan Purchases) Stats
    SELECT jsonb_object_agg(key, value) INTO transaction_stats FROM (
      SELECT 'total_transactions' as key, to_jsonb(COUNT(*)) as value FROM public.transactions UNION ALL
      SELECT 'successful_transactions' as key, to_jsonb(COUNT(*)) as value FROM public.transactions WHERE status = 'paid' UNION ALL
      SELECT 'total_revenue_from_visits' as key, to_jsonb(COALESCE(SUM(amount), 0.00)) as value FROM public.transactions WHERE status = 'paid'
    ) AS trans;

    -- Service Stats
    SELECT jsonb_build_object( 'total_services', COALESCE(SUM(count), 0::BIGINT), 'services_by_category', COALESCE(jsonb_object_agg(category, count), '{}'::jsonb) ) INTO service_stats FROM ( SELECT category::text, COUNT(*) as count FROM public.services GROUP BY category ) AS service_counts;

    -- Vendor Stats
    SELECT jsonb_build_object( 'total_vendors', COALESCE((SELECT COUNT(*) FROM public.vendors), 0::BIGINT), 'vendors_by_status', COALESCE((SELECT jsonb_object_agg(status, count) FROM (SELECT status::text, COUNT(*) as count FROM public.vendors GROUP BY status) AS s), '{}'::jsonb) ) INTO vendor_stats;

    -- Ticket Stats
    SELECT jsonb_build_object(
        'total_tickets', COALESCE((SELECT COUNT(*) FROM public.tickets), 0::BIGINT),
        'tickets_by_status', COALESCE((SELECT jsonb_object_agg(status, count) FROM (SELECT status::text, COUNT(*) as count FROM public.tickets GROUP BY status) AS s), '{}'::jsonb),
        'tickets_by_priority', COALESCE((SELECT jsonb_object_agg(priority, count) FROM (SELECT priority::text, COUNT(*) as count FROM public.tickets GROUP BY priority) AS p), '{}'::jsonb),
        'assigned_to_admin_tickets', COALESCE((SELECT COUNT(*) FROM public.tickets WHERE assigned_support_admin_id IS NOT NULL), 0::BIGINT),
        'assigned_to_vendor_tickets', COALESCE((SELECT COUNT(*) FROM public.tickets WHERE assigned_to_vendor_id IS NOT NULL), 0::BIGINT),
        'unassigned_open_tickets', COALESCE((SELECT COUNT(*) FROM public.tickets WHERE assigned_support_admin_id IS NULL AND assigned_to_vendor_id IS NULL AND status IN ('NEW', 'OPEN', 'IN_PROGRESS', 'WAITING_TENANT_RESPONSE', 'WAITING_OWNER_RESPONSE')), 0::BIGINT)
    ) INTO ticket_stats;

    -- Rent Stats
    SELECT jsonb_build_object(
        'total_rent_records', COALESCE((SELECT COUNT(*) FROM public.rent_records), 0::BIGINT),
        'rent_records_by_status', COALESCE((SELECT jsonb_object_agg(status, count) FROM (SELECT status::text, COUNT(*) as count FROM public.rent_records GROUP BY status) AS s), '{}'::jsonb),
        'total_rent_amount_due_outstanding', COALESCE((SELECT SUM(amount_due - amount_paid) FROM public.rent_records WHERE status IN ('DUE', 'OVERDUE', 'PARTIALLY_PAID')), 0.00),
        'total_rent_collected_ever', COALESCE((SELECT SUM(amount_paid) FROM public.rent_records), 0.00) -- Or SUM(amount) from rent_payments
    ) INTO rent_stats;

    -- Management Service Plan Stats
    SELECT jsonb_build_object( 'total_mgmt_plans', COALESCE((SELECT COUNT(*) FROM public.management_service_plans), 0::BIGINT), 'active_mgmt_plans', COALESCE((SELECT COUNT(*) FROM public.management_service_plans WHERE is_active = TRUE), 0::BIGINT) ) INTO mgmt_plan_stats;

    -- Visit Plan Stats
    SELECT jsonb_build_object( 'total_visit_plans', COALESCE((SELECT COUNT(*) FROM public.visit_plans), 0::BIGINT), 'active_visit_plans', COALESCE((SELECT COUNT(*) FROM public.visit_plans WHERE is_active = TRUE), 0::BIGINT) ) INTO visit_plan_stats;


    SELECT jsonb_build_object(
        'properties', prop_stats,
        'admin_staff', admin_staff_stats,
        'customers', customer_stats,
        'interactions', interaction_stats,
        'visit_transactions', transaction_stats,
        'services', service_stats,
        'vendors', vendor_stats,
        'tickets', ticket_stats,
        'rent_records', rent_stats,
        'management_plans', mgmt_plan_stats,
        'visit_plans', visit_plan_stats
    ) INTO stats;

    RETURN stats;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;
GRANT EXECUTE ON FUNCTION public.get_dashboard_stats_admin() TO authenticated;


-- Example Reporting Function: Occupied Properties Rent Status (from old dashboard functions)
-- This function is useful and should be retained/adapted.
CREATE OR REPLACE FUNCTION public.get_occupied_properties_rent_status_report_admin(
    p_property_search TEXT DEFAULT NULL, -- Search address, locality, pincode
    p_tenant_search TEXT DEFAULT NULL,   -- Search tenant name, email, phone
    p_rent_status_filter public.rent_status_enum DEFAULT NULL,
    p_offset INTEGER DEFAULT 0,
    p_limit INTEGER DEFAULT 10
)
RETURNS TABLE (
    property_id UUID,
    property_address TEXT,
    property_locality TEXT,
    property_city TEXT,
    property_pincode INTEGER,
    tenant_user_id UUID,
    tenant_name TEXT,
    tenant_email TEXT,
    tenant_phone TEXT,
    property_rent_due_day INTEGER,
    latest_rent_record_id UUID,
    latest_rent_record_status public.rent_status_enum,
    latest_rent_record_due_date DATE,
    latest_rent_amount_due DECIMAL,
    latest_rent_amount_paid DECIMAL,
    last_payment_date_for_latest_record TIMESTAMPTZ,
    total_count BIGINT
) AS $$
BEGIN
    IF NOT (public.current_user_has_role('accounts-team') OR public.current_user_has_role('super-admin')) THEN
        RAISE EXCEPTION 'Unauthorized: Insufficient privileges for this report.';
    END IF;

    RETURN QUERY
    WITH OccupiedPropsBase AS (
        SELECT
            p.property_id, p.address, p.locality, p.city, p.pincode, p.rent_due_day AS prop_rent_due_day,
            p.tenant AS ten_id,
            tu.email::TEXT as ten_email_val,
            tu.raw_user_meta_data ->> 'full_name' AS ten_name_val,
            tu.phone::TEXT AS ten_phone_val
        FROM public.properties p
        JOIN auth.users tu ON p.tenant = tu.id
        WHERE p.listing_type = 'RENTAL'
          AND p.tenant IS NOT NULL
          AND p.admin_status = 'RENTED' -- Specifically properties marked as RENTED
          AND (p_property_search IS NULL OR (
                p.address ILIKE '%' || p_property_search || '%' OR
                p.city ILIKE '%' || p_property_search || '%' OR
                p.locality ILIKE '%' || p_property_search || '%' OR
                p.pincode::TEXT ILIKE '%' || p_property_search || '%'
              ))
          AND (p_tenant_search IS NULL OR (
                tu.email ILIKE '%' || p_tenant_search || '%' OR
                (tu.raw_user_meta_data ->> 'full_name') ILIKE '%' || p_tenant_search || '%' OR
                tu.phone ILIKE '%' || p_tenant_search || '%'
              ))
    ),
    LatestRentForProp AS (
        SELECT
            rr.property_id,
            rr.rent_record_id,
            rr.status AS latest_status,
            rr.due_date AS latest_due_date,
            rr.amount_due AS latest_amt_due,
            rr.amount_paid AS latest_amt_paid,
            (SELECT MAX(rp.payment_date) FROM public.rent_payments rp WHERE rp.rent_record_id = rr.rent_record_id) as last_payment_on_record,
            ROW_NUMBER() OVER (PARTITION BY rr.property_id ORDER BY rr.due_date DESC) as rn
        FROM public.rent_records rr
        WHERE rr.property_id IN (SELECT opb.property_id FROM OccupiedPropsBase opb)
    ),
    FilteredReportData AS (
        SELECT
            opb.*,
            lr.rent_record_id AS latest_rr_id,
            lr.latest_status,
            lr.latest_due_date,
            lr.latest_amt_due,
            lr.latest_amt_paid,
            lr.last_payment_on_record
        FROM OccupiedPropsBase opb
        LEFT JOIN LatestRentForProp lr ON opb.property_id = lr.property_id AND lr.rn = 1
        WHERE (p_rent_status_filter IS NULL OR lr.latest_status = p_rent_status_filter OR (p_rent_status_filter IS NOT NULL AND lr.latest_status IS NULL)) -- handles cases where no rent record exists yet
    ),
    ReportWithCount AS (
      SELECT *, COUNT(*) OVER() AS total_rows FROM FilteredReportData
    )
    SELECT
        rwc.property_id, rwc.address, rwc.locality, rwc.city, rwc.pincode,
        rwc.ten_id, rwc.ten_name_val, rwc.ten_email_val, rwc.ten_phone_val,
        rwc.prop_rent_due_day,
        rwc.latest_rr_id, rwc.latest_status, rwc.latest_due_date, rwc.latest_amt_due, rwc.latest_amt_paid,
        rwc.last_payment_on_record,
        rwc.total_rows
    FROM ReportWithCount rwc
    ORDER BY rwc.latest_due_date DESC NULLS LAST, rwc.prop_rent_due_day ASC, rwc.address ASC
    OFFSET p_offset
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;
GRANT EXECUTE ON FUNCTION public.get_occupied_properties_rent_status_report_admin(TEXT, TEXT, public.rent_status_enum, INTEGER, INTEGER) TO authenticated;


-- FILE NAME: 06_12_admin_performance_analytics_functions.sql
-- Description: Functions for Super Admins to view performance analytics of various teams and individuals.
-------------------------------------------------------------------------------

-- Performance analytics for Telecalling Owner Team
CREATE OR REPLACE FUNCTION public.get_telecalling_owner_team_performance_admin(
    p_start_date DATE DEFAULT (CURRENT_DATE - INTERVAL '30 days'),
    p_end_date DATE DEFAULT CURRENT_DATE,
    p_admin_id_filter UUID DEFAULT NULL -- Optional: filter for a specific admin
) RETURNS TABLE (
    admin_id UUID,
    admin_name TEXT,
    properties_verified_count BIGINT, -- Properties moved to OWNER_VERIFIED by this admin in period
    currently_assigned_pending_count BIGINT, -- Properties in OWNER_CONTACT_PENDING currently assigned
    avg_docs_per_verified_property DECIMAL -- Avg property docs added for properties they verified
) AS $$
BEGIN
    IF NOT public.current_user_has_role('super-admin') THEN
        RAISE EXCEPTION 'Unauthorized: Only super-admins can view team performance analytics.';
    END IF;

    RETURN QUERY
    WITH admin_actions AS (
        -- Count properties verified by each admin in the period
        -- This requires tracking who moved the property to 'OWNER_VERIFIED'.
        -- Assuming updated_by or a log table would store this. For now, we link through assignment.
        -- This is an approximation: properties whose status became OWNER_VERIFIED while assigned to them.
        SELECT
            poca.assigned_admin_id,
            COUNT(DISTINCT p.property_id) AS verified_count
        FROM public.properties p
        JOIN public.property_owner_contact_assignments poca ON p.property_id = poca.property_id
        -- We need a way to link the status change event to the admin.
        -- Let's assume the 'updated_at' of the property when status changed to OWNER_VERIFIED
        -- happened while it was assigned to this admin during the period. This is imperfect.
        -- A proper audit log table `property_status_changes(property_id, new_status, changed_by_admin_id, changed_at)` would be better.
        -- For now, count properties that are currently OWNER_VERIFIED and were assigned to them.
        WHERE p.admin_status = 'OWNER_VERIFIED'
          AND p.updated_at >= p_start_date AND p.updated_at <= p_end_date -- Property became verified in this period
        GROUP BY poca.assigned_admin_id
    ),
    current_assignments AS (
        SELECT
            poca.assigned_admin_id,
            COUNT(DISTINCT p.property_id) AS current_pending_count
        FROM public.properties p
        JOIN public.property_owner_contact_assignments poca ON p.property_id = poca.property_id
        WHERE p.admin_status = 'OWNER_CONTACT_PENDING'
        GROUP BY poca.assigned_admin_id
    ),
    docs_added AS (
        -- This counts documents uploaded by admins for properties they likely handled
        -- Again, direct attribution is better with an audit log.
        SELECT
            pd.uploaded_by AS admin_id, -- Assuming uploaded_by is the admin_id
            p.property_id,
            COUNT(pd.document_id) as doc_count
        FROM public.property_documents pd
        JOIN public.properties p ON pd.property_id = p.property_id
        JOIN public.property_owner_contact_assignments poca ON p.property_id = poca.property_id AND pd.uploaded_by = poca.assigned_admin_id
        WHERE p.admin_status = 'OWNER_VERIFIED' -- Count docs for properties they helped verify
          AND pd.uploaded_at >= p_start_date AND pd.uploaded_at <= p_end_date
        GROUP BY pd.uploaded_by, p.property_id
    ),
    avg_docs AS (
        SELECT
            da.admin_id,
            AVG(da.doc_count) as avg_doc_per_prop
        FROM docs_added da
        GROUP BY da.admin_id
    )
    SELECT
        adm.user_id AS admin_id,
        COALESCE(u.raw_user_meta_data->>'full_name', adm.user_id::TEXT) AS admin_name,
        COALESCE(aa.verified_count, 0) AS properties_verified_count,
        COALESCE(ca.current_pending_count, 0) AS currently_assigned_pending_count,
        COALESCE(ad.avg_doc_per_prop, 0.0) AS avg_docs_per_verified_property
    FROM public.admins adm
    JOIN auth.users u ON adm.user_id = u.id
    LEFT JOIN admin_actions aa ON adm.user_id = aa.assigned_admin_id
    LEFT JOIN current_assignments ca ON adm.user_id = ca.assigned_admin_id
    LEFT JOIN avg_docs ad ON adm.user_id = ad.admin_id
    WHERE 'telecalling-owner-team' = ANY(adm.roles)
      AND (p_admin_id_filter IS NULL OR adm.user_id = p_admin_id_filter)
    ORDER BY admin_name;

END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;
GRANT EXECUTE ON FUNCTION public.get_telecalling_owner_team_performance_admin(DATE, DATE, UUID) TO authenticated;


-- Performance analytics for Sales Team
CREATE OR REPLACE FUNCTION public.get_sales_team_performance_admin(
    p_start_date DATE DEFAULT (CURRENT_DATE - INTERVAL '30 days'),
    p_end_date DATE DEFAULT CURRENT_DATE,
    p_admin_id_filter UUID DEFAULT NULL -- Optional: filter for a specific admin
) RETURNS TABLE (
    admin_id UUID,
    admin_name TEXT,
    total_visit_assignments BIGINT, -- Number of PVA groups assigned
    total_interactions_scheduled BIGINT, -- Sum of interactions in those PVAL groups for the period
    total_interactions_completed BIGINT, -- Interactions marked COMPLETED by this admin in period
    total_interactions_cancelled_by_sales BIGINT -- Interactions marked CANCELLED by this admin
) AS $$
BEGIN
    IF NOT public.current_user_has_role('super-admin') THEN
        RAISE EXCEPTION 'Unauthorized: Only super-admins can view team performance analytics.';
    END IF;

    RETURN QUERY
    WITH sales_admin_base AS (
        SELECT adm.user_id, COALESCE(u.raw_user_meta_data->>'full_name', adm.user_id::TEXT) AS name
        FROM public.admins adm
        JOIN auth.users u ON adm.user_id = u.id
        WHERE 'sales-team' = ANY(adm.roles)
          AND (p_admin_id_filter IS NULL OR adm.user_id = p_admin_id_filter)
    ),
    visit_assignments_stats AS (
        SELECT
            pva.assigned_sales_admin_id,
            COUNT(DISTINCT pva.visit_assignment_id) AS pva_count,
            COUNT(pvai.interaction_id) AS interactions_in_pva_count
        FROM public.property_visit_assignments pva
        JOIN public.property_visit_assignment_interactions pvai ON pva.visit_assignment_id = pvai.visit_assignment_id
        WHERE pva.visit_date >= p_start_date AND pva.visit_date <= p_end_date
        GROUP BY pva.assigned_sales_admin_id
    ),
    completed_interactions AS (
        SELECT
            ci.assigned_sales_admin_id, -- Assuming this is correctly updated when sales completes it
            COUNT(ci.interaction_id) AS completed_count
        FROM public.customers_interaction ci
        WHERE ci.status = 'VISIT_COMPLETED'
          AND ci.visited_at >= p_start_date AND ci.visited_at <= p_end_date
        GROUP BY ci.assigned_sales_admin_id
    ),
    cancelled_interactions AS (
        -- Assuming admin_notes or another field indicates who cancelled if it's sales admin
        -- For simplicity, let's count cancellations where they were the assigned sales admin
        -- A more robust way: check who set the status to 'VISIT_CANCELLED' via an audit log.
        SELECT
            ci.assigned_sales_admin_id,
            COUNT(ci.interaction_id) AS cancelled_count
        FROM public.customers_interaction ci
        WHERE ci.status = 'VISIT_CANCELLED'
          AND ci.updated_at >= p_start_date AND ci.updated_at <= p_end_date -- Cancellation happened in period
          -- AND ci.admin_notes ILIKE '%cancelled by sales%' -- This is very weak.
        GROUP BY ci.assigned_sales_admin_id
    )
    SELECT
        sab.user_id AS admin_id,
        sab.name AS admin_name,
        COALESCE(vas.pva_count, 0) AS total_visit_assignments,
        COALESCE(vas.interactions_in_pva_count, 0) AS total_interactions_scheduled,
        COALESCE(ci_comp.completed_count, 0) AS total_interactions_completed,
        COALESCE(ci_canc.cancelled_count, 0) AS total_interactions_cancelled_by_sales
    FROM sales_admin_base sab
    LEFT JOIN visit_assignments_stats vas ON sab.user_id = vas.assigned_sales_admin_id
    LEFT JOIN completed_interactions ci_comp ON sab.user_id = ci_comp.assigned_sales_admin_id
    LEFT JOIN cancelled_interactions ci_canc ON sab.user_id = ci_canc.assigned_sales_admin_id
    ORDER BY admin_name;

END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;
GRANT EXECUTE ON FUNCTION public.get_sales_team_performance_admin(DATE, DATE, UUID) TO authenticated;


-- Performance analytics for Ticket Handling Admins (Telecalling Teams, Super Admins)
CREATE OR REPLACE FUNCTION public.get_ticket_handling_performance_admin(
    p_start_date DATE DEFAULT (CURRENT_DATE - INTERVAL '30 days'),
    p_end_date DATE DEFAULT CURRENT_DATE,
    p_admin_id_filter UUID DEFAULT NULL, -- Optional: filter for a specific admin
    p_role_filter public.admin_role_enum DEFAULT NULL -- Optional: filter by role (e.g. 'telecalling-tenant-team')
) RETURNS TABLE (
    admin_id UUID,
    admin_name TEXT,
    roles public.admin_role_enum[],
    tickets_assigned_in_period BIGINT, -- Tickets assigned to this admin where assignment happened in period
    tickets_resolved_in_period BIGINT, -- Tickets moved to RESOLVED by this admin in period
    tickets_closed_in_period BIGINT,   -- Tickets moved to CLOSED by this admin in period
    avg_resolution_time_hours DECIMAL(10,2) -- For tickets resolved in period by this admin
) AS $$
BEGIN
    IF NOT public.current_user_has_role('super-admin') THEN
        RAISE EXCEPTION 'Unauthorized: Only super-admins can view team performance analytics.';
    END IF;

    RETURN QUERY
    WITH relevant_admins AS (
        SELECT adm.user_id, COALESCE(u.raw_user_meta_data->>'full_name', adm.user_id::TEXT) AS name, adm.roles
        FROM public.admins adm
        JOIN auth.users u ON adm.user_id = u.id
        WHERE (p_admin_id_filter IS NULL OR adm.user_id = p_admin_id_filter)
          AND (p_role_filter IS NULL OR p_role_filter = ANY(adm.roles))
          AND ( -- Ensure admin is part of ticket handling roles if no specific admin is filtered
                p_admin_id_filter IS NOT NULL OR -- if specific admin, show their stats regardless of role filter for this query
                'telecalling-owner-team' = ANY(adm.roles) OR
                'telecalling-tenant-team' = ANY(adm.roles) OR
                'super-admin' = ANY(adm.roles)
              )
    ),
    -- For assigned_in_period, we'd need an audit log of assignments.
    -- Approximating by tickets currently assigned to them that were created/updated recently. This is not ideal.
    -- Let's count tickets where their assignment was the *last* significant update in the period leading to an assigned state.
    -- This is still tricky without a proper assignment log.
    -- For now, this will be simplified to: Tickets they currently hold that moved to an assigned state in period.

    tickets_resolved AS (
        -- Tickets moved to RESOLVED by this admin (need audit log for who resolved it)
        -- Assuming assigned_support_admin_id is the one who resolves.
        SELECT
            t.assigned_support_admin_id AS resolver_admin_id,
            COUNT(t.ticket_id) AS resolved_count,
            AVG(EXTRACT(EPOCH FROM (t.resolved_at - t.created_at))/3600.0) AS avg_res_time -- From creation to resolution
        FROM public.tickets t
        WHERE t.status = 'RESOLVED'
          AND t.resolved_at >= p_start_date AND t.resolved_at <= p_end_date
          AND t.assigned_support_admin_id IS NOT NULL
        GROUP BY t.assigned_support_admin_id
    ),
    tickets_closed AS (
        -- Tickets moved to CLOSED by this admin (similar audit issue)
        SELECT
            t.assigned_support_admin_id AS closer_admin_id, -- Assuming assigned admin is closer
            COUNT(t.ticket_id) AS closed_count
        FROM public.tickets t
        WHERE t.status = 'CLOSED'
          AND t.closed_at >= p_start_date AND t.closed_at <= p_end_date
          AND t.assigned_support_admin_id IS NOT NULL
        GROUP BY t.assigned_support_admin_id
    ),
    -- A better 'tickets_assigned_in_period' would require an audit table like:
    -- ticket_assignments_log(ticket_id, assigned_to_admin_id, assigned_at, assigned_by_admin_id)
    -- For now, count currently assigned tickets to them:
    current_assigned_tickets AS (
         SELECT t.assigned_support_admin_id as admin_id, count(t.ticket_id) as currently_assigned_count
         FROM public.tickets t
         WHERE t.assigned_support_admin_id IS NOT NULL
           AND t.status NOT IN ('RESOLVED', 'CLOSED', 'CANCELLED')
         GROUP BY t.assigned_support_admin_id
    )
    SELECT
        ra.user_id AS admin_id,
        ra.name AS admin_name,
        ra.roles,
        COALESCE(cat.currently_assigned_count, 0) AS tickets_assigned_in_period, -- Placeholder for now
        COALESCE(tr.resolved_count, 0) AS tickets_resolved_in_period,
        COALESCE(tc.closed_count, 0) AS tickets_closed_in_period,
        ROUND(COALESCE(tr.avg_res_time, 0.0), 2) AS avg_resolution_time_hours
    FROM relevant_admins ra
    LEFT JOIN tickets_resolved tr ON ra.user_id = tr.resolver_admin_id
    LEFT JOIN tickets_closed tc ON ra.user_id = tc.closer_admin_id
    LEFT JOIN current_assigned_tickets cat ON ra.user_id = cat.admin_id
    ORDER BY admin_name;

END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;
GRANT EXECUTE ON FUNCTION public.get_ticket_handling_performance_admin(DATE, DATE, UUID, public.admin_role_enum) TO authenticated;


-- FILE NAME: 06_13_admin_rental_application_functions.sql

-- Description: Functions for admins to manage rental applications.
-------------------------------------------------------------------------------

-- Function 1: admin_get_rental_applications
CREATE OR REPLACE FUNCTION public.admin_get_rental_applications(
    p_status_filter public.rental_application_status_enum[] DEFAULT NULL,
    p_assigned_admin_id_filter UUID DEFAULT NULL,
    p_property_id_filter UUID DEFAULT NULL,
    p_applicant_user_id_filter UUID DEFAULT NULL,
    p_landlord_user_id_filter UUID DEFAULT NULL,
    p_submitted_at_start TIMESTAMPTZ DEFAULT NULL,
    p_submitted_at_end TIMESTAMPTZ DEFAULT NULL,
    p_search_term TEXT DEFAULT NULL,
    p_sort_by TEXT DEFAULT 'submitted_at',
    p_sort_direction TEXT DEFAULT 'DESC',
    p_offset INTEGER DEFAULT 0,
    p_limit INTEGER DEFAULT 10
)
RETURNS TABLE (
    application_id UUID,
    property_id UUID,
    property_address TEXT,
    property_locality TEXT,
    property_city TEXT,
    applicant_user_id UUID,
    applicant_name TEXT,
    applicant_email TEXT,
    applicant_phone TEXT,
    landlord_user_id UUID,
    landlord_name TEXT,
    application_status public.rental_application_status_enum,
    application_data JSONB,
    assigned_admin_id UUID,
    assigned_admin_name TEXT,
    submitted_at TIMESTAMPTZ,
    status_updated_at TIMESTAMPTZ,
    total_count BIGINT
) AS $$
DECLARE
    v_sql TEXT;
    v_order_by_clause TEXT;
    v_final_sort_by TEXT;
    v_final_sort_direction TEXT;
    v_allowed_sort_columns TEXT[] := ARRAY['submitted_at', 'status_updated_at', 'property_address', 'applicant_name', 'application_status'];
BEGIN
    IF NOT (
        public.current_user_has_role('super-admin') OR
        public.current_user_has_role('telecalling-owner-team') OR
        public.current_user_has_role('telecalling-tenant-team') OR
        public.current_user_has_role('accounts-team')
    ) THEN
        RAISE EXCEPTION 'Unauthorized: Insufficient privileges to view rental applications.';
    END IF;

    IF p_sort_by IS NOT NULL AND p_sort_by = ANY(v_allowed_sort_columns) THEN
        v_final_sort_by := 'ca.' || quote_ident(p_sort_by);
    ELSE
        v_final_sort_by := 'ca.submitted_at';
    END IF;

    IF p_sort_direction IS NOT NULL AND upper(p_sort_direction) IN ('ASC', 'DESC') THEN
        v_final_sort_direction := upper(p_sort_direction);
    ELSE
        v_final_sort_direction := 'DESC';
    END IF;
    v_order_by_clause := format('ORDER BY %s %s NULLS LAST, ca.application_id ASC', v_final_sort_by, v_final_sort_direction);

    v_sql := $QUERY$
    WITH base_applications AS (
        SELECT
            ra.application_id,
            ra.property_id,
            p.address AS property_address,
            p.locality AS property_locality,
            p.city AS property_city,
            ra.user_id AS applicant_user_id,
            applicant_auth.raw_user_meta_data->>'full_name' AS applicant_name,
            applicant_auth.email::TEXT AS applicant_email,
            applicant_auth.phone::TEXT AS applicant_phone,
            ra.landlord_user_id,
            landlord_auth.raw_user_meta_data->>'full_name' AS landlord_name,
            ra.status AS application_status,
            ra.application_data,
            ra.assigned_admin_id,
            assigned_admin_auth.raw_user_meta_data->>'full_name' AS assigned_admin_name,
            ra.submitted_at,
            ra.status_updated_at
        FROM public.rental_applications ra
        JOIN public.properties p ON ra.property_id = p.property_id
        JOIN auth.users applicant_auth ON ra.user_id = applicant_auth.id
        JOIN auth.users landlord_auth ON ra.landlord_user_id = landlord_auth.id
        LEFT JOIN public.admins assigned_adm ON ra.assigned_admin_id = assigned_adm.user_id
        LEFT JOIN auth.users assigned_admin_auth ON assigned_adm.user_id = assigned_admin_auth.id
        WHERE
            ($1 IS NULL OR ra.status = ANY($1)) AND
            ($2 IS NULL OR ra.assigned_admin_id = $2) AND
            ($3 IS NULL OR ra.property_id = $3) AND
            ($4 IS NULL OR ra.user_id = $4) AND
            ($5 IS NULL OR ra.landlord_user_id = $5) AND
            ($6 IS NULL OR ra.submitted_at >= $6) AND
            ($7 IS NULL OR ra.submitted_at <= $7) AND
            ($8 IS NULL OR (
                ra.application_id::text ILIKE '%' || $8 || '%' OR
                applicant_auth.raw_user_meta_data->>'full_name' ILIKE '%' || $8 || '%' OR
                applicant_auth.email ILIKE '%' || $8 || '%' OR
                p.address ILIKE '%' || $8 || '%' OR
                p.locality ILIKE '%' || $8 || '%'
            ))
    ),
    counted_applications AS (
        SELECT *, COUNT(*) OVER() AS total_rows FROM base_applications
    )
    SELECT
        ca.application_id, ca.property_id, ca.property_address, ca.property_locality, ca.property_city,
        ca.applicant_user_id, ca.applicant_name, ca.applicant_email, ca.applicant_phone,
        ca.landlord_user_id, ca.landlord_name, ca.application_status, ca.application_data,
        ca.assigned_admin_id, ca.assigned_admin_name, ca.submitted_at, ca.status_updated_at,
        ca.total_rows
    FROM counted_applications ca
    $QUERY$;

    v_sql := v_sql || ' ' || v_order_by_clause || ' OFFSET $9 LIMIT $10';

    RETURN QUERY EXECUTE v_sql
        USING p_status_filter, p_assigned_admin_id_filter, p_property_id_filter,
              p_applicant_user_id_filter, p_landlord_user_id_filter,
              p_submitted_at_start, p_submitted_at_end, p_search_term,
              p_offset, p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;
GRANT EXECUTE ON FUNCTION public.admin_get_rental_applications(public.rental_application_status_enum[], UUID, UUID, UUID, UUID, TIMESTAMPTZ, TIMESTAMPTZ, TEXT, TEXT, TEXT, INTEGER, INTEGER) TO authenticated;


-- Function 2: admin_get_rental_application_details
CREATE OR REPLACE FUNCTION public.admin_get_rental_application_details(p_application_id UUID)
RETURNS TABLE (
    application_id UUID,
    property_id UUID,
    user_id UUID,
    interaction_id UUID,
    landlord_user_id UUID,
    application_data JSONB,
    status public.rental_application_status_enum,
    admin_notes TEXT,
    assigned_admin_id UUID,
    submitted_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ,
    status_updated_at TIMESTAMPTZ,
    property_address TEXT,
    property_locality TEXT,
    property_city TEXT,
    property_pincode INTEGER,
    property_type public.property_type_enum,
    property_listing_type public.listing_type_enum,
    property_price DECIMAL,
    applicant_name TEXT,
    applicant_email TEXT,
    applicant_phone TEXT,
    applicant_profile_details JSONB,
    landlord_name TEXT,
    landlord_email TEXT,
    landlord_phone TEXT,
    assigned_admin_name TEXT,
    assigned_admin_email TEXT,
    interaction_visit_scheduled_for DATE,
    interaction_visit_completed_at TIMESTAMPTZ,
    interaction_original_status public.interaction_status_enum
) AS $$
BEGIN
    IF NOT (
        public.current_user_has_role('super-admin') OR
        public.current_user_has_role('telecalling-owner-team') OR
        public.current_user_has_role('telecalling-tenant-team') OR
        public.current_user_has_role('accounts-team')
    ) THEN
        RAISE EXCEPTION 'Unauthorized: Insufficient privileges to view application details.';
    END IF;

    RETURN QUERY
    SELECT
        ra.*,
        p.address, p.locality, p.city, p.pincode, p.property_type, p.listing_type, p.price,
        applicant_auth.raw_user_meta_data->>'full_name',
        applicant_auth.email::TEXT,
        applicant_auth.phone::TEXT,
        cust.profile_details,
        landlord_auth.raw_user_meta_data->>'full_name',
        landlord_auth.email::TEXT,
        landlord_auth.phone::TEXT,
        assigned_admin_auth.raw_user_meta_data->>'full_name',
        assigned_admin_auth.email::TEXT,
        ci.scheduled_for,
        ci.visited_at,
        ci.status
    FROM public.rental_applications ra
    JOIN public.properties p ON ra.property_id = p.property_id
    JOIN auth.users applicant_auth ON ra.user_id = applicant_auth.id
    LEFT JOIN public.customers cust ON ra.user_id = cust.user_id
    JOIN auth.users landlord_auth ON ra.landlord_user_id = landlord_auth.id
    LEFT JOIN public.admins assigned_adm ON ra.assigned_admin_id = assigned_adm.user_id
    LEFT JOIN auth.users assigned_admin_auth ON assigned_adm.user_id = assigned_admin_auth.id
    JOIN public.customers_interaction ci ON ra.interaction_id = ci.interaction_id
    WHERE ra.application_id = p_application_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;
GRANT EXECUTE ON FUNCTION public.admin_get_rental_application_details(UUID) TO authenticated;


-- Function 3: admin_self_assign_rental_application
CREATE OR REPLACE FUNCTION public.admin_self_assign_rental_application(p_application_id UUID)
RETURNS VOID AS $$
DECLARE
    v_calling_admin_id UUID := auth.uid();
BEGIN
    IF NOT (
        public.current_user_has_role('telecalling-owner-team') OR
        public.current_user_has_role('telecalling-tenant-team')
    ) THEN
        RAISE EXCEPTION 'Unauthorized: Only telecalling team members can self-assign applications.';
    END IF;

    UPDATE public.rental_applications
    SET assigned_admin_id = v_calling_admin_id,
        status = 'REVIEW_IN_PROGRESS',
        status_updated_at = CURRENT_TIMESTAMP,
        updated_at = CURRENT_TIMESTAMP
    WHERE application_id = p_application_id
      AND assigned_admin_id IS NULL
      AND status = 'SUBMITTED';

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Application ID % not found, already assigned, or not in SUBMITTED state.', p_application_id;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.admin_self_assign_rental_application(UUID) TO authenticated;


-- Function 4: admin_assign_rental_application
CREATE OR REPLACE FUNCTION public.admin_assign_rental_application(p_application_id UUID, p_target_admin_id UUID)
RETURNS VOID AS $$
BEGIN
    IF NOT public.current_user_has_role('super-admin') THEN
        RAISE EXCEPTION 'Unauthorized: Only super-admins can assign applications to others.';
    END IF;

    IF NOT (
        public.user_is_admin_with_role(p_target_admin_id, 'telecalling-owner-team') OR
        public.user_is_admin_with_role(p_target_admin_id, 'telecalling-tenant-team')
    ) THEN
        RAISE EXCEPTION 'Target admin ID % does not have a required telecalling role.', p_target_admin_id;
    END IF;

    UPDATE public.rental_applications
    SET assigned_admin_id = p_target_admin_id,
        status = CASE WHEN status = 'SUBMITTED' THEN 'REVIEW_IN_PROGRESS'::public.rental_application_status_enum ELSE status END,
        status_updated_at = CURRENT_TIMESTAMP,
        updated_at = CURRENT_TIMESTAMP
    WHERE application_id = p_application_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Application ID % not found.', p_application_id;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.admin_assign_rental_application(UUID, UUID) TO authenticated;


-- Function 5: admin_unassign_rental_application
CREATE OR REPLACE FUNCTION public.admin_unassign_rental_application(p_application_id UUID)
RETURNS VOID AS $$
DECLARE
    v_current_assigned_admin_id UUID;
BEGIN
    SELECT assigned_admin_id INTO v_current_assigned_admin_id FROM public.rental_applications WHERE application_id = p_application_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Application ID % not found.', p_application_id;
    END IF;

    IF NOT (
        public.current_user_has_role('super-admin') OR
        (v_current_assigned_admin_id IS NOT NULL AND v_current_assigned_admin_id = auth.uid())
    ) THEN
        RAISE EXCEPTION 'Unauthorized: Only super-admins or the currently assigned admin can unassign.';
    END IF;

    UPDATE public.rental_applications
    SET assigned_admin_id = NULL,
        status = 'SUBMITTED', -- Revert to SUBMITTED, assuming it's unassigned to be picked up again
        status_updated_at = CURRENT_TIMESTAMP,
        updated_at = CURRENT_TIMESTAMP
    WHERE application_id = p_application_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.admin_unassign_rental_application(UUID) TO authenticated;


-- Function 6: admin_update_rental_application_status
CREATE OR REPLACE FUNCTION public.admin_update_rental_application_status(
    p_application_id UUID,
    p_new_status public.rental_application_status_enum,
    p_admin_note TEXT DEFAULT NULL
)
RETURNS VOID AS $$
DECLARE
    v_current_app public.rental_applications%ROWTYPE;
    v_calling_admin_id UUID := auth.uid();
    v_can_update BOOLEAN := FALSE;
BEGIN
    SELECT * INTO v_current_app FROM public.rental_applications WHERE application_id = p_application_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'Application ID % not found.', p_application_id; END IF;

    -- Basic permission: Super-admin or assigned admin can update
    IF public.current_user_has_role('super-admin') OR v_current_app.assigned_admin_id = v_calling_admin_id THEN
        v_can_update := TRUE;
    END IF;

    -- Accounts team can update to/from payment-related statuses
    IF public.current_user_has_role('accounts-team') AND
       (v_current_app.status IN ('APPROVED_AWAITING_PAYMENT', 'PAYMENT_CONFIRMED') OR
        p_new_status IN ('APPROVED_AWAITING_PAYMENT', 'PAYMENT_CONFIRMED')) THEN
        v_can_update := TRUE;
    END IF;

    -- Telecalling teams can update if assigned, or if it's in a state they manage (e.g. SUBMITTED, REVIEW_IN_PROGRESS)
    IF (public.current_user_has_role('telecalling-owner-team') OR public.current_user_has_role('telecalling-tenant-team')) THEN
        IF v_current_app.assigned_admin_id = v_calling_admin_id OR
           v_current_app.status IN ('SUBMITTED', 'REVIEW_IN_PROGRESS', 'AWAITING_LANDLORD_CONTACT', 'LANDLORD_INFO_PENDING', 'DOCUMENTS_REQUESTED') THEN
           v_can_update := TRUE;
        END IF;
    END IF;


    IF NOT v_can_update THEN
        RAISE EXCEPTION 'Unauthorized: You do not have permission to update the status of this application from % to %.', v_current_app.status, p_new_status;
    END IF;

    -- Prevent illegal status transitions (example: cannot go from REJECTED to APPROVED_AWAITING_PAYMENT directly by non-superadmin)
    -- This logic can be expanded based on business rules.
    IF NOT public.current_user_has_role('super-admin') THEN
        IF (v_current_app.status IN ('LANDLORD_REJECTED', 'APPLICATION_WITHDRAWN_CUSTOMER', 'CANCELLED_ADMIN') AND
            p_new_status NOT IN ('LANDLORD_REJECTED', 'APPLICATION_WITHDRAWN_CUSTOMER', 'CANCELLED_ADMIN')) THEN
            RAISE EXCEPTION 'Cannot change status from a final rejected/cancelled state: % to % without super-admin override.', v_current_app.status, p_new_status;
        END IF;
        IF (v_current_app.status = 'TENANCY_ACTIVE' AND p_new_status <> 'TENANCY_ACTIVE') THEN
             RAISE EXCEPTION 'Cannot change status from TENANCY_ACTIVE without super-admin override.';
        END IF;
    END IF;


    UPDATE public.rental_applications
    SET status = p_new_status,
        admin_notes = CASE
                          WHEN p_admin_note IS NOT NULL AND TRIM(p_admin_note) <> '' THEN
                              COALESCE(admin_notes || E'\n\n', '') ||
                              '[' || TO_CHAR(CURRENT_TIMESTAMP, 'YYYY-MM-DD HH24:MI') || ' by ' || (SELECT COALESCE(raw_user_meta_data->>'full_name', auth.uid()::TEXT) FROM auth.users WHERE id = v_calling_admin_id) || E'] Status: ' || p_new_status || E'. Notes:\n' ||
                              TRIM(p_admin_note)
                          ELSE
                              COALESCE(admin_notes || E'\n\n', '') ||
                              '[' || TO_CHAR(CURRENT_TIMESTAMP, 'YYYY-MM-DD HH24:MI') || ' by ' || (SELECT COALESCE(raw_user_meta_data->>'full_name', auth.uid()::TEXT) FROM auth.users WHERE id = v_calling_admin_id) || E'] Status changed to: ' || p_new_status
                      END,
        status_updated_at = CURRENT_TIMESTAMP,
        updated_at = CURRENT_TIMESTAMP
    WHERE application_id = p_application_id;

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.admin_update_rental_application_status(UUID, public.rental_application_status_enum, TEXT) TO authenticated;


-- Function 7: admin_add_rental_application_note
CREATE OR REPLACE FUNCTION public.admin_add_rental_application_note(p_application_id UUID, p_note TEXT)
RETURNS VOID AS $$
DECLARE
    v_calling_admin_id UUID := auth.uid();
BEGIN
    IF NOT (
        public.current_user_has_role('super-admin') OR
        public.current_user_has_role('telecalling-owner-team') OR
        public.current_user_has_role('telecalling-tenant-team') OR
        public.current_user_has_role('accounts-team')
    ) THEN
        RAISE EXCEPTION 'Unauthorized: Insufficient privileges to add notes.';
    END IF;

    IF p_note IS NULL OR TRIM(p_note) = '' THEN
        RAISE EXCEPTION 'Note cannot be empty.';
    END IF;

    UPDATE public.rental_applications
    SET admin_notes = COALESCE(admin_notes || E'\n\n', '') ||
                      '[' || TO_CHAR(CURRENT_TIMESTAMP, 'YYYY-MM-DD HH24:MI') || ' by ' || (SELECT COALESCE(raw_user_meta_data->>'full_name', auth.uid()::TEXT) FROM auth.users WHERE id = v_calling_admin_id) || E'] Note:\n' ||
                      TRIM(p_note),
        updated_at = CURRENT_TIMESTAMP
    WHERE application_id = p_application_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Application ID % not found.', p_application_id;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.admin_add_rental_application_note(UUID, TEXT) TO authenticated;


-- Function 8: admin_finalize_lease_from_application
CREATE OR REPLACE FUNCTION public.admin_finalize_lease_from_application(p_application_id UUID)
RETURNS VOID AS $$
DECLARE
    v_app_data public.rental_applications%ROWTYPE;
    v_calling_admin_id UUID := auth.uid();
    v_can_finalize BOOLEAN := FALSE;
BEGIN
    SELECT * INTO v_app_data FROM public.rental_applications WHERE application_id = p_application_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'Application ID % not found.', p_application_id; END IF;

    -- Permission check:
    IF public.current_user_has_role('super-admin') THEN
        v_can_finalize := TRUE;
    ELSIF (public.current_user_has_role('telecalling-owner-team') OR public.current_user_has_role('telecalling-tenant-team')) AND
          v_app_data.assigned_admin_id = v_calling_admin_id AND
          v_app_data.status IN ('PAYMENT_CONFIRMED', 'LEASE_FINALIZED') THEN
        v_can_finalize := TRUE;
    ELSIF public.current_user_has_role('accounts-team') AND v_app_data.status = 'PAYMENT_CONFIRMED' THEN
        -- Accounts team can move from PAYMENT_CONFIRMED to LEASE_FINALIZED, but maybe not to TENANCY_ACTIVE directly.
        -- For simplicity now, let's allow them to trigger this if status is PAYMENT_CONFIRMED.
        v_can_finalize := TRUE;
    END IF;

    IF NOT v_can_finalize THEN
        RAISE EXCEPTION 'Unauthorized: You do not have permission to finalize this lease, or application is not in the correct state (%).', v_app_data.status;
    END IF;

    IF v_app_data.status NOT IN ('PAYMENT_CONFIRMED', 'LEASE_FINALIZED') THEN
        RAISE EXCEPTION 'Application status must be PAYMENT_CONFIRMED or LEASE_FINALIZED to finalize the lease. Current status: %', v_app_data.status;
    END IF;

    -- Check if property already has a tenant (and is not the current applicant)
    IF EXISTS (SELECT 1 FROM public.properties WHERE property_id = v_app_data.property_id AND tenant IS NOT NULL AND tenant <> v_app_data.user_id) THEN
        RAISE EXCEPTION 'Property % is already occupied by another tenant. Cannot finalize lease.', v_app_data.property_id;
    END IF;

    -- Start transaction
    BEGIN
        UPDATE public.rental_applications
        SET status = 'TENANCY_ACTIVE',
            status_updated_at = CURRENT_TIMESTAMP,
            updated_at = CURRENT_TIMESTAMP
        WHERE application_id = p_application_id;

        UPDATE public.properties
        SET tenant = v_app_data.user_id,
            admin_status = 'RENTED',
            updated_at = CURRENT_TIMESTAMP
        WHERE property_id = v_app_data.property_id;

        UPDATE public.customers_interaction
        SET status = 'LEASE_CONVERTED',
            updated_at = CURRENT_TIMESTAMP
        WHERE interaction_id = v_app_data.interaction_id;

        -- Optional: Create initial rent records (call another function or inline logic)
        -- PERFORM public.admin_create_initial_rent_records_for_tenancy(v_app_data.property_id, v_app_data.user_id);

        -- Optional: Update other pending applications for the same property
        UPDATE public.rental_applications
        SET status = 'CANCELLED_ADMIN',
            admin_notes = COALESCE(admin_notes || E'\n\n', '') || 'Automatically cancelled as property was leased to another applicant.',
            status_updated_at = CURRENT_TIMESTAMP,
            updated_at = CURRENT_TIMESTAMP
        WHERE property_id = v_app_data.property_id
          AND application_id <> p_application_id
          AND status NOT IN ('TENANCY_ACTIVE', 'LEASE_FINALIZED', 'APPLICATION_WITHDRAWN_CUSTOMER', 'LANDLORD_REJECTED', 'CANCELLED_ADMIN');

    EXCEPTION
        WHEN OTHERS THEN
            RAISE WARNING 'Error during lease finalization for application %: %', p_application_id, SQLERRM;
            RAISE; -- Re-raise the exception to ensure transaction rollback
    END;
    -- End transaction
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.admin_finalize_lease_from_application(UUID) TO authenticated;


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


-- FILE NAME: 08_initial_data.sql
-- Description: Seed initial data like admin roles (implicit in public.admins), visit plans, management plans.
-------------------------------------------------------------------------------

-- Add sample visit plans
INSERT INTO public.visit_plans (name, description, visits, price, is_active) VALUES
('Starter Pack', '5 property visits', 5, 10.00, true),
('Bronze Pack', '10 property visits', 10, 18.00, true),
('Silver Pack', '20 property visits', 20, 32.00, true),
('Gold Pack', '50 property visits', 50, 70.00, true)
ON CONFLICT (name) DO UPDATE SET
    description = EXCLUDED.description,
    visits = EXCLUDED.visits,
    price = EXCLUDED.price,
    is_active = EXCLUDED.is_active,
    updated_at = CURRENT_TIMESTAMP;

-- Add sample management service plans
INSERT INTO public.management_service_plans (name, percentage, description, is_active) VALUES
('Basic Self-Managed', 0.00, 'No active management. For owner reference or basic listing services only.', true),
('Standard Rental Management', 8.00, 'Inventory monitoring, tax & utilities tracking, maintenance intimation, reports, client support, rent collection, property marketing.', true),
('Premium Rental Management', 10.00, 'All Standard features + rental agreement drafting, tenant screening, tenant problem handling, maintenance undertaking, dedicated property manager.', true),
('Property Care Plus', 15.00, 'All Premium features + enhanced maintenance coverage and proactive property checks.', true) -- Adjusted name and percentage for variety
ON CONFLICT (name) DO UPDATE SET
    percentage = EXCLUDED.percentage,
    description = EXCLUDED.description,
    is_active = EXCLUDED.is_active,
    updated_at = CURRENT_TIMESTAMP;

-- Add initial services
INSERT INTO public.services (service_name, description, category) VALUES
('General Maintenance', 'Basic upkeep and minor repairs.', 'MAINTENANCE'),
('Plumbing Repair', 'Fixing leaks, clogs, pipe issues.', 'REPAIR'),
('Electrical Repair', 'Wiring, fixture, and outage repairs.', 'REPAIR'),
('HVAC Service', 'Heating, Ventilation, and Air Conditioning maintenance and repair.', 'REPAIR'),
('Interior Design Consultation', 'Consultation for interior aesthetics.', 'DESIGN'),
('Security Guard Services', 'On-site guards.', 'SECURITY'),
('Landscaping & Gardening', 'Garden design, lawn care, tree trimming.', 'LANDSCAPING'),
('Swimming Pool Maintenance', 'Cleaning, chemical balancing, equipment checks.', 'POOL'),
('Pest Control Services', 'Extermination and prevention services.', 'PEST_CONTROL'),
('Residential Cleaning', 'Regular cleaning services for homes.', 'CLEANING'),
('Appliance Repair Service', 'Fixing major household appliances.', 'REPAIR'),
('Painting (Interior/Exterior)', 'Interior and exterior painting services.', 'MAINTENANCE'),
('Roofing Repair & Maintenance', 'Fixing leaks and damage to roofs.', 'REPAIR'),
('Carpentry & Woodwork', 'Custom woodwork, repairs, installations.', 'CONSTRUCTION'),
('Deep Cleaning Services', 'Intensive cleaning for move-in/out or special occasions.', 'CLEANING'),
('Utility Bill Payment Assistance', 'Assistance with managing and paying utility bills.', 'UTILITIES')
ON CONFLICT (service_name) DO NOTHING;


-- Add an initial super-admin user.
-- IMPORTANT: Replace 'your-super-admin-auth-user-id-here' with the actual UUID
-- from the auth.users table for the user you want to be the super-admin.
-- This user MUST exist in auth.users before this script is run.
DO $$
DECLARE
  -- !!! IMPORTANT: REPLACE THIS UUID WITH THE ACTUAL auth.users.id OF YOUR SUPER ADMIN USER !!!
  super_admin_auth_id UUID := 'a76d0b87-a059-41a6-b527-a4f05f8173eb'; -- <<< REPLACE THIS PLACEHOLDER UUID
  telecalling_owner_admin_auth_id UUID := 'd2a75546-f9d3-45a9-b8b7-51ebf9f2f54f'; -- Example for another admin
  marketing_admin_auth_id UUID := 'd2a75546-f9d3-45a9-b8b7-51ebf9f2f54f'; -- Example
BEGIN
  IF super_admin_auth_id = '00000000-0000-0000-0000-000000000000' THEN
      RAISE WARNING 'Placeholder UUID detected for super_admin_auth_id. Please replace it in 08_initial_data.sql before running.';
  ELSIF EXISTS (SELECT 1 FROM auth.users WHERE id = super_admin_auth_id) THEN
      INSERT INTO public.admins (user_id, roles, is_active, served_pincodes)
      VALUES (super_admin_auth_id, ARRAY['super-admin']::public.admin_role_enum[], TRUE, NULL)
      ON CONFLICT (user_id) DO UPDATE SET
        roles = public.admins.roles || ARRAY['super-admin']::public.admin_role_enum[], -- Add super-admin if not present
        is_active = TRUE;
      RAISE NOTICE 'Ensured super-admin role for user %', super_admin_auth_id;
  ELSE
      RAISE WARNING 'User ID % for super-admin not found in auth.users. Cannot assign super-admin role.', super_admin_auth_id;
  END IF;

  -- Example: Add another admin with specific roles (ensure these UUIDs are also replaced if used)
  IF telecalling_owner_admin_auth_id <> '11111111-1111-1111-1111-111111111111' AND EXISTS (SELECT 1 FROM auth.users WHERE id = telecalling_owner_admin_auth_id) THEN
    INSERT INTO public.admins (user_id, roles, is_active, served_pincodes)
    VALUES (telecalling_owner_admin_auth_id, ARRAY['telecalling-owner-team', 'telecalling-tenant-team']::public.admin_role_enum[], TRUE, ARRAY[627001, 627002])
    ON CONFLICT (user_id) DO UPDATE SET
        roles = EXCLUDED.roles, is_active = EXCLUDED.is_active, served_pincodes = EXCLUDED.served_pincodes;
    RAISE NOTICE 'Added/Updated admin % with telecalling roles.', telecalling_owner_admin_auth_id;
  END IF;

  IF marketing_admin_auth_id <> '22222222-2222-2222-2222-222222222222' AND EXISTS (SELECT 1 FROM auth.users WHERE id = marketing_admin_auth_id) THEN
    INSERT INTO public.admins (user_id, roles, is_active, served_pincodes)
    VALUES (marketing_admin_auth_id, ARRAY['marketing-team']::public.admin_role_enum[], TRUE, ARRAY[627005, 627007, 627011])
    ON CONFLICT (user_id) DO UPDATE SET
        roles = EXCLUDED.roles, is_active = EXCLUDED.is_active, served_pincodes = EXCLUDED.served_pincodes;
    RAISE NOTICE 'Added/Updated admin % with marketing role.', marketing_admin_auth_id;
  END IF;

END $$;


-- FILE NAME: 09_seed_properties.sql
-- Description: Seeds initial property data into the 'properties' table.
-- Depends on: 00_enums.sql, 01_tables.sql, 08_initial_data.sql (for admin users and plans)
-------------------------------------------------------------------------------

DO $$
DECLARE
    -- These users MUST exist in auth.users and relevant ones in public.admins.
    v_owner_submitter_user_id UUID := 'a76d0b87-a059-41a6-b527-a4f05f8173eb'; -- An admin who will act as submitter/owner
    v_another_owner_user_id UUID := 'd2a75546-f9d3-45a9-b8b7-51ebf9f2f54f'; -- Another user who can be a submitter
    v_tenant_user_id_1 UUID := 'd2a75546-f9d3-45a9-b8b7-51ebf9f2f54f';     -- A user who will be a tenant
    v_tenant_user_id_2 UUID := 'a76d0b87-a059-41a6-b527-a4f05f8173eb';     -- Another tenant

    v_standard_plan_id UUID;
    v_premium_plan_id UUID;

    prop1_id UUID;
    prop2_id UUID;
    prop3_id UUID;
    prop4_id UUID;
    prop5_id UUID;
    prop6_id UUID;
    prop7_id UUID; -- For a SUBMITTED property
    prop8_id UUID; -- For a RENTED property
BEGIN

    -- Basic UUID placeholder check
    IF v_owner_submitter_user_id = '00000000-0000-0000-0000-000000000000' OR
       v_another_owner_user_id = '11111111-1111-1111-1111-111111111111' OR
       v_tenant_user_id_1 = '33333333-3333-3333-3333-333333333333' OR
       v_tenant_user_id_2 = '44444444-4444-4444-4444-444444444444' THEN
       RAISE EXCEPTION 'Placeholder UUIDs detected for users in 09_seed_properties.sql. Please replace them with actual auth.users.id values before running.';
    END IF;

    -- Check if users exist (basic check, assumes they are in auth.users)
    -- For v_owner_submitter_user_id, it's also assumed this user is an admin if they are uploading images/docs "as admin"
    PERFORM 1 FROM auth.users WHERE id = v_owner_submitter_user_id;
    IF NOT FOUND THEN 
        RAISE WARNING 'User ID for v_owner_submitter_user_id (%) not found in auth.users. Skipping mock property seeding.', v_owner_submitter_user_id; 
        RETURN; 
    END IF;
    
    PERFORM 1 FROM auth.users WHERE id = v_another_owner_user_id;
    IF NOT FOUND THEN 
        RAISE WARNING 'User ID for v_another_owner_user_id (%) not found. Skipping mock property seeding.', v_another_owner_user_id; 
        RETURN; 
    END IF;
    
    PERFORM 1 FROM auth.users WHERE id = v_tenant_user_id_1;
    IF NOT FOUND THEN 
        RAISE WARNING 'User ID for v_tenant_user_id_1 (%) not found. Skipping mock property seeding.', v_tenant_user_id_1; 
        RETURN; 
    END IF;
    
    PERFORM 1 FROM auth.users WHERE id = v_tenant_user_id_2;
    IF NOT FOUND THEN 
        RAISE WARNING 'User ID for v_tenant_user_id_2 (%) not found. Skipping mock property seeding.', v_tenant_user_id_2; 
        RETURN; 
    END IF;


    -- Get Plan IDs
    SELECT plan_id INTO v_standard_plan_id FROM public.management_service_plans WHERE name = 'Standard Rental Management';
    SELECT plan_id INTO v_premium_plan_id FROM public.management_service_plans WHERE name = 'Premium Rental Management';

    IF v_standard_plan_id IS NULL OR v_premium_plan_id IS NULL THEN
        RAISE EXCEPTION 'Management plan IDs not found. Ensure 08_initial_data.sql was run correctly and plans exist.';
    END IF;


    RAISE NOTICE 'Seeding properties in Tirunelveli...';

    -- Property 1: House for Sale, Listed, by v_owner_submitter_user_id
    INSERT INTO public.properties (
        property_type, listing_type, price, area, area_unit, description, locality, city, address, pincode, latitude, longitude, year_built,
        nearest_hospital, nearest_school, nearest_busstop, proximity_unit,
        admin_status, is_listed, is_featured, is_exclusive, details,
        submitter, submitter_type, submitted_at, availability_status, can_reachout, advance_amount
    ) VALUES (
        'HOUSE', 'SALE', 7500000.00, 1800.00, 'SQ_FT', 'Spacious 3 BHK Independent Villa near St. Xavier''s College. Well-maintained.', 'Palayamkottai', 'Tirunelveli', '15, College Road, Palayamkottai', 627002, 8.715123, 77.745678, 2012,
        1.2, 0.5, 0.3, 'KM',
        'MARKETING_VERIFIED', TRUE, TRUE, FALSE, -- Assuming it passed all internal checks to be listed
        '{"house_type": "INDEPENDENT_VILLA", "house_name": "Xavier''s View Villa", "num_bedrooms": 3, "num_bathrooms": 3, "num_balconies": 2, "total_floors": 2, "floor_number": null, "num_carparking": 1, "furnished_status": "SEMI_FURNISHED", "facing_direction": "EAST", "is_corner_plot": false, "water_source": "BOTH", "power_backup": "PARTIAL"}'::jsonb,
        v_owner_submitter_user_id, 'OWNER', CURRENT_TIMESTAMP - INTERVAL '10 days', 'READY_TO_MOVE', TRUE, NULL -- No advance for sale
    ) RETURNING property_id INTO prop1_id;

    INSERT INTO public.property_images (property_id, image_url, display_order, is_internal_image, uploaded_by) VALUES
    (prop1_id, 'https://placehold.co/600x400/EFEFEF/AAAAAA?text=Villa+Exterior', 0, FALSE, v_owner_submitter_user_id),
    (prop1_id, 'https://placehold.co/600x400/EEEEEE/31343C?text=Living+Area', 1, FALSE, v_owner_submitter_user_id);

    INSERT INTO public.property_documents (property_id, document_type, document_url, file_name, uploaded_by) VALUES
    (prop1_id, 'Sale Deed Copy', 'https://example.com/docs/prop1_sale_deed.pdf', 'prop1_sale_deed.pdf', v_owner_submitter_user_id);


    -- Property 2: Land for Sale, Listed, by v_another_owner_user_id
    INSERT INTO public.properties (
        property_type, listing_type, price, area, area_unit, description, locality, city, address, pincode, latitude, longitude,
        admin_status, is_listed, details,
        submitter, submitter_type, submitted_at, availability_status, can_reachout
    ) VALUES (
        'LAND', 'SALE', 4500000.00, 5.5, 'CENTS', 'Prime residential plot near Vannarpettai bridge.', 'Vannarpettai', 'Tirunelveli', 'Plot No. 22, Bridge View Layout, Vannarpettai', 627001, 8.709876, 77.751234,
        'MARKETING_VERIFIED', TRUE,
        '{"land_type": "RESIDENTIAL", "plot_dimensions": "50x48", "road_access_width_ft": 30}'::jsonb,
        v_another_owner_user_id, 'OWNER', CURRENT_TIMESTAMP - INTERVAL '5 days', 'READY_TO_MOVE', TRUE
    ) RETURNING property_id INTO prop2_id;

    INSERT INTO public.property_images (property_id, image_url, display_order, uploaded_by) VALUES
    (prop2_id, 'https://placehold.co/600x400/F5F5F5/888888?text=Plot+View+1', 0, v_another_owner_user_id);


    -- Property 3: Apartment for Rent, Listed, Occupied by v_tenant_user_id_1, Standard Plan, submitted by v_owner_submitter_user_id
    INSERT INTO public.properties (
        property_type, listing_type, price, area, area_unit, description, locality, city, address, pincode, latitude, longitude, year_built,
        admin_status, is_listed, details, rent_due_day, advance_amount,
        submitter, submitter_type, tenant, management_plan_id,
        submitted_at, availability_status, can_reachout
    ) VALUES (
        'HOUSE', 'RENTAL', 12000.00, 1100.00, 'SQ_FT', 'Modern 2 BHK apartment in a gated community.', 'Maharaja Nagar', 'Tirunelveli', 'Apt #305, Royal Gardens, Maharaja Nagar', 627011, 8.721111, 77.738888, 2018,
        'RENTED', TRUE, -- Listed and Rented
        '{"house_type": "APARTMENT_FLAT", "house_name": "Royal Gardens", "num_bedrooms": 2, "num_bathrooms": 2, "num_balconies": 1, "total_floors": 8, "floor_number": 3, "furnished_status": "UNFURNISHED"}'::jsonb,
        5, 50000.00, -- Rent due day, Advance
        v_owner_submitter_user_id, 'OWNER', v_tenant_user_id_1, v_standard_plan_id,
        CURRENT_TIMESTAMP - INTERVAL '20 days', 'READY_TO_MOVE', TRUE
    ) RETURNING property_id INTO prop3_id;

    INSERT INTO public.property_images (property_id, image_url, display_order, uploaded_by) VALUES
    (prop3_id, 'https://placehold.co/600x400/FFF0E1/A0522D?text=Apt+Building', 0, v_owner_submitter_user_id);


    -- Property 4: Commercial Building for Rent, Listed, Vacant, Premium Plan, submitted by v_owner_submitter_user_id
    INSERT INTO public.properties (
        property_type, listing_type, price, area, area_unit, description, locality, city, address, pincode, year_built,
        admin_status, is_listed, is_exclusive, details, rent_due_day, advance_amount,
        submitter, submitter_type, management_plan_id,
        submitted_at, availability_status
    ) VALUES (
        'BUILDING', 'RENTAL', 80000.00, 3500.00, 'SQ_FT', 'Ground floor commercial space, high footfall area.', 'Tirunelveli Junction', 'Tirunelveli', '78, Madurai Road, Tirunelveli Junction', 627001, 2005,
        'AWAITING_LISTING', TRUE, TRUE, -- Marketing verified, now listed by admin
        '{"building_type": "RETAIL", "building_name": "Junction Plaza", "total_floors": 3}'::jsonb,
        1, 300000.00,
        v_owner_submitter_user_id, 'BUILDER', v_premium_plan_id,
        CURRENT_TIMESTAMP - INTERVAL '15 days', 'READY_TO_MOVE'
    ) RETURNING property_id INTO prop4_id;


    -- Property 5: Agricultural Land, Listed, submitted by v_another_owner_user_id
    INSERT INTO public.properties (
        property_type, listing_type, price, area, area_unit, description, locality, city, address, pincode,
        admin_status, is_listed, details,
        submitter, submitter_type, submitted_at
    ) VALUES (
        'LAND', 'SALE', 9500000.00, 2.5, 'ACRES', 'Fertile agricultural land with good water source.', 'Melapalayam Outskirts', 'Tirunelveli', 'Survey No. 105/2B, Near Bypass Road', 627005,
        'MARKETING_VERIFIED', TRUE,
        '{"land_type": "AGRICULTURAL"}'::jsonb,
        v_another_owner_user_id, 'OWNER', CURRENT_TIMESTAMP - INTERVAL '3 days'
    ) RETURNING property_id INTO prop5_id;


    -- Property 6: House for Rent, submitted by v_owner_submitter_user_id, current status OWNER_VERIFIED (not yet listed)
    INSERT INTO public.properties (
        property_type, listing_type, price, area, area_unit, description, locality, city, address, pincode, year_built,
        admin_status, is_listed, details, rent_due_day, advance_amount,
        submitter, submitter_type, submitter_notes,
        submitted_at, availability_status
    ) VALUES (
        'HOUSE', 'RENTAL', 15000.00, 1400.00, 'SQ_FT', '3 BHK Independent House, calm residential area. Awaiting marketing visit.', 'Perumalpuram', 'Tirunelveli', 'Plot 45, 7th Street, Perumalpuram', 627007, 2008,
        'OWNER_VERIFIED', FALSE, -- Telecalling owner verified, awaiting marketing
        '{"house_type": "INDEPENDENT_VILLA", "num_bedrooms": 3, "num_bathrooms": 2, "furnished_status": "SEMI_FURNISHED"}'::jsonb,
        10, 60000.00,
        v_owner_submitter_user_id, 'OWNER', 'Owner contact verified. Property details seem correct. Needs marketing photos.',
        CURRENT_TIMESTAMP - INTERVAL '2 days', 'READY_TO_MOVE'
    ) RETURNING property_id INTO prop6_id;

    INSERT INTO public.property_images (property_id, image_url, display_order, is_internal_image, uploaded_by) VALUES
    (prop6_id, 'https://placehold.co/600x400/FDF5E6/A0522D?text=House+Front+(Awaiting+Marketing)', 0, FALSE, v_owner_submitter_user_id),
    (prop6_id, 'https://placehold.co/600x400/888888/EEEEEE?text=Internal+View+Needed', 0, TRUE, v_owner_submitter_user_id);


    -- Property 7: New submission by v_another_owner_user_id, status SUBMITTED
    INSERT INTO public.properties (
        property_type, listing_type, price, area, area_unit, description, locality, city, address, pincode,
        admin_status, is_listed, details,
        submitter, submitter_type, submitted_at, can_reachout, availability_status
    ) VALUES (
        'HOUSE', 'SALE', 5500000.00, 1200.00, 'SQ_FT', 'Newly submitted 2BHK for sale in NGO Colony.', 'NGO Colony', 'Tirunelveli', '12B, Anna Nagar, NGO Colony', 627007,
        'SUBMITTED', FALSE,
        '{"house_type": "INDEPENDENT_VILLA", "num_bedrooms": 2}'::jsonb,
        v_another_owner_user_id, 'OWNER', CURRENT_TIMESTAMP - INTERVAL '1 hour', FALSE, 'UNDER_CONSTRUCTION'
    ) RETURNING property_id INTO prop7_id;


    -- Property 8: Apartment for Rent, RENTED status, occupied by v_tenant_user_id_2, submitted by v_owner_submitter_user_id
    INSERT INTO public.properties (
        property_type, listing_type, price, area, area_unit, description, locality, city, address, pincode, year_built,
        admin_status, is_listed, details, rent_due_day, advance_amount,
        submitter, submitter_type, tenant, management_plan_id,
        submitted_at, availability_status, can_reachout
    ) VALUES (
        'HOUSE', 'RENTAL', 9500.00, 900.00, 'SQ_FT', 'Cozy 2 BHK apartment, currently occupied.', 'Thiyagaraja Nagar', 'Tirunelveli', 'Flat 1A, Star Apartments, Thiyagaraja Nagar', 627011, 2015,
        'RENTED', TRUE, -- It was listed, now rented
        '{"house_type": "APARTMENT_FLAT", "num_bedrooms": 2, "num_bathrooms": 1, "furnished_status": "SEMI_FURNISHED"}'::jsonb,
        3, 30000.00,
        v_owner_submitter_user_id, 'OWNER', v_tenant_user_id_2, v_standard_plan_id,
        CURRENT_TIMESTAMP - INTERVAL '6 months', 'READY_TO_MOVE', TRUE
    ) RETURNING property_id INTO prop8_id;


    RAISE NOTICE 'Property seeding complete. Remember to replace placeholder UUIDs if you havent already.';

END $$;


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


-- FILE NAME: 11_cron_job_setup.sql
-- Description: Sets up cron jobs for automated tasks like rent record generation and sales visit assignment.
-------------------------------------------------------------------------------

-- Enable pg_cron extension
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Grant usage on the cron schema to the postgres role.
GRANT USAGE ON SCHEMA cron TO postgres;

-- Grant privileges on the job and job_run_details tables
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE cron.job TO postgres;
GRANT USAGE ON SEQUENCE cron.jobid_seq TO postgres;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE cron.job_run_details TO postgres;
GRANT USAGE ON SEQUENCE cron.runid_seq TO postgres;

-- Ensure the postgres user (or the user Supabase cron runs as) can EXECUTE the target functions.
GRANT EXECUTE ON FUNCTION public.create_upcoming_rent_records_admin() TO postgres;
GRANT EXECUTE ON FUNCTION public.assign_pending_sales_visits_admin() TO postgres;

-- Schedule the function to generate upcoming rent records daily.
SELECT cron.schedule(
    'daily-rent-record-generation',
    '0 2 * * *',                    -- Cron schedule (minute hour day month day-of-week)
    $$SELECT public.create_upcoming_rent_records_admin()$$
);

-- Schedule the function to assign pending sales visits.
SELECT cron.schedule(
    'sales-visit-assignment-processor',
    '*/5 * * * *',                      -- Cron schedule: "every 5 minutes"
    $$SELECT public.assign_pending_sales_visits_admin()$$
);

SELECT cron.schedule(
    'auto-assign-marketing-tasks',
    '*/5 * * * *',                      -- Cron schedule: "every 5 minutes"
    $$SELECT public.auto_assign_marketing_tasks_cron_worker()$$
);


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


