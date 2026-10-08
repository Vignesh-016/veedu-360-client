-- Distinguish administrator-provisioned customers from self-created/legacy users.
ALTER TABLE public.customers
  ADD COLUMN IF NOT EXISTS mobile_verification_required BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS created_by_admin BOOLEAN NOT NULL DEFAULT FALSE;

-- Phone changes only invalidate verification where an admin-created customer
-- is explicitly required to complete the OTP flow. Self-created/legacy users
-- are treated as verified by the server status endpoint.
CREATE OR REPLACE FUNCTION public.reset_customer_mobile_verification()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.phone IS DISTINCT FROM OLD.phone THEN
    UPDATE public.customers
       SET mobile_verified = CASE WHEN mobile_verification_required THEN FALSE ELSE mobile_verified END,
           mobile_verified_at = CASE WHEN mobile_verification_required THEN NULL ELSE mobile_verified_at END,
           updated_at = NOW()
     WHERE user_id = NEW.id;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS customer_mobile_change_resets_verification ON auth.users;
CREATE TRIGGER customer_mobile_change_resets_verification
AFTER UPDATE OF phone ON auth.users
FOR EACH ROW EXECUTE FUNCTION public.reset_customer_mobile_verification();

NOTIFY pgrst, 'reload schema';
