import { createClient } from '@supabase/supabase-js';

const supabaseUrl = 'https://wopqohofnfayjasggcux.supabase.co';
const supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndvcHFvaG9mbmZheWphc2dnY3V4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODAwMjY1NDksImV4cCI6MjA5NTYwMjU0OX0.PL7aKXftt_CLOetVN6e_XA1Ogbdlorte-qQk3_Nj6Ws';

const supabase = createClient(supabaseUrl, supabaseAnonKey);

async function main() {
  const { data, error } = await supabase
    .from('visit_plans')
    .insert([
      {
        name: 'Property Listing Fee',
        description: 'Listing fee for additional properties',
        visits: 1,
        price: 1.00,
        is_active: true
      }
    ])
    .select();

  if (error) {
    console.error('Error inserting plan:', error);
  } else {
    console.log('Successfully inserted plan:', data);
  }
}

main();
