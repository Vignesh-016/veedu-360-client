-- Per-admin, persistent notifications for newly created support tickets.
-- This migration is idempotent so it is safe to apply more than once.

CREATE TABLE IF NOT EXISTS public.admin_notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    recipient_admin_id UUID REFERENCES public.admins(user_id) ON DELETE CASCADE,
    type TEXT NOT NULL,
    source_id TEXT,
    payload JSONB NOT NULL DEFAULT '{}'::JSONB,
    page_context TEXT NOT NULL,
    target_role TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    read_at TIMESTAMPTZ
);

-- Support databases where admin_notifications was created before this migration.
ALTER TABLE public.admin_notifications
    ADD COLUMN IF NOT EXISTS recipient_admin_id UUID
        REFERENCES public.admins(user_id) ON DELETE CASCADE,
    ADD COLUMN IF NOT EXISTS source_id TEXT;

CREATE INDEX IF NOT EXISTS idx_admin_notifications_recipient_unread
    ON public.admin_notifications (recipient_admin_id, page_context, created_at DESC)
    WHERE read_at IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS uq_admin_notification_event_recipient
    ON public.admin_notifications (type, source_id, recipient_admin_id)
    WHERE source_id IS NOT NULL AND recipient_admin_id IS NOT NULL;

ALTER TABLE public.admin_notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admins can read their notifications"
    ON public.admin_notifications;
CREATE POLICY "Admins can read their notifications"
    ON public.admin_notifications
    FOR SELECT
    TO authenticated
    USING (
        recipient_admin_id = auth.uid()
        AND public.current_user_is_admin()
    );

DROP POLICY IF EXISTS "Admins can update their notifications"
    ON public.admin_notifications;
CREATE POLICY "Admins can update their notifications"
    ON public.admin_notifications
    FOR UPDATE
    TO authenticated
    USING (
        recipient_admin_id = auth.uid()
        AND public.current_user_is_admin()
    )
    WITH CHECK (
        recipient_admin_id = auth.uid()
        AND public.current_user_is_admin()
    );

GRANT SELECT, UPDATE ON public.admin_notifications TO authenticated;

CREATE OR REPLACE FUNCTION public.notify_admins_of_new_ticket()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    INSERT INTO public.admin_notifications (
        recipient_admin_id,
        type,
        source_id,
        payload,
        page_context,
        target_role
    )
    SELECT
        admin_user.user_id,
        'ticket_created',
        NEW.ticket_id::TEXT,
        jsonb_build_object(
            'title', 'New support ticket #' || NEW.ticket_id,
            'message', NEW.subject,
            'ticket_id', NEW.ticket_id,
            'property_id', NEW.property_id,
            'priority', NEW.priority,
            'category', NEW.category
        ),
        'tickets',
        'ticket-management'
    FROM public.admins AS admin_user
    WHERE admin_user.is_active = TRUE
      AND admin_user.roles && ARRAY[
          'super-admin',
          'telecalling-owner-team',
          'telecalling-tenant-team'
      ]::public.admin_role_enum[]
    ON CONFLICT (type, source_id, recipient_admin_id)
    WHERE source_id IS NOT NULL AND recipient_admin_id IS NOT NULL
    DO NOTHING;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trigger_notify_admins_of_new_ticket
    ON public.tickets;
CREATE TRIGGER trigger_notify_admins_of_new_ticket
    AFTER INSERT ON public.tickets
    FOR EACH ROW
    EXECUTE FUNCTION public.notify_admins_of_new_ticket();

ALTER TABLE public.admin_notifications REPLICA IDENTITY FULL;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_publication_tables
        WHERE pubname = 'supabase_realtime'
          AND schemaname = 'public'
          AND tablename = 'admin_notifications'
    ) THEN
        ALTER PUBLICATION supabase_realtime
            ADD TABLE public.admin_notifications;
    END IF;
END;
$$;
