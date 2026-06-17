import React, { ChangeEvent } from 'react';
import FormFieldWrapper from './FormFieldWrapper';
import { ProximityUnit } from '../../lib/types';
import { getBaseInputClasses } from '../../lib/twUtils';
import { proximityUnitMap } from '../../lib/displayUtils';

interface Props {
    formData: {
        proximity_unit: ProximityUnit;
        nearest_hospital: number | undefined;
        nearest_busstop: number | undefined;
        nearest_school: number | undefined;
        nearest_park: number | undefined;
        nearest_gym: number | undefined;
        nearest_swimmingpool: number | undefined;
    };
    onFormDataChange: (fieldName: string, value: any) => void;
    formErrors: Partial<Record<keyof Props['formData'], string>>;
    disabledFields?: Partial<Record<keyof Props['formData'], boolean>>;
}

const NearbyAmenitiesSection: React.FC<Props> = ({ formData, onFormDataChange, formErrors, disabledFields = {} }) => {
    const handleInputChange = (e: ChangeEvent<HTMLInputElement | HTMLSelectElement>) => {
        const { name, value } = e.target;
        if (name === 'proximity_unit') {
            onFormDataChange(name, value as ProximityUnit);
        } else {
            onFormDataChange(name, value === '' ? undefined : Number(value));
        }
    };

    const amenityFields: (keyof Pick<Props['formData'], 'nearest_hospital' | 'nearest_busstop' | 'nearest_school' | 'nearest_park' | 'nearest_gym' | 'nearest_swimmingpool'>)[] = [
        'nearest_hospital', 'nearest_busstop', 'nearest_school', 'nearest_park', 'nearest_gym', 'nearest_swimmingpool'
    ];

    const getLabel = (key: string) => key.replace('nearest_', '').replace('_', ' ').replace(/\b\w/g, l => l.toUpperCase());

    return (
        <>
            <div className="md:col-span-2">
                <FormFieldWrapper label="Unit for Proximity Distances" htmlFor="proximity_unit" errorMessage={formErrors.proximity_unit} disabled={disabledFields.proximity_unit}>
                    <select name="proximity_unit" id="proximity_unit" value={formData.proximity_unit} onChange={handleInputChange}
                        className={getBaseInputClasses()} disabled={disabledFields.proximity_unit}>
                        {Object.entries(proximityUnitMap).map(([value, label]) => <option key={value} value={value}>{label}</option>)}
                    </select>
                </FormFieldWrapper>
            </div>
            {amenityFields.map(fieldKey => (
                <FormFieldWrapper label={getLabel(fieldKey)} htmlFor={fieldKey} key={fieldKey} errorMessage={formErrors[fieldKey]} disabled={disabledFields[fieldKey]}>
                    <input type="number" name={fieldKey} id={fieldKey} value={formData[fieldKey] ?? ''} onChange={handleInputChange}
                        className={getBaseInputClasses()} placeholder="Distance" min="0" step="0.1" disabled={disabledFields[fieldKey]} />
                </FormFieldWrapper>
            ))}
        </>
    );
};

export default NearbyAmenitiesSection;