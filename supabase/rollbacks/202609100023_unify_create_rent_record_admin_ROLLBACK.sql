-- Restore the prior canonical definition from migration 202609090021 if required.
NOTIFY pgrst,'reload schema';
