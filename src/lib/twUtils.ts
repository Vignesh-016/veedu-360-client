import { InteractionStatus, ListingType, PropertyType, PropertyAdminStatus } from "./types";

const buttonBaseClasses = `
    font-medium rounded-2xl shadow-md focus:outline-none focus:ring-2 focus:ring-primary
    focus:ring-offset-2 transition-all duration-200 ease-in-out flex items-center justify-center
    disabled:opacity-60 disabled:cursor-not-allowed
`;

export const getPrimaryButtonClasses = (): string => {
    return `
        ${buttonBaseClasses}
        bg-[#2C4964] hover:bg-[#1E3347] text-white px-6 py-2.5 text-sm
    `;
};

export const getSecondaryButtonClasses = (): string => {
    return `
        ${buttonBaseClasses}
        border border-[#2C4964] bg-white text-[#2C4964] hover:bg-[#2C4964] hover:text-white px-5 py-2 text-sm
    `;
};


export const getTertiaryButtonClasses = (): string => {
    return `
        ${buttonBaseClasses}
        text-[#2C4964] hover:text-[#1E3347] hover:bg-gray-100 px-4 py-2 shadow-none text-sm
    `;
};

export const getBaseCardClasses = (): string => {
    return `
        bg-white rounded-2xl border border-gray-200 shadow-md p-4
        transition-shadow duration-200 ease-in-out hover:shadow-lg
    `;
};

export const getBaseInputClasses = (hasError?: boolean): string => {
    return `
        block w-full border rounded-xl shadow-sm px-4 py-2 text-sm
        placeholder-gray-400 focus:outline-none focus:ring-2 focus:border-transparent
        transition-all duration-200 ease-in-out bg-gray-50
        ${hasError
            ? 'border-red-400 focus:ring-red-500'
            : 'border-gray-300 focus:ring-primary'}
    `;
};

const badgeBaseClasses = `
    px-3 py-0.5 rounded-full text-xs font-medium inline-flex items-center gap-1
    bg-gray-100 text-gray-700 border border-gray-200
`;

const defaultBadgeClasses = `${badgeBaseClasses} bg-gray-100 text-gray-700 border-gray-200`;

export const getStatusBadgeClasses = (status: InteractionStatus | PropertyAdminStatus | string | null | undefined): string => {
    const base = badgeBaseClasses;
    switch (status) {
        case 'WISHLISTED': return `${base} bg-purple-100 text-purple-700 border-purple-200`;
        case 'VISIT_PENDING': return `${base} bg-yellow-100 text-yellow-700 border-yellow-200`;
        case 'VISIT_APPROVED': return `${base} bg-[#2C4964]/10 text-[#2C4964] border-[#2C4964]/20`;
        case 'VISIT_COMPLETED': return `${base} bg-green-100 text-green-700 border-green-200`;
        case 'VISIT_CANCELLED': return `${base} bg-red-100 text-red-700 border-red-200`;

        case 'UNVERIFIED': return `${base} bg-yellow-100 text-yellow-700 border-yellow-200`;
        case 'LISTED': return `${base} bg-green-100 text-green-700 border-green-200`;
        case 'REJECTED': return `${base} bg-red-100 text-red-700 border-red-200`;

        case 'PENDING': return `${base} bg-yellow-100 text-yellow-700 border-yellow-200`;
        case 'SUCCESS': return `${base} bg-green-100 text-green-700 border-green-200`;
        case 'FAILED': return `${base} bg-red-100 text-red-700 border-red-200`;

        default: return defaultBadgeClasses;
    }
};

export const getPropertyTypeBadgeClasses = (type: PropertyType | string | null | undefined): string => {
    const base = badgeBaseClasses;
    switch (type) {
        case 'HOUSE': return `${base} bg-[#2C4964]/10 text-[#2C4964] border-[#2C4964]/20`;
        case 'LAND': return `${base} bg-green-100 text-green-700 border-green-200`;
        case 'BUILDING': return `${base} bg-indigo-100 text-indigo-700 border-indigo-200`;
        default: return defaultBadgeClasses;
    }
};

export const getListingTypeBadgeClasses = (type: ListingType | string | null | undefined): string => {
    const base = badgeBaseClasses;
    switch (type) {
        case 'RENTAL': return `${base} bg-cyan-100 text-cyan-700 border-cyan-200`;
        case 'SALE': return `${base} bg-orange-100 text-orange-700 border-orange-200`;
        default: return defaultBadgeClasses;
    }
};
