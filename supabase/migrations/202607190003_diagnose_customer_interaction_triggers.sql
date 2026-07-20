-- No-op catalog diagnostic: records the live trigger functions in migration
-- output so drift from the checked-in schema can be corrected precisely.
DO $$
DECLARE
    trigger_record RECORD;
BEGIN
    FOR trigger_record IN
        SELECT
            trigger_info.tgname,
            procedure_info.proname,
            pg_get_functiondef(procedure_info.oid) AS function_definition
        FROM pg_trigger AS trigger_info
        JOIN pg_proc AS procedure_info
          ON procedure_info.oid = trigger_info.tgfoid
        WHERE trigger_info.tgrelid = 'public.customers_interaction'::regclass
          AND NOT trigger_info.tgisinternal
    LOOP
        RAISE NOTICE 'CUSTOMER_INTERACTION_TRIGGER: %, FUNCTION: %, DEFINITION: %',
            trigger_record.tgname,
            trigger_record.proname,
            trigger_record.function_definition;
    END LOOP;
END;
$$;
