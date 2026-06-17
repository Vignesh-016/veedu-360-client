import React, { ChangeEvent } from 'react';
import FormFieldWrapper from './FormFieldWrapper';
import { AreaUnit } from '../../lib/types';
import { getBaseInputClasses } from '../../lib/twUtils';

interface Props {
    formData: {
        area: number | null | undefined;
        area_unit: AreaUnit;
    };
    onFormDataChange: (fieldName: string, value: any) => void;
    formErrors: Partial<Record<keyof Props['formData'], string>>;
    disabledFields?: Partial<Record<keyof Props['formData'], boolean>>;
}

const AreaDimensionsSection: React.FC<Props> = ({ formData, onFormDataChange, formErrors, disabledFields = {} }) => {
    const handleInputChange = (e: ChangeEvent<HTMLInputElement | HTMLSelectElement>) => {
        const { name, value } = e.target;
        if (name === 'area') {
            onFormDataChange(name, value === '' ? null : Number(value));
        } else {
            onFormDataChange(name, value as AreaUnit);
        }
    };
    return (
        <>
            <FormFieldWrapper label="Total Plot/Built-up Area" htmlFor="area" required errorMessage={formErrors.area} disabled={disabledFields.area}>
                <input type="number" name="area" id="area" value={formData.area ?? ''} onChange={handleInputChange}
                    className={getBaseInputClasses(!!formErrors.area)} placeholder="Enter area value" min="0.01" step="0.01" disabled={disabledFields.area} />
            </FormFieldWrapper>
            <FormFieldWrapper label="Unit of Area" htmlFor="area_unit" required errorMessage={formErrors.area_unit} disabled={disabledFields.area_unit}>
                <select name="area_unit" id="area_unit" value={formData.area_unit} onChange={handleInputChange}
                    className={getBaseInputClasses(!!formErrors.area_unit)} disabled={disabledFields.area_unit}>
                    <option value="SQ_FT">Square Feet (sq.ft)</option>
                    <option value="CENTS">Cents</option>
                    <option value="ACRES">Acres</option>
                </select>
            </FormFieldWrapper>
        </>
    );
};

export default AreaDimensionsSection;