-- External Razorpay resources are not deleted by rollback.
DROP FUNCTION IF EXISTS public.save_my_route_consent(BOOLEAN);
DROP FUNCTION IF EXISTS public.associate_owner_razorpay_account(UUID,TEXT);
ALTER TABLE public.owner_payout_accounts
  DROP COLUMN IF EXISTS razorpay_account_id, DROP COLUMN IF EXISTS razorpay_account_status,
  DROP COLUMN IF EXISTS razorpay_stakeholder_id, DROP COLUMN IF EXISTS razorpay_product_id,
  DROP COLUMN IF EXISTS razorpay_product_status, DROP COLUMN IF EXISTS payment_eligible,
  DROP COLUMN IF EXISTS route_onboarding_error, DROP COLUMN IF EXISTS linked_account_created_at,
  DROP COLUMN IF EXISTS last_status_checked_at, DROP COLUMN IF EXISTS route_consent_accepted,
  DROP COLUMN IF EXISTS route_consent_at, DROP COLUMN IF EXISTS route_consent_version;
