ALTER TABLE public.rent_records
  ADD CONSTRAINT rent_records_amount_paise_matches_amount_due_check
  CHECK (total_amount_paise IS NULL OR total_amount_paise = ROUND(amount_due * 100)::BIGINT);

ALTER TABLE public.recurring_rent_agreements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rent_notification_queue ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rent_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rent_payment_attempts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rent_payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.route_transfers ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.recurring_rent_agreements FROM PUBLIC, anon, authenticated;
REVOKE ALL ON public.rent_notification_queue FROM PUBLIC, anon, authenticated;
REVOKE ALL ON TABLE public.recurring_rent_agreement_record_diagnostics FROM PUBLIC, anon, authenticated;
