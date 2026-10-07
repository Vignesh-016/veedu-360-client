DROP TRIGGER IF EXISTS trigger_queue_post_submitted_sms_unified ON public.properties;

CREATE TRIGGER trigger_queue_post_submitted_sms
AFTER INSERT ON public.properties
FOR EACH ROW
EXECUTE FUNCTION public.queue_post_submitted_sms();

DROP FUNCTION IF EXISTS public.queue_post_submitted_sms_after_payment();
