-- Stage 4A rollback: removes owner address data only. Stage 3 payout data is preserved.
-- WARNING: owner_profiles rows are removed by this rollback.
REVOKE ALL ON FUNCTION public.get_my_owner_profile() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.save_my_owner_profile(TEXT,TEXT,TEXT,TEXT,TEXT) FROM PUBLIC, anon, authenticated;
DROP FUNCTION IF EXISTS public.get_my_owner_profile();
DROP FUNCTION IF EXISTS public.save_my_owner_profile(TEXT,TEXT,TEXT,TEXT,TEXT);
DROP POLICY IF EXISTS owner_profiles_select_own ON public.owner_profiles;
DROP POLICY IF EXISTS owner_profiles_insert_own ON public.owner_profiles;
DROP POLICY IF EXISTS owner_profiles_update_own ON public.owner_profiles;
DROP TRIGGER IF EXISTS owner_profiles_set_updated_at ON public.owner_profiles;
DROP TABLE IF EXISTS public.owner_profiles;
