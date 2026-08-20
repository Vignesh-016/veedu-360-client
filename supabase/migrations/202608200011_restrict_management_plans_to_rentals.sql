-- Management plans are a rental-only service. Enforce this at the database
-- boundary so sale properties cannot receive a plan through an old client or
-- a direct API call.
CREATE OR REPLACE FUNCTION public.clear_management_plan_for_non_rental()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
    IF NEW.listing_type <> 'RENTAL' THEN
        NEW.management_plan_id := NULL;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS clear_management_plan_for_non_rental ON public.properties;
CREATE TRIGGER clear_management_plan_for_non_rental
BEFORE INSERT OR UPDATE OF listing_type, management_plan_id
ON public.properties
FOR EACH ROW
EXECUTE FUNCTION public.clear_management_plan_for_non_rental();

-- Remove legacy plan assignments from sale listings.
UPDATE public.properties
SET management_plan_id = NULL
WHERE listing_type <> 'RENTAL'
  AND management_plan_id IS NOT NULL;
