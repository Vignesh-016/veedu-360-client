# TASKLIST: Implement "Become a Tenant" Feature

This tasklist outlines the steps to implement the streamlined rental application feature.

## I. Database Schema Changes (SQL)

1.  **Create New ENUM Type:**
    *   Define `public.rental_application_status_enum` with values:
        *   `SUBMITTED`
        *   `REVIEW_IN_PROGRESS` (Admin has picked it up)
        *   `AWAITING_LANDLORD_CONTACT`
        *   `LANDLORD_INFO_PENDING` (Admin waiting for landlord feedback)
        *   `LANDLORD_APPROVED`
        *   `LANDLORD_REJECTED`
        *   `DOCUMENTS_REQUESTED` (Admin has requested docs from applicant)
        *   `DOCUMENTS_VERIFIED`
        *   `APPROVED_AWAITING_PAYMENT`
        *   `PAYMENT_CONFIRMED`
        *   `LEASE_FINALIZED` (All steps complete, ready for tenant assignment)
        *   `TENANCY_ACTIVE` (Tenant assigned, property marked rented)
        *   `APPLICATION_WITHDRAWN_CUSTOMER`
        *   `CANCELLED_ADMIN`
    *   File: `database-tables/00_enums.sql`

2.  **Update Existing ENUM Type:**
    *   Add to `public.interaction_status_enum`:
        *   `RENTAL_APPLICATION_SUBMITTED`
        *   `LEASE_CONVERTED` (or similar, to mark the original visit interaction as successful)
    *   File: `database-tables/00_enums.sql`

3.  **Create New Table: `rental_applications`**
    *   `application_id` (PK, UUID, default `gen_random_uuid()`)
    *   `property_id` (FK to `properties.property_id`, NOT NULL, ON DELETE CASCADE)
    *   `user_id` (FK to `auth.users.id` - applicant, NOT NULL, ON DELETE CASCADE)
    *   `interaction_id` (FK to `customers_interaction.interaction_id`, NOT NULL, ON DELETE CASCADE)
    *   `landlord_user_id` (FK to `auth.users.id` - property owner, NOT NULL, ON DELETE RESTRICT)
    *   `application_data` (JSONB, NOT NULL - e.g., `{"move_in_date": "YYYY-MM-DD", "occupants": 2, "applicant_notes": "..."}`)
    *   `status` (`rental_application_status_enum`, NOT NULL, default `'SUBMITTED'`)
    *   `admin_notes` (TEXT, NULLABLE - for internal admin logging)
    *   `assigned_admin_id` (FK to `admins.user_id`, NULLABLE, ON DELETE SET NULL)
    *   `submitted_at` (TIMESTAMPTZ, NOT NULL, default `now()`)
    *   `updated_at` (TIMESTAMPTZ, NOT NULL, default `now()`)
    *   `status_updated_at` (TIMESTAMPTZ, NOT NULL, default `now()`)
    *   Add `UNIQUE (property_id, user_id, status)` constraint for active application statuses (e.g., prevent multiple 'SUBMITTED' or 'REVIEW_IN_PROGRESS' applications for the same property by the same user. Consider which statuses make sense for uniqueness). Maybe just `UNIQUE (property_id, user_id)` if a user can only have one *active* application per property.
    *   File: `database-tables/01_tables.sql`

4.  **Create Indexes for `rental_applications`:**
    *   `idx_rental_applications_property_id`
    *   `idx_rental_applications_user_id`
    *   `idx_rental_applications_status`
    *   `idx_rental_applications_assigned_admin_id`
    *   `idx_rental_applications_submitted_at`
    *   File: `database-tables/02_indexes.sql`

5.  **Create Triggers for `rental_applications`:**
    *   `trigger_set_timestamp_updated_at` on `updated_at`.
    *   `trigger_set_status_updated_at` on `status` change (can be part of the main update trigger or separate).
    *   File: `database-tables/04_triggers.sql`

## II. Backend - SQL Functions

*File: `database-tables/05_0X_customer_rental_application_functions.sql` (new file)*
*File: `database-tables/06_XX_admin_rental_application_functions.sql` (new file)*

1.  **Customer Functions:**
    *   `customer_submit_rental_application(p_property_id UUID, p_interaction_id UUID, p_application_data JSONB) RETURNS UUID (application_id)`
        *   Checks if `customers_interaction.status` is `VISIT_COMPLETED`.
        *   Creates a `rental_applications` record.
        *   Updates `customers_interaction.status` to `RENTAL_APPLICATION_SUBMITTED`.
    *   `customer_get_my_rental_applications(p_offset INT, p_limit INT) RETURNS TABLE (...)`
        *   Lists applications for the current user with property info and status.
    *   `customer_get_rental_application_details(p_application_id UUID) RETURNS TABLE (...)`
    *   `customer_withdraw_rental_application(p_application_id UUID) RETURNS VOID`
        *   Sets status to `APPLICATION_WITHDRAWN_CUSTOMER`.
        *   Reverts `customers_interaction.status` to `VISIT_COMPLETED` (or `WISHLISTED` if appropriate).

2.  **Admin Functions (accessible by relevant roles):**
    *   `admin_get_rental_applications(p_filters JSONB, p_offset INT, p_limit INT) RETURNS TABLE (...)`
        *   Filters: status, assigned_admin_id, property_id, date range, etc.
        *   Accessible by `telecalling-owner-team`, `telecalling-tenant-team`, `accounts-team`, `super-admin`.
    *   `admin_get_rental_application_details(p_application_id UUID) RETURNS TABLE (...)` (more detailed than customer view, includes `admin_notes`).
    *   `admin_self_assign_rental_application(p_application_id UUID) RETURNS VOID`
        *   Assigns to `auth.uid()`. Checks if unassigned.
        *   Allowed for `telecalling-owner-team`, `telecalling-tenant-team`.
    *   `admin_assign_rental_application(p_application_id UUID, p_target_admin_id UUID) RETURNS VOID` (Super-admin only).
    *   `admin_unassign_rental_application(p_application_id UUID) RETURNS VOID`
        *   Sets `assigned_admin_id` to NULL.
        *   Allowed for assigned admin or super-admin.
    *   `admin_update_rental_application_status(p_application_id UUID, p_new_status rental_application_status_enum, p_notes TEXT DEFAULT NULL) RETURNS VOID`
        *   Updates status and appends to `admin_notes`.
        *   Role checks for specific status transitions might be needed if complex.
    *   `admin_add_rental_application_note(p_application_id UUID, p_note TEXT) RETURNS VOID`
        *   Appends to `admin_notes`.
    *   `admin_finalize_lease_from_application(p_application_id UUID) RETURNS VOID`
        *   **Critical Function:**
            *   Updates `rental_applications.status` to `TENANCY_ACTIVE`.
            *   Updates `properties.tenant` with `rental_applications.user_id`.
            *   Updates `properties.admin_status` to `RENTED`.
            *   Updates `customers_interaction.status` (for the original visit) to `LEASE_CONVERTED`.
            *   (Optional) Creates initial `rent_records`.
            *   Needs strong permission checks (e.g., Super-admin, or a senior telecalling/accounts role).

## III. Frontend - Customer UI

1.  **Property Details / Wishlist Item:**
    *   If `customers_interaction.status` is `VISIT_COMPLETED` for the current user and property:
        *   Show "Apply to Rent This Property" button.
        *   If `RENTAL_APPLICATION_SUBMITTED` or other application status, show "View Application Status" button linking to "My Rental Applications" page, perhaps highlighting that specific application.
2.  **Rental Application Form (Modal or Page):**
    *   Fields: Proposed move-in date, number of occupants, applicant notes/message.
    *   Submit button calls `customer_submit_rental_application`.
3.  **New Page: "My Rental Applications"**
    *   Similar UI to "My Tickets" or "My Transactions".
    *   List of applications with: Property Name/Address, Submission Date, Status.
    *   Link to a detailed application view.
    *   Option to withdraw application if status allows.
4.  **Rental Application Detail View (Customer):**
    *   Shows application data, current status, and a simplified log/history if desired (e.g., "Status changed to 'Landlord Approved' on [date]").

## IV. Frontend - Admin UI

1.  **New Dashboard Section: "Rental Applications"**
    *   Accessible to `telecalling-owner-team`, `telecalling-tenant-team`, `accounts-team`, `super-admin`.
    *   **List View:**
        *   Table/Cards of applications.
        *   Columns: App ID, Applicant Name, Property Address, Submitted Date, Status, Assigned Admin.
        *   Filters: By Status, Assigned Admin, Property, Date Range.
        *   "Assign to Me" button for unassigned applications.
        *   (Super-admin) "Assign" button to pick an admin.
    *   **Detailed Application View (Admin):**
        *   All application data from `rental_applications` table.
        *   Property snapshot (key details).
        *   Applicant snapshot (key details).
        *   Landlord snapshot (key details).
        *   `admin_notes` section (view and add new notes).
        *   Action buttons:
            *   "Update Status" (dropdown with valid next statuses).
            *   "Add Note".
            *   "Assign/Unassign" (if permissions allow).
            *   "Finalize Lease" (if status is `PAYMENT_CONFIRMED` and permissions allow).

## V. API Client (Supabase Client Wrapper)

*   Add new methods in `src/lib/supabaseClient.ts` to call all the new SQL functions created in Step II.
*   Update `src/lib/types.ts` with new ENUMs, table types, and function argument/return types.

## VI. RLS Policies

*   File: `database-tables/07_rls_policies.sql`
1.  **`rental_applications` Table:**
    *   **SELECT:**
        *   Customer can select their own applications (`user_id = auth.uid()`).
        *   Admins (`telecalling-owner-team`, `telecalling-tenant-team`, `accounts-team`, `super-admin`) can select applications based on their workflow needs (e.g., all, assigned to them, specific statuses).
    *   **INSERT:**
        *   Authenticated users can insert (via `customer_submit_rental_application` which sets `user_id = auth.uid()`).
    *   **UPDATE:**
        *   Customer can update if status allows withdrawal (via `customer_withdraw_rental_application`).
        *   Admins can update based on assignment and role (via `admin_update_rental_application_status`, `admin_assign_rental_application`, etc.).
    *   **DELETE:**
        *   Generally, soft delete (status change) is preferred. Direct deletes might be restricted to super-admin for cleanup.
