// Run this script with: node seed_listing_plan.cjs
// It inserts the "Property Listing Fee" plan into the live Supabase database
// using the PostgREST RPC endpoint for get_visit_plans_customer to check,
// and direct SQL via the Supabase SQL endpoint if needed.

const SUPABASE_URL = 'https://wopqohofnfayjasggcux.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndvcHFvaG9mbmZheWphc2dnY3V4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODAwMjY1NDksImV4cCI6MjA5NTYwMjU0OX0.PL7aKXftt_CLOetVN6e_XA1Ogbdlorte-qQk3_Nj6Ws';

async function main() {
    // Step 1: Check if the plan already exists by calling the customer RPC
    console.log('Checking if "Property Listing Fee" plan already exists...');
    const checkRes = await fetch(`${SUPABASE_URL}/rest/v1/rpc/get_visit_plans_customer`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
            'apikey': SUPABASE_ANON_KEY,
            'Authorization': `Bearer ${SUPABASE_ANON_KEY}`,
        },
        body: JSON.stringify({}),
    });

    if (checkRes.ok) {
        const plans = await checkRes.json();
        const existing = plans.find(p =>
            p.name && (p.name.toLowerCase().includes('listing') || p.name.toLowerCase().includes('property listing'))
        );
        if (existing) {
            console.log('Plan already exists:', existing);
            console.log('No action needed. Exiting.');
            return;
        }
        console.log('Plan NOT found. Available plans:', plans.map(p => p.name));
    } else {
        const errorText = await checkRes.text();
        console.log('Could not check plans via RPC (might need auth):', checkRes.status, errorText);
        console.log('Proceeding to attempt insert anyway...');
    }

    // Step 2: Try direct table insert (will likely fail due to RLS with anon key)
    console.log('\nAttempting direct insert into visit_plans table...');
    const insertRes = await fetch(`${SUPABASE_URL}/rest/v1/visit_plans`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
            'apikey': SUPABASE_ANON_KEY,
            'Authorization': `Bearer ${SUPABASE_ANON_KEY}`,
            'Prefer': 'return=representation',
        },
        body: JSON.stringify({
            name: 'Property Listing Fee',
            description: 'Listing fee for additional properties',
            visits: 1,
            price: 1.00,
            is_active: true,
        }),
    });

    if (insertRes.ok) {
        const data = await insertRes.json();
        console.log('SUCCESS! Plan inserted:', data);
    } else {
        const errorText = await insertRes.text();
        console.log('Direct insert failed (expected if RLS blocks anon inserts):', insertRes.status, errorText);
        console.log('\n========================================');
        console.log('MANUAL ACTION REQUIRED:');
        console.log('========================================');
        console.log('Go to your Supabase Dashboard > SQL Editor and run:');
        console.log('');
        console.log(`INSERT INTO public.visit_plans (name, description, visits, price, is_active)`);
        console.log(`VALUES ('Property Listing Fee', 'Listing fee for additional properties', 1, 1.00, true)`);
        console.log(`ON CONFLICT (name) DO UPDATE SET`);
        console.log(`  description = EXCLUDED.description,`);
        console.log(`  visits = EXCLUDED.visits,`);
        console.log(`  price = EXCLUDED.price,`);
        console.log(`  is_active = EXCLUDED.is_active,`);
        console.log(`  updated_at = CURRENT_TIMESTAMP;`);
        console.log('');
        console.log('========================================');
        console.log('ALSO SET RAZORPAY SECRETS:');
        console.log('========================================');
        console.log('Go to Supabase Dashboard > Project Settings > Edge Functions > Secrets');
        console.log('Add these secrets:');
        console.log('  RAZORPAY_KEY_ID = rzp_live_T1qyzHjpvp248Q');
        console.log('  RAZORPAY_KEY_SECRET = ULvq2iK9IOJ2Rx9VzWhPsJlu');
        console.log('========================================');
    }
}

main().catch(console.error);
