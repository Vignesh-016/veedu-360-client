ALTER TABLE public.customers
  ADD COLUMN IF NOT EXISTS mobile_verified BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS mobile_verified_at TIMESTAMPTZ;

CREATE TABLE IF NOT EXISTS public.admin_owner_mobile_otp_challenges (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  phone_normalized TEXT NOT NULL,
  otp_hash TEXT NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL,
  attempt_count INTEGER NOT NULL DEFAULT 0 CHECK (attempt_count >= 0),
  max_attempts INTEGER NOT NULL DEFAULT 5 CHECK (max_attempts > 0),
  used_at TIMESTAMPTZ,
  created_by_admin UUID NOT NULL REFERENCES public.admins(user_id) ON DELETE RESTRICT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_admin_owner_mobile_otp_active ON public.admin_owner_mobile_otp_challenges(owner_user_id, created_at DESC);
ALTER TABLE public.admin_owner_mobile_otp_challenges ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.admin_owner_mobile_otp_challenges FROM anon, authenticated;

CREATE OR REPLACE FUNCTION public.reset_customer_mobile_verification()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
BEGIN
  IF NEW.phone IS DISTINCT FROM OLD.phone THEN
    UPDATE public.customers SET mobile_verified = FALSE, mobile_verified_at = NULL WHERE user_id = NEW.id;
  END IF;
  RETURN NEW;
END; $$;
DROP TRIGGER IF EXISTS customer_mobile_change_resets_verification ON auth.users;
CREATE TRIGGER customer_mobile_change_resets_verification AFTER UPDATE OF phone ON auth.users FOR EACH ROW EXECUTE FUNCTION public.reset_customer_mobile_verification();
