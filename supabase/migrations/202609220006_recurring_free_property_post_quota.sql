-- Recurring free property-post entitlement.
-- One free post is available before the first property is posted. After the
-- first post, one additional free post becomes available every 60 days.

CREATE OR REPLACE FUNCTION public.get_property_posting_quota_customer()
RETURNS TABLE (
    property_count BIGINT,
    paid_listing_credits BIGINT,
    free_listing_entitlement BIGINT,
    total_listing_entitlement BIGINT,
    remaining_free_posts BIGINT,
    remaining_paid_posts BIGINT,
    remaining_posts BIGINT,
    next_free_post_at DATE
) AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_first_post DATE;
    v_free_entitlement BIGINT;
    v_property_count BIGINT;
    v_paid_credits BIGINT;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.';
    END IF;

    SELECT COUNT(*)::BIGINT, MIN(p.submitted_at::DATE)
    INTO v_property_count, v_first_post
    FROM public.properties p
    WHERE p.submitter = v_user_id
      AND p.admin_status <> 'PAYMENT_PENDING';

    SELECT COUNT(*)::BIGINT
    INTO v_paid_credits
    FROM public.transactions t
    WHERE t.user_id = v_user_id
      AND t.status = 'paid'
      AND t.payment_type IN ('property_listing', 'property_management')
      AND COALESCE(t.amount, 0) > 0;

    IF v_first_post IS NULL THEN
        v_free_entitlement := 10;
    ELSE
        v_free_entitlement := 10 + GREATEST(
            0,
            FLOOR((CURRENT_DATE - v_first_post)::NUMERIC / 60)::BIGINT
        );
    END IF;

    RETURN QUERY SELECT
        v_property_count,
        v_paid_credits,
        v_free_entitlement,
        v_free_entitlement + v_paid_credits,
        GREATEST(v_free_entitlement - LEAST(v_property_count, v_free_entitlement), 0),
        GREATEST(v_paid_credits - GREATEST(v_property_count - v_free_entitlement, 0), 0),
        GREATEST((v_free_entitlement + v_paid_credits) - v_property_count, 0),
        CASE
            WHEN v_first_post IS NULL THEN CURRENT_DATE
            ELSE v_first_post + ((FLOOR((CURRENT_DATE - v_first_post)::NUMERIC / 60)::INTEGER + 1) * 60)
        END;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE SET search_path = public;

GRANT EXECUTE ON FUNCTION public.get_property_posting_quota_customer() TO authenticated;
