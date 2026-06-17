import { Database, Json } from '../database.types';

// --- Core Enums (Matching Database Enums) ---
export type PropertyType = Database['public']['Enums']['property_type_enum'];
export type ListingType = Database['public']['Enums']['listing_type_enum'];
export type AreaUnit = Database['public']['Enums']['area_unit_enum'];
export type Direction = Database['public']['Enums']['direction_enum'];
export type InteractionStatus = Database['public']['Enums']['interaction_status_enum'];
export type PropertyAdminStatus = Database['public']['Enums']['property_admin_status_enum'];
export type HouseType = Database['public']['Enums']['house_type_enum'];
export type LandType = Database['public']['Enums']['land_type_enum'];
export type BuildingType = Database['public']['Enums']['building_type_enum'];
export type FurnishedStatus = Database['public']['Enums']['furnished_status_enum'];
export type SubmitterType = Database['public']['Enums']['submitter_type_enum'];
export type AvailabilityStatus = Database['public']['Enums']['availability_status_enum'];
export type ProximityUnit = Database['public']['Enums']['proximity_unit_enum'];
export type WaterSource = Database['public']['Enums']['water_source_enum'];
export type PowerBackup = Database['public']['Enums']['power_backup_enum'];
export type RentStatus = Database['public']['Enums']['rent_status_enum'];
export type TicketStatus = Database['public']['Enums']['ticket_status_enum'];
export type TicketCategory = Database['public']['Enums']['ticket_category_enum'];
export type TicketPriority = Database['public']['Enums']['ticket_priority_enum'];
export type RentalApplicationStatus = Database['public']['Enums']['rental_application_status_enum'];


// --- Image Structure ---
export interface PropertyImage {
    image_id: string;
    image_url: string;
    description: string | null;
    display_order: number;
}

// Detailed image structure for "My Properties" view.
export interface DetailedPropertyImage {
    image_id: string;
    image_url: string;
    description: string | null;
    display_order: number;
    is_internal_image: boolean;
}


interface UserInfo { // Simplified user info, as tenant_info from get_my_properties_customer
    user_id: string;
    name: string | null;
    email: string | null;
    phone: string | null;
}

// Reflects structure from get_ticket_details_customer SQL (images JSONB)
export interface TicketImage {
    image_id: string;
    image_url: string;
    description: string | null;
    uploaded_by_name: string | null; // Name of the user who uploaded
    created_at: string;
}

// --- Property Interfaces ---
export type Property = Omit<Database['public']['Functions']['get_properties_customer']['Returns'][0], 'property_images'> & {
    property_images: PropertyImage[];
}

// Further specialized property types if needed for UI logic based on property_type
export interface HouseDetailsSpecific extends Property {
    property_type: 'HOUSE';
    details: {
        house_name: string;
        house_type?: HouseType;
        num_bedrooms?: number;
        num_bathrooms?: number;
        num_balconies?: number;
        total_floors?: number;
        floor_number?: number;
        num_carparking?: number;
        furnished_status?: Database['public']['Enums']['furnished_status_enum'];
        facing_direction?: Database['public']['Enums']['direction_enum'];
        is_corner_plot?: boolean;
        water_source?: Database['public']['Enums']['water_source_enum'];
        power_backup?: Database['public']['Enums']['power_backup_enum'];
        lift_facility_available?: boolean;
    } & Json;
}

export interface LandDetailsSpecific extends Property {
    property_type: 'LAND';
    details: {
        land_name: string;
        land_type?: LandType;
        plot_dimensions?: string;
        road_access_width_ft?: number;
        is_corner_plot?: boolean;
    } & Json;
}

export interface BuildingDetailsSpecific extends Property {
    property_type: 'BUILDING';
    details: {
        building_name: string;
        building_type?: BuildingType;
        total_floors?: number;
        num_units?: number;
        available_units?: number;
        common_amenities?: string[];
    } & Json;
}

export type InsertPropertyPayload = Database['public']['Functions']['insert_property_customer']['Args'];
export type UpdatePropertyPayload = Database['public']['Functions']['update_property_customer']['Args'];

export type DeletePropertyImagePayload = Database['public']['Functions']['delete_property_image_customer']['Args'];

export type EditPropertyImagePayload = Database['public']['Functions']['edit_property_image_customer']['Args'];


// --- Owner's View of Their Properties ---
export type MyProperties = Omit<Database['public']['Functions']['get_my_properties_customer']['Returns'][0], 'property_images' | 'tenant_info'> & {
    property_images: DetailedPropertyImage[]; // Matches the JSON structure from get_my_properties_customer
    tenant_info: UserInfo | null; // Matches the JSON structure from get_my_properties_customer
}

// Corrected RPC function name
export type PropertyRentDues = Database['public']['Functions']['get_property_rent_dues_landlord']['Returns'][0];

// Corrected RPC function name
export type MyPropertyTickets = Database['public']['Functions']['get_property_tickets_landlord']['Returns'][0];

// --- Tenant View ---
export type MyOccupiedProperties = Omit<Database['public']['Functions']['get_my_occupied_properties_customer']['Returns'][0], 'property_images'> & {
    property_images: PropertyImage[];
}

export type MyRentDues = Database['public']['Functions']['get_my_rent_dues_customer']['Returns'][0];

export type MyTickets = Database['public']['Functions']['get_my_raised_tickets_customer']['Returns'][0];


// --- Shared Ticket Component Types ---
export interface TicketComment {
    comment_id: number;
    user_id: string;
    user_name: string | null;
    comment_text: string;
    created_at: string;
}

export type TicketDetails = Omit<Database['public']['Functions']['get_ticket_details_customer']['Returns'][0], 'images' | 'comments'> & {
    images: TicketImage[]; // Correctly typed based on SQL output
    comments: TicketComment[]; // Correctly typed based on SQL output
}

// --- General Customer Types ---
export type WishlistItem = Database['public']['Functions']['get_my_interactions_customer']['Returns'][0];

export type VisitPlan = Database['public']['Functions']['get_visit_plans_customer']['Returns'][0];

export interface VisitStatus {
    visit_balance: number;
    expiry_date: string | null; // Date string, e.g., "YYYY-MM-DD"
}

export type MyTransactions = Database['public']['Functions']['get_my_transactions_customer']['Returns'][0];

// Corrected RPC function name
export type PropertyPaymentHistory = Database['public']['Functions']['get_property_payment_history_landlord']['Returns'][0];

// --- Filter & Payload Types ---
export type PropertiesFilterParams = Database['public']['Functions']['get_properties_customer']['Args']


export interface CreatePaymentOrderPayload {
    plan_id: string;
}

export interface CreatePaymentOrderResponse {
    orderId: string;
    amount: number;
    transactionId: string;
    keyId: string;
}

export interface VerifyPaymentPayload {
    razorpay_order_id: string;
    razorpay_payment_id: string;
    razorpay_signature: string;
}

export interface VerifyPaymentResponse {
    success: boolean;
}

export type CreateTicketPayload = Database['public']['Functions']['create_ticket_customer']['Args'];

export type AddTicketCommentPayload = Database['public']['Functions']['add_ticket_comment_customer']['Args'];

export interface UploadPropertyImageResponse {
    image_id: string;
    image_url: string;
}

// --- Geolocation Types ---
export interface NominatimAddress {
    road?: string;
    village?: string;
    town?: string;
    city?: string;
    county?: string;
    state_district?: string;
    state?: string;
    postcode?: string;
    country?: string;
    country_code?: string;
    suburb?: string;
    neighbourhood?: string;
}

export interface NominatimResponse {
    place_id: string;
    licence: string;
    osm_type: string;
    osm_id: string;
    lat: string;
    lon: string;
    place_rank: string;
    category: string;
    type: string;
    importance: number;
    addresstype: string;
    name: string | null;
    display_name: string;
    address: NominatimAddress;
    boundingbox: [string, string, string, string];
}

export type ManagementPlan = Database['public']['Functions']['list_management_plans_customer']['Returns'][0]

// --- Rental Application Specific Types ---
export type RentalApplicationData = {
    move_in_date: string;
    num_occupants: number;
    applicant_notes?: string;
} & Json;

export type CustomerSubmitRentalApplicationPayload = Database['public']['Functions']['customer_submit_rental_application']['Args'];

export type MyRentalApplication = Database['public']['Functions']['customer_get_my_rental_applications']['Returns'][0];

export type MyRentalApplicationDetails = Database['public']['Functions']['customer_get_rental_application_details']['Returns'][0];
