-- Recurring rent configuration for active tenancies.
CREATE TABLE IF NOT EXISTS public.rent_agreements (
    agreement_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    property_id UUID NOT NULL REFERENCES public.properties(property_id) ON DELETE RESTRICT,
    tenant_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
    landlord_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
    key_handover_date DATE NOT NULL,
    monthly_rent NUMERIC(12,2) NOT NULL CHECK (monthly_rent > 0),
    due_day INTEGER NOT NULL DEFAULT 5 CHECK (due_day BETWEEN 1 AND 28),
    auto_generate_months INTEGER NOT NULL DEFAULT 12 CHECK (auto_generate_months BETWEEN 1 AND 60),
    generated_months INTEGER NOT NULL DEFAULT 0 CHECK (generated_months >= 0),
    next_period_start DATE NOT NULL,
    next_due_date DATE NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS rent_agreements_one_active_property
ON public.rent_agreements(property_id) WHERE is_active = TRUE;

CREATE INDEX IF NOT EXISTS rent_agreements_due_index
ON public.rent_agreements(is_active, next_due_date);

ALTER TABLE public.rent_records
ADD COLUMN IF NOT EXISTS agreement_id UUID
REFERENCES public.rent_agreements(agreement_id) ON DELETE RESTRICT;

CREATE INDEX IF NOT EXISTS rent_records_agreement_index
ON public.rent_records(agreement_id, period_start_date, period_end_date);

CREATE UNIQUE INDEX IF NOT EXISTS rent_records_agreement_period_unique
ON public.rent_records(agreement_id, period_start_date, period_end_date)
WHERE agreement_id IS NOT NULL;

CREATE TABLE IF NOT EXISTS public.rent_notification_queue (
    notification_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    rent_record_id UUID NOT NULL REFERENCES public.rent_records(rent_record_id) ON DELETE CASCADE,
    recipient_user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    recipient_email TEXT NOT NULL,
    recipient_type TEXT NOT NULL CHECK (recipient_type IN ('TENANT', 'OWNER', 'ADMIN')),
    subject TEXT NOT NULL,
    body TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'SENT', 'FAILED')),
    attempts INTEGER NOT NULL DEFAULT 0,
    last_error TEXT,
    sent_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS rent_notification_queue_pending_index
ON public.rent_notification_queue(status, created_at);

ALTER TABLE public.rent_agreements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rent_notification_queue ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON public.rent_agreements FROM PUBLIC, anon, authenticated;
REVOKE ALL ON public.rent_notification_queue FROM PUBLIC, anon, authenticated;
