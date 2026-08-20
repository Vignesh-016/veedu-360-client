-- Migration: Support Seller and Buyer Enquiry Types
-- Created At: 2026-08-20

-- 1. Drop existing check constraints from public.customer_enquiries
ALTER TABLE public.customer_enquiries DROP CONSTRAINT IF EXISTS customer_enquiries_enquiry_type_check;
ALTER TABLE public.customer_enquiries DROP CONSTRAINT IF EXISTS customer_enquiries_occupancy_type_check;
ALTER TABLE public.customer_enquiries DROP CONSTRAINT IF EXISTS customer_enquiries_type_details_check;

-- 2. Add updated check constraints to support SELLER and BUYER
ALTER TABLE public.customer_enquiries ADD CONSTRAINT customer_enquiries_enquiry_type_check 
    CHECK (enquiry_type IN ('TENANT', 'OWNER', 'SELLER', 'BUYER'));

ALTER TABLE public.customer_enquiries ADD CONSTRAINT customer_enquiries_occupancy_type_check 
    CHECK (occupancy_type IN ('FAMILY', 'BACHELOR', 'COMMERCIAL', 'LAND', 'HOUSE'));

ALTER TABLE public.customer_enquiries ADD CONSTRAINT customer_enquiries_type_details_check CHECK (
    (enquiry_type = 'TENANT' AND occupancy_type IS NOT NULL AND budget IS NOT NULL
     AND bedroom_requirement IS NOT NULL AND preferred_area IS NOT NULL)
    OR
    (enquiry_type = 'OWNER' AND email IS NOT NULL AND message IS NOT NULL)
    OR
    (enquiry_type = 'SELLER' AND occupancy_type IS NOT NULL AND preferred_area IS NOT NULL AND email IS NOT NULL)
    OR
    (enquiry_type = 'BUYER' AND occupancy_type IS NOT NULL AND budget IS NOT NULL AND message IS NOT NULL AND email IS NOT NULL)
);

-- 3. Replace public.submit_customer_enquiry with updated version that handles SELLER and BUYER mapping
CREATE OR REPLACE FUNCTION public.submit_customer_enquiry(
    p_enquiry_type TEXT,
    p_customer_name TEXT,
    p_contact_phone TEXT,
    p_email TEXT DEFAULT NULL,
    p_occupancy_type TEXT DEFAULT NULL,
    p_budget NUMERIC DEFAULT NULL,
    p_bedroom_requirement TEXT DEFAULT NULL,
    p_preferred_area TEXT DEFAULT NULL,
    p_message TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_enquiry_id UUID;
    v_type TEXT := upper(btrim(coalesce(p_enquiry_type, '')));
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Authentication is required.';
    END IF;

    IF v_type NOT IN ('TENANT', 'OWNER', 'SELLER', 'BUYER') THEN
        RAISE EXCEPTION 'Invalid enquiry type.';
    END IF;

    IF v_type = 'TENANT' AND (
        upper(btrim(coalesce(p_occupancy_type, ''))) NOT IN ('FAMILY', 'BACHELOR', 'COMMERCIAL')
        OR p_budget IS NULL OR p_budget < 0
        OR nullif(btrim(p_bedroom_requirement), '') IS NULL
        OR nullif(btrim(p_preferred_area), '') IS NULL
    ) THEN
        RAISE EXCEPTION 'Please complete all tenant enquiry fields.';
    END IF;

    IF v_type = 'OWNER' AND (
        nullif(btrim(p_email), '') IS NULL OR nullif(btrim(p_message), '') IS NULL
    ) THEN
        RAISE EXCEPTION 'Email and message are required for an owner enquiry.';
    END IF;

    IF v_type = 'SELLER' AND (
        upper(btrim(coalesce(p_occupancy_type, ''))) NOT IN ('LAND', 'HOUSE')
        OR nullif(btrim(p_preferred_area), '') IS NULL
        OR nullif(btrim(p_email), '') IS NULL
    ) THEN
        RAISE EXCEPTION 'Property type, area, and email are required for a seller enquiry.';
    END IF;

    IF v_type = 'BUYER' AND (
        upper(btrim(coalesce(p_occupancy_type, ''))) NOT IN ('LAND', 'HOUSE')
        OR p_budget IS NULL OR p_budget < 0
        OR nullif(btrim(p_message), '') IS NULL
        OR nullif(btrim(p_email), '') IS NULL
    ) THEN
        RAISE EXCEPTION 'Property type, budget, message, and email are required for a buyer enquiry.';
    END IF;

    INSERT INTO public.customer_enquiries (
        user_id, enquiry_type, customer_name, contact_phone, email, occupancy_type,
        budget, bedroom_requirement, preferred_area, message
    ) VALUES (
        auth.uid(), v_type, btrim(p_customer_name), btrim(p_contact_phone),
        nullif(btrim(p_email), ''),
        CASE 
            WHEN v_type = 'TENANT' THEN upper(btrim(p_occupancy_type)) 
            WHEN v_type IN ('SELLER', 'BUYER') THEN upper(btrim(p_occupancy_type))
            ELSE NULL 
        END,
        CASE 
            WHEN v_type = 'TENANT' THEN p_budget 
            WHEN v_type = 'BUYER' THEN p_budget
            ELSE NULL 
        END,
        CASE 
            WHEN v_type = 'TENANT' THEN nullif(btrim(p_bedroom_requirement), '') 
            ELSE NULL 
        END,
        CASE 
            WHEN v_type = 'TENANT' THEN nullif(btrim(p_preferred_area), '') 
            WHEN v_type = 'SELLER' THEN nullif(btrim(p_preferred_area), '')
            ELSE NULL 
        END,
        CASE 
            WHEN v_type = 'OWNER' THEN nullif(btrim(p_message), '') 
            WHEN v_type = 'BUYER' THEN nullif(btrim(p_message), '')
            WHEN v_type = 'SELLER' THEN nullif(btrim(p_message), '')
            ELSE NULL 
        END
    ) RETURNING enquiry_id INTO v_enquiry_id;

    RETURN v_enquiry_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.submit_customer_enquiry(TEXT, TEXT, TEXT, TEXT, TEXT, NUMERIC, TEXT, TEXT, TEXT) TO authenticated;

NOTIFY pgrst, 'reload schema';
