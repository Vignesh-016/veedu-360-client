-- Ensure the separate fee table exists and is independently manageable.
CREATE TABLE IF NOT EXISTS public.property_listing_fees (
    listing_type public.listing_type_enum PRIMARY KEY,
    fee NUMERIC(10,2) NOT NULL CHECK (fee >= 0),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO public.property_listing_fees (listing_type, fee)
VALUES ('RENTAL', 99), ('SALE', 99)
ON CONFLICT (listing_type) DO NOTHING;

ALTER TABLE public.property_listing_fees ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS property_listing_fees_read_authenticated ON public.property_listing_fees;
CREATE POLICY property_listing_fees_read_authenticated ON public.property_listing_fees
FOR SELECT TO authenticated USING (is_active = TRUE);

DROP POLICY IF EXISTS property_listing_fees_manage_admin ON public.property_listing_fees;
CREATE POLICY property_listing_fees_manage_admin ON public.property_listing_fees
FOR ALL TO authenticated
USING (public.current_user_has_role('super-admin') OR public.current_user_has_role('accounts-team'))
WITH CHECK (public.current_user_has_role('super-admin') OR public.current_user_has_role('accounts-team'));

DO $$
DECLARE
    v_plan_id UUID;
BEGIN
    SELECT plan_id INTO v_plan_id FROM public.visit_plans
    WHERE lower(trim(name)) = 'property listing fee' LIMIT 1;
    IF v_plan_id IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM public.transactions WHERE plan_id = v_plan_id
    ) THEN
        DELETE FROM public.visit_plans WHERE plan_id = v_plan_id;
    ELSE
        UPDATE public.visit_plans SET is_active = FALSE WHERE plan_id = v_plan_id;
    END IF;
END $$;
