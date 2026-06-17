import React from 'react';
import { Property } from '../../lib/types';
import { getDisplayValue, propertyTypeMap } from '../../lib/displayUtils';
import { IconTag, IconSparkles, IconMapPin } from '@tabler/icons-react';

interface PropertyHeaderProps {
    details: Property;
    displayName: string;
    PropertyIcon: React.ElementType;
}

const PropertyHeader: React.FC<PropertyHeaderProps> = ({ details, displayName, PropertyIcon }) => {
    return (
        <div className="mb-5 bg-white p-6 rounded-lg border border-gray-200 shadow-sm">
            <div className="flex items-center gap-2 mb-2 flex-wrap">
                <span className={`inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-medium border bg-gray-50 text-gray-700 border-gray-200`}>
                    <PropertyIcon size={14} /> {getDisplayValue(propertyTypeMap, details.property_type)}
                </span>
                <span className={`inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-medium border bg-gray-50 text-gray-700 border-gray-200`}>
                    <IconTag size={14} /> {details.listing_type === 'SALE' ? 'For Sale' : 'For Rent'}
                </span>
                {details.is_featured && (
                    <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-bold border bg-gradient-to-r from-yellow-100 via-amber-100 to-orange-100 text-amber-800 border-amber-300 shadow-sm" title="Featured Property">
                        <IconSparkles size={14} stroke={2} className="text-amber-600" />
                        Featured
                    </span>
                )}
            </div>
            <h1 className="text-3xl font-bold text-gray-900">{displayName}</h1>
            <div className="mt-1 flex items-center text-sm text-gray-600">
                <IconMapPin size={16} className="mr-1.5 text-gray-400" />
                {details.locality}, {details.city}{details.pincode ? `, Pincode: ${details.pincode}` : ''}
            </div>
        </div>
    );
};

export default PropertyHeader;