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

    function_definition := replace(
        function_definition,
        '    is_featured BOOLEAN,',
        '    is_featured BOOLEAN,
    is_exclusive BOOLEAN,'
    );
    function_definition := replace(
        function_definition,
        'pwc.proximity_unit, pwc.is_featured, pwc.property_images_data AS property_images,',
        'pwc.proximity_unit, pwc.is_featured, pwc.is_exclusive, pwc.property_images_data AS property_images,'
    );

    EXECUTE format('DROP FUNCTION public.get_properties_customer(%s)', identity_arguments);
    EXECUTE function_definition;
    EXECUTE format('GRANT EXECUTE ON FUNCTION public.get_properties_customer(%s) TO anon, authenticated', identity_arguments);
END;
$fix$;
