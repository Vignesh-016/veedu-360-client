-- Keep the database plan price aligned with the Post Property checkout price.
UPDATE public.visit_plans
SET price = 99
WHERE lower(name) LIKE '%listing%'
  AND (
    lower(name) LIKE '%property%'
    OR lower(description) LIKE '%propert%'
  );
