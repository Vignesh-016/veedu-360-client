import React, { ChangeEvent } from 'react';
import FormFieldWrapper from './FormFieldWrapper';
import { PropertyType } from '../../lib/types';
import { getBaseInputClasses } from '../../lib/twUtils';

interface Props {
    propertyType: PropertyType;
    formData: {
        house_name: string;
        land_name: string;
        building_name: string;
        description: string;
    };
    onFormDataChange: (fieldName: string, value: string) => void;
    formErrors: Partial<Record<'house_name' | 'land_name' | 'building_name' | 'description', string>>;
    disabledFields?: Partial<Record<'house_name' | 'land_name' | 'building_name' | 'description', boolean>>;
}

const PropertyTitleDescriptionSection: React.FC<Props> = ({ propertyType, formData, onFormDataChange, formErrors, disabledFields = {} }) => {
    const handleInputChange = (e: ChangeEvent<HTMLInputElement | HTMLTextAreaElement>) => {
        onFormDataChange(e.target.name, e.target.value);
    };

    const getTitleFieldName = (): 'house_name' | 'land_name' | 'building_name' => {
        if (propertyType === 'HOUSE') return 'house_name';
        if (propertyType === 'LAND') return 'land_name';
        return 'building_name'; // Default for BUILDING
    };

    const titleFieldName = getTitleFieldName();
    const titleValue = formData[titleFieldName];

    return (
        <>
            <div className="md:col-span-2">
                <FormFieldWrapper label="Post Title" htmlFor={titleFieldName} required errorMessage={formErrors[titleFieldName]} disabled={disabledFields[titleFieldName]}>
                    <input
                        type="text"
                        name={titleFieldName}
                        id={titleFieldName}
                        value={titleValue}
                        onChange={handleInputChange}
                        className={getBaseInputClasses(!!formErrors[titleFieldName])}
                        placeholder={
                            propertyType === 'HOUSE' ? "e.g., Serene Villa, Star Apartments" :
                                propertyType === 'LAND' ? "e.g., Prime Plot near Bypass" :
                                    "e.g., Sunshine Plaza, Tech Tower"
                        }
                        disabled={disabledFields[titleFieldName]}
                        maxLength={100}
                    />
                </FormFieldWrapper>
            </div>
            <div className="md:col-span-2">
                <FormFieldWrapper label="Property Description (Optional)" htmlFor="description" errorMessage={formErrors.description} disabled={disabledFields.description}>
                    <textarea
                        name="description"
                        id="description"
                        value={formData.description}
                        onChange={handleInputChange}
                        className={`${getBaseInputClasses(!!formErrors.description)} min-h-[100px]`}
                        placeholder="Highlight key features, landmarks, or unique selling points..."
                        maxLength={1000}
                        disabled={disabledFields.description}
                    />
                    <p className="mt-1 text-xs text-gray-500">{(formData.description || '').length}/1000 characters</p>
                </FormFieldWrapper>
            </div>
        </>
    );
};

export default PropertyTitleDescriptionSection;