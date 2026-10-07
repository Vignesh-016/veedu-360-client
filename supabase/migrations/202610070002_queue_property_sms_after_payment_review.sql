-- Queue the owner SMS only when payment completion moves a property into admin review.
DROP TRIGGER IF EXISTS trigger_queue_post_submitted_sms ON public.properties;

CREATE OR REPLACE FUNCTION public.queue_post_submitted_sms_after_payment()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public AS $$
DECLARE
  v_phone TEXT;
BEGIN
  IF OLD.admin_status IS DISTINCT FROM 'SUBMITTED'::public.property_admin_status_enum
     AND NEW.admin_status = 'SUBMITTED'::public.property_admin_status_enum
     AND NEW.submitter IS NOT NULL THEN
    SELECT phone INTO v_phone FROM auth.users WHERE id = NEW.submitter;
    IF v_phone IS NOT NULL AND btrim(v_phone) <> '' THEN
      INSERT INTO public.service_sms_log (sms_type, to_phone_number, variables)
      VALUES ('POST_SUBMITTED', v_phone, ARRAY[NEW.property_id::TEXT]);
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trigger_queue_post_submitted_sms_after_payment ON public.properties;
CREATE TRIGGER trigger_queue_post_submitted_sms_after_payment
AFTER UPDATE OF admin_status ON public.properties
FOR EACH ROW
EXECUTE FUNCTION public.queue_post_submitted_sms_after_payment();
