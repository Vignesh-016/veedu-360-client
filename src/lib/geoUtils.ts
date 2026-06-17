import { NominatimResponse, NominatimAddress } from './types';

export const DEFAULT_CITY = 'Tirunelveli';

/**
 * Extracts the city name from Nominatim API response.
 * Prioritizes 'city', then 'town', then 'village', then 'county' as a fallback for city-like entity.
 * @param data - The Nominatim API response object.
 * @returns The city name or null if not found.
 */
export function getCityFromNominatimData(data: NominatimResponse | null): string {
    if (!data || !data.address) {
        return DEFAULT_CITY;
    }
    const address: NominatimAddress = data.address;
    return address.city || address.town || address.village || address.county || DEFAULT_CITY;
}