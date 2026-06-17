-- FILE NAME: 08_initial_data.sql
-- Description: Seed initial data like admin roles (implicit in public.admins), visit plans, management plans.
-------------------------------------------------------------------------------

-- Add sample visit plans
INSERT INTO public.visit_plans (name, description, visits, price, is_active) VALUES
('Starter Pack', '5 property visits', 5, 10.00, true),
('Bronze Pack', '10 property visits', 10, 18.00, true),
('Silver Pack', '20 property visits', 20, 32.00, true),
('Gold Pack', '50 property visits', 50, 70.00, true),
('Property Listing Fee', 'Listing fee for additional properties', 1, 1.00, true)
ON CONFLICT (name) DO UPDATE SET
    description = EXCLUDED.description,
    visits = EXCLUDED.visits,
    price = EXCLUDED.price,
    is_active = EXCLUDED.is_active,
    updated_at = CURRENT_TIMESTAMP;

-- Add sample management service plans
INSERT INTO public.management_service_plans (name, percentage, description, is_active) VALUES
('Basic Self-Managed', 0.00, 'No active management. For owner reference or basic listing services only.', true),
('Standard Rental Management', 8.00, 'Inventory monitoring, tax & utilities tracking, maintenance intimation, reports, client support, rent collection, property marketing.', true),
('Premium Rental Management', 10.00, 'All Standard features + rental agreement drafting, tenant screening, tenant problem handling, maintenance undertaking, dedicated property manager.', true),
('Property Care Plus', 15.00, 'All Premium features + enhanced maintenance coverage and proactive property checks.', true) -- Adjusted name and percentage for variety
ON CONFLICT (name) DO UPDATE SET
    percentage = EXCLUDED.percentage,
    description = EXCLUDED.description,
    is_active = EXCLUDED.is_active,
    updated_at = CURRENT_TIMESTAMP;

-- Add initial services
INSERT INTO public.services (service_name, description, category) VALUES
('General Maintenance', 'Basic upkeep and minor repairs.', 'MAINTENANCE'),
('Plumbing Repair', 'Fixing leaks, clogs, pipe issues.', 'REPAIR'),
('Electrical Repair', 'Wiring, fixture, and outage repairs.', 'REPAIR'),
('HVAC Service', 'Heating, Ventilation, and Air Conditioning maintenance and repair.', 'REPAIR'),
('Interior Design Consultation', 'Consultation for interior aesthetics.', 'DESIGN'),
('Security Guard Services', 'On-site guards.', 'SECURITY'),
('Landscaping & Gardening', 'Garden design, lawn care, tree trimming.', 'LANDSCAPING'),
('Swimming Pool Maintenance', 'Cleaning, chemical balancing, equipment checks.', 'POOL'),
('Pest Control Services', 'Extermination and prevention services.', 'PEST_CONTROL'),
('Residential Cleaning', 'Regular cleaning services for homes.', 'CLEANING'),
('Appliance Repair Service', 'Fixing major household appliances.', 'REPAIR'),
('Painting (Interior/Exterior)', 'Interior and exterior painting services.', 'MAINTENANCE'),
('Roofing Repair & Maintenance', 'Fixing leaks and damage to roofs.', 'REPAIR'),
('Carpentry & Woodwork', 'Custom woodwork, repairs, installations.', 'CONSTRUCTION'),
('Deep Cleaning Services', 'Intensive cleaning for move-in/out or special occasions.', 'CLEANING'),
('Utility Bill Payment Assistance', 'Assistance with managing and paying utility bills.', 'UTILITIES')
ON CONFLICT (service_name) DO NOTHING;


-- Add an initial super-admin user.
-- IMPORTANT: Replace 'your-super-admin-auth-user-id-here' with the actual UUID
-- from the auth.users table for the user you want to be the super-admin.
-- This user MUST exist in auth.users before this script is run.
DO $$
DECLARE
  -- !!! IMPORTANT: REPLACE THIS UUID WITH THE ACTUAL auth.users.id OF YOUR SUPER ADMIN USER !!!
  super_admin_auth_id UUID := 'a76d0b87-a059-41a6-b527-a4f05f8173eb'; -- <<< REPLACE THIS PLACEHOLDER UUID
  telecalling_owner_admin_auth_id UUID := 'd2a75546-f9d3-45a9-b8b7-51ebf9f2f54f'; -- Example for another admin
  marketing_admin_auth_id UUID := 'd2a75546-f9d3-45a9-b8b7-51ebf9f2f54f'; -- Example
BEGIN
  IF super_admin_auth_id = '00000000-0000-0000-0000-000000000000' THEN
      RAISE WARNING 'Placeholder UUID detected for super_admin_auth_id. Please replace it in 08_initial_data.sql before running.';
  ELSIF EXISTS (SELECT 1 FROM auth.users WHERE id = super_admin_auth_id) THEN
      INSERT INTO public.admins (user_id, roles, is_active, served_pincodes)
      VALUES (super_admin_auth_id, ARRAY['super-admin']::public.admin_role_enum[], TRUE, NULL)
      ON CONFLICT (user_id) DO UPDATE SET
        roles = public.admins.roles || ARRAY['super-admin']::public.admin_role_enum[], -- Add super-admin if not present
        is_active = TRUE;
      RAISE NOTICE 'Ensured super-admin role for user %', super_admin_auth_id;
  ELSE
      RAISE WARNING 'User ID % for super-admin not found in auth.users. Cannot assign super-admin role.', super_admin_auth_id;
  END IF;

  -- Example: Add another admin with specific roles (ensure these UUIDs are also replaced if used)
  IF telecalling_owner_admin_auth_id <> '11111111-1111-1111-1111-111111111111' AND EXISTS (SELECT 1 FROM auth.users WHERE id = telecalling_owner_admin_auth_id) THEN
    INSERT INTO public.admins (user_id, roles, is_active, served_pincodes)
    VALUES (telecalling_owner_admin_auth_id, ARRAY['telecalling-owner-team', 'telecalling-tenant-team']::public.admin_role_enum[], TRUE, ARRAY[627001, 627002])
    ON CONFLICT (user_id) DO UPDATE SET
        roles = EXCLUDED.roles, is_active = EXCLUDED.is_active, served_pincodes = EXCLUDED.served_pincodes;
    RAISE NOTICE 'Added/Updated admin % with telecalling roles.', telecalling_owner_admin_auth_id;
  END IF;

  IF marketing_admin_auth_id <> '22222222-2222-2222-2222-222222222222' AND EXISTS (SELECT 1 FROM auth.users WHERE id = marketing_admin_auth_id) THEN
    INSERT INTO public.admins (user_id, roles, is_active, served_pincodes)
    VALUES (marketing_admin_auth_id, ARRAY['marketing-team']::public.admin_role_enum[], TRUE, ARRAY[627005, 627007, 627011])
    ON CONFLICT (user_id) DO UPDATE SET
        roles = EXCLUDED.roles, is_active = EXCLUDED.is_active, served_pincodes = EXCLUDED.served_pincodes;
    RAISE NOTICE 'Added/Updated admin % with marketing role.', marketing_admin_auth_id;
  END IF;

END $$;