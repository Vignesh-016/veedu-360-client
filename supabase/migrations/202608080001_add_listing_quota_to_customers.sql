-- Migration: Add listing_quota to customers table and update RPC functions
-- Description: Default listing quota set to 50 for free postings, editable by admins.

-- 1. Add listing_quota column to public.customers
ALTER TABLE public.customers ADD COLUMN IF NOT EXISTS listing_quota INTEGER NOT NULL DEFAULT 50 CHECK (listing_quota >= 0);

-- 2. Function for admins to update customer's property listing quota
CREATE OR REPLACE FUNCTION public.update_customer_listing_quota_admin(
    p_customer_user_id UUID,
    p_new_listing_quota INTEGER
) RETURNS VOID AS $$
BEGIN
    IF NOT (
        public.current_user_has_role('super-admin') OR 
        public.current_user_has_role('accounts-team') OR
        public.current_user_has_role('telecalling-owner-team') OR
        public.current_user_is_admin()
    ) THEN
        RAISE EXCEPTION 'Unauthorized: Insufficient privileges to modify listing quota.';
    END IF;

    IF p_new_listing_quota < 0 THEN
        RAISE EXCEPTION 'Listing quota cannot be negative.';
    END IF;

    UPDATE public.customers
    SET listing_quota = p_new_listing_quota,
        updated_at = CURRENT_TIMESTAMP
    WHERE user_id = p_customer_user_id;

    IF NOT FOUND THEN
        INSERT INTO public.customers (user_id, visit_balance, listing_quota, expiry_date)
        VALUES (p_customer_user_id, 5, p_new_listing_quota, (CURRENT_DATE + INTERVAL '30 days'))
        ON CONFLICT (user_id) DO UPDATE SET listing_quota = p_new_listing_quota;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.update_customer_listing_quota_admin(UUID, INTEGER) TO authenticated;

-- 3. Update get_visit_status_customer to include listing_quota for client app
DROP FUNCTION IF EXISTS public.get_visit_status_customer();

CREATE FUNCTION public.get_visit_status_customer()
RETURNS TABLE (visit_balance INTEGER, expiry_date DATE, listing_quota INTEGER) AS $$
DECLARE
    v_user_id UUID := auth.uid();
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.';
    END IF;

    RETURN QUERY
    SELECT
        c.visit_balance,
        c.expiry_date,
        COALESCE(c.listing_quota, 50) AS listing_quota
    FROM public.customers c
    WHERE c.user_id = v_user_id;

    IF NOT FOUND THEN
        RETURN QUERY SELECT 0, CAST(NULL AS DATE), 50;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

GRANT EXECUTE ON FUNCTION public.get_visit_status_customer() TO authenticated;

-- 3.5 RPC function to safely fetch available cities without direct table access
CREATE OR REPLACE FUNCTION public.get_available_cities_customer()
RETURNS TABLE (city TEXT) AS $$
BEGIN
    RETURN QUERY
    SELECT DISTINCT p.city
    FROM public.properties p
    WHERE p.is_listed = TRUE AND p.city IS NOT NULL AND TRIM(p.city) <> ''
    ORDER BY p.city ASC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

GRANT EXECUTE ON FUNCTION public.get_available_cities_customer() TO authenticated;


-- 4. Update get_customer_full_details_admin to return listing_quota for winoli-admin
DROP FUNCTION IF EXISTS public.get_customer_full_details_admin(UUID);

CREATE OR REPLACE FUNCTION public.get_customer_full_details_admin(p_customer_user_id UUID)
RETURNS TABLE (
    user_id UUID,
    full_name TEXT,
    email TEXT,
    phone TEXT,
    visit_balance INTEGER,
    contact_balance INTEGER,
    listing_quota INTEGER,
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
    IF NOT (
        public.current_user_has_role('super-admin') OR
        public.current_user_has_role('telecalling-owner-team') OR
        public.current_user_has_role('telecalling-tenant-team') OR
        public.current_user_is_admin()
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
            COALESCE(c.contact_balance, 0) AS contact_balance,
            COALESCE(c.listing_quota, 50) AS listing_quota,
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
                    'is_listed', p.is_listed
                )) ORDER BY p.updated_at DESC
            ) AS owned_props_data
        FROM public.properties p
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
                    'is_listed', p.is_listed
                )) ORDER BY p.updated_at DESC
            ) AS tenant_props_data
        FROM public.properties p
        WHERE p.tenant = p_customer_user_id
        GROUP BY p.tenant
    ),
    agg_transactions AS (
        SELECT
            t.user_id,
            jsonb_agg(
                jsonb_build_object(
                    'transaction_id', t.transaction_id,
                    'amount', t.amount,
                    'status', t.status,
                    'created_at', t.created_at
                ) ORDER BY t.created_at DESC
            ) AS transactions_data
        FROM public.transactions t
        WHERE t.user_id = p_customer_user_id
        GROUP BY t.user_id
    ),
    agg_raised_tickets AS (
        SELECT
            t.raised_by_user_id as user_id,
            jsonb_agg(
                jsonb_build_object(
                    'ticket_id', t.ticket_id,
                    'subject', t.subject,
                    'status', t.status,
                    'priority', t.priority,
                    'created_at', t.created_at
                ) ORDER BY t.created_at DESC
            ) AS tickets_data
        FROM public.tickets t
        WHERE t.raised_by_user_id = p_customer_user_id
        GROUP BY t.raised_by_user_id
    ),
    agg_landlord_rent_records AS (
        SELECT
            rr.landlord_user_id as user_id,
            jsonb_agg(
                jsonb_build_object(
                    'rent_record_id', rr.rent_record_id,
                    'due_date', rr.due_date,
                    'amount_due', rr.amount_due,
                    'status', rr.status
                ) ORDER BY rr.due_date DESC
            ) AS landlord_rent_data
        FROM public.rent_records rr
        WHERE rr.landlord_user_id = p_customer_user_id
        GROUP BY rr.landlord_user_id
    ),
    agg_tenant_rent_records AS (
        SELECT
            rr.tenant_user_id as user_id,
            jsonb_agg(
                jsonb_build_object(
                    'rent_record_id', rr.rent_record_id,
                    'due_date', rr.due_date,
                    'amount_due', rr.amount_due,
                    'status', rr.status
                ) ORDER BY rr.due_date DESC
            ) AS tenant_rent_data
        FROM public.rent_records rr
        WHERE rr.tenant_user_id = p_customer_user_id
        GROUP BY rr.tenant_user_id
    )
    SELECT
        bui.user_id_val, bui.full_name_val, bui.email_val, bui.phone_val,
        bui.visit_balance, bui.contact_balance, bui.listing_quota, bui.expiry_date, bui.profile_details,
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

GRANT EXECUTE ON FUNCTION public.get_customer_full_details_admin(UUID) TO authenticated;

-- 5. Seed Property Listing Fee plan into visit_plans table with Rs 99 price
INSERT INTO public.visit_plans (name, description, visits, price, is_active)
VALUES ('Property Listing Fee', 'Listing fee for additional properties', 1, 99.00, true)
ON CONFLICT (name) DO UPDATE SET
    description = EXCLUDED.description,
    visits = EXCLUDED.visits,
    price = 99.00,
    is_active = true,
    updated_at = CURRENT_TIMESTAMP;

