ALTER TABLE public.rent_notification_queue
  ADD COLUMN IF NOT EXISTS notification_type TEXT NOT NULL DEFAULT 'RENT_DUE' CHECK (notification_type IN ('RENT_DUE','RENT_PAID','LEASE_EXPIRY_1_MONTH')),
  ADD COLUMN IF NOT EXISTS agreement_id UUID REFERENCES public.recurring_rent_agreements(agreement_id) ON DELETE CASCADE;
ALTER TABLE public.rent_notification_queue ALTER COLUMN rent_record_id DROP NOT NULL;
ALTER TABLE public.rent_notification_queue DROP CONSTRAINT IF EXISTS rent_notification_queue_unique_recipient;
CREATE UNIQUE INDEX IF NOT EXISTS rent_notification_queue_event_unique ON public.rent_notification_queue(rent_record_id, recipient_email, recipient_type, notification_type) WHERE rent_record_id IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS rent_notification_queue_agreement_event_unique ON public.rent_notification_queue(agreement_id, recipient_email, recipient_type, notification_type) WHERE agreement_id IS NOT NULL;
REVOKE ALL ON public.rent_notification_queue FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.enqueue_rent_notifications(p_rent_record_id UUID) RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE r RECORD; admin_email TEXT;
BEGIN
 SELECT rr.*,p.address,p.city,tu.email tenant_email,lu.email owner_email FROM rent_records rr JOIN properties p USING(property_id) JOIN auth.users tu ON tu.id=rr.tenant_user_id JOIN auth.users lu ON lu.id=rr.landlord_user_id WHERE rr.rent_record_id=p_rent_record_id INTO r;
 SELECT email INTO admin_email FROM auth.users u JOIN admins ad ON ad.user_id=u.id ORDER BY u.created_at LIMIT 1;
 INSERT INTO rent_notification_queue(rent_record_id,recipient_email,recipient_type,notification_type,subject,body)
 SELECT p_rent_record_id,e,t,'RENT_DUE','Rent due for '||r.address,'Property: '||r.address||', '||r.city||E'\nPeriod: '||r.period_start_date||' to '||r.period_end_date||E'\nAmount Due: INR '||r.amount_due||E'\nDue Date: '||r.due_date||E'\nPayment Status: Due' FROM (VALUES(r.tenant_email,'TENANT'),(r.owner_email,'OWNER'),(admin_email,'ADMIN')) v(e,t) WHERE e IS NOT NULL ON CONFLICT DO NOTHING;
END; $$;

CREATE OR REPLACE FUNCTION public.generate_due_recurring_rents(p_run_date DATE DEFAULT CURRENT_DATE) RETURNS INTEGER LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE a RECORD; period_start DATE; period_end DATE; due DATE; amount NUMERIC; rid UUID; created INTEGER := 0; days INTEGER; occupied_days INTEGER; admin_email TEXT; tenant_email TEXT; property_label TEXT;
BEGIN
  FOR a IN SELECT * FROM recurring_rent_agreements WHERE status='ACTIVE' AND due_day=EXTRACT(DAY FROM p_run_date) AND generated_months < auto_generate_months FOR UPDATE SKIP LOCKED LOOP
    period_end := LEAST((date_trunc('month', p_run_date)::date - 1), a.lease_end_date); period_start := date_trunc('month', period_end)::date;
    IF a.last_generated_period_end IS NOT NULL THEN period_start := a.last_generated_period_end + 1; END IF;
    IF period_start > period_end THEN CONTINUE; END IF;
    days := EXTRACT(DAY FROM (date_trunc('month', period_end) + INTERVAL '1 month - 1 day')); occupied_days := period_end-period_start+1;
    amount := CASE WHEN period_start=date_trunc('month',period_end)::date AND occupied_days=days THEN a.monthly_rent ELSE ROUND(a.monthly_rent*occupied_days/days,2) END;
    due := p_run_date;
    SELECT rr.rent_record_id INTO rid FROM rent_records rr WHERE rr.recurring_rent_agreement_id=a.agreement_id AND rr.period_start_date=period_start AND rr.period_end_date=period_end LIMIT 1;
    IF rid IS NULL THEN
      rid := public.create_rent_record_admin(a.property_id,due,period_start,period_end,amount,a.notes,NULL,NULL);
      UPDATE rent_records SET recurring_rent_agreement_id=a.agreement_id WHERE rent_record_id=rid;
      PERFORM public.enqueue_rent_notifications(rid); created := created+1;
    END IF;
    UPDATE recurring_rent_agreements SET generated_months=generated_months+1,last_generated_period_end=period_end,next_period_start=period_end+1,next_due_date=(p_run_date+INTERVAL '1 month')::date,status=CASE WHEN generated_months+1>=auto_generate_months OR period_end>=lease_end_date THEN 'COMPLETED' ELSE 'ACTIVE' END,updated_at=NOW() WHERE agreement_id=a.agreement_id;
  END LOOP;
  SELECT email INTO admin_email FROM auth.users u JOIN admins ad ON ad.user_id=u.id ORDER BY u.created_at LIMIT 1;
  FOR a IN SELECT ra.*,p.address,tu.email tenant_email,(tu.raw_user_meta_data->>'full_name') tenant_name FROM recurring_rent_agreements ra JOIN properties p ON p.property_id=ra.property_id JOIN auth.users tu ON tu.id=ra.tenant_user_id WHERE ra.status='ACTIVE' AND ra.lease_end_date IS NOT NULL AND (ra.lease_end_date - INTERVAL '1 month')::date=p_run_date LOOP
    INSERT INTO rent_notification_queue(agreement_id,recipient_email,recipient_type,notification_type,subject,body) VALUES(a.agreement_id,a.tenant_email,'TENANT','LEASE_EXPIRY_1_MONTH','Lease expiry reminder - '||a.address,'Your lease for '||a.address||' is scheduled to end on '||a.lease_end_date||'. Please contact the property management team regarding renewal, extension, or move-out arrangements.') ON CONFLICT DO NOTHING;
    IF admin_email IS NOT NULL THEN INSERT INTO rent_notification_queue(agreement_id,recipient_email,recipient_type,notification_type,subject,body) VALUES(a.agreement_id,admin_email,'ADMIN','LEASE_EXPIRY_1_MONTH','Lease expiry reminder - '||a.address,'Lease expiry reminder. Tenant: '||COALESCE(a.tenant_name,a.tenant_email)||'. Property: '||a.address||'. Lease end date: '||a.lease_end_date||'.') ON CONFLICT DO NOTHING; END IF;
  END LOOP;
  RETURN created;
END; $$;

CREATE OR REPLACE FUNCTION public.complete_rent_payment(p_order_id TEXT,p_payment_id TEXT) RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE a public.rent_payment_attempts%ROWTYPE; r public.rent_records%ROWTYPE; v_actor UUID:=auth.uid(); admin_email TEXT; p public.properties%ROWTYPE; t_email TEXT;
BEGIN
 SELECT * INTO a FROM rent_payment_attempts WHERE razorpay_order_id=p_order_id FOR UPDATE; IF NOT FOUND OR (v_actor IS NOT NULL AND a.tenant_user_id<>v_actor) THEN RAISE EXCEPTION 'Payment attempt not found.'; END IF;
 SELECT * INTO r FROM rent_records WHERE rent_record_id=a.rent_record_id FOR UPDATE; IF a.status='PAID' THEN RETURN; END IF; IF r.status='CANCELLED' THEN RAISE EXCEPTION 'Rent is cancelled.'; END IF;
 UPDATE rent_payment_attempts SET status='PAID',razorpay_payment_id=COALESCE(razorpay_payment_id,p_payment_id),failure_reason=NULL,updated_at=NOW() WHERE payment_attempt_id=a.payment_attempt_id;
 UPDATE rent_records SET status='PAID',amount_paid=(a.amount_paise::numeric/100),updated_at=NOW() WHERE rent_record_id=r.rent_record_id;
 INSERT INTO rent_payments(rent_record_id,paid_by_user_id,amount,payment_date,payment_method,transaction_ref,notes) VALUES(r.rent_record_id,a.tenant_user_id,(a.amount_paise::numeric/100),NOW(),'RAZORPAY',p_payment_id,'Online rent payment') ON CONFLICT (transaction_ref) DO NOTHING;
 SELECT email INTO admin_email FROM auth.users u JOIN admins ad ON ad.user_id=u.id ORDER BY u.created_at LIMIT 1;
 SELECT address INTO p FROM properties WHERE property_id=r.property_id; SELECT email INTO t_email FROM auth.users WHERE id=r.tenant_user_id;
 IF admin_email IS NOT NULL THEN INSERT INTO rent_notification_queue(rent_record_id,recipient_email,recipient_type,notification_type,subject,body) VALUES(r.rent_record_id,admin_email,'ADMIN','RENT_PAID','Rent paid - '||p.address,'Rent record paid. Tenant: '||COALESCE(t_email,'')||E'\nProperty: '||p.address||E'\nRent record ID: '||r.rent_record_id||E'\nPeriod: '||r.period_start_date||' to '||r.period_end_date||E'\nPaid amount: INR '||r.amount_due||E'\nPayment status: Paid') ON CONFLICT DO NOTHING; END IF;
END; $$;

CREATE OR REPLACE FUNCTION public.get_my_active_lease_ends_customer()
RETURNS TABLE(property_id UUID, move_in_date DATE, lease_end_date DATE)
LANGUAGE sql SECURITY DEFINER STABLE SET search_path=public AS $$
  SELECT a.property_id,a.move_in_date,a.lease_end_date FROM recurring_rent_agreements a WHERE a.tenant_user_id=auth.uid() AND a.status IN ('ACTIVE','COMPLETED');
$$;
GRANT EXECUTE ON FUNCTION public.get_my_active_lease_ends_customer() TO authenticated;
