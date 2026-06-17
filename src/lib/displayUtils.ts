import {
    AreaUnit, HouseType, FurnishedStatus, LandType,
    BuildingType, Direction, ListingType, PropertyType,
    InteractionStatus, SubmitterType,
    AvailabilityStatus, ProximityUnit, WaterSource, PowerBackup, PropertyAdminStatus,
    RentalApplicationStatus
} from './types';

type EnumMap<T extends string> = Record<T, string>;

export const areaUnitMap: EnumMap<AreaUnit> = {
    SQ_FT: 'sq.ft',
    CENTS: 'cents',
    ACRES: 'acres',
};

export const houseTypeMap: EnumMap<HouseType> = {
    APARTMENT_FLAT: 'Apartment',
    INDEPENDENT_VILLA: 'House/Villa',
    HOSTEL_PG: 'Hostel/PG',
};

export const furnishedStatusMap: EnumMap<FurnishedStatus> = {
    UNFURNISHED: 'Unfurnished',
    SEMI_FURNISHED: 'Semi-Furnished',
    FULLY_FURNISHED: 'Furnished',
};

export const landTypeMap: EnumMap<LandType> = {
    RESIDENTIAL: 'Residential',
    COMMERCIAL: 'Commercial',
    AGRICULTURAL: 'Agricultural',
};

export const buildingTypeMap: EnumMap<BuildingType> = {
    OFFICE: 'Office',
    WAREHOUSE: 'Warehouse',
    RETAIL: 'Retail',
    INDUSTRIAL: 'Industrial',
    HOSPITALITY: 'Hospitality',
};

export const directionMap: EnumMap<Direction> = {
    NORTH: 'North',
    SOUTH: 'South',
    EAST: 'East',
    WEST: 'West',
};

export const listingTypeMap: EnumMap<ListingType> = {
    SALE: 'For Sale',
    RENTAL: 'For Rent',
};

export const propertyTypeMap: EnumMap<PropertyType> = {
    HOUSE: 'House',
    LAND: 'Land',
    BUILDING: 'Building',
};

export const interactionStatusMap: EnumMap<InteractionStatus> = {
    WISHLISTED: 'Wishlisted',
    VISIT_PENDING: 'Visit Pending',
    VISIT_CONFIRMED_PENDING_SALES: 'Visit Confirmed',
    VISIT_SCHEDULED_WITH_SALES: 'Visit Scheduled',
    VISIT_COMPLETED: 'Visit Completed',
    VISIT_CANCELLED: 'Visit Cancelled',
    RENTAL_APPLICATION_SUBMITTED: 'Rental Application Submitted',
    LEASE_CONVERTED: 'Lease Finalized',
};

// PropertyAdminStatus map for customer's "My Properties" view
export const propertyAdminStatusMap: EnumMap<PropertyAdminStatus> = {
    SUBMITTED: 'Submitted (Under Review)',
    OWNER_CONTACT_PENDING: 'Verification Pending',
    OWNER_VERIFIED: 'Owner Verified',
    MARKETING_VISIT_PENDING: 'Property Visit Pending',
    MARKETING_VERIFIED: 'Property Verified',
    AWAITING_LISTING: 'Ready to List',
    REJECTED: 'Rejected',
    SUSPENDED: 'Suspended (Temporarily Unlisted)',
    RENTED: 'Rented',
    SOLD: 'Sold',
};


// SubmitterType map
export const submitterTypeMap: EnumMap<SubmitterType> = {
    OWNER: 'Owner',
    BUILDER: 'Builder',
    AGENT: 'Agent',
};

export const availabilityStatusMap: EnumMap<AvailabilityStatus> = {
    UNDER_CONSTRUCTION: 'Under Construction',
    READY_TO_MOVE: 'Ready to Move',
};

export const proximityUnitMap: EnumMap<ProximityUnit> = {
    KM: 'km',
    METERS: 'm',
    MINUTES_WALK: 'min walk',
    MINUTES_DRIVE: 'min drive',
};

export const waterSourceMap: EnumMap<WaterSource> = {
    BOREWELL: 'Borewell',
    MUNICIPAL: 'Municipal Supply',
    BOTH: 'Both',
};

export const powerBackupMap: EnumMap<PowerBackup> = {
    NONE: 'None',
    PARTIAL: 'Partial',
    FULL: 'Full',
};

export const rentalApplicationStatusMap: EnumMap<RentalApplicationStatus> = {
    SUBMITTED: 'Submitted',
    REVIEW_IN_PROGRESS: 'Review In Progress',
    AWAITING_LANDLORD_CONTACT: 'Awaiting Landlord Contact',
    LANDLORD_INFO_PENDING: 'Landlord Review Pending',
    LANDLORD_APPROVED: 'Landlord Approved',
    LANDLORD_REJECTED: 'Landlord Rejected',
    DOCUMENTS_REQUESTED: 'Documents Requested',
    DOCUMENTS_VERIFIED: 'Documents Verified',
    APPROVED_AWAITING_PAYMENT: 'Approved - Awaiting Payment',
    PAYMENT_CONFIRMED: 'Payment Confirmed',
    LEASE_FINALIZED: 'Lease Finalized',
    TENANCY_ACTIVE: 'Tenancy Active',
    APPLICATION_WITHDRAWN_CUSTOMER: 'Application Withdrawn',
    CANCELLED_ADMIN: 'Cancelled by Admin',
};


// Helper function to safely get display value or return original
export function getDisplayValue<T extends string>(
    map: Record<T, string>,
    value: T | null | undefined,
    defaultValue: string = 'N/A'
): string {
    return value && Object.prototype.hasOwnProperty.call(map, value) ? map[value] : defaultValue;
}