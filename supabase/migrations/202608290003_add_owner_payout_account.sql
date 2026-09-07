-- Stage 3: one saved payout bank account per authenticated property owner.
-- Razorpay/KYC/verification fields intentionally belong to a later stage.

CREATE TABLE public.owner_payout_accounts (
    owner_user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE RESTRICT,
    account_holder_name TEXT NOT NULL,
    account_number TEXT NOT NULL,
    ifsc_code TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'PENDING_VERIFICATION'
        CONSTRAINT owner_payout_accounts_status_check CHECK (status = 'PENDING_VERIFICATION'),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT owner_payout_accounts_holder_name_check
        CHECK (char_length(btrim(account_holder_name)) BETWEEN 2 AND 200),
    CONSTRAINT owner_payout_accounts_account_number_check
        CHECK (account_number ~ '^[0-9]{6,35}$'),
    CONSTRAINT owner_payout_accounts_ifsc_check
        CHECK (ifsc_code ~ '^[A-Z]{4}0[A-Z0-9]{6}$')
);

ALTER TABLE public.owner_payout_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.owner_payout_accounts FORCE ROW LEVEL SECURITY;

CREATE POLICY owner_payout_accounts_select_own
    ON public.owner_payout_accounts FOR SELECT TO authenticated
    USING (owner_user_id = auth.uid());

CREATE POLICY owner_payout_accounts_insert_own
    ON public.owner_payout_accounts FOR INSERT TO authenticated
    WITH CHECK (owner_user_id = auth.uid());

CREATE POLICY owner_payout_accounts_update_own
    ON public.owner_payout_accounts FOR UPDATE TO authenticated
    USING (owner_user_id = auth.uid())
    WITH CHECK (owner_user_id = auth.uid());

-- Keep the raw account number inaccessible through PostgREST. Owners interact
-- only through the two RPCs below; RLS remains a second line of defence.
REVOKE ALL ON TABLE public.owner_payout_accounts FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.get_my_owner_payout_account()
RETURNS TABLE (
    account_holder_name TEXT,
    masked_account_number TEXT,
    ifsc_code TEXT,
    status TEXT,
    updated_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
DECLARE
    v_user_id UUID := auth.uid();
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.';
    END IF;

    RETURN QUERY
    SELECT
        opa.account_holder_name,
        repeat('X', greatest(char_length(opa.account_number) - 4, 0)) || right(opa.account_number, 4),
        opa.ifsc_code,
        opa.status,
        opa.updated_at
    FROM public.owner_payout_accounts opa
    WHERE opa.owner_user_id = v_user_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.save_my_owner_payout_account(
    p_account_holder_name TEXT,
    p_account_number TEXT,
    p_ifsc_code TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_holder_name TEXT := btrim(p_account_holder_name);
    v_account_number TEXT := btrim(p_account_number);
    v_ifsc_code TEXT := upper(btrim(p_ifsc_code));
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.';
    END IF;
    IF v_holder_name IS NULL OR char_length(v_holder_name) NOT BETWEEN 2 AND 200 THEN
        RAISE EXCEPTION 'Account holder name must be between 2 and 200 characters.';
    END IF;
    IF v_account_number IS NULL OR v_account_number !~ '^[0-9]{6,35}$' THEN
        RAISE EXCEPTION 'Account number must contain 6 to 35 digits.';
    END IF;
    IF v_ifsc_code IS NULL OR v_ifsc_code !~ '^[A-Z]{4}0[A-Z0-9]{6}$' THEN
        RAISE EXCEPTION 'IFSC code must use the standard 11-character format.';
    END IF;

    INSERT INTO public.owner_payout_accounts (
        owner_user_id, account_holder_name, account_number, ifsc_code,
        status, created_at, updated_at
    ) VALUES (
        v_user_id, v_holder_name, v_account_number, v_ifsc_code,
        'PENDING_VERIFICATION', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
    )
    ON CONFLICT (owner_user_id) DO UPDATE SET
        account_holder_name = EXCLUDED.account_holder_name,
        account_number = EXCLUDED.account_number,
        ifsc_code = EXCLUDED.ifsc_code,
        status = 'PENDING_VERIFICATION',
        updated_at = CURRENT_TIMESTAMP;
END;
$$;

REVOKE ALL ON FUNCTION public.get_my_owner_payout_account() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.save_my_owner_payout_account(TEXT, TEXT, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_my_owner_payout_account() TO authenticated;
GRANT EXECUTE ON FUNCTION public.save_my_owner_payout_account(TEXT, TEXT, TEXT) TO authenticated;
