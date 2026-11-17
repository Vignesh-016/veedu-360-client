CREATE SEQUENCE IF NOT EXISTS public.razorpay_route_reference_seq;

ALTER TABLE public.owner_payout_accounts
    ADD COLUMN IF NOT EXISTS razorpay_reference_id TEXT;

ALTER TABLE public.owner_payout_accounts
    ALTER COLUMN razorpay_reference_id SET DEFAULT (
        'po_' || lpad(nextval('public.razorpay_route_reference_seq')::TEXT, 17, '0')
    );

UPDATE public.owner_payout_accounts
SET razorpay_reference_id =
    'po_' || lpad(nextval('public.razorpay_route_reference_seq')::TEXT, 17, '0')
WHERE razorpay_reference_id IS NULL;

ALTER TABLE public.owner_payout_accounts
    ALTER COLUMN razorpay_reference_id SET NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS owner_payout_accounts_razorpay_reference_id_idx
    ON public.owner_payout_accounts(razorpay_reference_id);
