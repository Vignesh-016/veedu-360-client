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