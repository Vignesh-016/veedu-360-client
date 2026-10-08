-- Do not overwrite historical verification state during rollback. New status
-- synchronization can safely continue using payment_eligible as its authority.
NOTIFY pgrst, 'reload schema';
