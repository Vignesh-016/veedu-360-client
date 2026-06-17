import { createClient } from "jsr:@supabase/supabase-js@2";
import { Database } from 'supabase-types';

const supabaseClient = createClient<Database>(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_ANON_KEY')!
);

export default supabaseClient;
