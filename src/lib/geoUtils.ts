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

export async function geocodeLocation(query: string): Promise<{ latitude: number; longitude: number; city?: string } | null> {
    try {
        const response = await fetch(`https://nominatim.openstreetmap.org/search?format=jsonv2&limit=1&q=${encodeURIComponent(query)}`);
        if (!response.ok) return null;
        const results = await response.json() as NominatimResponse[];
        const result = results[0];
        if (!result || !result.lat || !result.lon) return null;
        return {
            latitude: Number(result.lat),
            longitude: Number(result.lon),
            city: getCityFromNominatimData(result),
        };
    } catch {
        return null;
    }
}

export function distanceInKilometres(latitude: number, longitude: number, targetLatitude: number, targetLongitude: number): number {
    const radians = (value: number) => value * Math.PI / 180;
    const earthRadius = 6371;
    const latitudeDelta = radians(targetLatitude - latitude);
    const longitudeDelta = radians(targetLongitude - longitude);
    const a = Math.sin(latitudeDelta / 2) ** 2
        + Math.cos(radians(latitude)) * Math.cos(radians(targetLatitude)) * Math.sin(longitudeDelta / 2) ** 2;
    return earthRadius * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}
