import { MapContainer, TileLayer, Marker, Popup, useMap } from 'react-leaflet';
import L, { LatLngExpression, LatLngBounds } from 'leaflet';
import { Property, HouseDetailsSpecific, LandDetailsSpecific, BuildingDetailsSpecific } from '../lib/types';
import { formatPrice } from '../lib/formatUtils';
import { IconBuildingCommunity, IconHome2, IconMapPin, IconMapPin2, IconArrowRight } from '@tabler/icons-react';
import { getDisplayValue, propertyTypeMap } from '../lib/displayUtils';
import { getPrimaryButtonClasses } from '../lib/twUtils';
import { useNavigate } from 'react-router-dom';
import { Json } from '../database.types';

interface PropertiesMapViewProps {
    properties: Property[];
    className?: string;
}

// --- Custom Marker Icon ---
const createPriceMarkerIcon = (priceFormatted: string, isRental: boolean) => {
    const bgColor = isRental ? 'bg-cyan-600' : 'bg-orange-600';
    const textColor = 'text-white';
    const html = `
        <div class="price-marker ${bgColor} ${textColor} px-2 py-0.5 rounded-md text-xs font-semibold shadow-md whitespace-nowrap">
            ${priceFormatted}
        </div>
    `;
    return L.divIcon({
        html: html,
        className: 'leaflet-price-marker',
        iconSize: L.point(80, 20),
        iconAnchor: L.point(40, 10)
    });
};

// --- FitBounds Component ---
const ChangeView = ({ bounds }: { bounds: LatLngBounds | null }) => {
    const map = useMap();
    if (bounds) {
        map.fitBounds(bounds, { padding: [30, 30] });
    }
    return null;
};

// --- Map Component ---
function PropertiesMapView({ properties, className = 'h-[500px] w-full rounded-lg shadow-md border border-gray-200 mb-6' }: PropertiesMapViewProps) {
    const navigate = useNavigate();

    // Filter properties with valid coordinates and calculate bounds
    const validProperties = properties.filter(p => p.latitude != null && p.longitude != null);
    let mapBounds: LatLngBounds | null = null;
    if (validProperties.length > 0) {
        const corner1 = L.latLng(
            Math.min(...validProperties.map(p => p.latitude!)),
            Math.min(...validProperties.map(p => p.longitude!))
        );
        const corner2 = L.latLng(
            Math.max(...validProperties.map(p => p.latitude!)),
            Math.max(...validProperties.map(p => p.longitude!))
        );
        mapBounds = L.latLngBounds(corner1, corner2);
    }

    // Fallback center if no properties or only one property
    const defaultCenter: LatLngExpression = mapBounds && validProperties.length > 1
        ? mapBounds.getCenter()
        : (validProperties[0] ? [validProperties[0].latitude!, validProperties[0].longitude!] : [10.0, 77.5]); // Default to a generic location

    const defaultZoom = mapBounds && validProperties.length > 1 ? 12 : 14; // Zoom further if only one property

    const handleViewDetails = (propertyId: string) => {
        navigate(`/property/${propertyId}`);
    };

    // --- Get Property Icon ---
    const getPropertyIcon = (type: Property['property_type']) => {
        switch (type) {
            case 'HOUSE': return IconHome2;
            case 'LAND': return IconMapPin2;
            case 'BUILDING': return IconBuildingCommunity;
            default: return IconMapPin;
        }
    };

    // --- Get Property Name ---
    const getPropertyName = (property: Property): string => {
        const details = property.details as Json;
        if (property.property_type === 'HOUSE' && details && (details as HouseDetailsSpecific['details']).house_name) {
            return (details as HouseDetailsSpecific['details']).house_name;
        }
        if (property.property_type === 'LAND' && details && (details as LandDetailsSpecific['details']).land_name) {
            return (details as LandDetailsSpecific['details']).land_name;
        }
        if (property.property_type === 'BUILDING' && details && (details as BuildingDetailsSpecific['details']).building_name) {
            return (details as BuildingDetailsSpecific['details']).building_name;
        }
        return property.locality || 'Property';
    };


    return (
        <MapContainer
            center={defaultCenter}
            zoom={defaultZoom}
            scrollWheelZoom={true}
            className={className}
            attributionControl={false}
        >
            <TileLayer
                url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
            // attribution='© <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
            />
            {/* Add component to adjust bounds */}
            {mapBounds && <ChangeView bounds={mapBounds} />}

            {validProperties.map((prop) => {
                const position: LatLngExpression = [prop.latitude!, prop.longitude!];
                const priceFormatted = formatPrice(prop.price);
                const isRental = prop.listing_type === 'RENTAL';
                const PropertyIcon = getPropertyIcon(prop.property_type);
                const fallbackImageUrl = `https://placehold.co/200x150/e2e8f0/94a3b8?text=${encodeURIComponent(prop.locality || 'Property')}`;
                const propertyName = getPropertyName(prop);

                return (
                    <Marker key={prop.property_id} position={position} icon={createPriceMarkerIcon(priceFormatted, isRental)}>
                        <Popup minWidth={250}>
                            <div className="flex flex-col gap-1">
                                <img
                                    src={prop.property_images[0]?.image_url || fallbackImageUrl}
                                    alt={propertyName}
                                    className="w-full h-32 object-cover rounded-md"
                                    loading="lazy"
                                    onError={(e) => { e.currentTarget.src = fallbackImageUrl; }}
                                />
                                <div className="flex items-center gap-1 text-xs text-gray-500">
                                    <PropertyIcon size={14} className="text-gray-400" />
                                    <span>{getDisplayValue(propertyTypeMap, prop.property_type)} ({isRental ? 'Rent' : 'Sale'})</span>
                                </div>
                                <h3 className="font-semibold text-sm text-gray-800 line-clamp-1" title={propertyName}>
                                    {propertyName}
                                </h3>
                                <p className="font-bold text-base text-gray-700">
                                    {priceFormatted} {isRental && <span className="text-xs font-normal text-gray-500">/month</span>}
                                </p>
                                <button
                                    onClick={() => handleViewDetails(prop.property_id)}
                                    className={`${getPrimaryButtonClasses()} !text-xs !px-3 !py-1.5 w-full mt-1`}
                                >
                                    View Details <IconArrowRight size={14} className='ml-1' />
                                </button>
                            </div>
                        </Popup>
                    </Marker>
                );
            })}
        </MapContainer>
    );
}

export default PropertiesMapView;