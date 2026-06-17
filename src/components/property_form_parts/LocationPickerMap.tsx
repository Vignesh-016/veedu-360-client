import { MapContainer, TileLayer, Marker, useMapEvents } from 'react-leaflet';
import L, { LatLngTuple } from 'leaflet';
import { IconMapPinFilled, IconCurrentLocation } from '@tabler/icons-react';
import { renderToStaticMarkup } from 'react-dom/server';
import { useNotification } from '../NotificationProvider';

interface LocationPickerMapProps {
    mapCenter: LatLngTuple;
    markerPosition: LatLngTuple | null;
    onLocationSelect: (lat: number, lng: number) => void;
    zoom?: number;
    className?: string;
}

// Custom Icon
const customIconMarkup = renderToStaticMarkup(
    <IconMapPinFilled size={32} className="text-red-500 drop-shadow-lg" />
);
const customMapIcon = L.divIcon({
    html: customIconMarkup,
    className: '',
    iconSize: [32, 32],
    iconAnchor: [16, 32],
});

function MapEventsHandler({ onLocationSelect }: { onLocationSelect: (lat: number, lng: number) => void }) {
    useMapEvents({
        click(e) {
            onLocationSelect(e.latlng.lat, e.latlng.lng);
        },
    });
    return null;
}

export default function LocationPickerMap({
    mapCenter,
    markerPosition,
    onLocationSelect,
    zoom = 13,
    className = 'h-72 w-full rounded-lg shadow-sm border border-gray-300'
}: LocationPickerMapProps) {
    const { showErrorNotification } = useNotification();

    const handleUseMyLocation = () => {
        if (!navigator.geolocation) {
            showErrorNotification("Geolocation Error", "Geolocation is not supported by your browser.");
            return;
        }
        navigator.geolocation.getCurrentPosition(
            (position) => {
                const { latitude, longitude } = position.coords;
                onLocationSelect(latitude, longitude);
            },
            (error) => {
                console.error("Error getting current location:", error);
                showErrorNotification("Geolocation Error", `Could not get location: ${error.message}`);
            }
        );
    };

    return (
        <div className="relative">
            <MapContainer
                center={markerPosition || mapCenter}
                zoom={zoom}
                scrollWheelZoom={true}
                className={className}
                attributionControl={false}
            >
                <TileLayer
                    url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
                />
                <MapEventsHandler onLocationSelect={onLocationSelect} />
                {markerPosition && (
                    <Marker position={markerPosition} icon={customMapIcon} />
                )}
            </MapContainer>
            <button
                type="button"
                onClick={handleUseMyLocation}
                className="absolute top-2 right-2 z-[401] bg-white text-gray-700 px-2.5 py-1.5 rounded-md shadow-md text-xs border border-gray-300 hover:bg-gray-50 flex items-center gap-1"
                title="Use my current location"
            >
                <IconCurrentLocation size={14} /> Current Location
            </button>
        </div>
    );
}