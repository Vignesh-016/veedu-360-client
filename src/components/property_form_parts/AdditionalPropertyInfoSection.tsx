import React, { ChangeEvent } from 'react';
import FormFieldWrapper from './FormFieldWrapper';
import { getBaseInputClasses } from '../../lib/twUtils';

interface Props {
    formData: {
        year_built: number | undefined;
        youtube_url: string;
        notes: string;
    };
    onFormDataChange: (fieldName: string, value: any) => void;
    formErrors: Partial<Record<keyof Props['formData'], string>>;
    disabledFields?: Partial<Record<keyof Props['formData'], boolean>>;
}

const AdditionalPropertyInfoSection: React.FC<Props> = ({ formData, onFormDataChange, formErrors, disabledFields = {} }) => {
    const handleInputChange = (e: ChangeEvent<HTMLInputElement | HTMLTextAreaElement>) => {
        const { name, value } = e.target;
        if (name === 'year_built') {
            onFormDataChange(name, value === '' ? undefined : Number(value));
        } else {
            onFormDataChange(name, value);
        }
    };

    return (
        <>
            <FormFieldWrapper label="Year Built (Optional)" htmlFor="year_built" errorMessage={formErrors.year_built} disabled={disabledFields.year_built}>
                <input type="number" name="year_built" id="year_built" value={formData.year_built ?? ''} onChange={handleInputChange}
                    className={getBaseInputClasses()} placeholder="e.g., 2010" min="1800" max={new Date().getFullYear() + 5} step="1" disabled={disabledFields.year_built} />
            </FormFieldWrapper>
            <div className="md:col-span-2">
                <FormFieldWrapper label="YouTube Video URL (Optional)" htmlFor="youtube_url" errorMessage={formErrors.youtube_url} disabled={disabledFields.youtube_url}>
                    <input type="url" name="youtube_url" id="youtube_url" value={formData.youtube_url} onChange={handleInputChange}
                        className={getBaseInputClasses(!!formErrors.youtube_url)} placeholder="https://www.youtube.com/watch?v=..." disabled={disabledFields.youtube_url} />
                </FormFieldWrapper>
            </div>
            <div className="md:col-span-2">
                <FormFieldWrapper label="Internal Notes for Your Reference (Optional)" htmlFor="notes" errorMessage={formErrors.notes} disabled={disabledFields.notes}>
                    <textarea name="notes" id="notes" value={formData.notes} onChange={handleInputChange}
                        className={`${getBaseInputClasses()} min-h-[80px]`} placeholder="Any other details for your team or yourself..." maxLength={500} disabled={disabledFields.notes} />
                    <p className="mt-1 text-xs text-gray-500">{(formData.notes || '').length}/500 characters</p>
                </FormFieldWrapper>
            </div>
        </>
    );
};

export default AdditionalPropertyInfoSection;