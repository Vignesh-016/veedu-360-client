import { Database } from 'supabase-types';

// --- Core Enums (Matching Database Enums) ---
export type PropertyType = Database['public']['Enums']['property_type_enum'];
export type ListingType = Database['public']['Enums']['listing_type_enum'];
export type AreaUnit = Database['public']['Enums']['area_unit_enum'];
export type Direction = Database['public']['Enums']['direction_enum'];
export type SubmitterType = Database['public']['Enums']['submitter_type_enum'];
export type AvailabilityStatus = Database['public']['Enums']['availability_status_enum'];
export type ProximityUnit = Database['public']['Enums']['proximity_unit_enum'];
export type HouseType = Database['public']['Enums']['house_type_enum'];
export type LandType = Database['public']['Enums']['land_type_enum'];
export type BuildingType = Database['public']['Enums']['building_type_enum'];
export type FurnishedStatus = Database['public']['Enums']['furnished_status_enum'];
export type WaterSource = Database['public']['Enums']['water_source_enum'];
export type PowerBackup = Database['public']['Enums']['power_backup_enum'];

// --- JSON Definition ---
export type Json =
    | string
    | number
    | boolean
    | null
    | { [key: string]: Json | undefined }
    | Json[];


// Interface for data expected in the 'create-property-submission' FormData
// Reflects the fields the function needs to parse and insert.
export interface PropertySubmissionFormData {
    // Submission specific required fields
    submitter_type: SubmitterType;
    availability_status: AvailabilityStatus;
    is_exclusive?: boolean; // Defaults to false in DB
    can_reachout?: boolean; // Defaults to true in DB
    owner_name?: string;
    owner_phone?: string;
    owner_email?: string;

    // Mirrored property fields (nullable as it's user input)
    property_type?: PropertyType;
    listing_type?: ListingType;
    price?: number;
    area?: number;
    area_unit?: AreaUnit;
    description?: string;
    locality?: string;
    address?: string;
    latitude?: number;
    longitude?: number;
    year_built?: number;
    nearest_hospital?: number;
    nearest_busstop?: number;
    nearest_gym?: number;
    nearest_park?: number;
    nearest_school?: number;
    nearest_swimmingpool?: number;
    proximity_unit?: ProximityUnit;
    notes?: string;

    // Type-specific details collected into a single JSON object
    // This object's structure depends on property_type
    details?: Json;

    // Individual fields that will be combined into 'details' object by the function
    // HOUSE specific example fields (client might send these individually):
    house_type?: HouseType;
    house_name?: string;
    num_bedrooms?: number;
    num_bathrooms?: number;
    num_balconies?: number;
    total_floors?: number; // For house/building
    floor_number?: number; // For house
    num_carparking?: number; // For house
    furnished_status?: FurnishedStatus;
    facing_direction?: Direction;
    is_corner_plot?: boolean; // For house
    water_source?: WaterSource; // For house
    power_backup?: PowerBackup; // For house

    // LAND specific example fields:
    land_type?: LandType;
    plot_dimensions?: string;
    road_access_width_ft?: number;

    // BUILDING specific example fields:
    building_type?: BuildingType;
    building_name?: string;
    // total_floors (already listed above)
    num_units?: number;
    available_units?: number;
    common_amenities?: string[]; // Example: client sends as comma-separated string? Function needs to parse.

    // NOTE: Images are handled directly from FormData, not part of this interface.
}