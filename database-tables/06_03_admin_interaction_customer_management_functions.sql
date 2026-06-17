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