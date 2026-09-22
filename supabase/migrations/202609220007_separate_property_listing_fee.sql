-- Property posting fees are separate from visit plans.
CREATE TABLE IF NOT EXISTS public.property_listing_fees (
    listing_type public.listing_type_enum PRIMARY KEY,
    fee NUMERIC(10,2) NOT NULL CHECK (fee >= 0),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO public.property_listing_fees (listing_type, fee)
VALUES ('RENTAL', 99), ('SALE', 99)
ON CONFLICT (listing_type) DO UPDATE SET fee = EXCLUDED.fee, is_active = TRUE, updated_at = now();

ALTER TABLE public.property_listing_fees ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS property_listing_fees_read_authenticated ON public.property_listing_fees;
CREATE POLICY property_listing_fees_read_authenticated
ON public.property_listing_fees FOR SELECT TO authenticated
USING (is_active = TRUE);

-- The old visit-plan row must no longer be presented as a visit plan.
UPDATE public.visit_plans
SET is_active = FALSE
WHERE lower(name) = 'property listing fee';

COMMENT ON TABLE public.property_listing_fees IS 'Property posting fees, independent of visit plans.';
