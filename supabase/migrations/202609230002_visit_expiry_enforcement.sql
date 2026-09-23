-- Enforce expiry consistently: zero usable visits after the expiry date.
CREATE OR REPLACE FUNCTION public.get_customer_visit_balance_customer()
RETURNS TABLE (visit_balance INTEGER, expiry_date DATE) AS $$
BEGIN
  RETURN QUERY SELECT CASE WHEN c.expiry_date < CURRENT_DATE THEN 0 ELSE c.visit_balance END,
      c.expiry_date FROM public.customers c WHERE c.user_id = auth.uid();
END; $$ LANGUAGE plpgsql SECURITY DEFINER STABLE SET search_path = public;
GRANT EXECUTE ON FUNCTION public.get_customer_visit_balance_customer() TO authenticated;

-- Admin edits must be authoritative. Do not silently replace an explicitly
-- entered date; a past date intentionally makes the credits expired.
CREATE OR REPLACE FUNCTION public.update_customer_visits_admin(
    p_customer_user_id UUID, p_new_visit_balance INTEGER, p_new_expiry_date DATE
) RETURNS VOID AS $$
BEGIN
  IF NOT (public.current_user_has_role('super-admin') OR public.current_user_has_role('accounts-team') OR public.current_user_is_admin()) THEN
    RAISE EXCEPTION 'Unauthorized: Insufficient privileges to modify visit balances.';
  END IF;
  IF p_new_visit_balance < 0 THEN RAISE EXCEPTION 'Visit balance cannot be negative.'; END IF;
  IF NOT EXISTS (SELECT 1 FROM auth.users WHERE id = p_customer_user_id) THEN RAISE EXCEPTION 'Customer not found.'; END IF;
  INSERT INTO public.customers(user_id, visit_balance, expiry_date, updated_at)
  VALUES (p_customer_user_id, p_new_visit_balance, COALESCE(p_new_expiry_date, CURRENT_DATE), CURRENT_TIMESTAMP)
  ON CONFLICT (user_id) DO UPDATE SET visit_balance=EXCLUDED.visit_balance, expiry_date=EXCLUDED.expiry_date, updated_at=CURRENT_TIMESTAMP;
END; $$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;
GRANT EXECUTE ON FUNCTION public.update_customer_visits_admin(UUID, INTEGER, DATE) TO authenticated;
