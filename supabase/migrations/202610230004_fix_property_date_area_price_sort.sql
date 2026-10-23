DO $fix$
DECLARE
    function_definition TEXT;
    function_oid OID;
    old_order TEXT;
    new_order TEXT := $sql$IF p_sort_by IS NULL OR p_sort_by = 'updated_at' THEN
        v_order_by_clause := 'ORDER BY COALESCE(pwc.updated_at, pwc.created_at) DESC, pwc.property_id DESC';
    ELSIF p_sort_by = 'area' THEN
        v_order_by_clause := format('ORDER BY pwc.normalized_area_sqft %s NULLS LAST, COALESCE(pwc.updated_at, pwc.created_at) DESC, pwc.property_id DESC', v_final_sort_direction);
    ELSE
        v_order_by_clause := format('ORDER BY %s %s NULLS LAST, COALESCE(pwc.updated_at, pwc.created_at) DESC, pwc.property_id DESC', v_final_sort_by, v_final_sort_direction);
    END IF;$sql$;
BEGIN
    SELECT p.oid, pg_get_functiondef(p.oid)
    INTO function_oid, function_definition
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = 'get_properties_customer' AND p.pronargs = 22;

    IF function_oid IS NULL THEN RAISE EXCEPTION 'get_properties_customer was not found'; END IF;

    function_definition := replace(function_definition,
        '                p.proximity_unit, p.is_featured, p.updated_at, p.created_at,',
        '                p.proximity_unit, p.is_featured, p.updated_at, p.created_at,
                CASE p.area_unit
                    WHEN ''SQ_FT'' THEN p.area
                    WHEN ''CENTS'' THEN p.area * 435.6
                    WHEN ''ACRES'' THEN p.area * 43560
                    ELSE NULL
                END AS normalized_area_sqft,');

    old_order := $sql$IF p_sort_by IS NULL OR p_sort_by = 'updated_at' THEN
        v_order_by_clause := 'ORDER BY COALESCE(pwc.updated_at, pwc.created_at) DESC, pwc.property_id DESC';
    ELSE
        v_order_by_clause := format('ORDER BY %s %s NULLS LAST, COALESCE(pwc.updated_at, pwc.created_at) DESC, pwc.property_id DESC', v_final_sort_by, v_final_sort_direction);
    END IF;$sql$;
    function_definition := replace(function_definition, old_order, new_order);
    old_order := $sql$v_order_by_clause := format('ORDER BY pwc.is_featured DESC, %s %s, pwc.property_id ASC', v_final_sort_by, v_final_sort_direction);$sql$;
    function_definition := replace(function_definition, old_order, new_order);

    EXECUTE function_definition;
END;
$fix$;
