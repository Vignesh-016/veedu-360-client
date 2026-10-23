DO $fix$
DECLARE
    function_definition TEXT;
    function_oid OID;
    identity_arguments TEXT;
BEGIN
    SELECT p.oid, pg_get_functiondef(p.oid), pg_get_function_identity_arguments(p.oid)
    INTO function_oid, function_definition, identity_arguments
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = 'get_properties_customer'
      AND p.pronargs = 22;

    IF function_oid IS NULL THEN
        RAISE EXCEPTION 'get_properties_customer was not found';
    END IF;

    function_definition := replace(function_definition, '\n', E'\n');

    -- Add is_exclusive to the declared return table only when it is absent.
    IF function_definition NOT LIKE '%is_exclusive boolean%property_images jsonb%' THEN
        function_definition := regexp_replace(
            function_definition,
            'is_featured[[:space:]]+boolean,[[:space:]]+property_images[[:space:]]+jsonb',
            'is_featured boolean, is_exclusive boolean, property_images jsonb',
            1,
            1,
            'i'
        );
    END IF;

    -- Return the flag to the client when it is not already selected.
    IF function_definition NOT LIKE '%pwc.is_featured, pwc.is_exclusive, pwc.property_images_data%' THEN
        function_definition := replace(
            function_definition,
            'pwc.proximity_unit, pwc.is_featured, pwc.property_images_data AS property_images,',
            'pwc.proximity_unit, pwc.is_featured, pwc.is_exclusive, pwc.property_images_data AS property_images,'
        );
    END IF;

    EXECUTE format('DROP FUNCTION public.get_properties_customer(%s)', identity_arguments);
    EXECUTE function_definition;
    EXECUTE format('GRANT EXECUTE ON FUNCTION public.get_properties_customer(%s) TO anon, authenticated', identity_arguments);
END;
$fix$;
