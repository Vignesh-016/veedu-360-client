-- Expose the same calculated free-post entitlement to admins.
CREATE OR REPLACE FUNCTION public.get_property_posting_quota_admin(p_customer_user_id UUID)
RETURNS TABLE (
    first_post_date DATE,
    initial_free_posts BIGINT,
    free_posts_earned BIGINT,
    free_posts_used BIGINT,
    remaining_free_posts BIGINT,
    paid_listing_credits BIGINT,
    next_free_post_at DATE
) AS $$
DECLARE v_first DATE; v_base BIGINT; v_count BIGINT; v_paid BIGINT; v_earned BIGINT;
BEGIN
    IF NOT public.current_user_is_admin() THEN RAISE EXCEPTION 'Unauthorized.'; END IF;
    SELECT COALESCE(c.listing_quota, 10)::BIGINT INTO v_base FROM public.customers c WHERE c.user_id = p_customer_user_id;
    v_base := COALESCE(v_base, 10);
    SELECT COUNT(*)::BIGINT, MIN(p.submitted_at::DATE) INTO v_count, v_first
      FROM public.properties p WHERE p.submitter = p_customer_user_id AND p.admin_status <> 'PAYMENT_PENDING';
    SELECT COUNT(*)::BIGINT INTO v_paid FROM public.transactions t
      WHERE t.user_id = p_customer_user_id AND t.status = 'paid'
        AND t.payment_type IN ('property_listing', 'property_management') AND COALESCE(t.amount, 0) > 0;
    v_earned := v_base + CASE WHEN v_first IS NULL THEN 0 ELSE FLOOR((CURRENT_DATE - v_first)::NUMERIC / 60)::BIGINT END;
    RETURN QUERY SELECT v_first, v_base, v_earned, LEAST(v_count, v_earned),
      GREATEST(v_earned - LEAST(v_count, v_earned), 0), v_paid,
      CASE WHEN v_first IS NULL THEN CURRENT_DATE ELSE v_first + ((FLOOR((CURRENT_DATE - v_first)::NUMERIC / 60)::INTEGER + 1) * 60) END;
END; $$ LANGUAGE plpgsql SECURITY DEFINER STABLE SET search_path = public;
GRANT EXECUTE ON FUNCTION public.get_property_posting_quota_admin(UUID) TO authenticated;

-- A tenant must be able to open a rented property from My Rentals.
DO $$
DECLARE v_definition TEXT;
BEGIN
    SELECT pg_get_functiondef('public.get_my_property_with_id_customer(uuid)'::regprocedure)
      INTO v_definition;
    v_definition := replace(v_definition,
      'p.property_id = p_property_id_input AND p.submitter = v_current_user_id',
      'p.property_id = p_property_id_input AND (p.submitter = v_current_user_id OR p.tenant = v_current_user_id)');
    EXECUTE v_definition;
END $$;
