-- Supabase migration: create transactions table and RPC functions
-- Filename: 20230820_create_transactions_and_functions.sql

create extension if not exists "uuid-ossp";

create table if not exists public.transactions (
    transaction_id uuid primary key default uuid_generate_v4(),
    user_id uuid references auth.users(id) not null,
    plan_id uuid references public.plans(id) not null,
    status text not null default 'pending',
    payment_type text not null,
    amount bigint not null,
    razorpay_order_id text unique not null,
    razorpay_payment_id text,
    razorpay_signature text,
    error_message text,
    created_at timestamp with time zone default now(),
    updated_at timestamp with time zone default now()
);

-- Function to update transaction status (used by webhook)
create or replace function public.update_transaction_status(
    p_razorpay_order_id text,
    p_status text,
    p_razorpay_payment_id text default null,
    p_razorpay_signature text default null,
    p_error_message text default null
) returns void language plpgsql security definer as $$
begin
    update public.transactions
    set status = p_status,
        razorpay_payment_id = coalesce(p_razorpay_payment_id, razorpay_payment_id),
        razorpay_signature = coalesce(p_razorpay_signature, razorpay_signature),
        error_message = p_error_message,
        updated_at = now()
    where razorpay_order_id = p_razorpay_order_id;
end;
$$;
DROP FUNCTION IF EXISTS public.complete_property_management_payment(text, text, text);

-- Function to complete property management payment (placeholder implementation)
create or replace function public.complete_property_management_payment(
    p_razorpay_order_id text,
    p_razorpay_payment_id text,
    p_razorpay_signature text
) returns void language plpgsql security definer as $$
begin
    -- Mark the transaction as paid and store payment details
    update public.transactions
    set status = 'paid',
        razorpay_payment_id = p_razorpay_payment_id,
        razorpay_signature = p_razorpay_signature,
        updated_at = now()
    where razorpay_order_id = p_razorpay_order_id;
    -- Additional property‑management specific logic can be added here (e.g., link to property, send notifications)
end;
$$;

-- Function to complete purchase (placeholder implementation)
create or replace function public.complete_purchase(
    p_razorpay_order_id text
) returns void language plpgsql security definer as $$
begin
    -- Here you would insert visit records, grant access, etc.
    -- For now we just ensure the transaction is marked as paid (if not already).
    update public.transactions
    set status = 'paid',
        updated_at = now()
    where razorpay_order_id = p_razorpay_order_id;
end;
$$;

-- Grant the service_role to invoke the RPCs via the Supabase client
grant execute on function public.update_transaction_status(text, text, text, text, text) to service_role;
grant execute on function public.complete_property_management_payment(text, text, text) to service_role;
grant execute on function public.complete_purchase(text) to service_role;
