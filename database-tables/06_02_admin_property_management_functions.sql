-- Description: Functions for admins to manage properties, including CRUD and status changes.
-------------------------------------------------------------------------------

-- Function for admins to get properties with extensive filters
CREATE OR REPLACE FUNCTION public.get_properties_admin(
    p_property_types public.property_type_enum[] DEFAULT NULL,
    p_listing_types public.listing_type_enum[] DEFAULT NULL,
    p_admin_statuses public.property_admin_status_enum[] DEFAULT NULL,
    p_is_listed_filter BOOLEAN DEFAULT NULL,
    p_pincodes INTEGER[] DEFAULT NULL,
    p_price_min DECIMAL DEFAULT NULL,
    p_price_max DECIMAL DEFAULT NULL,
    p_city TEXT DEFAULT NULL,
    p_is_featured BOOLEAN DEFAULT NULL,
    p_is_exclusive BOOLEAN DEFAULT NULL,
    p_submitter_id UUID DEFAULT NULL,
    p_tenant_id UUID DEFAULT NULL,
    p_management_plan_id UUID DEFAULT NULL,
    p_property_search TEXT DEFAULT NULL,
    p_owner_contact_assignment_status TEXT DEFAULT NULL,
    p_owner_contact_assigned_to_admin_id UUID DEFAULT NULL,
    p_marketing_assignment_status TEXT DEFAULT NULL,
    p_marketing_assigned_to_admin_id UUID DEFAULT NULL,
    p_offset INTEGER DEFAULT 0,
    p_limit INTEGER DEFAULT 10,
    p_sort_by TEXT DEFAULT 'updated_at',
    p_sort_direction TEXT DEFAULT 'DESC'
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
    admin_notes TEXT,
    inventory_details JSONB,
    admin_status public.property_admin_status_enum,
    is_listed BOOLEAN,
    is_featured BOOLEAN,
    is_exclusive BOOLEAN,
    rent_due_day INTEGER,
    submitter_type public.submitter_type_enum,
    submitter_notes TEXT,
    submitted_at TIMESTAMP WITH TIME ZONE,
    availability_status public.availability_status_enum,
    can_reachout BOOLEAN,
    property_name TEXT,
    property_images JSONB,
    submitter_info JSONB,
    tenant_info JSONB,
    management_plan_info JSONB,
    owner_contact_assigned_admin_id UUID,
    owner_contact_assigned_admin_name TEXT,
    owner_contact_assigned_at TIMESTAMPTZ,
    marketing_assigned_admin_id UUID,
    marketing_assigned_admin_name TEXT,
    marketing_assigned_at TIMESTAMPTZ,
    created_at TIMESTAMP WITH TIME ZONE,
    updated_at TIMESTAMP WITH TIME ZONE,
    total_count BIGINT
)
AS $$
DECLARE
    v_sql TEXT;
    v_order_by_clause TEXT;
    v_final_sort_by TEXT;
    v_final_sort_direction TEXT;
    v_allowed_sort_columns TEXT[] := ARRAY['price', 'area', 'updated_at', 'created_at', 'locality', 'city', 'year_built', 'admin_status', 'submitted_at', 'pincode'];
    v_calling_admin_id UUID := auth.uid(); 
BEGIN
    IF NOT public.current_user_is_admin() THEN
        RAISE EXCEPTION 'Unauthorized: Admin access required.';
    END IF;

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
    v_order_by_clause := format('ORDER BY %s %s NULLS LAST, pwc.property_id ASC', v_final_sort_by, v_final_sort_direction);

    v_sql := $QUERY$
    WITH properties_base AS (
        SELECT
            p.property_id, p.property_type, p.listing_type, p.price, p.advance_amount, p.area, p.area_unit, p.year_built,
            p.description, p.details, p.youtube_url, p.locality, p.city, p.address, p.pincode, p.latitude, p.longitude,
            p.admin_notes, p.inventory_details, p.admin_status, p.is_listed, p.is_featured, p.is_exclusive, p.rent_due_day,
            p.submitter_type, p.submitter_notes, p.submitted_at, p.availability_status, p.can_reachout,
            p.created_at, p.updated_at,
            p.submitter AS submitter_user_id, p.tenant AS tenant_user_id, p.management_plan_id AS mgmt_plan_id,
            poca.assigned_admin_id AS oca_admin_id, poca.assigned_at AS oca_assigned_at,
            pma.assigned_admin_id AS pma_admin_id, pma.assigned_at AS pma_assigned_at,
            COALESCE(p.details->>'house_name', p.details->>'building_name', p.details->>'land_name', p.locality) AS derived_property_name
        FROM public.properties p
        LEFT JOIN public.property_owner_contact_assignments poca ON p.property_id = poca.property_id
        LEFT JOIN public.property_marketing_assignments pma ON p.property_id = pma.property_id
        WHERE
            ($1 IS NULL OR p.property_type = ANY($1)) AND
            ($2 IS NULL OR p.listing_type = ANY($2)) AND
            ($3 IS NULL OR p.admin_status = ANY($3)) AND
            ($4 IS NULL OR p.is_listed = $4) AND
            ($5 IS NULL OR p.pincode = ANY($5)) AND
            ($6 IS NULL OR p.price >= $6) AND
            ($7 IS NULL OR p.price <= $7) AND
            ($8 IS NULL OR p.city ILIKE $8) AND
            ($9 IS NULL OR p.is_featured = $9) AND
            ($10 IS NULL OR p.is_exclusive = $10) AND
            ($11 IS NULL OR p.submitter = $11) AND
            ($12 IS NULL OR p.tenant = $12) AND
            ($13 IS NULL OR p.management_plan_id = $13) AND
            ($14 IS NULL OR (
                p.locality ILIKE '%' || $14 || '%' OR
                p.city ILIKE '%' || $14 || '%' OR
                p.address ILIKE '%' || $14 || '%' OR
                p.description ILIKE '%' || $14 || '%' OR
                p.admin_notes ILIKE '%' || $14 || '%' OR
                p.submitter_notes ILIKE '%' || $14 || '%' OR
                p.property_id::text ILIKE '%' || $14 || '%' OR
                p.pincode::text ILIKE '%' || $14 || '%' OR
                COALESCE(p.details->>'house_name', '') ILIKE '%' || $14 || '%' OR
                COALESCE(p.details->>'building_name', '') ILIKE '%' || $14 || '%' OR
                COALESCE(p.details->>'land_name', '') ILIKE '%' || $14 || '%'
            )) AND
            ($15 IS NULL OR
                ($15 = 'ASSIGNED' AND poca.property_id IS NOT NULL AND ($16 IS NULL OR poca.assigned_admin_id = $16)) OR
                ($15 = 'UNASSIGNED' AND poca.property_id IS NULL)
            ) AND
            -- Marketing assignment filters ($17 for status, $18 for admin_id) with role-based restrictions
            (
                CASE
                    WHEN (public.current_user_has_role('marketing-team') AND 
                          NOT public.current_user_has_role('super-admin') AND
                          NOT public.current_user_has_role('telecalling-owner-team')) THEN
                        (
                            pma.assigned_admin_id = auth.uid() AND -- Property must be assigned to current marketing admin
                            ($17 IS NULL OR $17 = 'ASSIGNED') AND -- Filter status must be ASSIGNED or not provided
                            ($18 IS NULL OR $18 = auth.uid())     -- Filter admin must be current admin or not provided
                        )
                    ELSE
                        -- Original logic for super-admins, telecalling-owner-team, or other roles
                        (
                            $17 IS NULL OR
                            ($17 = 'ASSIGNED' AND pma.property_id IS NOT NULL AND ($18 IS NULL OR pma.assigned_admin_id = $18)) OR
                            ($17 = 'UNASSIGNED' AND pma.property_id IS NULL)
                        )
                END
            )
    ),
    enriched_properties AS (
      SELECT
        pb.*,
        (
            SELECT COALESCE(jsonb_agg(
                jsonb_build_object(
                    'image_id', pi.image_id, 'image_url', pi.image_url, 'description', pi.description,
                    'display_order', pi.display_order, 'is_internal_image', pi.is_internal_image,
                    'uploaded_by_name', u_img_uploader.raw_user_meta_data->>'full_name'
                ) ORDER BY pi.display_order ASC, pi.created_at ASC
            ), '[]'::jsonb)
            FROM public.property_images pi
            LEFT JOIN public.admins admin_uploader ON pi.uploaded_by = admin_uploader.user_id
            LEFT JOIN auth.users u_img_uploader ON admin_uploader.user_id = u_img_uploader.id
            WHERE pi.property_id = pb.property_id
        ) AS property_images_data,
        CASE WHEN pb.submitter_user_id IS NOT NULL THEN jsonb_build_object(
            'user_id', u_submitter.id, 'name', u_submitter.raw_user_meta_data->>'full_name',
            'email', u_submitter.email, 'phone', u_submitter.phone
        ) ELSE NULL END AS submitter_info_data,
        CASE WHEN pb.tenant_user_id IS NOT NULL THEN jsonb_build_object(
            'user_id', u_tenant.id, 'name', u_tenant.raw_user_meta_data->>'full_name',
            'email', u_tenant.email, 'phone', u_tenant.phone
        ) ELSE NULL END AS tenant_info_data,
        CASE WHEN pb.mgmt_plan_id IS NOT NULL THEN jsonb_build_object(
            'plan_id', msp.plan_id, 'name', msp.name, 'percentage', msp.percentage
        ) ELSE NULL END AS management_plan_info_data,
        u_oca.raw_user_meta_data->>'full_name' AS oca_admin_name_val,
        u_pma.raw_user_meta_data->>'full_name' AS pma_admin_name_val
      FROM properties_base pb
      LEFT JOIN auth.users u_submitter ON pb.submitter_user_id = u_submitter.id
      LEFT JOIN auth.users u_tenant ON pb.tenant_user_id = u_tenant.id
      LEFT JOIN public.management_service_plans msp ON pb.mgmt_plan_id = msp.plan_id
      LEFT JOIN public.admins admin_oca ON pb.oca_admin_id = admin_oca.user_id
      LEFT JOIN auth.users u_oca ON admin_oca.user_id = u_oca.id
      LEFT JOIN public.admins admin_pma ON pb.pma_admin_id = admin_pma.user_id
      LEFT JOIN auth.users u_pma ON admin_pma.user_id = u_pma.id
    ),
    properties_with_count AS (
        SELECT *, COUNT(*) OVER() AS total_rows FROM enriched_properties
    )
    SELECT
        pwc.property_id, pwc.property_type, pwc.listing_type, pwc.price, pwc.advance_amount, pwc.area, pwc.area_unit, pwc.year_built,
        pwc.description, pwc.details, pwc.youtube_url, pwc.locality, pwc.city, pwc.address, pwc.pincode, pwc.latitude, pwc.longitude,
        pwc.admin_notes, pwc.inventory_details, pwc.admin_status, pwc.is_listed, pwc.is_featured, pwc.is_exclusive, pwc.rent_due_day,
        pwc.submitter_type, pwc.submitter_notes, pwc.submitted_at, pwc.availability_status, pwc.can_reachout,
        pwc.derived_property_name,
        pwc.property_images_data, pwc.submitter_info_data, pwc.tenant_info_data, pwc.management_plan_info_data,
        pwc.oca_admin_id AS owner_contact_assigned_admin_id,
        pwc.oca_admin_name_val AS owner_contact_assigned_admin_name,
        pwc.oca_assigned_at AS owner_contact_assigned_at,
        pwc.pma_admin_id AS marketing_assigned_admin_id,
        pwc.pma_admin_name_val AS marketing_assigned_admin_name,
        pwc.pma_assigned_at AS marketing_assigned_at,
        pwc.created_at, pwc.updated_at, pwc.total_rows
    FROM properties_with_count pwc
    $QUERY$;

    v_sql := v_sql || ' ' || v_order_by_clause || ' OFFSET $19 LIMIT $20';

    RETURN QUERY EXECUTE v_sql
        USING p_property_types, p_listing_types, p_admin_statuses, p_is_listed_filter, p_pincodes,
              p_price_min, p_price_max, p_city, p_is_featured, p_is_exclusive,
              p_submitter_id, p_tenant_id, p_management_plan_id, p_property_search,
              p_owner_contact_assignment_status, p_owner_contact_assigned_to_admin_id,
              p_marketing_assignment_status, p_marketing_assigned_to_admin_id,
              p_offset, p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;
GRANT EXECUTE ON FUNCTION public.get_properties_admin(
    public.property_type_enum[], public.listing_type_enum[], public.property_admin_status_enum[],
    BOOLEAN, INTEGER[], DECIMAL, DECIMAL, TEXT, BOOLEAN, BOOLEAN,
    UUID, UUID, UUID, TEXT,
    TEXT, UUID, TEXT, UUID,
    INTEGER, INTEGER, TEXT, TEXT
) TO authenticated;

-- Function for admins to get a single property by ID with full details
CREATE OR REPLACE FUNCTION public.get_property_details_admin(
    p_property_id_input UUID
)
RETURNS TABLE (
    property_id UUID, property_type public.property_type_enum, listing_type public.listing_type_enum,
    price DECIMAL, advance_amount DECIMAL, area DECIMAL, area_unit public.area_unit_enum, year_built INTEGER,
    description TEXT, details JSONB, youtube_url TEXT,
    locality TEXT, city TEXT, address TEXT, pincode INTEGER, latitude DECIMAL(9,6), longitude DECIMAL(9,6),
    nearest_hospital DECIMAL, nearest_busstop DECIMAL, nearest_gym DECIMAL, nearest_park DECIMAL, nearest_school DECIMAL, nearest_swimmingpool DECIMAL, proximity_unit public.proximity_unit_enum,
    admin_notes TEXT, inventory_details JSONB,
    admin_status public.property_admin_status_enum, is_listed BOOLEAN, is_featured BOOLEAN, is_exclusive BOOLEAN,
    rent_due_day INTEGER,
    submitter_type public.submitter_type_enum, submitter_notes TEXT, submitted_at TIMESTAMP WITH TIME ZONE,
    availability_status public.availability_status_enum, can_reachout BOOLEAN,
    created_at TIMESTAMP WITH TIME ZONE, updated_at TIMESTAMP WITH TIME ZONE,
    property_name TEXT,
    property_images JSONB,
    property_documents JSONB,
    submitter_info JSONB, tenant_info JSONB, management_plan_info JSONB,
    owner_contact_assignment JSONB,
    marketing_assignment JSONB
)
AS $$
BEGIN
    IF NOT public.current_user_is_admin() THEN
        RAISE EXCEPTION 'Unauthorized: Admin access required.';
    END IF;

    RETURN QUERY
    SELECT
        p.property_id, p.property_type, p.listing_type,
        p.price, p.advance_amount, p.area, p.area_unit, p.year_built,
        p.description, p.details, p.youtube_url,
        p.locality, p.city, p.address, p.pincode, p.latitude, p.longitude,
        p.nearest_hospital, p.nearest_busstop, p.nearest_gym, p.nearest_park, p.nearest_school, p.nearest_swimmingpool, p.proximity_unit,
        p.admin_notes, p.inventory_details,
        p.admin_status, p.is_listed, p.is_featured, p.is_exclusive,
        p.rent_due_day,
        p.submitter_type, p.submitter_notes, p.submitted_at,
        p.availability_status, p.can_reachout,
        p.created_at, p.updated_at,
        COALESCE(p.details->>'house_name', p.details->>'building_name', p.details->>'land_name', p.locality) AS derived_property_name,
        (SELECT COALESCE(jsonb_agg(jsonb_build_object(
            'image_id', pi.image_id, 'image_url', pi.image_url, 'description', pi.description,
            'display_order', pi.display_order, 'is_internal_image', pi.is_internal_image,
            'uploaded_by_name', u_img_uploader.raw_user_meta_data->>'full_name', 'uploaded_at', pi.created_at
            ) ORDER BY pi.display_order ASC, pi.created_at ASC), '[]'::jsonb)
         FROM public.property_images pi
         LEFT JOIN public.admins admin_img_uploader ON pi.uploaded_by = admin_img_uploader.user_id
         LEFT JOIN auth.users u_img_uploader ON admin_img_uploader.user_id = u_img_uploader.id
         WHERE pi.property_id = p.property_id
        ) AS property_images_data,
        (SELECT COALESCE(jsonb_agg(jsonb_build_object(
            'document_id', pd.document_id, 'document_type', pd.document_type, 'document_url', pd.document_url,
            'file_name', pd.file_name, 'description', pd.description,
            'uploaded_by_name', u_doc_uploader.raw_user_meta_data->>'full_name', 'uploaded_at', pd.uploaded_at
            ) ORDER BY pd.uploaded_at ASC), '[]'::jsonb)
         FROM public.property_documents pd
         LEFT JOIN public.admins admin_doc_uploader ON pd.uploaded_by = admin_doc_uploader.user_id
         LEFT JOIN auth.users u_doc_uploader ON admin_doc_uploader.user_id = u_doc_uploader.id
         WHERE pd.property_id = p.property_id
        ) AS property_documents_data,
        CASE WHEN p.submitter IS NOT NULL THEN jsonb_build_object('user_id', u_s.id, 'name', u_s.raw_user_meta_data->>'full_name', 'email', u_s.email, 'phone', u_s.phone) ELSE NULL END,
        CASE WHEN p.tenant IS NOT NULL THEN jsonb_build_object('user_id', u_t.id, 'name', u_t.raw_user_meta_data->>'full_name', 'email', u_t.email, 'phone', u_t.phone) ELSE NULL END,
        CASE WHEN p.management_plan_id IS NOT NULL THEN jsonb_build_object('plan_id', msp.plan_id, 'name', msp.name, 'percentage', msp.percentage) ELSE NULL END,
        (SELECT jsonb_build_object('assigned_admin_id', oca.assigned_admin_id, 'assigned_admin_name', u_oca.raw_user_meta_data->>'full_name', 'assigned_at', oca.assigned_at)
         FROM public.property_owner_contact_assignments oca JOIN public.admins a_oca ON oca.assigned_admin_id = a_oca.user_id JOIN auth.users u_oca ON a_oca.user_id = u_oca.id
         WHERE oca.property_id = p.property_id) AS owner_contact_assignment_data,
        (SELECT jsonb_build_object('assigned_admin_id', pma.assigned_admin_id, 'assigned_admin_name', u_pma.raw_user_meta_data->>'full_name', 'assigned_at', pma.assigned_at)
         FROM public.property_marketing_assignments pma JOIN public.admins a_pma ON pma.assigned_admin_id = a_pma.user_id JOIN auth.users u_pma ON a_pma.user_id = u_pma.id
         WHERE pma.property_id = p.property_id) AS marketing_assignment_data
    FROM public.properties p
    LEFT JOIN auth.users u_s ON p.submitter = u_s.id
    LEFT JOIN auth.users u_t ON p.tenant = u_t.id
    LEFT JOIN public.management_service_plans msp ON p.management_plan_id = msp.plan_id
    WHERE p.property_id = p_property_id_input;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;
GRANT EXECUTE ON FUNCTION public.get_property_details_admin(UUID) TO authenticated;

-- Function for admins to insert a new property
CREATE OR REPLACE FUNCTION public.insert_property_admin(
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
    p_admin_notes TEXT DEFAULT NULL,
    p_inventory_details JSONB DEFAULT '{}'::jsonb,
    p_admin_status public.property_admin_status_enum DEFAULT 'SUBMITTED',
    p_is_listed BOOLEAN DEFAULT FALSE,
    p_is_featured BOOLEAN DEFAULT FALSE,
    p_is_exclusive BOOLEAN DEFAULT FALSE,
    p_advance_amount DECIMAL(10,2) DEFAULT NULL,
    p_rent_due_day INTEGER DEFAULT NULL,
    p_submitter UUID DEFAULT NULL,
    p_submitter_type public.submitter_type_enum DEFAULT NULL,
    p_submitter_notes TEXT DEFAULT NULL,
    p_availability_status public.availability_status_enum DEFAULT NULL,
    p_can_reachout BOOLEAN DEFAULT TRUE,
    p_tenant UUID DEFAULT NULL,
    p_management_plan_id UUID DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
    v_property_id UUID;
    v_final_submitter UUID;
BEGIN
   IF NOT public.current_user_is_admin() THEN
       RAISE EXCEPTION 'Unauthorized: Admin access required.';
   END IF;

   IF p_details IS NULL THEN RAISE EXCEPTION 'Property details (JSONB) cannot be null.'; END IF;

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

   IF p_inventory_details IS NULL THEN p_inventory_details := '{}'::jsonb; END IF;

   IF p_listing_type = 'RENTAL' AND p_rent_due_day IS NOT NULL AND (p_rent_due_day < 1 OR p_rent_due_day > 28) THEN
       RAISE EXCEPTION 'Rent Due Day must be between 1 and 28 for rentals.';
   END IF;
   IF p_listing_type = 'SALE' THEN
       p_rent_due_day := NULL;
       p_advance_amount := NULL;
   END IF;

   IF p_submitter IS NOT NULL AND NOT EXISTS (SELECT 1 FROM auth.users WHERE id = p_submitter) THEN RAISE EXCEPTION 'Submitter User ID % does not exist.', p_submitter; END IF;
   IF p_tenant IS NOT NULL AND NOT EXISTS (SELECT 1 FROM auth.users WHERE id = p_tenant) THEN RAISE EXCEPTION 'Tenant User ID % does not exist.', p_tenant; END IF;
   IF p_management_plan_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public.management_service_plans WHERE plan_id = p_management_plan_id) THEN RAISE EXCEPTION 'Management Plan ID % does not exist.', p_management_plan_id; END IF;

   v_final_submitter := COALESCE(p_submitter, auth.uid());

   INSERT INTO public.properties (
        property_type, listing_type, price, area, area_unit, year_built, description, details, youtube_url,
        locality, city, address, pincode, latitude, longitude,
        nearest_hospital, nearest_busstop, nearest_gym, nearest_park, nearest_school, nearest_swimmingpool, proximity_unit,
        admin_notes, inventory_details, admin_status, is_listed, is_featured, is_exclusive,
        advance_amount, rent_due_day,
        submitter, submitter_type, submitter_notes, submitted_at, availability_status, can_reachout,
        tenant, management_plan_id
    ) VALUES (
        p_property_type, p_listing_type, p_price, p_area, p_area_unit, p_year_built, p_description, p_details, p_youtube_url,
        p_locality, p_city, p_address, p_pincode, p_latitude, p_longitude,
        p_nearest_hospital, p_nearest_busstop, p_nearest_gym, p_nearest_park, p_nearest_school, p_nearest_swimmingpool, p_proximity_unit,
        p_admin_notes, p_inventory_details, p_admin_status, p_is_listed, p_is_featured, p_is_exclusive,
        p_advance_amount, p_rent_due_day,
        v_final_submitter, p_submitter_type, p_submitter_notes, CURRENT_TIMESTAMP, p_availability_status, p_can_reachout,
        p_tenant, p_management_plan_id
    ) RETURNING property_id INTO v_property_id;

   RETURN v_property_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.insert_property_admin(public.property_type_enum, public.listing_type_enum, DECIMAL, DECIMAL, public.area_unit_enum, JSONB, TEXT, TEXT, TEXT, INTEGER, INTEGER, TEXT, TEXT, DECIMAL(9,6), DECIMAL(9,6), DECIMAL(5,1), DECIMAL(5,1), DECIMAL(5,1), DECIMAL(5,1), DECIMAL(5,1), DECIMAL(5,1), public.proximity_unit_enum, TEXT, JSONB, public.property_admin_status_enum, BOOLEAN, BOOLEAN, BOOLEAN, DECIMAL(10,2), INTEGER, UUID, public.submitter_type_enum, TEXT, public.availability_status_enum, BOOLEAN, UUID, UUID) TO authenticated;


-- Function for admins to update a property
CREATE OR REPLACE FUNCTION public.update_property_admin(
    p_property_id UUID,
    p_property_type public.property_type_enum DEFAULT NULL,
    p_listing_type public.listing_type_enum DEFAULT NULL,
    p_price DECIMAL DEFAULT NULL,
    p_advance_amount DECIMAL DEFAULT NULL,
    p_area DECIMAL DEFAULT NULL,
    p_area_unit public.area_unit_enum DEFAULT NULL,
    p_details JSONB DEFAULT NULL,
    p_locality TEXT DEFAULT NULL,
    p_city TEXT DEFAULT NULL,
    p_address TEXT DEFAULT NULL,
    p_pincode INTEGER DEFAULT NULL,
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
    p_proximity_unit public.proximity_unit_enum DEFAULT NULL,
    p_admin_notes TEXT DEFAULT NULL,
    p_inventory_details JSONB DEFAULT NULL,
    p_admin_status public.property_admin_status_enum DEFAULT NULL,
    p_is_listed BOOLEAN DEFAULT NULL,
    p_is_featured BOOLEAN DEFAULT NULL,
    p_is_exclusive BOOLEAN DEFAULT NULL,
    p_rent_due_day INTEGER DEFAULT NULL,
    p_submitter UUID DEFAULT NULL,
    p_submitter_type public.submitter_type_enum DEFAULT NULL,
    p_submitter_notes TEXT DEFAULT NULL,
    p_availability_status public.availability_status_enum DEFAULT NULL,
    p_can_reachout BOOLEAN DEFAULT NULL,
    p_tenant UUID DEFAULT NULL,
    p_management_plan_id UUID DEFAULT NULL
) RETURNS VOID AS $$
DECLARE
    v_current_listing_type public.listing_type_enum;
    v_current_property_type public.property_type_enum;
    v_final_rent_due_day INTEGER;
    v_final_advance_amount DECIMAL;
    v_can_edit BOOLEAN := FALSE;
    v_calling_admin_id UUID := auth.uid();
BEGIN
    IF NOT public.current_user_is_admin() THEN
        RAISE EXCEPTION 'Unauthorized: Admin access required.';
    END IF;

    -- Authorization Check Block
    IF public.current_user_has_role('super-admin') THEN
        v_can_edit := TRUE;
    ELSE
        IF public.current_user_has_role('telecalling-owner-team') THEN
            SELECT EXISTS (
                SELECT 1 FROM public.property_owner_contact_assignments poca
                WHERE poca.property_id = p_property_id AND poca.assigned_admin_id = v_calling_admin_id
            ) INTO v_can_edit;
        END IF;

        IF NOT v_can_edit AND public.current_user_has_role('marketing-team') THEN
            SELECT EXISTS (
                SELECT 1 FROM public.property_marketing_assignments pma
                WHERE pma.property_id = p_property_id AND pma.assigned_admin_id = v_calling_admin_id
            ) INTO v_can_edit;
        END IF;
    END IF;

    IF NOT v_can_edit THEN
        RAISE EXCEPTION 'Unauthorized: You do not have permission to update this property (ID: %). Ensure it is assigned to you if you are on the telecalling-owner or marketing team, or you are a super-admin.', p_property_id;
    END IF;

    -- Fetch current property details
    SELECT listing_type, property_type, rent_due_day, advance_amount
    INTO v_current_listing_type, v_current_property_type, v_final_rent_due_day, v_final_advance_amount
    FROM public.properties WHERE property_id = p_property_id;

    IF NOT FOUND THEN RAISE EXCEPTION 'Property with ID % not found.', p_property_id; END IF;

    -- Apply defaults for listing type and property type if not provided in parameters
    v_current_listing_type := COALESCE(p_listing_type, v_current_listing_type);
    v_current_property_type := COALESCE(p_property_type, v_current_property_type);

    -- Validate details based on property type if details are being updated
    IF p_details IS NOT NULL THEN
        IF v_current_property_type = 'HOUSE' THEN
           IF NOT (p_details ? 'house_name') OR TRIM(p_details->>'house_name') = '' THEN
               RAISE EXCEPTION 'Post Title (house_name) is required for House properties within details when details are updated.';
           END IF;
        ELSIF v_current_property_type = 'LAND' THEN
           IF NOT (p_details ? 'land_name') OR TRIM(p_details->>'land_name') = '' THEN
               RAISE EXCEPTION 'Post Title (land_name) is required for Land properties within details when details are updated.';
           END IF;
        ELSIF v_current_property_type = 'BUILDING' THEN
           IF NOT (p_details ? 'building_name') OR TRIM(p_details->>'building_name') = '' THEN
               RAISE EXCEPTION 'Post Title (building_name) is required for Building properties within details when details are updated.';
           END IF;
        END IF;
    END IF;

    -- Validate rent_due_day for rentals
    IF v_current_listing_type = 'RENTAL' THEN
        IF p_rent_due_day IS NOT NULL AND (p_rent_due_day < 1 OR p_rent_due_day > 28) THEN
            RAISE EXCEPTION 'Rent Due Day must be between 1 and 28 for rentals.';
        END IF;
        v_final_rent_due_day := COALESCE(p_rent_due_day, v_final_rent_due_day);
        v_final_advance_amount := COALESCE(p_advance_amount, v_final_advance_amount);
    ELSIF v_current_listing_type = 'SALE' THEN
        v_final_rent_due_day := NULL;
        v_final_advance_amount := NULL;
    END IF;


    UPDATE public.properties SET
        property_type = COALESCE(p_property_type, property_type),
        listing_type = COALESCE(p_listing_type, listing_type),
        price = COALESCE(p_price, price),
        advance_amount = v_final_advance_amount,
        area = COALESCE(p_area, area),
        area_unit = COALESCE(p_area_unit, area_unit),
        details = COALESCE(p_details, details),
        locality = COALESCE(p_locality, locality),
        city = COALESCE(p_city, city),
        address = COALESCE(p_address, address),
        pincode = COALESCE(p_pincode, pincode),
        year_built = COALESCE(p_year_built, year_built),
        description = COALESCE(p_description, description),
        youtube_url = COALESCE(p_youtube_url, youtube_url),
        latitude = COALESCE(p_latitude, latitude),
        longitude = COALESCE(p_longitude, longitude),
        nearest_hospital = COALESCE(p_nearest_hospital, nearest_hospital),
        nearest_busstop = COALESCE(p_nearest_busstop, nearest_busstop),
        nearest_gym = COALESCE(p_nearest_gym, nearest_gym),
        nearest_park = COALESCE(p_nearest_park, nearest_park),
        nearest_school = COALESCE(p_nearest_school, nearest_school),
        nearest_swimmingpool = COALESCE(p_nearest_swimmingpool, nearest_swimmingpool),
        proximity_unit = COALESCE(p_proximity_unit, proximity_unit),
        admin_notes = COALESCE(p_admin_notes, admin_notes),
        inventory_details = COALESCE(p_inventory_details, inventory_details),
        admin_status = COALESCE(p_admin_status, admin_status),
        is_listed = COALESCE(p_is_listed, is_listed),
        is_featured = COALESCE(p_is_featured, is_featured),
        is_exclusive = COALESCE(p_is_exclusive, is_exclusive),
        rent_due_day = v_final_rent_due_day,
        submitter = COALESCE(p_submitter, submitter),
        submitter_type = COALESCE(p_submitter_type, submitter_type),
        submitter_notes = COALESCE(p_submitter_notes, submitter_notes),
        availability_status = COALESCE(p_availability_status, availability_status),
        can_reachout = COALESCE(p_can_reachout, can_reachout),
        tenant = p_tenant,
        management_plan_id = COALESCE(p_management_plan_id, management_plan_id),
        updated_at = CURRENT_TIMESTAMP
    WHERE property_id = p_property_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.update_property_admin(UUID, public.property_type_enum, public.listing_type_enum, DECIMAL, DECIMAL, DECIMAL, public.area_unit_enum, JSONB, TEXT, TEXT, TEXT, INTEGER, INTEGER, TEXT, TEXT, DECIMAL(9,6), DECIMAL(9,6), DECIMAL(5,1), DECIMAL(5,1), DECIMAL(5,1), DECIMAL(5,1), DECIMAL(5,1), DECIMAL(5,1), public.proximity_unit_enum, TEXT, JSONB, public.property_admin_status_enum, BOOLEAN, BOOLEAN, BOOLEAN, INTEGER, UUID, public.submitter_type_enum, TEXT, public.availability_status_enum, BOOLEAN, UUID, UUID) TO authenticated;

-- Function for super-admin to delete a property (use with caution)
CREATE OR REPLACE FUNCTION public.delete_property_admin(p_property_id UUID)
RETURNS VOID AS $$
BEGIN
    IF NOT public.current_user_has_role('super-admin') THEN
        RAISE EXCEPTION 'Unauthorized: Only super-admins can delete properties.';
    END IF;
    DELETE FROM public.properties WHERE property_id = p_property_id;
    IF NOT FOUND THEN RAISE WARNING 'Property with ID % not found for deletion.', p_property_id; END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.delete_property_admin(UUID) TO authenticated;


-- Function for admins to delete a property image by image_id
CREATE OR REPLACE FUNCTION public.delete_property_image_admin(p_image_id UUID)
RETURNS VOID AS $$
DECLARE
    v_property_id UUID;
BEGIN
    IF NOT public.current_user_is_admin() THEN
        RAISE EXCEPTION 'Unauthorized: Admin access required.';
    END IF;

    SELECT property_id INTO v_property_id FROM public.property_images WHERE image_id = p_image_id;
    IF NOT FOUND THEN RAISE WARNING 'Property image with ID % not found.', p_image_id; RETURN; END IF;

    DELETE FROM public.property_images WHERE image_id = p_image_id;

    UPDATE public.properties
    SET admin_status = 'SUBMITTED', is_listed = FALSE, updated_at = CURRENT_TIMESTAMP
    WHERE property_id = v_property_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.delete_property_image_admin(UUID) TO authenticated;

-- Function for admins to update property image details
CREATE OR REPLACE FUNCTION public.update_property_image_admin(
    p_image_id UUID,
    p_description TEXT DEFAULT NULL,
    p_display_order INTEGER DEFAULT NULL,
    p_is_internal_image BOOLEAN DEFAULT NULL
) RETURNS VOID AS $$
DECLARE
    v_property_id UUID;
BEGIN
    IF NOT public.current_user_is_admin() THEN
        RAISE EXCEPTION 'Unauthorized: Admin access required.';
    END IF;

    SELECT property_id INTO v_property_id FROM public.property_images WHERE image_id = p_image_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'Property image with ID % not found.', p_image_id; END IF;

    UPDATE public.property_images SET
        description = COALESCE(p_description, description),
        display_order = COALESCE(p_display_order, display_order),
        is_internal_image = COALESCE(p_is_internal_image, is_internal_image),
        updated_at = CURRENT_TIMESTAMP
    WHERE image_id = p_image_id;

    UPDATE public.properties
    SET admin_status = 'SUBMITTED', is_listed = FALSE, updated_at = CURRENT_TIMESTAMP
    WHERE property_id = v_property_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.update_property_image_admin(UUID, TEXT, INTEGER, BOOLEAN) TO authenticated;

CREATE OR REPLACE FUNCTION public.record_property_image_upload_admin(
    p_property_id UUID,
    p_image_url TEXT,
    p_description TEXT DEFAULT NULL,
    p_display_order INTEGER DEFAULT 0,
    p_is_internal_image BOOLEAN DEFAULT FALSE
) RETURNS UUID AS $$
DECLARE
    v_image_id UUID;
    v_uploader_admin_id UUID := auth.uid();
BEGIN
    IF NOT public.current_user_is_admin() THEN
        RAISE EXCEPTION 'Unauthorized: Admin access required.';
    END IF;
    IF NOT (public.current_user_has_role('marketing-team') OR public.current_user_has_role('telecalling-owner-team') OR public.current_user_has_role('super-admin')) THEN
        RAISE EXCEPTION 'Unauthorized: Insufficient role privileges to upload property images.';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM public.properties WHERE property_id = p_property_id) THEN
        RAISE EXCEPTION 'Property ID % not found.', p_property_id;
    END IF;

    INSERT INTO public.property_images (property_id, image_url, description, display_order, is_internal_image, uploaded_by)
    VALUES (p_property_id, p_image_url, p_description, p_display_order, p_is_internal_image, v_uploader_admin_id)
    RETURNING image_id INTO v_image_id;

    UPDATE public.properties
    SET admin_status = 'SUBMITTED', is_listed = FALSE, updated_at = CURRENT_TIMESTAMP
    WHERE property_id = p_property_id;

    RETURN v_image_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.record_property_image_upload_admin(UUID, TEXT, TEXT, INTEGER, BOOLEAN) TO authenticated;


CREATE OR REPLACE FUNCTION public.record_property_document_upload_admin(
    p_property_id UUID,
    p_document_type TEXT,
    p_document_url TEXT,
    p_file_name TEXT DEFAULT NULL,
    p_description TEXT DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
    v_document_id UUID;
    v_uploader_admin_id UUID := auth.uid();
BEGIN
    IF NOT public.current_user_is_admin() THEN
        RAISE EXCEPTION 'Unauthorized: Admin access required.';
    END IF;
    IF NOT (public.current_user_has_role('telecalling-owner-team') OR public.current_user_has_role('marketing-team') OR public.current_user_has_role('super-admin')) THEN
        RAISE EXCEPTION 'Unauthorized: Insufficient privileges to manage property documents.';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM public.properties WHERE property_id = p_property_id) THEN
        RAISE EXCEPTION 'Property ID % not found.', p_property_id;
    END IF;

    INSERT INTO public.property_documents(property_id, document_type, document_url, file_name, description, uploaded_by, uploaded_at)
    VALUES (p_property_id, p_document_type, p_document_url, p_file_name, p_description, v_uploader_admin_id, CURRENT_TIMESTAMP)
    RETURNING document_id INTO v_document_id;

    UPDATE public.properties
    SET admin_status = 'SUBMITTED', is_listed = FALSE, updated_at = CURRENT_TIMESTAMP
    WHERE property_id = p_property_id;

    RETURN v_document_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.record_property_document_upload_admin(UUID, TEXT, TEXT, TEXT, TEXT) TO authenticated;

CREATE OR REPLACE FUNCTION public.delete_property_document_admin(p_document_id UUID)
RETURNS VOID AS $$
DECLARE
    v_property_id UUID;
BEGIN
    IF NOT public.current_user_is_admin() THEN
        RAISE EXCEPTION 'Unauthorized: Admin access required.';
    END IF;
     IF NOT (public.current_user_has_role('telecalling-owner-team') OR public.current_user_has_role('marketing-team') OR public.current_user_has_role('super-admin')) THEN
        RAISE EXCEPTION 'Unauthorized: Insufficient privileges to manage property documents.';
    END IF;

    SELECT property_id INTO v_property_id FROM public.property_documents WHERE document_id = p_document_id;
    IF NOT FOUND THEN RAISE WARNING 'Property document % not found.', p_document_id; RETURN; END IF;

    DELETE FROM public.property_documents WHERE document_id = p_document_id;

    UPDATE public.properties
    SET admin_status = 'SUBMITTED', is_listed = FALSE, updated_at = CURRENT_TIMESTAMP
    WHERE property_id = v_property_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.delete_property_document_admin(UUID) TO authenticated;


CREATE OR REPLACE FUNCTION public.record_customer_document_upload_admin(
    p_customer_user_id UUID,
    p_document_type TEXT,
    p_document_url TEXT,
    p_file_name TEXT DEFAULT NULL,
    p_description TEXT DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
    v_document_id UUID;
    v_uploader_admin_id UUID := auth.uid();
BEGIN
    IF NOT public.current_user_is_admin() THEN
        RAISE EXCEPTION 'Unauthorized: Admin access required.';
    END IF;
    IF NOT (public.current_user_has_role('telecalling-owner-team') OR public.current_user_has_role('telecalling-tenant-team') OR public.current_user_has_role('super-admin')) THEN
        RAISE EXCEPTION 'Unauthorized: Insufficient privileges to manage customer documents.';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM auth.users WHERE id = p_customer_user_id) THEN
        RAISE EXCEPTION 'Customer User ID % not found.', p_customer_user_id;
    END IF;

    INSERT INTO public.customer_documents(user_id, document_type, document_url, file_name, description, uploaded_by, uploaded_at)
    VALUES (p_customer_user_id, p_document_type, p_document_url, p_file_name, p_description, v_uploader_admin_id, CURRENT_TIMESTAMP)
    RETURNING document_id INTO v_document_id;
    RETURN v_document_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.record_customer_document_upload_admin(UUID, TEXT, TEXT, TEXT, TEXT) TO authenticated;

CREATE OR REPLACE FUNCTION public.delete_customer_document_admin(p_document_id UUID)
RETURNS VOID AS $$
BEGIN
    IF NOT public.current_user_is_admin() THEN
        RAISE EXCEPTION 'Unauthorized: Admin access required.';
    END IF;
     IF NOT (public.current_user_has_role('telecalling-owner-team') OR public.current_user_has_role('telecalling-tenant-team') OR public.current_user_has_role('super-admin')) THEN
        RAISE EXCEPTION 'Unauthorized: Insufficient privileges to manage customer documents.';
    END IF;
    DELETE FROM public.customer_documents WHERE document_id = p_document_id;
    IF NOT FOUND THEN RAISE WARNING 'Customer document % not found.', p_document_id; END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.delete_customer_document_admin(UUID) TO authenticated;


CREATE OR REPLACE FUNCTION public.get_full_property_details_admin(p_property_id_input UUID)
RETURNS TABLE (
    property_id UUID,
    property_type public.property_type_enum,
    listing_type public.listing_type_enum,
    price DECIMAL,
    area DECIMAL,
    area_unit public.area_unit_enum,
    description TEXT,
    details JSONB,
    locality TEXT,
    city TEXT,
    address TEXT,
    pincode INTEGER,
    youtube_url TEXT,
    latitude DECIMAL(9,6),
    longitude DECIMAL(9,6),
    year_built INTEGER,
    nearest_hospital DECIMAL(5,1),
    nearest_busstop DECIMAL(5,1),
    nearest_gym DECIMAL(5,1),
    nearest_park DECIMAL(5,1),
    nearest_school DECIMAL(5,1),
    nearest_swimmingpool DECIMAL(5,1),
    proximity_unit public.proximity_unit_enum,
    admin_notes TEXT,
    inventory_details JSONB,
    admin_status public.property_admin_status_enum,
    is_listed BOOLEAN,
    is_featured BOOLEAN,
    is_exclusive BOOLEAN,
    advance_amount DECIMAL(10,2),
    rent_due_day INTEGER,
    submitter_type public.submitter_type_enum,
    submitter_notes TEXT,
    submitted_at TIMESTAMP WITH TIME ZONE,
    availability_status public.availability_status_enum,
    can_reachout BOOLEAN,
    created_at TIMESTAMP WITH TIME ZONE,
    updated_at TIMESTAMP WITH TIME ZONE,
    images JSONB,
    property_documents JSONB,
    submitter JSONB,
    tenant JSONB,
    management_plan JSONB,
    owner_contact_assignment JSONB,
    marketing_assignment JSONB,
    customer_interactions JSONB,
    rent_records JSONB,
    tickets JSONB
) AS $$
BEGIN
    IF NOT public.current_user_is_admin() THEN
        RAISE EXCEPTION 'Unauthorized: Admin access required to access full property details.';
    END IF;

    RETURN QUERY
    WITH property_base AS (
        SELECT p.*
        FROM public.properties p
        WHERE p.property_id = p_property_id_input
    ),
    submitter_info_cte AS (
        SELECT
            pb.property_id,
            jsonb_build_object(
                'id', u.id,
                'name', (u.raw_user_meta_data ->> 'full_name')::TEXT,
                'email', u.email::TEXT,
                'phone', u.phone::TEXT,
                'visit_balance', c.visit_balance,
                'expiry_date', c.expiry_date,
                'profile_details', c.profile_details,
                'created_at', u.created_at,
                'updated_at', u.updated_at
            ) AS submitter_data
        FROM property_base pb
        JOIN auth.users u ON pb.submitter = u.id
        LEFT JOIN public.customers c ON pb.submitter = c.user_id
        WHERE pb.submitter IS NOT NULL
    ),
    tenant_info_cte AS (
        SELECT
            pb.property_id,
            jsonb_build_object(
                'id', u.id,
                'name', (u.raw_user_meta_data ->> 'full_name')::TEXT,
                'email', u.email::TEXT,
                'phone', u.phone::TEXT,
                'visit_balance', c.visit_balance,
                'expiry_date', c.expiry_date,
                'profile_details', c.profile_details,
                'created_at', u.created_at,
                'updated_at', u.updated_at
            ) AS tenant_data
        FROM property_base pb
        JOIN auth.users u ON pb.tenant = u.id
        LEFT JOIN public.customers c ON pb.tenant = c.user_id
        WHERE pb.tenant IS NOT NULL
    ),
    management_plan_info_cte AS (
        SELECT
            pb.property_id,
            jsonb_build_object(
                'plan_id', msp.plan_id,
                'name', msp.name,
                'percentage', msp.percentage,
                'description', msp.description,
                'is_active', msp.is_active,
                'created_at', msp.created_at,
                'updated_at', msp.updated_at
            ) AS management_plan_data
        FROM property_base pb
        JOIN public.management_service_plans msp ON pb.management_plan_id = msp.plan_id
        WHERE pb.management_plan_id IS NOT NULL
    ),
    aggregated_property_images_cte AS (
        SELECT
            pi.property_id,
            jsonb_agg(
                jsonb_build_object(
                    'image_id', pi.image_id,
                    'image_url', pi.image_url,
                    'description', pi.description,
                    'display_order', pi.display_order,
                    'is_internal_image', pi.is_internal_image,
                    'uploaded_by', CASE
                        WHEN uploader_admin.user_id IS NOT NULL THEN jsonb_build_object(
                            'id', uploader_admin.user_id,
                            'name', (uploader_auth_user.raw_user_meta_data->>'full_name')::TEXT,
                            'email', uploader_auth_user.email::TEXT
                        )
                        ELSE NULL
                    END,
                    'created_at', pi.created_at
                ) ORDER BY pi.display_order ASC, pi.created_at ASC
            ) AS images_data
        FROM public.property_images pi
        LEFT JOIN public.admins uploader_admin ON pi.uploaded_by = uploader_admin.user_id
        LEFT JOIN auth.users uploader_auth_user ON uploader_admin.user_id = uploader_auth_user.id
        WHERE pi.property_id = p_property_id_input
        GROUP BY pi.property_id
    ),
    aggregated_property_documents_cte AS (
        SELECT
            pd.property_id,
            jsonb_agg(
                jsonb_build_object(
                    'document_id', pd.document_id,
                    'document_type', pd.document_type,
                    'document_url', pd.document_url,
                    'file_name', pd.file_name,
                    'description', pd.description,
                    'uploaded_by_name', (uploader_auth_user.raw_user_meta_data->>'full_name')::TEXT,
                    'uploaded_at', pd.uploaded_at
                ) ORDER BY pd.uploaded_at ASC
            ) AS property_documents_data
        FROM public.property_documents pd
        LEFT JOIN public.admins uploader_admin ON pd.uploaded_by = uploader_admin.user_id
        LEFT JOIN auth.users uploader_auth_user ON uploader_admin.user_id = uploader_auth_user.id
        WHERE pd.property_id = p_property_id_input
        GROUP BY pd.property_id
    ),
    owner_contact_assignment_info_cte AS (
        SELECT
            poca.property_id,
            jsonb_build_object(
                'assigned_admin_id', poca.assigned_admin_id,
                'assigned_admin_name', (assignee_auth_user.raw_user_meta_data->>'full_name')::TEXT,
                'assigned_at', poca.assigned_at
            ) AS owner_contact_assignment_data
        FROM public.property_owner_contact_assignments poca
        JOIN public.admins assignee_admin ON poca.assigned_admin_id = assignee_admin.user_id
        JOIN auth.users assignee_auth_user ON assignee_admin.user_id = assignee_auth_user.id
        WHERE poca.property_id = p_property_id_input
    ),
    marketing_assignment_info_cte AS (
        SELECT
            pma.property_id,
            jsonb_build_object(
                'assigned_admin_id', pma.assigned_admin_id,
                'assigned_admin_name', (assignee_auth_user.raw_user_meta_data->>'full_name')::TEXT,
                'assigned_at', pma.assigned_at
            ) AS marketing_assignment_data
        FROM public.property_marketing_assignments pma
        JOIN public.admins assignee_admin ON pma.assigned_admin_id = assignee_admin.user_id
        JOIN auth.users assignee_auth_user ON assignee_admin.user_id = assignee_auth_user.id
        WHERE pma.property_id = p_property_id_input
    ),
    aggregated_customer_interactions_cte AS (
        SELECT
            ci.property_id,
            jsonb_agg(
                jsonb_build_object(
                    'interaction_id', ci.interaction_id,
                    'user', jsonb_build_object(
                        'id', u.id,
                        'name', (u.raw_user_meta_data->>'full_name')::TEXT,
                        'email', u.email::TEXT
                    ),
                    'assigned_sales_admin', CASE
                        WHEN sales_admin.user_id IS NOT NULL THEN jsonb_build_object(
                            'id', sales_admin.user_id,
                            'name', (sales_admin_auth_user.raw_user_meta_data->>'full_name')::TEXT
                        )
                        ELSE NULL
                    END,
                    'status', ci.status,
                    'created_at', ci.created_at,
                    'scheduled_for', ci.scheduled_for,
                    'visited_at', ci.visited_at,
                    'admin_notes', ci.admin_notes
                ) ORDER BY ci.created_at DESC
            ) AS interactions_data
        FROM public.customers_interaction ci
        LEFT JOIN auth.users u ON ci.user_id = u.id
        LEFT JOIN public.admins sales_admin ON ci.assigned_sales_admin_id = sales_admin.user_id
        LEFT JOIN auth.users sales_admin_auth_user ON sales_admin.user_id = sales_admin_auth_user.id
        WHERE ci.property_id = p_property_id_input
        GROUP BY ci.property_id
    ),
    aggregated_rent_records_cte AS (
        SELECT
            rr.property_id,
            jsonb_agg(
                jsonb_build_object(
                    'rent_record_id', rr.rent_record_id,
                    'tenant', jsonb_build_object(
                        'id', t_user.id,
                        'name', (t_user.raw_user_meta_data->>'full_name')::TEXT,
                        'email', t_user.email::TEXT
                    ),
                    'landlord', jsonb_build_object(
                        'id', l_user.id,
                        'name', (l_user.raw_user_meta_data->>'full_name')::TEXT,
                        'email', l_user.email::TEXT
                    ),
                    'due_date', rr.due_date,
                    'period_start_date', rr.period_start_date,
                    'period_end_date', rr.period_end_date,
                    'amount_due', rr.amount_due,
                    'amount_paid', rr.amount_paid,
                    'status', rr.status,
                    'notes', rr.notes,
                    'created_at', rr.created_at
                ) ORDER BY rr.due_date DESC
            ) AS rent_records_data
        FROM public.rent_records rr
        LEFT JOIN auth.users t_user ON rr.tenant_user_id = t_user.id
        LEFT JOIN auth.users l_user ON rr.landlord_user_id = l_user.id
        WHERE rr.property_id = p_property_id_input
        GROUP BY rr.property_id
    ),
    aggregated_tickets_cte AS (
        SELECT
            t.property_id,
            jsonb_agg(
                jsonb_build_object(
                    'ticket_id', t.ticket_id,
                    'raised_by', jsonb_build_object(
                        'id', r_user.id,
                        'name', (r_user.raw_user_meta_data->>'full_name')::TEXT,
                        'email', r_user.email::TEXT
                    ),
                    'subject', t.subject,
                    'description', t.description,
                    'category', t.category,
                    'priority', t.priority,
                    'status', t.status,
                    'assigned_vendor', CASE
                        WHEN v.vendor_id IS NOT NULL THEN jsonb_build_object(
                            'vendor_id', v.vendor_id,
                            'company_name', v.company_name
                        )
                        ELSE NULL
                    END,
                    'assigned_support_admin', CASE
                        WHEN support_admin.user_id IS NOT NULL THEN jsonb_build_object(
                            'admin_id', support_admin.user_id,
                            'name', (support_admin_auth_user.raw_user_meta_data->>'full_name')::TEXT
                        )
                        ELSE NULL
                    END,
                    'resolution_notes', t.resolution_notes,
                    'created_at', t.created_at,
                    'images', COALESCE((
                        SELECT jsonb_agg(jsonb_build_object(
                            'image_id', ti.image_id,
                            'ticket_id', ti.ticket_id,
                            'image_url', ti.image_url,
                            'description', ti.description,
                            'uploaded_by', ti.uploaded_by::TEXT,
                            'created_at', ti.created_at
                        ) ORDER BY ti.created_at ASC)
                        FROM public.ticket_images ti WHERE ti.ticket_id = t.ticket_id
                    ), '[]'::jsonb),
                    'comments', COALESCE((
                        SELECT jsonb_agg(jsonb_build_object(
                            'comment_id', tc.comment_id,
                            'ticket_id', tc.ticket_id,
                            'comment_text', tc.comment_text,
                            'is_internal', tc.is_internal,
                            'user_id', tc.user_id::TEXT,
                            'created_at', tc.created_at
                        ) ORDER BY tc.created_at ASC)
                        FROM public.ticket_comments tc WHERE tc.ticket_id = t.ticket_id
                    ), '[]'::jsonb)
                ) ORDER BY t.created_at DESC
            ) AS tickets_data
        FROM public.tickets t
        LEFT JOIN auth.users r_user ON t.raised_by_user_id = r_user.id
        LEFT JOIN public.vendors v ON t.assigned_to_vendor_id = v.vendor_id
        LEFT JOIN public.admins support_admin ON t.assigned_support_admin_id = support_admin.user_id
        LEFT JOIN auth.users support_admin_auth_user ON support_admin.user_id = support_admin_auth_user.id
        WHERE t.property_id = p_property_id_input
        GROUP BY t.property_id
    )
    SELECT
        pb.property_id,
        pb.property_type,
        pb.listing_type,
        pb.price,
        pb.area,
        pb.area_unit,
        pb.description,
        pb.details,
        pb.locality,
        pb.city,
        pb.address,
        pb.pincode,
        pb.youtube_url,
        pb.latitude,
        pb.longitude,
        pb.year_built,
        pb.nearest_hospital,
        pb.nearest_busstop,
        pb.nearest_gym,
        pb.nearest_park,
        pb.nearest_school,
        pb.nearest_swimmingpool,
        pb.proximity_unit,
        pb.admin_notes,
        pb.inventory_details,
        pb.admin_status,
        pb.is_listed,
        pb.is_featured,
        pb.is_exclusive,
        pb.advance_amount,
        pb.rent_due_day,
        pb.submitter_type,
        pb.submitter_notes,
        pb.submitted_at,
        pb.availability_status,
        pb.can_reachout,
        pb.created_at,
        pb.updated_at,
        COALESCE(img_cte.images_data, '[]'::jsonb),
        COALESCE(docs_cte.property_documents_data, '[]'::jsonb),
        s_info_cte.submitter_data,
        t_info_cte.tenant_data,
        mp_info_cte.management_plan_data,
        oca_info_cte.owner_contact_assignment_data,
        mka_info_cte.marketing_assignment_data,
        COALESCE(inter_cte.interactions_data, '[]'::jsonb),
        COALESCE(rent_cte.rent_records_data, '[]'::jsonb),
        COALESCE(ticket_cte.tickets_data, '[]'::jsonb)
    FROM property_base pb
    LEFT JOIN submitter_info_cte s_info_cte ON pb.property_id = s_info_cte.property_id
    LEFT JOIN tenant_info_cte t_info_cte ON pb.property_id = t_info_cte.property_id
    LEFT JOIN management_plan_info_cte mp_info_cte ON pb.property_id = mp_info_cte.property_id
    LEFT JOIN aggregated_property_images_cte img_cte ON pb.property_id = img_cte.property_id
    LEFT JOIN aggregated_property_documents_cte docs_cte ON pb.property_id = docs_cte.property_id
    LEFT JOIN owner_contact_assignment_info_cte oca_info_cte ON pb.property_id = oca_info_cte.property_id
    LEFT JOIN marketing_assignment_info_cte mka_info_cte ON pb.property_id = mka_info_cte.property_id
    LEFT JOIN aggregated_customer_interactions_cte inter_cte ON pb.property_id = inter_cte.property_id
    LEFT JOIN aggregated_rent_records_cte rent_cte ON pb.property_id = rent_cte.property_id
    LEFT JOIN aggregated_tickets_cte ticket_cte ON pb.property_id = ticket_cte.property_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

GRANT EXECUTE ON FUNCTION public.get_full_property_details_admin(UUID) TO authenticated;