-- WARNING: This rollback permanently removes saved owner bank details.

DO $$
DECLARE
    v_account_count BIGINT;
BEGIN
    SELECT COUNT(*) INTO v_account_count FROM public.owner_payout_accounts;
    IF v_account_count > 0 THEN
        RAISE WARNING 'Rollback will permanently delete % saved owner payout account(s).', v_account_count;
    END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.get_my_owner_payout_account() FROM authenticated;
REVOKE ALL ON FUNCTION public.save_my_owner_payout_account(TEXT, TEXT, TEXT) FROM authenticated;
DROP FUNCTION IF EXISTS public.get_my_owner_payout_account();
DROP FUNCTION IF EXISTS public.save_my_owner_payout_account(TEXT, TEXT, TEXT);

DROP POLICY IF EXISTS owner_payout_accounts_update_own ON public.owner_payout_accounts;
DROP POLICY IF EXISTS owner_payout_accounts_insert_own ON public.owner_payout_accounts;
DROP POLICY IF EXISTS owner_payout_accounts_select_own ON public.owner_payout_accounts;

DROP TABLE IF EXISTS public.owner_payout_accounts;
