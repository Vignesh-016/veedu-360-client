-- Keep the normal admin list clean while preserving explicit CANCELLED filtering.
CREATE OR REPLACE FUNCTION public.list_rent_records_admin(
    p_property_id_filter UUID DEFAULT NULL, p_tenant_user_id_filter UUID DEFAULT NULL,
    p_landlord_user_id_filter UUID DEFAULT NULL, p_status_filter public.rent_status_enum DEFAULT NULL,
    p_due_date_start DATE DEFAULT NULL, p_due_date_end DATE DEFAULT NULL,
    p_offset INTEGER DEFAULT 0, p_limit INTEGER DEFAULT 25
) RETURNS TABLE (rent_record_id UUID, property_id UUID, property_address TEXT, property_locality TEXT, tenant_user_id UUID, tenant_name TEXT, tenant_email TEXT, tenant_phone TEXT, landlord_user_id UUID, landlord_name TEXT, landlord_email TEXT, landlord_phone TEXT, due_date DATE, period_start_date DATE, period_end_date DATE, amount_due DECIMAL, amount_paid DECIMAL, status public.rent_status_enum, notes TEXT, created_at TIMESTAMPTZ, updated_at TIMESTAMPTZ, total_count BIGINT)
LANGUAGE plpgsql SECURITY DEFINER STABLE SET search_path=public AS $$
BEGIN
 IF NOT (public.current_user_has_role('accounts-team') OR public.current_user_has_role('super-admin')) THEN RAISE EXCEPTION 'Unauthorized: Insufficient privileges.'; END IF;
 RETURN QUERY SELECT rr.rent_record_id,rr.property_id,p.address,p.locality,rr.tenant_user_id,tu.raw_user_meta_data->>'full_name',tu.email::text,tu.phone::text,rr.landlord_user_id,lu.raw_user_meta_data->>'full_name',lu.email::text,lu.phone::text,rr.due_date,rr.period_start_date,rr.period_end_date,rr.amount_due,rr.amount_paid,rr.status,rr.notes,rr.created_at,rr.updated_at,COUNT(*) OVER()
 FROM rent_records rr JOIN properties p USING(property_id) JOIN auth.users tu ON tu.id=rr.tenant_user_id JOIN auth.users lu ON lu.id=rr.landlord_user_id
 WHERE (p_property_id_filter IS NULL OR rr.property_id=p_property_id_filter) AND (p_tenant_user_id_filter IS NULL OR rr.tenant_user_id=p_tenant_user_id_filter) AND (p_landlord_user_id_filter IS NULL OR rr.landlord_user_id=p_landlord_user_id_filter) AND (p_status_filter IS NULL AND rr.status <> 'CANCELLED' OR p_status_filter IS NOT NULL AND rr.status=p_status_filter) AND (p_due_date_start IS NULL OR rr.due_date>=p_due_date_start) AND (p_due_date_end IS NULL OR rr.due_date<=p_due_date_end)
 ORDER BY rr.due_date DESC,rr.created_at DESC OFFSET p_offset LIMIT p_limit;
END; $$;

CREATE OR REPLACE FUNCTION public.get_my_rent_payment_history_customer()
RETURNS TABLE(rent_record_id UUID, property_id UUID, period_start_date DATE, period_end_date DATE, due_date DATE, amount_due DECIMAL, amount_paid DECIMAL, status public.rent_status_enum, paid_at TIMESTAMPTZ, payment_reference TEXT)
LANGUAGE sql SECURITY DEFINER STABLE SET search_path=public AS $$
 SELECT rr.rent_record_id,rr.property_id,rr.period_start_date,rr.period_end_date,rr.due_date,rr.amount_due,rr.amount_paid,rr.status,rp.payment_date,COALESCE(rp.transaction_ref,rpa.razorpay_payment_id)
 FROM rent_records rr LEFT JOIN LATERAL (SELECT payment_date,transaction_ref FROM rent_payments WHERE rent_record_id=rr.rent_record_id ORDER BY payment_date DESC LIMIT 1) rp ON true LEFT JOIN LATERAL (SELECT razorpay_payment_id FROM rent_payment_attempts WHERE rent_record_id=rr.rent_record_id AND status='PAID' ORDER BY updated_at DESC LIMIT 1) rpa ON true
 WHERE rr.tenant_user_id=auth.uid() AND rr.status <> 'CANCELLED' ORDER BY rr.due_date DESC,rr.period_start_date DESC;
$$;
GRANT EXECUTE ON FUNCTION public.get_my_rent_payment_history_customer() TO authenticated;

-- Payment finalization remains the only source of paid receipts. Queue both
-- recipients in the same transaction as the PAID state; SMTP is asynchronous.
CREATE OR REPLACE FUNCTION public.complete_rent_payment(p_order_id TEXT,p_payment_id TEXT) RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE a public.rent_payment_attempts%ROWTYPE; r public.rent_records%ROWTYPE; v_actor UUID:=auth.uid(); admin_email TEXT; tenant_email TEXT; tenant_name TEXT; property_name TEXT;
BEGIN
 SELECT * INTO a FROM rent_payment_attempts WHERE razorpay_order_id=p_order_id FOR UPDATE; IF NOT FOUND OR (v_actor IS NOT NULL AND a.tenant_user_id<>v_actor) THEN RAISE EXCEPTION 'Payment attempt not found.'; END IF;
 SELECT * INTO r FROM rent_records WHERE rent_record_id=a.rent_record_id FOR UPDATE; IF a.status='PAID' THEN RETURN; END IF; IF r.status='CANCELLED' THEN RAISE EXCEPTION 'Rent is cancelled.'; END IF;
 UPDATE rent_payment_attempts SET status='PAID',razorpay_payment_id=COALESCE(razorpay_payment_id,p_payment_id),failure_reason=NULL,updated_at=NOW() WHERE payment_attempt_id=a.payment_attempt_id;
 UPDATE rent_records SET status='PAID',amount_paid=(a.amount_paise::numeric/100),updated_at=NOW() WHERE rent_record_id=r.rent_record_id;
 INSERT INTO rent_payments(rent_record_id,paid_by_user_id,amount,payment_date,payment_method,transaction_ref,notes) VALUES(r.rent_record_id,a.tenant_user_id,(a.amount_paise::numeric/100),NOW(),'RAZORPAY',p_payment_id,'Online rent payment') ON CONFLICT (transaction_ref) DO NOTHING;
 SELECT email,raw_user_meta_data->>'full_name' INTO tenant_email,tenant_name FROM auth.users WHERE id=r.tenant_user_id; SELECT address INTO property_name FROM properties WHERE property_id=r.property_id; SELECT email INTO admin_email FROM auth.users u JOIN admins ad ON ad.user_id=u.id ORDER BY u.created_at LIMIT 1;
 IF tenant_email IS NOT NULL THEN INSERT INTO rent_notification_queue(rent_record_id,recipient_email,recipient_type,notification_type,subject,body) VALUES(r.rent_record_id,tenant_email,'TENANT','RENT_PAID','Rent Payment Received - Veedu360','Hello '||COALESCE(tenant_name,'')||E',\n\nWe have successfully received your rent payment.\n\nProperty: '||property_name||E'\nRental Period: '||r.period_start_date||' to '||r.period_end_date||E'\nAmount Paid: INR '||r.amount_due||E'\nStatus: Paid\nPayment Reference: '||p_payment_id||E'\n\nThank you.\nVeedu360 Property Management') ON CONFLICT DO NOTHING; END IF;
 IF admin_email IS NOT NULL THEN INSERT INTO rent_notification_queue(rent_record_id,recipient_email,recipient_type,notification_type,subject,body) VALUES(r.rent_record_id,admin_email,'ADMIN','RENT_PAID','Rent payment received - '||property_name,'Tenant: '||COALESCE(tenant_name,tenant_email)||E'\nProperty: '||property_name||E'\nPeriod: '||r.period_start_date||' to '||r.period_end_date||E'\nAmount: INR '||r.amount_due||E'\nPaid at: '||NOW()||E'\nPayment reference: '||p_payment_id) ON CONFLICT DO NOTHING; END IF;
END; $$;
