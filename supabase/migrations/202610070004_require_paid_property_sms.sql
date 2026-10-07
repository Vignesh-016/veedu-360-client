-- Do not notify an owner for an unpaid/cancelled paid property draft.
CREATE OR REPLACE FUNCTION public.queue_post_submitted_sms_after_payment()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public AS $$
DECLARE
  v_phone TEXT;
  v_requires_payment BOOLEAN := FALSE;
  v_payment_confirmed BOOLEAN := FALSE;
BEGIN
  IF NEW.admin_status <> 'SUBMITTED'::public.property_admin_status_enum THEN
    RETURN NEW;
  END IF;

  IF TG_OP = 'UPDATE' AND OLD.admin_status IS NOT DISTINCT FROM NEW.admin_status THEN
    RETURN NEW;
  END IF;

  SELECT (COALESCE(m.post_price, 0) > 0 OR COALESCE(m.document_processing_fee_enabled, FALSE))
    INTO v_requires_payment
  FROM public.properties p
  LEFT JOIN public.management_service_plans m ON m.plan_id = p.management_plan_id
  WHERE p.property_id = NEW.property_id;

  IF v_requires_payment THEN
    SELECT EXISTS (
      SELECT 1 FROM public.transactions t
      WHERE t.property_id = NEW.property_id
        AND t.payment_type = 'property_management'
        AND lower(t.status::text) = 'paid'
    ) INTO v_payment_confirmed;
    IF NOT v_payment_confirmed THEN
      RETURN NEW;
    END IF;
  END IF;

  IF NEW.submitter IS NOT NULL THEN
    SELECT phone INTO v_phone FROM auth.users WHERE id = NEW.submitter;
    IF v_phone IS NOT NULL AND btrim(v_phone) <> '' THEN
      INSERT INTO public.service_sms_log (sms_type, to_phone_number, variables)
      VALUES ('POST_SUBMITTED', v_phone, ARRAY[NEW.property_id::TEXT]);
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.remove_unsent_property_sms_on_delete()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
BEGIN
  DELETE FROM public.service_sms_log
  WHERE sms_type = 'POST_SUBMITTED'
    AND status = 'NOT_SENT'
    AND variables @> ARRAY[OLD.property_id::TEXT];
  RETURN OLD;
END;
$$;

DROP TRIGGER IF EXISTS trigger_remove_property_sms_on_delete ON public.properties;
CREATE TRIGGER trigger_remove_property_sms_on_delete
BEFORE DELETE ON public.properties
FOR EACH ROW EXECUTE FUNCTION public.remove_unsent_property_sms_on_delete();
