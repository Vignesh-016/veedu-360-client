-- Preserve expected unread state for recent tickets created immediately before
-- the notification trigger was deployed.
INSERT INTO public.admin_notifications (
    recipient_admin_id,
    type,
    source_id,
    payload,
    page_context,
    target_role,
    created_at
)
SELECT
    admin_user.user_id,
    'ticket_created',
    ticket.ticket_id::TEXT,
    jsonb_build_object(
        'title', 'New support ticket #' || ticket.ticket_id,
        'message', ticket.subject,
        'ticket_id', ticket.ticket_id,
        'property_id', ticket.property_id,
        'priority', ticket.priority,
        'category', ticket.category
    ),
    'tickets',
    'ticket-management',
    ticket.created_at
FROM public.tickets AS ticket
CROSS JOIN public.admins AS admin_user
WHERE ticket.created_at >= now() - INTERVAL '24 hours'
  AND ticket.status IN ('NEW', 'OPEN')
  AND admin_user.is_active = TRUE
  AND admin_user.roles && ARRAY[
      'super-admin',
      'telecalling-owner-team',
      'telecalling-tenant-team'
  ]::public.admin_role_enum[]
ON CONFLICT (type, source_id, recipient_admin_id)
WHERE source_id IS NOT NULL AND recipient_admin_id IS NOT NULL
DO NOTHING;
