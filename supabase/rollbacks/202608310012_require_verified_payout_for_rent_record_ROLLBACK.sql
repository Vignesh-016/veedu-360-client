-- Restores the pre-gate Stage 2 function. Reapply 202608290002 to restore the canonical definition.
DROP FUNCTION IF EXISTS public.create_rent_record_admin(UUID,DATE,DATE,DATE,DECIMAL,TEXT);
