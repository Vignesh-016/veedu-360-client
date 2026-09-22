-- Process queued SMS jobs every minute.
-- Before applying this migration, store these Vault secrets in Supabase:
--   supabase_url       = https://<project-ref>.supabase.co
--   service_role_key   = <Supabase service-role key>
--   cron_secret        = the same value configured as Edge Function CRON_SECRET
--
-- Example (run in the Supabase SQL editor, with real values):
-- SELECT vault.create_secret('https://<project-ref>.supabase.co', 'supabase_url');
-- SELECT vault.create_secret('<service-role-key>', 'service_role_key');
-- SELECT vault.create_secret('<cron-secret>', 'cron_secret');

-- pg_cron is Supabase-managed and must not be recreated here. pg_net is the
-- HTTP client used by this job and must exist before the cron command runs.
CREATE EXTENSION IF NOT EXISTS pg_net;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'process-sms-queue-every-minute') THEN
        PERFORM cron.unschedule('process-sms-queue-every-minute');
    END IF;
END;
$$;

SELECT cron.schedule(
    'process-sms-queue-every-minute',
    '* * * * *',
    $job$
    SELECT net.http_post(
        url := (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'supabase_url')
               || '/functions/v1/process-sms-queue',
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer ' || (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'service_role_key'),
            'apikey', (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'service_role_key'),
            'x-cron-secret', (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'cron_secret')
        ),
        body := '{}'::jsonb
    );
    $job$
);
