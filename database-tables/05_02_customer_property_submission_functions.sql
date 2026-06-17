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