DO $fix$
DECLARE
    function_definition TEXT;
    function_oid OID;
BEGIN
    SELECT p.oid, pg_get_functiondef(p.oid)
    INTO function_oid, function_definition
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = 'get_properties_customer'
      AND p.pronargs = 22;

    IF function_oid IS NULL THEN
        RAISE EXCEPTION 'get_properties_customer was not found';
    END IF;

    function_definition := replace(function_definition,
        'pwc.is_exclusive DESC, pwc.is_featured DESC,',
        'pwc.is_exclusive DESC,'
    );

    EXECUTE function_definition;
END;
$fix$;
