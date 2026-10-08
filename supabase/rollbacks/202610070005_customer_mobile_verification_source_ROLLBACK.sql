DROP TRIGGER IF EXISTS customer_mobile_change_resets_verification ON auth.users;
CREATE OR REPLACE FUNCTION public.reset_customer_mobile_verification()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NEW.phone IS DISTINCT FROM OLD.phone THEN
    UPDATE public.customers SET mobile_verified = FALSE, mobile_verified_at = NULL WHERE user_id = NEW.id;
  END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER customer_mobile_change_resets_verification
AFTER UPDATE OF phone ON auth.users FOR EACH ROW
EXECUTE FUNCTION public.reset_customer_mobile_verification();

ALTER TABLE public.customers
  DROP COLUMN IF EXISTS mobile_verification_required,
  DROP COLUMN IF EXISTS created_by_admin;

NOTIFY pgrst, 'reload schema';
