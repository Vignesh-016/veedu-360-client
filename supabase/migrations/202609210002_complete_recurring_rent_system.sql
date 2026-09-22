-- Complete recurring rent generation. Existing manual rent records remain compatible.
ALTER TABLE public.rent_agreements RENAME TO recurring_rent_agreements;
ALTER TABLE public.rent_records RENAME COLUMN agreement_id TO recurring_rent_agreement_id;
ALTER TABLE public.recurring_rent_agreements ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE','COMPLETED','DISABLED'));
ALTER TABLE public.recurring_rent_agreements ADD COLUMN IF NOT EXISTS notes TEXT;
ALTER TABLE public.recurring_rent_agreements ADD COLUMN IF NOT EXISTS last_generated_period_end DATE;
ALTER TABLE public.recurring_rent_agreements ADD COLUMN IF NOT EXISTS created_by_admin UUID REFERENCES auth.users(id) ON DELETE SET NULL;
ALTER TABLE public.recurring_rent_agreements ADD COLUMN IF NOT EXISTS move_in_date DATE;
UPDATE public.recurring_rent_agreements SET move_in_date = key_handover_date WHERE move_in_date IS NULL;
ALTER TABLE public.recurring_rent_agreements ALTER COLUMN move_in_date SET NOT NULL;
ALTER TABLE public.recurring_rent_agreements ALTER COLUMN status DROP DEFAULT;
ALTER TABLE public.recurring_rent_agreements ALTER COLUMN status SET DEFAULT 'ACTIVE';
ALTER TABLE public.rent_notification_queue ADD CONSTRAINT rent_notification_queue_unique_recipient UNIQUE (rent_record_id, recipient_email, recipient_type);
CREATE UNIQUE INDEX IF NOT EXISTS recurring_rent_agreements_property_active ON public.recurring_rent_agreements(property_id) WHERE status = 'ACTIVE';
CREATE INDEX IF NOT EXISTS recurring_rent_agreements_due_idx ON public.recurring_rent_agreements(status, due_day);

CREATE OR REPLACE FUNCTION public.create_recurring_rent_agreement(
  p_property_id UUID, p_move_in_date DATE, p_monthly_rent NUMERIC,
  p_due_day INTEGER DEFAULT 5, p_total_months INTEGER DEFAULT 12, p_notes TEXT DEFAULT NULL
) RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE p RECORD; a UUID; admin_id UUID := auth.uid();
BEGIN
  IF NOT (public.current_user_has_role('accounts-team') OR public.current_user_has_role('super-admin')) THEN RAISE EXCEPTION 'Unauthorized'; END IF;
  IF p_move_in_date IS NULL OR p_monthly_rent <= 0 OR p_due_day NOT BETWEEN 1 AND 28 OR p_total_months NOT BETWEEN 1 AND 60 THEN RAISE EXCEPTION 'Invalid recurring rent setup'; END IF;
  SELECT property_id, listing_type, tenant, submitter INTO p FROM properties WHERE property_id=p_property_id FOR UPDATE;
  IF NOT FOUND OR p.listing_type <> 'RENTAL' OR p.tenant IS NULL OR p.submitter IS NULL THEN RAISE EXCEPTION 'Property must be a rental with an active tenant and owner'; END IF;
  IF NOT EXISTS (SELECT 1 FROM rental_applications WHERE property_id=p_property_id AND user_id=p.tenant AND status='TENANCY_ACTIVE') THEN RAISE EXCEPTION 'Tenant must have an active tenancy'; END IF;
  INSERT INTO recurring_rent_agreements(property_id,tenant_user_id,landlord_user_id,move_in_date,key_handover_date,monthly_rent,due_day,auto_generate_months,generated_months,next_period_start,next_due_date,status,notes,created_by,created_by_admin)
  VALUES(p.property_id,p.tenant,p.submitter,p_move_in_date,p_move_in_date,p_monthly_rent,p_due_day,p_total_months,0,p_move_in_date,(p_move_in_date + INTERVAL '1 month')::date + (p_due_day-1),'ACTIVE',p_notes,admin_id,admin_id) RETURNING agreement_id INTO a;
  RETURN a;
END; $$;
GRANT EXECUTE ON FUNCTION public.create_recurring_rent_agreement(UUID,DATE,NUMERIC,INTEGER,INTEGER,TEXT) TO authenticated;

CREATE OR REPLACE FUNCTION public.generate_due_recurring_rents(p_run_date DATE DEFAULT CURRENT_DATE) RETURNS INTEGER LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE a RECORD; period_start DATE; period_end DATE; due DATE; amount NUMERIC; rid UUID; created INTEGER := 0; days INTEGER;
BEGIN
  FOR a IN SELECT * FROM recurring_rent_agreements WHERE status='ACTIVE' AND due_day=EXTRACT(DAY FROM p_run_date) AND generated_months < auto_generate_months FOR UPDATE SKIP LOCKED LOOP
    period_end := (date_trunc('month', p_run_date)::date - 1); period_start := date_trunc('month', period_end)::date;
    IF a.generated_months=0 AND a.move_in_date > period_start THEN period_start := a.move_in_date; END IF;
    days := EXTRACT(DAY FROM (date_trunc('month', period_end) + INTERVAL '1 month - 1 day'));
    amount := CASE WHEN period_start = date_trunc('month', period_end)::date THEN a.monthly_rent ELSE ROUND(a.monthly_rent * (days - EXTRACT(DAY FROM a.move_in_date) + 1) / days, 2) END;
    due := p_run_date;
    INSERT INTO rent_records(property_id,tenant_user_id,landlord_user_id,due_date,period_start_date,period_end_date,amount_due,status,notes,recurring_rent_agreement_id)
      VALUES(a.property_id,a.tenant_user_id,a.landlord_user_id,due,period_start,period_end,amount,'DUE',a.notes,a.agreement_id)
      ON CONFLICT (recurring_rent_agreement_id,period_start_date,period_end_date) DO NOTHING RETURNING rent_record_id INTO rid;
    IF rid IS NOT NULL THEN created := created + 1; END IF;
    IF rid IS NOT NULL THEN PERFORM public.enqueue_rent_notifications(rid); END IF;
    UPDATE recurring_rent_agreements SET generated_months=generated_months+1,last_generated_period_end=period_end,next_period_start=period_end+1,next_due_date=(p_run_date + INTERVAL '1 month')::date,status=CASE WHEN generated_months+1 >= auto_generate_months THEN 'COMPLETED' ELSE 'ACTIVE' END,updated_at=NOW() WHERE agreement_id=a.agreement_id;
  END LOOP; RETURN created;
END; $$;
REVOKE ALL ON FUNCTION public.generate_due_recurring_rents(DATE) FROM PUBLIC,authenticated;

CREATE OR REPLACE FUNCTION public.enqueue_rent_notifications(p_rent_record_id UUID) RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE r RECORD; admin_email TEXT;
BEGIN
 SELECT rr.*,p.address,p.city,tu.email tenant_email,lu.email owner_email,(tu.raw_user_meta_data->>'full_name') tenant_name INTO r FROM rent_records rr JOIN properties p USING(property_id) JOIN auth.users tu ON tu.id=rr.tenant_user_id JOIN auth.users lu ON lu.id=rr.landlord_user_id WHERE rr.rent_record_id=p_rent_record_id;
 SELECT email INTO admin_email FROM auth.users u JOIN admins ad ON ad.user_id=u.id ORDER BY u.created_at LIMIT 1;
 INSERT INTO rent_notification_queue(rent_record_id,recipient_email,recipient_type,subject,body) SELECT p_rent_record_id,e,t,'Rent due for '||r.address,'Property: '||r.address||', '||r.city||E'\nPeriod: '||r.period_start_date||' to '||r.period_end_date||E'\nAmount: INR '||r.amount_due||E'\nDue: '||r.due_date||E'\nPlease use the existing Pay Rent option in Winoli.' FROM (VALUES(r.tenant_email,'TENANT'),(r.owner_email,'OWNER'),(admin_email,'ADMIN')) v(e,t) WHERE e IS NOT NULL ON CONFLICT DO NOTHING;
END; $$;
REVOKE ALL ON FUNCTION public.enqueue_rent_notifications(UUID) FROM PUBLIC,authenticated;
