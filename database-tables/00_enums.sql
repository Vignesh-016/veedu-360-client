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