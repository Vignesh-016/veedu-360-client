import React, { ChangeEvent } from 'react';
import { LatLngTuple } from 'leaflet';
import FormFieldWrapper from './FormFieldWrapper';
import LocationPickerMap from './LocationPickerMap';
import { getBaseInputClasses } from '../../lib/twUtils';
import { IconX } from '@tabler/icons-react';

interface Props {
    formData: {
        city: string;
        locality: string;
        address: string;
        pincode: number | undefined;
        latitude: number | undefined;
        longitude: number | undefined;
    };
    onFormDataChange: (fieldName: string, value: any) => void;
    formErrors: Partial<Record<'city' | 'locality' | 'address' | 'pincode' | 'latitude' | 'longitude', string>>;
    initialMapCenter: LatLngTuple;
    userHasTypedCity: boolean;
    geolocationLoading: boolean;
    disabledFields?: Partial<Record<keyof Props['formData'], boolean>>;
}

const LocationDetailsSection: React.FC<Props> = ({
    formData, onFormDataChange, formErrors, initialMapCenter, userHasTypedCity, geolocationLoading, disabledFields = {}
}) => {
    const handleInputChange = (e: ChangeEvent<HTMLInputElement | HTMLTextAreaElement>) => {
        const { name, value } = e.target;
        if (name === 'pincode') {
            onFormDataChange(name, value === '' ? undefined : Number(value));
        } else {
            onFormDataChange(name, value);
        }
    };

    const handleCoordinateChange = (name: 'latitude' | 'longitude', valueStr: string) => {
        onFormDataChange(name, valueStr === '' ? undefined : Number(valueStr));
    };

    const handleLocationSelect = (lat: number, lng: number) => {
        onFormDataChange('latitude', lat);
        onFormDataChange('longitude', lng);
    };

    return (
        <>
            <FormFieldWrapper label={`City ${geolocationLoading && !userHasTypedCity && !formData.city ? '(Detecting...)' : ''}`} htmlFor="city" required errorMessage={formErrors.city} disabled={disabledFields.city}>
                <input type="text" name="city" id="city" value={formData.city} onChange={handleInputChange}
                    className={getBaseInputClasses(!!formErrors.city)} placeholder="Enter city" disabled={disabledFields.city} />
            </FormFieldWrapper>
            <FormFieldWrapper label="Locality / Area Name" htmlFor="locality" required errorMessage={formErrors.locality} disabled={disabledFields.locality}>
                <input type="text" name="locality" id="locality" value={formData.locality} onChange={handleInputChange}
                    className={getBaseInputClasses(!!formErrors.locality)} placeholder="e.g., Palayamkottai, Vannarpettai" disabled={disabledFields.locality} />
            </FormFieldWrapper>
            <div className="md:col-span-2">
                <FormFieldWrapper label="Full Address (Door No, Street, Landmark)" htmlFor="address" required errorMessage={formErrors.address} disabled={disabledFields.address}>
                    <textarea name="address" id="address" value={formData.address} onChange={handleInputChange}
                        className={`${getBaseInputClasses(!!formErrors.address)} min-h-[60px]`} placeholder="Enter full address" maxLength={250} disabled={disabledFields.address} />
                </FormFieldWrapper>
            </div>
            <FormFieldWrapper label="Pincode" htmlFor="pincode" required errorMessage={formErrors.pincode} disabled={disabledFields.pincode}>
                <input type="number" name="pincode" id="pincode" value={formData.pincode ?? ''} onChange={handleInputChange}
                    className={getBaseInputClasses(!!formErrors.pincode)} placeholder="e.g., 627007" disabled={disabledFields.pincode} />
            </FormFieldWrapper>
            <FormFieldWrapper label="Latitude (Optional)" htmlFor="latitude" errorMessage={formErrors.latitude} disabled={disabledFields.latitude}>
                <input type="number" name="latitude" id="latitude" value={formData.latitude ?? ''} onChange={(e) => handleCoordinateChange('latitude', e.target.value)}
                    className={getBaseInputClasses(!!formErrors.latitude)} placeholder="e.g., 8.7139" step="any" min="-90" max="90" disabled={disabledFields.latitude} />
            </FormFieldWrapper>
            <FormFieldWrapper label="Longitude (Optional)" htmlFor="longitude" errorMessage={formErrors.longitude} disabled={disabledFields.longitude}>
                <input type="number" name="longitude" id="longitude" value={formData.longitude ?? ''} onChange={(e) => handleCoordinateChange('longitude', e.target.value)}
                    className={getBaseInputClasses(!!formErrors.longitude)} placeholder="e.g., 77.7567" step="any" min="-180" max="180" disabled={disabledFields.longitude} />
            </FormFieldWrapper>
            <div className="md:col-span-2 mt-2">
                <p className="text-xs text-gray-500 mb-1">Click on the map to set coordinates, or enter them manually above.</p>
                <LocationPickerMap
                    mapCenter={initialMapCenter}
                    markerPosition={formData.latitude !== undefined && formData.longitude !== undefined ? [formData.latitude, formData.longitude] : null}
                    onLocationSelect={handleLocationSelect}
                />
                {(formData.latitude !== undefined || formData.longitude !== undefined) && (
                    <button type="button" onClick={() => { handleLocationSelect(NaN, NaN); onFormDataChange('latitude', undefined); onFormDataChange('longitude', undefined); }}
                        className="mt-2 text-xs text-red-600 hover:underline flex items-center gap-1">
                        <IconX size={14} /> Clear Coordinates
                    </button>
                )}
            </div>
        </>
    );
};

export default LocationDetailsSection;