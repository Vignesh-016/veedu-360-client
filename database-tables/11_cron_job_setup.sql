-- FILE NAME: 11_cron_job_setup.sql
-- Description: Sets up cron jobs for automated tasks like rent record generation and sales visit assignment.
-------------------------------------------------------------------------------

-- Enable pg_cron extension
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Grant usage on the cron schema to the postgres role.
GRANT USAGE ON SCHEMA cron TO postgres;

-- Grant privileges on the job and job_run_details tables
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE cron.job TO postgres;
GRANT USAGE ON SEQUENCE cron.jobid_seq TO postgres;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE cron.job_run_details TO postgres;
GRANT USAGE ON SEQUENCE cron.runid_seq TO postgres;

-- Ensure the postgres user (or the user Supabase cron runs as) can EXECUTE the target functions.
GRANT EXECUTE ON FUNCTION public.create_upcoming_rent_records_admin() TO postgres;
GRANT EXECUTE ON FUNCTION public.assign_pending_sales_visits_admin() TO postgres;

-- Schedule the function to generate upcoming rent records daily.
SELECT cron.schedule(
    'daily-rent-record-generation',
    '0 2 * * *',                    -- Cron schedule (minute hour day month day-of-week)
    $$SELECT public.create_upcoming_rent_records_admin()$$
);

-- Schedule the function to assign pending sales visits.
SELECT cron.schedule(
    'sales-visit-assignment-processor',
    '*/5 * * * *',                      -- Cron schedule: "every 5 minutes"
    $$SELECT public.assign_pending_sales_visits_admin()$$
);

SELECT cron.schedule(
    'auto-assign-marketing-tasks',
    '*/5 * * * *',                      -- Cron schedule: "every 5 minutes"
    $$SELECT public.auto_assign_marketing_tasks_cron_worker()$$
);