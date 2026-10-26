import { HouseType, PropertyType } from './types';

export function getPropertyLabel(
    propertyType?: PropertyType | string,
    houseType?: HouseType | string,
): string {
    if (propertyType === 'HOUSE' && houseType === 'HOSTEL_PG') return 'PG';
    if (propertyType === 'HOUSE' && houseType === 'APARTMENT_FLAT') return 'Apartments';
    if (propertyType === 'HOUSE') return 'Houses';
    if (propertyType === 'LAND') return 'Land';
    if (propertyType === 'BUILDING') return 'Buildings';
    return 'Properties';
}
