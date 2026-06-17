# Winoli Enterprise Property Management Platform
## Client Workflow & Architecture Documentation

Welcome to the comprehensive workflow and system manual for **Winoli (Version 2)**. This document is specifically prepared for client review and explains the user workflows, operational processes, database architecture, and integration layers of the Winoli application in a clear, structured, point-by-point format.

---

### Executive Summary

**Winoli** is an enterprise-grade, end-to-end real estate property listing, tenancy management, and operations platform. It bridges the gap between **Property Owners (Landlords/Builders/Agents)**, **Property Seekers (Tenants/Buyers)**, **Operational Teams (Telecallers, Marketers, Sales agents, Accountants)**, and **Maintenance Vendors** (Electricians, Plumbers, etc.) to automate the entire lifecycle of a property—from onboarding to monthly rent collection and maintenance.

---

## 1. User Roles & System Actors

To understand the workflow, we must first look at the roles involved in the ecosystem.

### A. Customers (External Users)
*   **Property Submitter / Owner:** A user who lists their property for sale or rent. They can be an **Owner**, **Builder**, or **Agent**.
*   **Tenant / Buyer:** A property seeker who browses listings, schedules physical visits, submits rental applications, pays monthly rent online, and raises maintenance tickets.

### B. Administrative Operational Teams (Internal Staff)
Internal roles are assigned in arrays under the `admins` table, allowing staff to hold multiple roles:
1.  **Super Admin:** Holds complete control over system configuration, global workflows, performance dashboards, and administrative oversight.
2.  **Telecalling-Owner Team:** Responsible for calling property submitters, qualifying newly submitted properties, verifying owner credentials, and moving properties to the verification stage.
3.  **Marketing Team:** Members are assigned to specific geographical areas based on pincodes. They visit qualified properties to inspect them, capture high-quality photos/videos, record internal notes, and recommend them for public listing.
4.  **Telecalling-Tenant Team:** Contacts and qualifies property seekers (tenants/buyers) who show interest in properties, ensuring high-intent inquiries before scheduling physical viewings.
5.  **Sales Team:** Coordinates and conducts the physical property viewings. The system automatically groups daily visits for a customer in a specific locality and assigns a local sales agent to show them the properties.
6.  **Accounts Team:** Handles financial aspects, including rent records verification, plan sales validation, and vendor payments.

### C. Vendors (Service Providers)
*   Third-party service companies or individual tradespeople (e.g., plumbers, electricians, cleaners, pest control) assigned to handle support and maintenance tickets raised by tenants.

---

## 2. Core Business Workflows (Step-by-Step)

The entire operations of Winoli are organized into six primary, interconnected workflows.

### Workflow A: Property Listing & Onboarding (Owner Flow)

This is how a property gets listed publicly on the platform:

1.  **Submission:** The Owner/Agent/Builder logs in (with mandatory Google authentication and Verified Phone Number) and submits a comprehensive multi-step form:
    *   **Basic Info:** Property type (House, Land, or Building), Listing type (Rent or Sale), and Role.
    *   **Location:** Real-time map coordinate placement (latitude/longitude), address, locality, and pincode.
    *   **Details:** Specific specifications like house type (Apartment, Independent Villa, Hostel/PG), bedrooms, bathrooms, furnishings, power backups, road access width, or common amenities.
    *   **Pricing & Plan:** Monthly rent/Sale price, advance deposit, and an optional **Property Management Plan** (subscribed by the owner for premium listing services).
    *   **Photos:** Submitter uploads property photos (compressed client-side for fast loading) and adds a YouTube video link.
2.  **Onboarding Status (Internal Workflow):** Once submitted, the property's `admin_status` is marked as `SUBMITTED` and is **not** visible to the public. It progresses through these steps:
    *   **`SUBMITTED` ➔ `OWNER_CONTACT_PENDING`:** An automated assignment system assigns a member of the **Telecalling-Owner Team** to contact the owner.
    *   **`OWNER_CONTACT_PENDING` ➔ `OWNER_VERIFIED`:** The telecaller verifies ownership details and updates the status.
    *   **`OWNER_VERIFIED` ➔ `MARKETING_VISIT_PENDING`:** The system assigns a member of the **Marketing Team** (selected by served pincodes or round-robin) to visit the site physically.
    *   **`MARKETING_VISIT_PENDING` ➔ `MARKETING_VERIFIED`:** The marketer inspects the property, uploads verified high-quality property pictures, and documents internal notes.
    *   **`MARKETING_VERIFIED` ➔ `AWAITING_LISTING` ➔ `LISTED`:** Once approved, `is_listed` is set to `TRUE`, making the property public for search on the customer catalog.

---

### Workflow B: Property Discovery & Geolocation Search (Tenant/Buyer Flow)

1.  **Geolocation Detection:** When a customer visits the platform, the site requests permission to access their browser location. If granted, the OpenStreetMap Nominatim API reverse-geocodes their coordinates to detect their current city automatically. If denied or unavailable, it defaults gracefully.
2.  **Catalog Browsing:** The user browses properties using a powerful filter system:
    *   Filter by Property type (House, Land, Building).
    *   Filter by Listing type (Sale vs. Rental).
    *   Filter by furnishing status, bedroom counts, price ranges, and localities.
    *   Interactive map view showing property pins in their vicinity.
3.  **Wishlisting:** Users can add properties to their **Wishlist** for quick access. This records a `WISHLISTED` status in the `customers_interaction` table.

---

### Workflow C: Physical Property Visit Request & Purchase Plans

To prevent spam and cover site visits overhead, Winoli utilizes a subscription-based **Visit Credits Plan**:

1.  **Visit Plan Purchase:**
    *   A visitor must purchase a **Visit Plan** (e.g., 5 physical visits, 10 physical visits) to schedule viewings.
    *   The purchase triggers **Razorpay** checkout. Upon successful payment, an automated Edge Function (`verify-payment`) confirms the transaction and increments the customer's `visit_balance` in the database with an expiration date (default 30 days).
2.  **Scheduling a Visit:**
    *   When browsing a listed property, the user requests a visit and selects a preferred date.
    *   The system checks the user's `visit_balance`. If valid, it deducts one visit credit and sets the interaction status to `VISIT_PENDING`.
3.  **Sales Agent Assignment:**
    *   The **Telecalling-Tenant Team** reviews and qualifies the customer's intent (`VISIT_PENDING` ➔ `VISIT_CONFIRMED_PENDING_SALES`).
    *   The system's daily automated batch processes group all visits scheduled by a single customer on a given day.
    *   A **Sales Agent** from the sales team is assigned to conduct the viewings (`VISIT_SCHEDULED_WITH_SALES`).
    *   Once shown, the agent updates the status to `VISIT_COMPLETED` (or `VISIT_CANCELLED` if they failed to show).

---

### Workflow D: Rental Application & Tenant Screening

If a tenant likes a property during their visit, they initiate the formal application process:

1.  **Submission:** The tenant submits a **Rental Application** directly from the visit details page, providing planned move-in dates, number of occupants, reference notes, and uploading required identification documents (Aadhaar, PAN, etc.).
2.  **Landlord Decision:** The application details are routed to the property owner/landlord.
    *   Status moves from `SUBMITTED` ➔ `REVIEW_IN_PROGRESS` ➔ `AWAITING_LANDLORD_CONTACT`.
    *   The landlord can **Approve** (`LANDLORD_APPROVED`) or **Reject** (`LANDLORD_REJECTED`) the applicant.
3.  **Verification & Finalization:**
    *   Upon Landlord approval, the system moves the status to `DOCUMENTS_REQUESTED` and then `DOCUMENTS_VERIFIED` once operational teams verify background credentials.
    *   The status moves to `APPROVED_AWAITING_PAYMENT` for the tenant to pay their security deposit.
    *   Once paid, the status transitions to `PAYMENT_CONFIRMED` ➔ `LEASE_FINALIZED` ➔ `TENANCY_ACTIVE`, and the property is officially updated to the `RENTED` status in the system, automatically disabling public visibility.

---

### Workflow E: Occupied Tenancy & Rent Management

Once a tenancy becomes active, the system automates monthly invoicing and payments:

1.  **Rent Record Invoicing:**
    *   Every month, the database automates the generation of a **Rent Record** containing the billing period, due date, amount due, and landlord/tenant IDs.
2.  **Notification:** An automated SMS trigger notifies the tenant that rent is due (`RENT_DUE` SMS event).
3.  **Payment Processing:**
    *   The Tenant views their dashboard where they see the rent dues.
    *   They click pay, which generates a Razorpay Order.
    *   Payments are verified securely in the backend, transitioning the rent record status from `DUE` to `PAID` (or `PARTIALLY_PAID`).
    *   A receipt is automatically logged in `rent_payments` for bookkeeping.
4.  **Landlord Dashboard:** Landlords can view their monthly payout history, rent payment statuses across all their occupied properties, and print ledger lists.

---

### Workflow F: Maintenance & Ticket Support Workflow (Tenant ➔ Vendor)

Tenants can raise service requests for any maintenance issues they face during their stay:

1.  **Ticket Creation:** The tenant creates a **Support Ticket** detailing the issue (e.g., Plumbing Leak, AC Malfunction), selecting a category, priority level, and uploading photos of the damage.
2.  **Admin Review & Vendor Assignment:**
    *   The ticket starts as `NEW`. An admin reviews it and marks it `OPEN`.
    *   The admin assigns the ticket to a verified local **Vendor** (e.g., an electrician registered under `vendors` who specializes in that service category) and assigns a **Support Admin** to oversee it (`ASSIGNED`).
3.  **Resolution Workflow:**
    *   The vendor coordinates with the tenant, does the job, and updates the status to `IN_PROGRESS` ➔ `RESOLVED`.
    *   The tenant reviews the work. If satisfied, the ticket is marked `CLOSED`.
    *   Both parties can post public or internal comments (`ticket_comments`) at each step to maintain a transparent audit log of the maintenance.

---

## 3. Technical Integration Highlights

To achieve this seamless workflow, Winoli incorporates several advanced technical integrations:

### I. Multi-Team Round-Robin Allocation
*   To prevent dispatch bottlenecks, the database features state-tracking (`round_robin_state`) that automatically rotates property assignments, lead verifications, and visit allocations fairly among active members of the respective operational teams (Marketing, Sales, and Support).

### II. Integrated Razorpay Checkout & Webhooks
*   Handles transaction verification for Visit Packages, Landlord Property Management fees, and Rent Dues.
*   Uses cryptographically signed webhook validation in Supabase Edge Functions (`verify-payment`) to protect against tamper attempts, ensuring credits/receipts are only given for verified bank settlements.

### III. Dynamic SMS Notifications
*   An automated SMS logging and queuing system (`service_sms_log`) fires transactional text messages during key lifecycle events (e.g., Owner submissions, Telecaller updates, Visit schedule alerts, Rent invoices, and Ticket vendor assignments).

---

## 4. Key Database Relational Mapping (For Copy-Paste to Docs)

To understand where the data resides, here is a mapping of the primary database tables:

| Table Name | Primary Purpose | Key Fields |
| :--- | :--- | :--- |
| **`properties`** | Stores details of listed/submitted properties | `property_type`, `listing_type`, `price`, `address`, `admin_status`, `is_listed`, `tenant`, `management_plan_id` |
| **`customers`** | Stores profile details and visit packages of customers | `user_id`, `visit_balance`, `expiry_date`, `profile_details` |
| **`customers_interaction`** | Tracks tenant interactions (Wishlist, Visit Bookings) | `user_id`, `property_id`, `status` (e.g., VISIT_SCHEDULED), `scheduled_for`, `assigned_sales_admin_id` |
| **`rental_applications`** | Tracks applications to rent specific properties | `property_id`, `user_id`, `landlord_user_id`, `status`, `application_data` |
| **`rent_records`** | Logs monthly rent dues generated by properties | `property_id`, `tenant_user_id`, `due_date`, `amount_due`, `status` (DUE/PAID) |
| **`tickets`** | Maintenance requests raised by tenants | `property_id`, `raised_by_user_id`, `category`, `status`, `assigned_to_vendor_id`, `priority` |
| **`vendors`** | Third-party maintenance service providers | `company_name`, `phone`, `email`, `status` (ACTIVE/INACTIVE) |
| **`transactions`** | Tracks customer visit plan payments | `user_id`, `plan_id`, `razorpay_order_id`, `amount`, `status` (paid/failed) |

---

### Conclusion & System Strengths

The **Winoli v2** system is built on a highly modular architecture that protects client operations at every step. By combining strong role segregation, geographical boundary handling, integrated payment validation, automated round-robin team assignments, and transparent maintenance ticketing, Winoli ensures a premium, reliable, and hands-free real estate rental experience.
