ALTER TABLE public.owner_payout_accounts
  DROP CONSTRAINT IF EXISTS owner_payout_accounts_status_check;

ALTER TABLE public.owner_payout_accounts
  ADD CONSTRAINT owner_payout_accounts_status_check
  CHECK (status IN ('PENDING_VERIFICATION','VERIFIED','ACTION_REQUIRED','VERIFICATION_FAILED','SUSPENDED'));

NOTIFY pgrst, 'reload schema';
