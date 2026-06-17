import React, { ChangeEvent } from 'react';
import FormFieldWrapper from './FormFieldWrapper';
import { getBaseInputClasses } from '../../lib/twUtils';

interface Props {
    formData: {
        total_floors_building: number | null | undefined;
        num_units: number | null | undefined;
        available_units: number | null | undefined;
        common_amenities: string;
    };
    onFormDataChange: (fieldName: string, value: any) => void;
    formErrors: Partial<Record<keyof Props['formData'], string>>;
    disabledFields?: Partial<Record<keyof Props['formData'], boolean>>;
}

const BuildingFeaturesSection: React.FC<Props> = ({ formData, onFormDataChange, formErrors, disabledFields = {} }) => {
    const handleInputChange = (e: ChangeEvent<HTMLInputElement | HTMLTextAreaElement>) => {
        const { name, value } = e.target;
        if (['total_floors_building', 'num_units', 'available_units'].includes(name)) {
            onFormDataChange(name, value === '' ? null : Number(value));
        } else {
            onFormDataChange(name, value);
        }
    };

    return (
        <>
            <FormFieldWrapper label="Total Floors" htmlFor="total_floors_building" required errorMessage={formErrors.total_floors_building} disabled={disabledFields.total_floors_building}>
                <input type="number" name="total_floors_building" id="total_floors_building" value={formData.total_floors_building ?? ''} onChange={handleInputChange}
                    className={getBaseInputClasses(!!formErrors.total_floors_building)} placeholder="e.g., 5" min="1" step="1" disabled={disabledFields.total_floors_building} />
            </FormFieldWrapper>
            <FormFieldWrapper label="Total Units in Building (Optional)" htmlFor="num_units" errorMessage={formErrors.num_units} disabled={disabledFields.num_units}>
                <input type="number" name="num_units" id="num_units" value={formData.num_units ?? ''} onChange={handleInputChange}
                    className={getBaseInputClasses()} placeholder="e.g., 20" min="0" step="1" disabled={disabledFields.num_units} />
            </FormFieldWrapper>
            <FormFieldWrapper label="Number of Available Units (Optional)" htmlFor="available_units" errorMessage={formErrors.available_units} disabled={disabledFields.available_units}>
                <input type="number" name="available_units" id="available_units" value={formData.available_units ?? ''} onChange={handleInputChange}
                    className={getBaseInputClasses()} placeholder="e.g., 5" min="0" step="1" disabled={disabledFields.available_units} />
            </FormFieldWrapper>
            <div className="md:col-span-2">
                <FormFieldWrapper label="Common Amenities (Optional, comma-separated)" htmlFor="common_amenities" errorMessage={formErrors.common_amenities} disabled={disabledFields.common_amenities}>
                    <textarea name="common_amenities" id="common_amenities" value={formData.common_amenities} onChange={handleInputChange}
                        className={`${getBaseInputClasses()} min-h-[60px]`} placeholder="e.g., Parking, Lift, Security, Gym" maxLength={250} disabled={disabledFields.common_amenities} />
                </FormFieldWrapper>
            </div>
        </>
    );
};

export default BuildingFeaturesSection;