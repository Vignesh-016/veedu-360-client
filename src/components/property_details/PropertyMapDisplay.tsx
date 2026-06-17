import { MapContainer, TileLayer, Marker, Popup } from 'react-leaflet';
import L, { LatLngExpression } from 'leaflet';
import { IconMapPinFilled } from '@tabler/icons-react';
import { renderToStaticMarkup } from 'react-dom/server';

interface PropertyMapDisplayProps {
    latitude: number;
    longitude: number;
    popupContent?: React.ReactNode;
    zoomLevel?: number;
    className?: string;
}

const PropertyMapDisplay: React.FC<PropertyMapDisplayProps> = ({
    latitude,
    longitude,
    popupContent,
    zoomLevel = 16,
    className = 'h-80 w-full rounded-lg shadow-md border border-gray-200'
}) => {
    const position: LatLngExpression = [latitude, longitude];
    const customIconMarkup = renderToStaticMarkup(
        <IconMapPinFilled size={32} className="text-red-500 drop-shadow-lg" />
    );
    const customIcon = L.divIcon({
        html: customIconMarkup,
        className: '',
        iconSize: [32, 32],
        iconAnchor: [16, 32],
        popupAnchor: [0, -32]
    });

    return (
        <MapContainer center={position} zoom={zoomLevel} scrollWheelZoom={true} className={className} attributionControl={false}>
            <TileLayer url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png" />
            <Marker position={position} icon={customIcon}>
                {popupContent && <Popup>{popupContent}</Popup>}
            </Marker>
        </MapContainer>
    );
};

export default PropertyMapDisplay;