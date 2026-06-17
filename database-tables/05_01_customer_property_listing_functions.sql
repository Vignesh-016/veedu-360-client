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