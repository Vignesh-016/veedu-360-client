import React from 'react';
import { Property, HouseDetailsSpecific, LandDetailsSpecific, BuildingDetailsSpecific } from '../../lib/types';
import { IconBed, IconBath, IconRuler, IconCarGarage, IconSofa, IconMapPin2, IconDimensions, IconBuildingCommunity, IconBuildingWarehouse, IconElevator } from '@tabler/icons-react';
import { getDisplayValue, areaUnitMap, furnishedStatusMap, landTypeMap, buildingTypeMap } from '../../lib/displayUtils';
import { Json } from '../../database.types';

interface KeyFeaturesProps {
    details: Property;
}

const KeyFeatures: React.FC<KeyFeaturesProps> = ({ details }) => {
    const features = [];
    const propertyDetails = details.details as Json;

    features.push({
        icon: IconRuler,
        label: "Area",
        value: `${details.area} ${getDisplayValue(areaUnitMap, details.area_unit)}`,
        color: 'text-gray-600'
    });

    if (details.property_type === 'HOUSE' && propertyDetails) {
        const houseDetails = propertyDetails as HouseDetailsSpecific['details'];
        if (houseDetails?.num_bedrooms) features.push({ icon: IconBed, label: "Beds", value: houseDetails.num_bedrooms, color: 'text-gray-600' });
        if (houseDetails?.num_bathrooms) features.push({ icon: IconBath, label: "Baths", value: houseDetails.num_bathrooms, color: 'text-gray-600' });
        if (houseDetails?.num_carparking) features.push({ icon: IconCarGarage, label: "Parking", value: houseDetails.num_carparking, color: 'text-gray-600' });
        if (houseDetails?.furnished_status) features.push({ icon: IconSofa, label: "Furnishing", value: getDisplayValue(furnishedStatusMap, houseDetails.furnished_status), color: 'text-gray-600' });
        if (houseDetails.house_type === 'APARTMENT_FLAT' && houseDetails.lift_facility_available !== undefined) {
            features.push({ icon: IconElevator, label: "Lift", value: houseDetails.lift_facility_available ? "Available" : "Not Available", color: 'text-gray-600' });
        }
    } else if (details.property_type === 'LAND' && propertyDetails) {
        const landDetails = propertyDetails as LandDetailsSpecific['details'];
        if (landDetails?.land_type) features.push({ icon: IconMapPin2, label: "Type", value: getDisplayValue(landTypeMap, landDetails.land_type), color: 'text-gray-600' });
        if (landDetails?.plot_dimensions) features.push({ icon: IconDimensions, label: "Dimensions", value: landDetails.plot_dimensions, color: 'text-gray-600' });
    } else if (details.property_type === 'BUILDING' && propertyDetails) {
        const buildingDetails = propertyDetails as BuildingDetailsSpecific['details'];
        if (buildingDetails?.building_type) features.push({ icon: IconBuildingCommunity, label: "Type", value: getDisplayValue(buildingTypeMap, buildingDetails.building_type), color: 'text-gray-600' });
        if (buildingDetails?.total_floors) features.push({ icon: IconBuildingWarehouse, label: "Floors", value: buildingDetails.total_floors, color: 'text-gray-600' });
    }

    if (features.length === 0) return null;

    return (
        <div className="mb-6 bg-white p-6 rounded-lg border border-gray-200 shadow-sm">
            <h3 className="text-lg font-semibold text-gray-700 mb-3">Key Features</h3>
            <div className="grid grid-cols-2 sm:grid-cols-3 gap-4">
                {features.map((feature, index) => (
                    <div key={index} className="bg-gray-50 p-4 rounded-lg border border-gray-200 flex items-center gap-3 shadow-sm">
                        <feature.icon size={24} className={`${feature.color || 'text-gray-500'} flex-shrink-0`} stroke={1.5} />
                        <div>
                            <span className="block text-xs text-gray-500">{feature.label}</span>
                            <span className="block font-semibold text-gray-800">{feature.value}</span>
                        </div>
                    </div>
                ))}
            </div>
        </div>
    );
};

export default KeyFeatures;