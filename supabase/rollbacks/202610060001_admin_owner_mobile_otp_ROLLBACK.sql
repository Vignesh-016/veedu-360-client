DROP TRIGGER IF EXISTS customer_mobile_change_resets_verification ON auth.users;
DROP FUNCTION IF EXISTS public.reset_customer_mobile_verification();
DROP TABLE IF EXISTS public.admin_owner_mobile_otp_challenges;
ALTER TABLE public.customers DROP COLUMN IF EXISTS mobile_verified_at, DROP COLUMN IF EXISTS mobile_verified;
