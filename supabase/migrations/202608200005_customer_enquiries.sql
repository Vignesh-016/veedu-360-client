-- Logged-in homepage owner / tenant enquiries.
-- This is the only schema migration for this feature.

CREATE TABLE IF NOT EXISTS public.customer_enquiries (
    enquiry_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    enquiry_type TEXT NOT NULL CHECK (enquiry_type IN ('TENANT', 'OWNER')),
    customer_name TEXT NOT NULL CHECK (char_length(btrim(customer_name)) BETWEEN 2 AND 120),
    contact_phone TEXT NOT NULL CHECK (char_length(btrim(contact_phone)) BETWEEN 6 AND 30),
    email TEXT,
    occupancy_type TEXT CHECK (occupancy_type IN ('FAMILY', 'BACHELOR', 'COMMERCIAL')),
    budget NUMERIC(12,2) CHECK (budget IS NULL OR budget >= 0),
    bedroom_requirement TEXT,
    preferred_area TEXT,
    message TEXT,
    status TEXT NOT NULL DEFAULT 'NEW' CHECK (status IN ('NEW', 'CONTACTED', 'CLOSED')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT customer_enquiries_type_details_check CHECK (
        (enquiry_type = 'TENANT' AND occupancy_type IS NOT NULL AND budget IS NOT NULL
         AND bedroom_requirement IS NOT NULL AND preferred_area IS NOT NULL)
        OR
        (enquiry_type = 'OWNER' AND email IS NOT NULL AND message IS NOT NULL)
    )
);

CREATE INDEX IF NOT EXISTS customer_enquiries_created_at_idx
    ON public.customer_enquiries (created_at DESC);
CREATE INDEX IF NOT EXISTS customer_enquiries_status_type_idx
    ON public.customer_enquiries (status, enquiry_type);

ALTER TABLE public.customer_enquiries ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.customer_enquiries FROM anon, authenticated;

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

    IF v_type NOT IN ('TENANT', 'OWNER') THEN
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

    INSERT INTO public.customer_enquiries (
        user_id, enquiry_type, customer_name, contact_phone, email, occupancy_type,
        budget, bedroom_requirement, preferred_area, message
    ) VALUES (
        auth.uid(), v_type, btrim(p_customer_name), btrim(p_contact_phone),
        nullif(btrim(p_email), ''),
        CASE WHEN v_type = 'TENANT' THEN upper(btrim(p_occupancy_type)) ELSE NULL END,
        CASE WHEN v_type = 'TENANT' THEN p_budget ELSE NULL END,
        CASE WHEN v_type = 'TENANT' THEN nullif(btrim(p_bedroom_requirement), '') ELSE NULL END,
        CASE WHEN v_type = 'TENANT' THEN nullif(btrim(p_preferred_area), '') ELSE NULL END,
        CASE WHEN v_type = 'OWNER' THEN nullif(btrim(p_message), '') ELSE NULL END
    ) RETURNING enquiry_id INTO v_enquiry_id;

    RETURN v_enquiry_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.list_customer_enquiries_admin(
    p_status TEXT DEFAULT NULL,
    p_enquiry_type TEXT DEFAULT NULL,
    p_offset INTEGER DEFAULT 0,
    p_limit INTEGER DEFAULT 25
)
RETURNS TABLE (
    enquiry_id UUID, user_id UUID, enquiry_type TEXT, customer_name TEXT,
    contact_phone TEXT, email TEXT, occupancy_type TEXT, budget NUMERIC,
    bedroom_requirement TEXT, preferred_area TEXT, message TEXT, status TEXT,
    created_at TIMESTAMPTZ, updated_at TIMESTAMPTZ, total_count BIGINT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF NOT public.current_user_is_admin() THEN
        RAISE EXCEPTION 'Admin access required.';
    END IF;

    RETURN QUERY
    SELECT e.enquiry_id, e.user_id, e.enquiry_type, e.customer_name,
           e.contact_phone, e.email, e.occupancy_type, e.budget,
           e.bedroom_requirement, e.preferred_area, e.message, e.status,
           e.created_at, e.updated_at, count(*) OVER ()
      FROM public.customer_enquiries e
     WHERE (p_status IS NULL OR e.status = upper(p_status))
       AND (p_enquiry_type IS NULL OR e.enquiry_type = upper(p_enquiry_type))
     ORDER BY e.created_at DESC
     OFFSET greatest(coalesce(p_offset, 0), 0)
     LIMIT least(greatest(coalesce(p_limit, 25), 1), 100);
END;
$$;

CREATE OR REPLACE FUNCTION public.update_customer_enquiry_status_admin(
    p_enquiry_id UUID,
    p_status TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF NOT public.current_user_is_admin() THEN
        RAISE EXCEPTION 'Admin access required.';
    END IF;
    IF upper(btrim(coalesce(p_status, ''))) NOT IN ('NEW', 'CONTACTED', 'CLOSED') THEN
        RAISE EXCEPTION 'Invalid enquiry status.';
    END IF;

    UPDATE public.customer_enquiries
       SET status = upper(btrim(p_status)), updated_at = now()
     WHERE enquiry_id = p_enquiry_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'Enquiry not found.'; END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.submit_customer_enquiry(TEXT, TEXT, TEXT, TEXT, TEXT, NUMERIC, TEXT, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_customer_enquiries_admin(TEXT, TEXT, INTEGER, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_customer_enquiry_status_admin(UUID, TEXT) TO authenticated;
NOTIFY pgrst, 'reload schema';
