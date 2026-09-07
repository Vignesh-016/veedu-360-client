UPDATE public.owner_payout_accounts
SET status = 'PENDING_VERIFICATION'
WHERE status NOT IN ('PENDING_VERIFICATION');

ALTER TABLE public.owner_payout_accounts
  DROP CONSTRAINT IF EXISTS owner_payout_accounts_status_check;

ALTER TABLE public.owner_payout_accounts
  ADD CONSTRAINT owner_payout_accounts_status_check
  CHECK (status = 'PENDING_VERIFICATION');

NOTIFY pgrst, 'reload schema';
