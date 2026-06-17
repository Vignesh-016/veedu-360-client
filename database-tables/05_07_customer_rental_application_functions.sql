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