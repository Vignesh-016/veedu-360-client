-- Create contact_plans table
CREATE TABLE IF NOT EXISTS public.contact_plans (
    plan_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    price DECIMAL NOT NULL,
    contacts INTEGER NOT NULL,
    description TEXT,
    is_active BOOLEAN DEFAULT true NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL
);

-- Insert default contact plans
INSERT INTO public.contact_plans (name, price, contacts, description) VALUES
('Free Contacts', 0, 2, 'Get 2 free owner contact unlocks to get started.'),
('Standard Contacts', 999, 10, 'Get 10 owner contact unlocks valid for lifetime.'),
('Premium Contacts', 1499, 20, 'Get 20 owner contact unlocks valid for lifetime.')
ON CONFLICT DO NOTHING;

-- Add contact_balance to customers
ALTER TABLE public.customers ADD COLUMN IF NOT EXISTS contact_balance INTEGER DEFAULT 0 NOT NULL;

-- Create contact_unlocks table
CREATE TABLE IF NOT EXISTS public.contact_unlocks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.customers(user_id) ON DELETE CASCADE,
    property_id UUID NOT NULL REFERENCES public.properties(property_id) ON DELETE CASCADE,
    unlocked_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
    CONSTRAINT contact_unlocks_user_property_unique UNIQUE (user_id, property_id)
);

-- Enable RLS on contact_unlocks
ALTER TABLE public.contact_unlocks ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE tablename = 'contact_unlocks' AND policyname = 'select_own_contact_unlocks'
    ) THEN
        CREATE POLICY select_own_contact_unlocks ON public.contact_unlocks
            FOR SELECT TO authenticated USING (auth.uid() = user_id);
    END IF;
END
$$;

-- Alter transactions table to support contact plans
ALTER TABLE public.transactions ALTER COLUMN plan_id DROP NOT NULL;
ALTER TABLE public.transactions ADD COLUMN IF NOT EXISTS contact_plan_id UUID REFERENCES public.contact_plans(plan_id) ON DELETE SET NULL;

-- Function to complete a purchase (handles visits and contact plans)
CREATE OR REPLACE FUNCTION public.complete_purchase(
    p_razorpay_order_id TEXT
) RETURNS VOID AS $$
DECLARE
    v_transaction RECORD;
    v_visit_plan RECORD;
    v_contact_plan RECORD;
    v_customer RECORD;
BEGIN
    -- This function should be called by trusted roles, e.g., service_role via update_transaction_status
    IF current_setting('role', true) <> 'service_role' THEN
        RAISE EXCEPTION 'Unauthorized: This function can only be called by service_role.';
    END IF;

    SELECT user_id, plan_id, contact_plan_id, status
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

    -- Fetch customer info or create if missing
    SELECT user_id, expiry_date
    INTO v_customer
    FROM public.customers
    WHERE user_id = v_transaction.user_id;

    IF NOT FOUND THEN
        INSERT INTO public.customers (user_id, visit_balance, contact_balance, expiry_date)
        VALUES (v_transaction.user_id, 0, 0, (CURRENT_DATE + INTERVAL '30 days'))
        ON CONFLICT (user_id) DO NOTHING;

        SELECT user_id, expiry_date
        INTO v_customer
        FROM public.customers
        WHERE user_id = v_transaction.user_id;
    END IF;

    IF v_transaction.plan_id IS NOT NULL THEN
        -- Visit Plan
        SELECT visits INTO v_visit_plan FROM public.visit_plans WHERE plan_id = v_transaction.plan_id;
        IF NOT FOUND THEN
            RAISE WARNING 'Visit plan % not found.', v_transaction.plan_id;
            RETURN;
        END IF;

        UPDATE public.customers
        SET visit_balance = visit_balance + v_visit_plan.visits,
            expiry_date = GREATEST(COALESCE(expiry_date, CURRENT_DATE - INTERVAL '1 day'), CURRENT_DATE) + INTERVAL '30 days',
            updated_at = CURRENT_TIMESTAMP
        WHERE user_id = v_transaction.user_id;

    ELSIF v_transaction.contact_plan_id IS NOT NULL THEN
        -- Contact Plan
        SELECT contacts INTO v_contact_plan FROM public.contact_plans WHERE plan_id = v_transaction.contact_plan_id;
        IF NOT FOUND THEN
            RAISE WARNING 'Contact plan % not found.', v_transaction.contact_plan_id;
            RETURN;
        END IF;

        UPDATE public.customers
        SET contact_balance = contact_balance + v_contact_plan.contacts,
            updated_at = CURRENT_TIMESTAMP
        WHERE user_id = v_transaction.user_id;
    END IF;

    RAISE NOTICE 'Purchase completed for Razorpay Order ID %.', p_razorpay_order_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to claim free contact plan
CREATE OR REPLACE FUNCTION public.claim_free_contact_plan(
    p_plan_id UUID
) RETURNS JSONB AS $$
DECLARE
    v_current_user_id UUID := auth.uid();
    v_plan RECORD;
    v_has_claimed BOOLEAN;
BEGIN
    IF v_current_user_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Authentication required.');
    END IF;

    SELECT name, price, contacts, is_active
    INTO v_plan
    FROM public.contact_plans
    WHERE plan_id = p_plan_id;

    IF NOT FOUND OR NOT v_plan.is_active OR v_plan.price <> 0 THEN
        RETURN jsonb_build_object('success', false, 'error', 'Invalid free plan.');
    END IF;

    SELECT EXISTS (
        SELECT 1 FROM public.transactions
        WHERE user_id = v_current_user_id AND contact_plan_id = p_plan_id AND status = 'completed'
    ) INTO v_has_claimed;

    IF v_has_claimed THEN
        RETURN jsonb_build_object('success', false, 'error', 'You have already claimed this free plan.');
    END IF;

    -- Make sure customer record exists
    INSERT INTO public.customers (user_id, visit_balance, contact_balance, expiry_date)
    VALUES (v_current_user_id, 0, 0, (CURRENT_DATE + INTERVAL '30 days'))
    ON CONFLICT (user_id) DO NOTHING;

    UPDATE public.customers
    SET contact_balance = contact_balance + v_plan.contacts
    WHERE user_id = v_current_user_id;

    INSERT INTO public.transactions (user_id, contact_plan_id, amount, status, admin_notes)
    VALUES (v_current_user_id, p_plan_id, 0, 'completed', 'Claimed free contact plan: ' || v_plan.name);

    RETURN jsonb_build_object('success', true, 'message', 'Free plan claimed successfully!');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.claim_free_contact_plan(UUID) TO authenticated;

-- Function to unlock property contact
CREATE OR REPLACE FUNCTION public.unlock_property_contact(
    p_property_id UUID
) RETURNS JSONB AS $$
DECLARE
    v_current_user_id UUID := auth.uid();
    v_contact_balance INTEGER;
    v_already_unlocked BOOLEAN;
    v_is_owner BOOLEAN;
BEGIN
    IF v_current_user_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Authentication required.');
    END IF;

    SELECT (submitter = v_current_user_id) INTO v_is_owner
    FROM public.properties
    WHERE property_id = p_property_id;

    IF v_is_owner THEN
        RETURN jsonb_build_object('success', true, 'message', 'Owner contact is free for the property owner.');
    END IF;

    SELECT EXISTS (
        SELECT 1 FROM public.contact_unlocks
        WHERE user_id = v_current_user_id AND property_id = p_property_id
    ) INTO v_already_unlocked;

    IF v_already_unlocked THEN
        RETURN jsonb_build_object('success', true, 'message', 'Contact already unlocked.');
    END IF;

    SELECT contact_balance INTO v_contact_balance
    FROM public.customers
    WHERE user_id = v_current_user_id;

    IF v_contact_balance IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Customer profile not found.');
    END IF;

    IF v_contact_balance < 1 THEN
        RETURN jsonb_build_object('success', false, 'error', 'Insufficient contact credits. Please buy a contact plan.');
    END IF;

    UPDATE public.customers
    SET contact_balance = contact_balance - 1
    WHERE user_id = v_current_user_id;

    INSERT INTO public.contact_unlocks (user_id, property_id)
    VALUES (v_current_user_id, p_property_id);

    RETURN jsonb_build_object('success', true, 'message', 'Owner contact unlocked successfully.');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.unlock_property_contact(UUID) TO authenticated;

-- Client status/plans RPCs
CREATE OR REPLACE FUNCTION public.get_contact_status_customer()
RETURNS TABLE (
    contact_balance INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT c.contact_balance
    FROM public.customers c
    WHERE c.user_id = auth.uid();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;
GRANT EXECUTE ON FUNCTION public.get_contact_status_customer() TO authenticated;

CREATE OR REPLACE FUNCTION public.get_contact_plans_customer()
RETURNS TABLE (
    plan_id UUID,
    name TEXT,
    price DECIMAL,
    contacts INTEGER,
    description TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT cp.plan_id, cp.name, cp.price, cp.contacts, cp.description
    FROM public.contact_plans cp
    WHERE cp.is_active = true
    ORDER BY cp.price ASC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;
GRANT EXECUTE ON FUNCTION public.get_contact_plans_customer() TO anon, authenticated;

-- Admin CRUD functions for Contact Plans
CREATE OR REPLACE FUNCTION public.get_all_contact_plans_admin(
    p_is_active_filter BOOLEAN DEFAULT NULL
) RETURNS TABLE (
    plan_id UUID,
    name TEXT,
    price DECIMAL,
    contacts INTEGER,
    description TEXT,
    is_active BOOLEAN,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ
) AS $$
BEGIN
    IF NOT public.current_user_is_admin() THEN
        RAISE EXCEPTION 'Unauthorized: Admin privileges required.';
    END IF;

    RETURN QUERY
    SELECT cp.plan_id, cp.name, cp.price, cp.contacts, cp.description, cp.is_active, cp.created_at, cp.updated_at
    FROM public.contact_plans cp
    WHERE (p_is_active_filter IS NULL OR cp.is_active = p_is_active_filter)
    ORDER BY cp.price ASC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.get_all_contact_plans_admin(BOOLEAN) TO authenticated;

CREATE OR REPLACE FUNCTION public.insert_contact_plan_admin(
    p_name TEXT,
    p_price DECIMAL,
    p_contacts INTEGER,
    p_description TEXT,
    p_is_active BOOLEAN
) RETURNS UUID AS $$
DECLARE
    v_plan_id UUID;
BEGIN
    IF NOT public.current_user_is_admin() THEN
        RAISE EXCEPTION 'Unauthorized: Admin privileges required.';
    END IF;

    INSERT INTO public.contact_plans (name, price, contacts, description, is_active)
    VALUES (p_name, p_price, p_contacts, p_description, p_is_active)
    RETURNING plan_id INTO v_plan_id;

    RETURN v_plan_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.insert_contact_plan_admin(TEXT, DECIMAL, INTEGER, TEXT, BOOLEAN) TO authenticated;

CREATE OR REPLACE FUNCTION public.update_contact_plan_admin(
    p_plan_id UUID,
    p_name TEXT,
    p_price DECIMAL,
    p_contacts INTEGER,
    p_description TEXT,
    p_is_active BOOLEAN
) RETURNS VOID AS $$
BEGIN
    IF NOT public.current_user_is_admin() THEN
        RAISE EXCEPTION 'Unauthorized: Admin privileges required.';
    END IF;

    UPDATE public.contact_plans
    SET name = p_name,
        price = p_price,
        contacts = p_contacts,
        description = p_description,
        is_active = p_is_active,
        updated_at = now()
    WHERE plan_id = p_plan_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.update_contact_plan_admin(UUID, TEXT, DECIMAL, INTEGER, TEXT, BOOLEAN) TO authenticated;

CREATE OR REPLACE FUNCTION public.delete_contact_plan_admin(
    p_plan_id UUID
) RETURNS VOID AS $$
BEGIN
    IF NOT public.current_user_is_admin() THEN
        RAISE EXCEPTION 'Unauthorized: Admin privileges required.';
    END IF;

    DELETE FROM public.contact_plans
    WHERE plan_id = p_plan_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.delete_contact_plan_admin(UUID) TO authenticated;

-- Alter get_property_from_id_customer to return submitter info conditionally
-- DROP required because PostgreSQL cannot change return type with CREATE OR REPLACE
DROP FUNCTION IF EXISTS public.get_property_from_id_customer(UUID);
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
                    'name', u_submitter.raw_user_meta_data->>'full_name',
                    'phone', CASE 
                        WHEN v_current_user_id = p.submitter OR EXISTS (
                            SELECT 1 FROM public.contact_unlocks cu
                            WHERE cu.property_id = p.property_id AND cu.user_id = v_current_user_id
                        ) THEN u_submitter.phone::TEXT
                        ELSE NULL
                    END,
                    'is_unlocked', (v_current_user_id = p.submitter OR EXISTS (
                        SELECT 1 FROM public.contact_unlocks cu
                        WHERE cu.property_id = p.property_id AND cu.user_id = v_current_user_id
                    ))
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

-- Alter get_customer_full_details_admin to return contact_balance and unlocked properties
-- DROP required because PostgreSQL cannot change return type with CREATE OR REPLACE
DROP FUNCTION IF EXISTS public.get_customer_full_details_admin(UUID);
CREATE OR REPLACE FUNCTION public.get_customer_full_details_admin(p_customer_user_id UUID)
RETURNS TABLE (
    user_id UUID,
    full_name TEXT,
    email TEXT,
    phone TEXT,
    visit_balance INTEGER,
    contact_balance INTEGER,
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
    tenant_rent_records JSONB,
    unlocked_properties JSONB
) AS $$
BEGIN
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
            c.contact_balance,
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
                        (
                            SELECT jsonb_agg(jsonb_build_object('image_id', pi.image_id, 'image_url', pi.image_url, 'description', pi.description, 'display_order', pi.display_order, 'is_internal_image', pi.is_internal_image))
                            FROM public.property_images pi
                            WHERE pi.property_id = p.property_id
                        ), '[]'::jsonb
                    ),
                    'tenant_info', CASE WHEN p.tenant IS NOT NULL THEN jsonb_build_object('user_id', p.tenant, 'name', tenant_user.raw_user_meta_data->>'full_name', 'phone', tenant_user.phone) ELSE NULL END
                )) ORDER BY p.created_at DESC
            ) AS owned_data
        FROM public.properties p
        LEFT JOIN auth.users tenant_user ON p.tenant = tenant_user.id
        WHERE p.submitter = p_customer_user_id
        GROUP BY p.submitter
    ),
    agg_tenant_properties AS (
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
                    'owner_details', jsonb_build_object('user_id', p.submitter, 'name', owner_user.raw_user_meta_data->>'full_name'),
                    'images', COALESCE(
                        (
                            SELECT jsonb_agg(jsonb_build_object('image_id', pi.image_id, 'image_url', pi.image_url, 'description', pi.description, 'display_order', pi.display_order))
                            FROM public.property_images pi
                            WHERE pi.property_id = p.property_id AND pi.is_internal_image = FALSE
                        ), '[]'::jsonb
                    )
                )) ORDER BY p.created_at DESC
            ) AS tenant_data
        FROM public.properties p
        LEFT JOIN auth.users owner_user ON p.submitter = owner_user.id
        WHERE p.tenant = p_customer_user_id
        GROUP BY p.tenant
    ),
    agg_transactions AS (
        SELECT
            t.user_id,
            jsonb_agg(
                jsonb_strip_nulls(jsonb_build_object(
                    'transaction_id', t.transaction_id,
                    'plan_name', COALESCE(vp.name, cp.name),
                    'amount', t.amount,
                    'status', t.status,
                    'created_at', t.created_at
                )) ORDER BY t.created_at DESC
            ) AS tx_data
        FROM public.transactions t
        LEFT JOIN public.visit_plans vp ON t.plan_id = vp.plan_id
        LEFT JOIN public.contact_plans cp ON t.contact_plan_id = cp.plan_id
        WHERE t.user_id = p_customer_user_id
        GROUP BY t.user_id
    ),
    agg_tickets AS (
        SELECT
            tk.raised_by_user_id AS user_id,
            jsonb_agg(
                jsonb_build_object(
                    'ticket_id', tk.ticket_id,
                    'property_id', tk.property_id,
                    'property_address', p.address,
                    'subject', tk.subject,
                    'category', tk.category,
                    'priority', tk.priority,
                    'status', tk.status,
                    'created_at', tk.created_at
                ) ORDER BY tk.created_at DESC
            ) AS ticket_data
        FROM public.tickets tk
        JOIN public.properties p ON tk.property_id = p.property_id
        WHERE tk.raised_by_user_id = p_customer_user_id
        GROUP BY tk.raised_by_user_id
    ),
    agg_landlord_rents AS (
        SELECT
            rr.landlord_user_id AS user_id,
            jsonb_agg(
                jsonb_build_object(
                    'rent_record_id', rr.rent_record_id,
                    'property_id', rr.property_id,
                    'property_address', p.address,
                    'tenant_name', tenant_user.raw_user_meta_data->>'full_name',
                    'tenant_email', tenant_user.email,
                    'tenant_phone', tenant_user.phone,
                    'due_date', rr.due_date,
                    'period_start_date', rr.period_start_date,
                    'period_end_date', rr.period_end_date,
                    'amount_due', rr.amount_due,
                    'amount_paid', rr.amount_paid,
                    'status', rr.status
                ) ORDER BY rr.due_date DESC
            ) AS rent_data
        FROM public.rent_records rr
        JOIN public.properties p ON rr.property_id = p.property_id
        LEFT JOIN auth.users tenant_user ON rr.tenant_user_id = tenant_user.id
        WHERE rr.landlord_user_id = p_customer_user_id
        GROUP BY rr.landlord_user_id
    ),
    agg_tenant_rents AS (
        SELECT
            rr.tenant_user_id AS user_id,
            jsonb_agg(
                jsonb_build_object(
                    'rent_record_id', rr.rent_record_id,
                    'property_id', rr.property_id,
                    'property_address', p.address,
                    'landlord_name', landlord_user.raw_user_meta_data->>'full_name',
                    'landlord_email', landlord_user.email,
                    'landlord_phone', landlord_user.phone,
                    'due_date', rr.due_date,
                    'period_start_date', rr.period_start_date,
                    'period_end_date', rr.period_end_date,
                    'amount_due', rr.amount_due,
                    'amount_paid', rr.amount_paid,
                    'status', rr.status
                ) ORDER BY rr.due_date DESC
            ) AS rent_data
        FROM public.rent_records rr
        JOIN public.properties p ON rr.property_id = p.property_id
        LEFT JOIN auth.users landlord_user ON rr.landlord_user_id = landlord_user.id
        WHERE rr.tenant_user_id = p_customer_user_id
        GROUP BY rr.tenant_user_id
    ),
    agg_unlocked_properties AS (
        SELECT
            cu.user_id,
            jsonb_agg(
                jsonb_build_object(
                    'property_id', p.property_id,
                    'property_name', COALESCE(p.details->>'house_name', p.details->>'building_name', p.details->>'land_name', p.locality),
                    'address', p.address,
                    'city', p.city,
                    'locality', p.locality,
                    'unlocked_at', cu.unlocked_at,
                    'owner_name', u_owner.raw_user_meta_data->>'full_name',
                    'owner_phone', u_owner.phone
                ) ORDER BY cu.unlocked_at DESC
            ) AS unlocked_data
        FROM public.contact_unlocks cu
        JOIN public.properties p ON cu.property_id = p.property_id
        LEFT JOIN auth.users u_owner ON p.submitter = u_owner.id
        WHERE cu.user_id = p_customer_user_id
        GROUP BY cu.user_id
    )
    SELECT
        bu.user_id_val, bu.full_name_val, bu.email_val, bu.phone_val,
        bu.visit_balance, bu.contact_balance, bu.expiry_date, bu.profile_details,
        bu.auth_created_at_val, bu.customer_updated_at_val,
        COALESCE(docs.docs_data, '[]'::jsonb),
        COALESCE(inter.interactions_data, '[]'::jsonb),
        COALESCE(owned.owned_data, '[]'::jsonb),
        COALESCE(tenant.tenant_data, '[]'::jsonb),
        COALESCE(tx.tx_data, '[]'::jsonb),
        COALESCE(ticket.ticket_data, '[]'::jsonb),
        COALESCE(lrent.rent_data, '[]'::jsonb),
        COALESCE(trent.rent_data, '[]'::jsonb),
        COALESCE(unlocked.unlocked_data, '[]'::jsonb)
    FROM base_user_info bu
    LEFT JOIN agg_customer_documents docs ON bu.user_id_val = docs.user_id
    LEFT JOIN agg_interactions inter ON bu.user_id_val = inter.user_id
    LEFT JOIN agg_owned_properties owned ON bu.user_id_val = owned.user_id
    LEFT JOIN agg_tenant_properties tenant ON bu.user_id_val = tenant.user_id
    LEFT JOIN agg_transactions tx ON bu.user_id_val = tx.user_id
    LEFT JOIN agg_tickets ticket ON bu.user_id_val = ticket.user_id
    LEFT JOIN agg_landlord_rents lrent ON bu.user_id_val = lrent.user_id
    LEFT JOIN agg_tenant_rents trent ON bu.user_id_val = trent.user_id
    LEFT JOIN agg_unlocked_properties unlocked ON bu.user_id_val = unlocked.user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.get_customer_full_details_admin(UUID) TO authenticated;
