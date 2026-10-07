-- Restore the previous status-only notification behavior.
CREATE OR REPLACE FUNCTION public.queue_post_submitted_sms_after_payment()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public AS $$
DECLARE v_phone TEXT;
BEGIN
  IF NEW.admin_status = 'SUBMITTED'::public.property_admin_status_enum
     AND (TG_OP = 'INSERT' OR OLD.admin_status IS DISTINCT FROM NEW.admin_status)
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

DROP TRIGGER IF EXISTS trigger_remove_property_sms_on_delete ON public.properties;
DROP FUNCTION IF EXISTS public.remove_unsent_property_sms_on_delete();
