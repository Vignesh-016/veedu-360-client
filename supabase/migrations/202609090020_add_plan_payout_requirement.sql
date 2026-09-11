ALTER TABLE public.management_service_plans ADD COLUMN IF NOT EXISTS requires_payout_account BOOLEAN NOT NULL DEFAULT FALSE;

DROP FUNCTION IF EXISTS public.create_management_plan_admin(TEXT,DECIMAL(5,2),TEXT,BOOLEAN);
CREATE FUNCTION public.create_management_plan_admin(p_name TEXT,p_percentage DECIMAL(5,2),p_description TEXT DEFAULT NULL,p_is_active BOOLEAN DEFAULT TRUE,p_requires_payout_account BOOLEAN DEFAULT FALSE) RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_id UUID;
BEGIN
 IF NOT (public.current_user_has_role('accounts-team') OR public.current_user_has_role('super-admin')) THEN RAISE EXCEPTION 'Unauthorized'; END IF;
 IF p_name IS NULL OR btrim(p_name)='' OR p_percentage IS NULL OR p_percentage NOT BETWEEN 0 AND 100 THEN RAISE EXCEPTION 'Invalid management plan'; END IF;
 INSERT INTO public.management_service_plans(name,percentage,description,is_active,requires_payout_account) VALUES(btrim(p_name),p_percentage,p_description,p_is_active,p_requires_payout_account) RETURNING plan_id INTO v_id; RETURN v_id;
END; $$;
GRANT EXECUTE ON FUNCTION public.create_management_plan_admin(TEXT,DECIMAL(5,2),TEXT,BOOLEAN,BOOLEAN) TO authenticated;

DROP FUNCTION IF EXISTS public.update_management_plan_admin(UUID,TEXT,DECIMAL(5,2),TEXT,BOOLEAN);
CREATE FUNCTION public.update_management_plan_admin(p_plan_id UUID,p_name TEXT DEFAULT NULL,p_percentage DECIMAL(5,2) DEFAULT NULL,p_description TEXT DEFAULT NULL,p_is_active BOOLEAN DEFAULT NULL,p_requires_payout_account BOOLEAN DEFAULT NULL) RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
 IF NOT (public.current_user_has_role('accounts-team') OR public.current_user_has_role('super-admin')) THEN RAISE EXCEPTION 'Unauthorized'; END IF;
 IF p_percentage IS NOT NULL AND p_percentage NOT BETWEEN 0 AND 100 THEN RAISE EXCEPTION 'Invalid percentage'; END IF;
 UPDATE public.management_service_plans SET name=COALESCE(NULLIF(btrim(p_name),''),name),percentage=COALESCE(p_percentage,percentage),description=COALESCE(p_description,description),is_active=COALESCE(p_is_active,is_active),requires_payout_account=COALESCE(p_requires_payout_account,requires_payout_account),updated_at=NOW() WHERE plan_id=p_plan_id;
 IF NOT FOUND THEN RAISE EXCEPTION 'Management plan not found'; END IF;
END; $$;
GRANT EXECUTE ON FUNCTION public.update_management_plan_admin(UUID,TEXT,DECIMAL(5,2),TEXT,BOOLEAN,BOOLEAN) TO authenticated;
