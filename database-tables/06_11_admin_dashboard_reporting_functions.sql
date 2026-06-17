-- FILE NAME: 06_11_admin_dashboard_reporting_functions.sql
-- Description: Functions for admins (primarily Super Admin) to get dashboard statistics and reports.
-------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.get_dashboard_stats_admin()
RETURNS JSONB AS $$
DECLARE
    stats JSONB;
    prop_stats JSONB;
    admin_staff_stats JSONB;
    customer_stats JSONB;
    interaction_stats JSONB;
    transaction_stats JSONB;
    service_stats JSONB;
    vendor_stats JSONB;
    ticket_stats JSONB;
    rent_stats JSONB;
    mgmt_plan_stats JSONB;
    visit_plan_stats JSONB;
BEGIN
    IF NOT public.current_user_has_role('super-admin') THEN
         RAISE EXCEPTION 'Unauthorized: Only super-admins can view dashboard stats.';
    END IF;

    -- Property Stats
    SELECT jsonb_object_agg(key, value) INTO prop_stats FROM (
      SELECT 'total_properties' as key, to_jsonb(count(*)) as value FROM public.properties UNION ALL
      SELECT 'publicly_listed_properties' as key, to_jsonb(count(*)) as value FROM public.properties WHERE is_listed = TRUE UNION ALL
      SELECT 'properties_by_admin_status' as key, COALESCE(jsonb_object_agg(admin_status, count), '{}'::jsonb) as value FROM (SELECT admin_status, COUNT(*) as count FROM public.properties GROUP BY admin_status) AS s UNION ALL
      SELECT 'rental_properties_is_listed' as key, to_jsonb(count(*)) as value FROM public.properties WHERE listing_type = 'RENTAL' AND is_listed = TRUE UNION ALL
      SELECT 'sale_properties_is_listed' as key, to_jsonb(count(*)) as value FROM public.properties WHERE listing_type = 'SALE' AND is_listed = TRUE UNION ALL
      SELECT 'occupied_rentals' as key, to_jsonb(count(*)) as value FROM public.properties WHERE listing_type = 'RENTAL' AND tenant IS NOT NULL AND admin_status = 'RENTED' UNION ALL -- Or other relevant active status
      SELECT 'properties_by_type' as key, COALESCE(jsonb_object_agg(property_type, count), '{}'::jsonb) as value FROM (SELECT property_type, COUNT(*) as count FROM public.properties GROUP BY property_type) AS pt
    ) AS prop;

    -- Admin Staff Stats
    SELECT jsonb_object_agg(key, value) INTO admin_staff_stats FROM (
        SELECT 'total_admin_staff' as key, to_jsonb(COUNT(*)) as value FROM public.admins UNION ALL
        SELECT 'active_admin_staff' as key, to_jsonb(COUNT(*)) as value FROM public.admins WHERE is_active = TRUE UNION ALL
        SELECT 'admin_staff_by_role' as key, COALESCE(jsonb_object_agg(role_name, count), '{}'::jsonb) as value FROM (
            SELECT unnest(roles) as role_name, COUNT(*) as count FROM public.admins WHERE is_active = TRUE GROUP BY role_name
        ) as r_counts
    ) AS adm_staff;

    -- Customer (User) Stats (from public.customers)
    SELECT jsonb_object_agg(key, value) INTO customer_stats FROM (
      SELECT 'total_registered_users' as key, to_jsonb(count(*)) as value FROM auth.users UNION ALL -- All users in the system
      SELECT 'customers_with_profiles' as key, to_jsonb(count(*)) as value FROM public.customers UNION ALL -- Users with a customer record
      SELECT 'customers_with_active_visits' as key, to_jsonb(count(*)) as value FROM public.customers WHERE visit_balance > 0 AND expiry_date >= CURRENT_DATE
    ) AS cust;

    -- Interaction Stats
    SELECT jsonb_object_agg(key, value) INTO interaction_stats FROM (
      SELECT 'total_interactions' as key, to_jsonb(COUNT(*)) as value FROM public.customers_interaction UNION ALL
      SELECT 'interactions_by_status' as key, COALESCE(jsonb_object_agg(status, count), '{}'::jsonb) as value FROM (
          SELECT status, COUNT(*) as count FROM public.customers_interaction GROUP BY status
      ) AS s
    ) AS intr;

    -- Transaction (Visit Plan Purchases) Stats
    SELECT jsonb_object_agg(key, value) INTO transaction_stats FROM (
      SELECT 'total_transactions' as key, to_jsonb(COUNT(*)) as value FROM public.transactions UNION ALL
      SELECT 'successful_transactions' as key, to_jsonb(COUNT(*)) as value FROM public.transactions WHERE status = 'paid' UNION ALL
      SELECT 'total_revenue_from_visits' as key, to_jsonb(COALESCE(SUM(amount), 0.00)) as value FROM public.transactions WHERE status = 'paid'
    ) AS trans;

    -- Service Stats
    SELECT jsonb_build_object( 'total_services', COALESCE(SUM(count), 0::BIGINT), 'services_by_category', COALESCE(jsonb_object_agg(category, count), '{}'::jsonb) ) INTO service_stats FROM ( SELECT category::text, COUNT(*) as count FROM public.services GROUP BY category ) AS service_counts;

    -- Vendor Stats
    SELECT jsonb_build_object( 'total_vendors', COALESCE((SELECT COUNT(*) FROM public.vendors), 0::BIGINT), 'vendors_by_status', COALESCE((SELECT jsonb_object_agg(status, count) FROM (SELECT status::text, COUNT(*) as count FROM public.vendors GROUP BY status) AS s), '{}'::jsonb) ) INTO vendor_stats;

    -- Ticket Stats
    SELECT jsonb_build_object(
        'total_tickets', COALESCE((SELECT COUNT(*) FROM public.tickets), 0::BIGINT),
        'tickets_by_status', COALESCE((SELECT jsonb_object_agg(status, count) FROM (SELECT status::text, COUNT(*) as count FROM public.tickets GROUP BY status) AS s), '{}'::jsonb),
        'tickets_by_priority', COALESCE((SELECT jsonb_object_agg(priority, count) FROM (SELECT priority::text, COUNT(*) as count FROM public.tickets GROUP BY priority) AS p), '{}'::jsonb),
        'assigned_to_admin_tickets', COALESCE((SELECT COUNT(*) FROM public.tickets WHERE assigned_support_admin_id IS NOT NULL), 0::BIGINT),
        'assigned_to_vendor_tickets', COALESCE((SELECT COUNT(*) FROM public.tickets WHERE assigned_to_vendor_id IS NOT NULL), 0::BIGINT),
        'unassigned_open_tickets', COALESCE((SELECT COUNT(*) FROM public.tickets WHERE assigned_support_admin_id IS NULL AND assigned_to_vendor_id IS NULL AND status IN ('NEW', 'OPEN', 'IN_PROGRESS', 'WAITING_TENANT_RESPONSE', 'WAITING_OWNER_RESPONSE')), 0::BIGINT)
    ) INTO ticket_stats;

    -- Rent Stats
    SELECT jsonb_build_object(
        'total_rent_records', COALESCE((SELECT COUNT(*) FROM public.rent_records), 0::BIGINT),
        'rent_records_by_status', COALESCE((SELECT jsonb_object_agg(status, count) FROM (SELECT status::text, COUNT(*) as count FROM public.rent_records GROUP BY status) AS s), '{}'::jsonb),
        'total_rent_amount_due_outstanding', COALESCE((SELECT SUM(amount_due - amount_paid) FROM public.rent_records WHERE status IN ('DUE', 'OVERDUE', 'PARTIALLY_PAID')), 0.00),
        'total_rent_collected_ever', COALESCE((SELECT SUM(amount_paid) FROM public.rent_records), 0.00) -- Or SUM(amount) from rent_payments
    ) INTO rent_stats;

    -- Management Service Plan Stats
    SELECT jsonb_build_object( 'total_mgmt_plans', COALESCE((SELECT COUNT(*) FROM public.management_service_plans), 0::BIGINT), 'active_mgmt_plans', COALESCE((SELECT COUNT(*) FROM public.management_service_plans WHERE is_active = TRUE), 0::BIGINT) ) INTO mgmt_plan_stats;

    -- Visit Plan Stats
    SELECT jsonb_build_object( 'total_visit_plans', COALESCE((SELECT COUNT(*) FROM public.visit_plans), 0::BIGINT), 'active_visit_plans', COALESCE((SELECT COUNT(*) FROM public.visit_plans WHERE is_active = TRUE), 0::BIGINT) ) INTO visit_plan_stats;


    SELECT jsonb_build_object(
        'properties', prop_stats,
        'admin_staff', admin_staff_stats,
        'customers', customer_stats,
        'interactions', interaction_stats,
        'visit_transactions', transaction_stats,
        'services', service_stats,
        'vendors', vendor_stats,
        'tickets', ticket_stats,
        'rent_records', rent_stats,
        'management_plans', mgmt_plan_stats,
        'visit_plans', visit_plan_stats
    ) INTO stats;

    RETURN stats;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;
GRANT EXECUTE ON FUNCTION public.get_dashboard_stats_admin() TO authenticated;


-- Example Reporting Function: Occupied Properties Rent Status (from old dashboard functions)
-- This function is useful and should be retained/adapted.
CREATE OR REPLACE FUNCTION public.get_occupied_properties_rent_status_report_admin(
    p_property_search TEXT DEFAULT NULL, -- Search address, locality, pincode
    p_tenant_search TEXT DEFAULT NULL,   -- Search tenant name, email, phone
    p_rent_status_filter public.rent_status_enum DEFAULT NULL,
    p_offset INTEGER DEFAULT 0,
    p_limit INTEGER DEFAULT 10
)
RETURNS TABLE (
    property_id UUID,
    property_address TEXT,
    property_locality TEXT,
    property_city TEXT,
    property_pincode INTEGER,
    tenant_user_id UUID,
    tenant_name TEXT,
    tenant_email TEXT,
    tenant_phone TEXT,
    property_rent_due_day INTEGER,
    latest_rent_record_id UUID,
    latest_rent_record_status public.rent_status_enum,
    latest_rent_record_due_date DATE,
    latest_rent_amount_due DECIMAL,
    latest_rent_amount_paid DECIMAL,
    last_payment_date_for_latest_record TIMESTAMPTZ,
    total_count BIGINT
) AS $$
BEGIN
    IF NOT (public.current_user_has_role('accounts-team') OR public.current_user_has_role('super-admin')) THEN
        RAISE EXCEPTION 'Unauthorized: Insufficient privileges for this report.';
    END IF;

    RETURN QUERY
    WITH OccupiedPropsBase AS (
        SELECT
            p.property_id, p.address, p.locality, p.city, p.pincode, p.rent_due_day AS prop_rent_due_day,
            p.tenant AS ten_id,
            tu.email::TEXT as ten_email_val,
            tu.raw_user_meta_data ->> 'full_name' AS ten_name_val,
            tu.phone::TEXT AS ten_phone_val
        FROM public.properties p
        JOIN auth.users tu ON p.tenant = tu.id
        WHERE p.listing_type = 'RENTAL'
          AND p.tenant IS NOT NULL
          AND p.admin_status = 'RENTED' -- Specifically properties marked as RENTED
          AND (p_property_search IS NULL OR (
                p.address ILIKE '%' || p_property_search || '%' OR
                p.city ILIKE '%' || p_property_search || '%' OR
                p.locality ILIKE '%' || p_property_search || '%' OR
                p.pincode::TEXT ILIKE '%' || p_property_search || '%'
              ))
          AND (p_tenant_search IS NULL OR (
                tu.email ILIKE '%' || p_tenant_search || '%' OR
                (tu.raw_user_meta_data ->> 'full_name') ILIKE '%' || p_tenant_search || '%' OR
                tu.phone ILIKE '%' || p_tenant_search || '%'
              ))
    ),
    LatestRentForProp AS (
        SELECT
            rr.property_id,
            rr.rent_record_id,
            rr.status AS latest_status,
            rr.due_date AS latest_due_date,
            rr.amount_due AS latest_amt_due,
            rr.amount_paid AS latest_amt_paid,
            (SELECT MAX(rp.payment_date) FROM public.rent_payments rp WHERE rp.rent_record_id = rr.rent_record_id) as last_payment_on_record,
            ROW_NUMBER() OVER (PARTITION BY rr.property_id ORDER BY rr.due_date DESC) as rn
        FROM public.rent_records rr
        WHERE rr.property_id IN (SELECT opb.property_id FROM OccupiedPropsBase opb)
    ),
    FilteredReportData AS (
        SELECT
            opb.*,
            lr.rent_record_id AS latest_rr_id,
            lr.latest_status,
            lr.latest_due_date,
            lr.latest_amt_due,
            lr.latest_amt_paid,
            lr.last_payment_on_record
        FROM OccupiedPropsBase opb
        LEFT JOIN LatestRentForProp lr ON opb.property_id = lr.property_id AND lr.rn = 1
        WHERE (p_rent_status_filter IS NULL OR lr.latest_status = p_rent_status_filter OR (p_rent_status_filter IS NOT NULL AND lr.latest_status IS NULL)) -- handles cases where no rent record exists yet
    ),
    ReportWithCount AS (
      SELECT *, COUNT(*) OVER() AS total_rows FROM FilteredReportData
    )
    SELECT
        rwc.property_id, rwc.address, rwc.locality, rwc.city, rwc.pincode,
        rwc.ten_id, rwc.ten_name_val, rwc.ten_email_val, rwc.ten_phone_val,
        rwc.prop_rent_due_day,
        rwc.latest_rr_id, rwc.latest_status, rwc.latest_due_date, rwc.latest_amt_due, rwc.latest_amt_paid,
        rwc.last_payment_on_record,
        rwc.total_rows
    FROM ReportWithCount rwc
    ORDER BY rwc.latest_due_date DESC NULLS LAST, rwc.prop_rent_due_day ASC, rwc.address ASC
    OFFSET p_offset
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;
GRANT EXECUTE ON FUNCTION public.get_occupied_properties_rent_status_report_admin(TEXT, TEXT, public.rent_status_enum, INTEGER, INTEGER) TO authenticated;