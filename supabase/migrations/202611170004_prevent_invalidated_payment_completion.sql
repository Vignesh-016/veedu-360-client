CREATE OR REPLACE FUNCTION public.prevent_invalidated_rent_payment_completion()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF OLD.status = 'FAILED' AND NEW.status = 'PAID' THEN
    RAISE EXCEPTION 'Payment attempt is no longer active.';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS prevent_invalidated_rent_payment_completion
ON public.rent_payment_attempts;

CREATE TRIGGER prevent_invalidated_rent_payment_completion
BEFORE UPDATE OF status ON public.rent_payment_attempts
FOR EACH ROW
EXECUTE FUNCTION public.prevent_invalidated_rent_payment_completion();
