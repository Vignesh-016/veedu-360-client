DO $$
DECLARE
    function_definition TEXT;
BEGIN
    SELECT pg_get_functiondef(p.oid)
    INTO function_definition
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = 'get_properties_customer'
      AND p.pronargs = 22;

    IF function_definition IS NULL THEN
        RAISE EXCEPTION 'get_properties_customer function was not found';
    END IF;

    function_definition := replace(
        function_definition,
        'ORDER BY pwc.is_featured DESC, %s %s, pwc.property_id ASC',
        'ORDER BY %s %s NULLS LAST, pwc.property_id ASC'
    );

    IF function_definition = pg_get_functiondef((
        SELECT p.oid
        FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'public'
          AND p.proname = 'get_properties_customer'
          AND p.pronargs = 22
    )) THEN
        RAISE NOTICE 'Customer property sort is already strict';
    ELSE
        EXECUTE function_definition;
    END IF;
END;
$$;
