-- Enforce advertised property-price minimums in the database.
-- Rental = monthly rent, Sale = sale price. This is deliberately separate
-- from posting/payment fees.

ALTER TABLE public.properties
    DROP CONSTRAINT IF EXISTS properties_minimum_advertised_price;

ALTER TABLE public.properties
    ADD CONSTRAINT properties_minimum_advertised_price
    CHECK (
        (listing_type = 'RENTAL' AND price >= 1000)
        OR
        (listing_type = 'SALE' AND price >= 10000)
    ) NOT VALID;

COMMENT ON CONSTRAINT properties_minimum_advertised_price ON public.properties IS
'Rental advertised price must be at least INR 1,000; sale advertised price must be at least INR 10,000.';
