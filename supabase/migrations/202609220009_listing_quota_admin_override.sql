-- Make the admin-edited customer listing_quota the authoritative initial
-- allowance. Recurring credits are added after the first post date.
CREATE OR REPLACE FUNCTION public.get_property_posting_quota_customer()
RETURNS TABLE (
    property_count BIGINT, paid_listing_credits BIGINT,
    free_listing_entitlement BIGINT, total_listing_entitlement BIGINT,
    remaining_free_posts BIGINT, remaining_paid_posts BIGINT,
    remaining_posts BIGINT, next_free_post_at DATE
) AS $$
DECLARE
    v_user_id UUID := auth.uid(); v_first_post DATE; v_base_free BIGINT;
    v_free BIGINT; v_count BIGINT; v_paid BIGINT;
BEGIN
    IF v_user_id IS NULL THEN RAISE EXCEPTION 'Authentication required.'; END IF;

    SELECT COALESCE(c.listing_quota, 10)::BIGINT
    INTO v_base_free FROM public.customers c WHERE c.user_id = v_user_id;
    v_base_free := COALESCE(v_base_free, 10);

    SELECT COUNT(*)::BIGINT, MIN(p.submitted_at::DATE) INTO v_count, v_first_post
    FROM public.properties p
    WHERE p.submitter = v_user_id AND p.admin_status <> 'PAYMENT_PENDING';

    SELECT COUNT(*)::BIGINT INTO v_paid
    FROM public.transactions t
    WHERE t.user_id = v_user_id AND t.status = 'paid'
      AND t.payment_type IN ('property_listing', 'property_management')
      AND COALESCE(t.amount, 0) > 0;

    v_free := CASE WHEN v_first_post IS NULL THEN v_base_free
      ELSE v_base_free + GREATEST(0, FLOOR((CURRENT_DATE - v_first_post)::NUMERIC / 60)::BIGINT) END;

    RETURN QUERY SELECT v_count, v_paid, v_free, v_free + v_paid,
      GREATEST(v_free - LEAST(v_count, v_free), 0),
      GREATEST(v_paid - GREATEST(v_count - v_free, 0), 0),
      GREATEST(v_free + v_paid - v_count, 0),
      CASE WHEN v_first_post IS NULL THEN CURRENT_DATE
        ELSE v_first_post + ((FLOOR((CURRENT_DATE - v_first_post)::NUMERIC / 60)::INTEGER + 1) * 60) END;
END; $$ LANGUAGE plpgsql SECURITY DEFINER STABLE SET search_path = public;
GRANT EXECUTE ON FUNCTION public.get_property_posting_quota_customer() TO authenticated;

-- Remove the legacy fee from visit plans. Keep the row for historical
-- transaction references, but it must not be active or offered for purchase.
UPDATE public.visit_plans
SET is_active = FALSE
WHERE lower(trim(name)) = 'property listing fee';
