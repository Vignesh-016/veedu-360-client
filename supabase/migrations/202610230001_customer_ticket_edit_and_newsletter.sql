CREATE TABLE IF NOT EXISTS public.newsletter_subscribers (
    subscriber_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS newsletter_subscribers_email_lower_idx
    ON public.newsletter_subscribers (lower(email));

ALTER TABLE public.newsletter_subscribers ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION public.update_ticket_customer(
    p_ticket_id BIGINT,
    p_subject TEXT,
    p_description TEXT,
    p_category public.ticket_category_enum
) RETURNS VOID AS $$
DECLARE
    v_user_id UUID := auth.uid();
BEGIN
    IF v_user_id IS NULL THEN RAISE EXCEPTION 'Authentication required.'; END IF;
    IF p_subject IS NULL OR btrim(p_subject) = '' THEN RAISE EXCEPTION 'Subject is required.'; END IF;
    IF p_description IS NULL OR btrim(p_description) = '' THEN RAISE EXCEPTION 'Description is required.'; END IF;

    UPDATE public.tickets
    SET subject = btrim(p_subject), description = btrim(p_description), category = p_category, updated_at = now()
    WHERE ticket_id = p_ticket_id
      AND raised_by_user_id = v_user_id
      AND status NOT IN ('RESOLVED', 'CLOSED', 'CANCELLED');

    IF NOT FOUND THEN RAISE EXCEPTION 'Ticket not found, not owned by you, or no longer editable.'; END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

GRANT EXECUTE ON FUNCTION public.update_ticket_customer(BIGINT, TEXT, TEXT, public.ticket_category_enum) TO authenticated;

CREATE OR REPLACE FUNCTION public.subscribe_to_newsletter(p_email TEXT)
RETURNS VOID AS $$
BEGIN
    IF p_email IS NULL OR btrim(p_email) !~* '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$' THEN
        RAISE EXCEPTION 'Please enter a valid email address.';
    END IF;
    INSERT INTO public.newsletter_subscribers (email) VALUES (lower(btrim(p_email)))
    ON CONFLICT DO NOTHING;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

GRANT EXECUTE ON FUNCTION public.subscribe_to_newsletter(TEXT) TO anon, authenticated;
