-- FILE NAME: 09_seed_properties.sql
-- Description: Seeds initial property data into the 'properties' table.
-- Depends on: 00_enums.sql, 01_tables.sql, 08_initial_data.sql (for admin users and plans)
-------------------------------------------------------------------------------

DO $$
DECLARE
    -- These users MUST exist in auth.users and relevant ones in public.admins.
    v_owner_submitter_user_id UUID := 'a76d0b87-a059-41a6-b527-a4f05f8173eb'; -- An admin who will act as submitter/owner
    v_another_owner_user_id UUID := 'd2a75546-f9d3-45a9-b8b7-51ebf9f2f54f'; -- Another user who can be a submitter
    v_tenant_user_id_1 UUID := 'd2a75546-f9d3-45a9-b8b7-51ebf9f2f54f';     -- A user who will be a tenant
    v_tenant_user_id_2 UUID := 'a76d0b87-a059-41a6-b527-a4f05f8173eb';     -- Another tenant

    v_standard_plan_id UUID;
    v_premium_plan_id UUID;

    prop1_id UUID;
    prop2_id UUID;
    prop3_id UUID;
    prop4_id UUID;
    prop5_id UUID;
    prop6_id UUID;
    prop7_id UUID; -- For a SUBMITTED property
    prop8_id UUID; -- For a RENTED property
BEGIN

    -- Basic UUID placeholder check
    IF v_owner_submitter_user_id = '00000000-0000-0000-0000-000000000000' OR
       v_another_owner_user_id = '11111111-1111-1111-1111-111111111111' OR
       v_tenant_user_id_1 = '33333333-3333-3333-3333-333333333333' OR
       v_tenant_user_id_2 = '44444444-4444-4444-4444-444444444444' THEN
       RAISE EXCEPTION 'Placeholder UUIDs detected for users in 09_seed_properties.sql. Please replace them with actual auth.users.id values before running.';
    END IF;

    -- Check if users exist (basic check, assumes they are in auth.users)
    -- For v_owner_submitter_user_id, it's also assumed this user is an admin if they are uploading images/docs "as admin"
    PERFORM 1 FROM auth.users WHERE id = v_owner_submitter_user_id;
    IF NOT FOUND THEN 
        RAISE WARNING 'User ID for v_owner_submitter_user_id (%) not found in auth.users. Skipping mock property seeding.', v_owner_submitter_user_id; 
        RETURN; 
    END IF;
    
    PERFORM 1 FROM auth.users WHERE id = v_another_owner_user_id;
    IF NOT FOUND THEN 
        RAISE WARNING 'User ID for v_another_owner_user_id (%) not found. Skipping mock property seeding.', v_another_owner_user_id; 
        RETURN; 
    END IF;
    
    PERFORM 1 FROM auth.users WHERE id = v_tenant_user_id_1;
    IF NOT FOUND THEN 
        RAISE WARNING 'User ID for v_tenant_user_id_1 (%) not found. Skipping mock property seeding.', v_tenant_user_id_1; 
        RETURN; 
    END IF;
    
    PERFORM 1 FROM auth.users WHERE id = v_tenant_user_id_2;
    IF NOT FOUND THEN 
        RAISE WARNING 'User ID for v_tenant_user_id_2 (%) not found. Skipping mock property seeding.', v_tenant_user_id_2; 
        RETURN; 
    END IF;


    -- Get Plan IDs
    SELECT plan_id INTO v_standard_plan_id FROM public.management_service_plans WHERE name = 'Standard Rental Management';
    SELECT plan_id INTO v_premium_plan_id FROM public.management_service_plans WHERE name = 'Premium Rental Management';

    IF v_standard_plan_id IS NULL OR v_premium_plan_id IS NULL THEN
        RAISE EXCEPTION 'Management plan IDs not found. Ensure 08_initial_data.sql was run correctly and plans exist.';
    END IF;


    RAISE NOTICE 'Seeding properties in Tirunelveli...';

    -- Property 1: House for Sale, Listed, by v_owner_submitter_user_id
    INSERT INTO public.properties (
        property_type, listing_type, price, area, area_unit, description, locality, city, address, pincode, latitude, longitude, year_built,
        nearest_hospital, nearest_school, nearest_busstop, proximity_unit,
        admin_status, is_listed, is_featured, is_exclusive, details,
        submitter, submitter_type, submitted_at, availability_status, can_reachout, advance_amount
    ) VALUES (
        'HOUSE', 'SALE', 7500000.00, 1800.00, 'SQ_FT', 'Spacious 3 BHK Independent Villa near St. Xavier''s College. Well-maintained.', 'Palayamkottai', 'Tirunelveli', '15, College Road, Palayamkottai', 627002, 8.715123, 77.745678, 2012,
        1.2, 0.5, 0.3, 'KM',
        'MARKETING_VERIFIED', TRUE, TRUE, FALSE, -- Assuming it passed all internal checks to be listed
        '{"house_type": "INDEPENDENT_VILLA", "house_name": "Xavier''s View Villa", "num_bedrooms": 3, "num_bathrooms": 3, "num_balconies": 2, "total_floors": 2, "floor_number": null, "num_carparking": 1, "furnished_status": "SEMI_FURNISHED", "facing_direction": "EAST", "is_corner_plot": false, "water_source": "BOTH", "power_backup": "PARTIAL"}'::jsonb,
        v_owner_submitter_user_id, 'OWNER', CURRENT_TIMESTAMP - INTERVAL '10 days', 'READY_TO_MOVE', TRUE, NULL -- No advance for sale
    ) RETURNING property_id INTO prop1_id;

    INSERT INTO public.property_images (property_id, image_url, display_order, is_internal_image, uploaded_by) VALUES
    (prop1_id, 'https://placehold.co/600x400/EFEFEF/AAAAAA?text=Villa+Exterior', 0, FALSE, v_owner_submitter_user_id),
    (prop1_id, 'https://placehold.co/600x400/EEEEEE/31343C?text=Living+Area', 1, FALSE, v_owner_submitter_user_id);

    INSERT INTO public.property_documents (property_id, document_type, document_url, file_name, uploaded_by) VALUES
    (prop1_id, 'Sale Deed Copy', 'https://example.com/docs/prop1_sale_deed.pdf', 'prop1_sale_deed.pdf', v_owner_submitter_user_id);


    -- Property 2: Land for Sale, Listed, by v_another_owner_user_id
    INSERT INTO public.properties (
        property_type, listing_type, price, area, area_unit, description, locality, city, address, pincode, latitude, longitude,
        admin_status, is_listed, details,
        submitter, submitter_type, submitted_at, availability_status, can_reachout
    ) VALUES (
        'LAND', 'SALE', 4500000.00, 5.5, 'CENTS', 'Prime residential plot near Vannarpettai bridge.', 'Vannarpettai', 'Tirunelveli', 'Plot No. 22, Bridge View Layout, Vannarpettai', 627001, 8.709876, 77.751234,
        'MARKETING_VERIFIED', TRUE,
        '{"land_type": "RESIDENTIAL", "plot_dimensions": "50x48", "road_access_width_ft": 30}'::jsonb,
        v_another_owner_user_id, 'OWNER', CURRENT_TIMESTAMP - INTERVAL '5 days', 'READY_TO_MOVE', TRUE
    ) RETURNING property_id INTO prop2_id;

    INSERT INTO public.property_images (property_id, image_url, display_order, uploaded_by) VALUES
    (prop2_id, 'https://placehold.co/600x400/F5F5F5/888888?text=Plot+View+1', 0, v_another_owner_user_id);


    -- Property 3: Apartment for Rent, Listed, Occupied by v_tenant_user_id_1, Standard Plan, submitted by v_owner_submitter_user_id
    INSERT INTO public.properties (
        property_type, listing_type, price, area, area_unit, description, locality, city, address, pincode, latitude, longitude, year_built,
        admin_status, is_listed, details, rent_due_day, advance_amount,
        submitter, submitter_type, tenant, management_plan_id,
        submitted_at, availability_status, can_reachout
    ) VALUES (
        'HOUSE', 'RENTAL', 12000.00, 1100.00, 'SQ_FT', 'Modern 2 BHK apartment in a gated community.', 'Maharaja Nagar', 'Tirunelveli', 'Apt #305, Royal Gardens, Maharaja Nagar', 627011, 8.721111, 77.738888, 2018,
        'RENTED', TRUE, -- Listed and Rented
        '{"house_type": "APARTMENT_FLAT", "house_name": "Royal Gardens", "num_bedrooms": 2, "num_bathrooms": 2, "num_balconies": 1, "total_floors": 8, "floor_number": 3, "furnished_status": "UNFURNISHED"}'::jsonb,
        5, 50000.00, -- Rent due day, Advance
        v_owner_submitter_user_id, 'OWNER', v_tenant_user_id_1, v_standard_plan_id,
        CURRENT_TIMESTAMP - INTERVAL '20 days', 'READY_TO_MOVE', TRUE
    ) RETURNING property_id INTO prop3_id;

    INSERT INTO public.property_images (property_id, image_url, display_order, uploaded_by) VALUES
    (prop3_id, 'https://placehold.co/600x400/FFF0E1/A0522D?text=Apt+Building', 0, v_owner_submitter_user_id);


    -- Property 4: Commercial Building for Rent, Listed, Vacant, Premium Plan, submitted by v_owner_submitter_user_id
    INSERT INTO public.properties (
        property_type, listing_type, price, area, area_unit, description, locality, city, address, pincode, year_built,
        admin_status, is_listed, is_exclusive, details, rent_due_day, advance_amount,
        submitter, submitter_type, management_plan_id,
        submitted_at, availability_status
    ) VALUES (
        'BUILDING', 'RENTAL', 80000.00, 3500.00, 'SQ_FT', 'Ground floor commercial space, high footfall area.', 'Tirunelveli Junction', 'Tirunelveli', '78, Madurai Road, Tirunelveli Junction', 627001, 2005,
        'AWAITING_LISTING', TRUE, TRUE, -- Marketing verified, now listed by admin
        '{"building_type": "RETAIL", "building_name": "Junction Plaza", "total_floors": 3}'::jsonb,
        1, 300000.00,
        v_owner_submitter_user_id, 'BUILDER', v_premium_plan_id,
        CURRENT_TIMESTAMP - INTERVAL '15 days', 'READY_TO_MOVE'
    ) RETURNING property_id INTO prop4_id;


    -- Property 5: Agricultural Land, Listed, submitted by v_another_owner_user_id
    INSERT INTO public.properties (
        property_type, listing_type, price, area, area_unit, description, locality, city, address, pincode,
        admin_status, is_listed, details,
        submitter, submitter_type, submitted_at
    ) VALUES (
        'LAND', 'SALE', 9500000.00, 2.5, 'ACRES', 'Fertile agricultural land with good water source.', 'Melapalayam Outskirts', 'Tirunelveli', 'Survey No. 105/2B, Near Bypass Road', 627005,
        'MARKETING_VERIFIED', TRUE,
        '{"land_type": "AGRICULTURAL"}'::jsonb,
        v_another_owner_user_id, 'OWNER', CURRENT_TIMESTAMP - INTERVAL '3 days'
    ) RETURNING property_id INTO prop5_id;


    -- Property 6: House for Rent, submitted by v_owner_submitter_user_id, current status OWNER_VERIFIED (not yet listed)
    INSERT INTO public.properties (
        property_type, listing_type, price, area, area_unit, description, locality, city, address, pincode, year_built,
        admin_status, is_listed, details, rent_due_day, advance_amount,
        submitter, submitter_type, submitter_notes,
        submitted_at, availability_status
    ) VALUES (
        'HOUSE', 'RENTAL', 15000.00, 1400.00, 'SQ_FT', '3 BHK Independent House, calm residential area. Awaiting marketing visit.', 'Perumalpuram', 'Tirunelveli', 'Plot 45, 7th Street, Perumalpuram', 627007, 2008,
        'OWNER_VERIFIED', FALSE, -- Telecalling owner verified, awaiting marketing
        '{"house_type": "INDEPENDENT_VILLA", "num_bedrooms": 3, "num_bathrooms": 2, "furnished_status": "SEMI_FURNISHED"}'::jsonb,
        10, 60000.00,
        v_owner_submitter_user_id, 'OWNER', 'Owner contact verified. Property details seem correct. Needs marketing photos.',
        CURRENT_TIMESTAMP - INTERVAL '2 days', 'READY_TO_MOVE'
    ) RETURNING property_id INTO prop6_id;

    INSERT INTO public.property_images (property_id, image_url, display_order, is_internal_image, uploaded_by) VALUES
    (prop6_id, 'https://placehold.co/600x400/FDF5E6/A0522D?text=House+Front+(Awaiting+Marketing)', 0, FALSE, v_owner_submitter_user_id),
    (prop6_id, 'https://placehold.co/600x400/888888/EEEEEE?text=Internal+View+Needed', 0, TRUE, v_owner_submitter_user_id);


    -- Property 7: New submission by v_another_owner_user_id, status SUBMITTED
    INSERT INTO public.properties (
        property_type, listing_type, price, area, area_unit, description, locality, city, address, pincode,
        admin_status, is_listed, details,
        submitter, submitter_type, submitted_at, can_reachout, availability_status
    ) VALUES (
        'HOUSE', 'SALE', 5500000.00, 1200.00, 'SQ_FT', 'Newly submitted 2BHK for sale in NGO Colony.', 'NGO Colony', 'Tirunelveli', '12B, Anna Nagar, NGO Colony', 627007,
        'SUBMITTED', FALSE,
        '{"house_type": "INDEPENDENT_VILLA", "num_bedrooms": 2}'::jsonb,
        v_another_owner_user_id, 'OWNER', CURRENT_TIMESTAMP - INTERVAL '1 hour', FALSE, 'UNDER_CONSTRUCTION'
    ) RETURNING property_id INTO prop7_id;


    -- Property 8: Apartment for Rent, RENTED status, occupied by v_tenant_user_id_2, submitted by v_owner_submitter_user_id
    INSERT INTO public.properties (
        property_type, listing_type, price, area, area_unit, description, locality, city, address, pincode, year_built,
        admin_status, is_listed, details, rent_due_day, advance_amount,
        submitter, submitter_type, tenant, management_plan_id,
        submitted_at, availability_status, can_reachout
    ) VALUES (
        'HOUSE', 'RENTAL', 9500.00, 900.00, 'SQ_FT', 'Cozy 2 BHK apartment, currently occupied.', 'Thiyagaraja Nagar', 'Tirunelveli', 'Flat 1A, Star Apartments, Thiyagaraja Nagar', 627011, 2015,
        'RENTED', TRUE, -- It was listed, now rented
        '{"house_type": "APARTMENT_FLAT", "num_bedrooms": 2, "num_bathrooms": 1, "furnished_status": "SEMI_FURNISHED"}'::jsonb,
        3, 30000.00,
        v_owner_submitter_user_id, 'OWNER', v_tenant_user_id_2, v_standard_plan_id,
        CURRENT_TIMESTAMP - INTERVAL '6 months', 'READY_TO_MOVE', TRUE
    ) RETURNING property_id INTO prop8_id;


    RAISE NOTICE 'Property seeding complete. Remember to replace placeholder UUIDs if you havent already.';

END $$;