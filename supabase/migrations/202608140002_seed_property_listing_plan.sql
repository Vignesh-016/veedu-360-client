-- Migration: Seed dedicated Property Listing Fee row in visit_plans with visits = 1 (satisfying CHECK visits > 0) and price = 99.00

INSERT INTO public.visit_plans (name, description, visits, price, is_active)
SELECT 'Property Listing Fee', 'Listing fee for posting additional properties on the platform.', 1, 99.00, true
WHERE NOT EXISTS (
    SELECT 1 FROM public.visit_plans WHERE name ILIKE '%listing%'
);
