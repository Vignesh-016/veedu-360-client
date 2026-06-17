import React, { ChangeEvent } from 'react';
import FormFieldWrapper from './FormFieldWrapper';

interface Props {
    formData: {
        is_exclusive: boolean;
        agree_terms: boolean;
    };
    onFormDataChange: (fieldName: string, value: boolean) => void;
    formErrors: Partial<Record<keyof Props['formData'], string>>;
    companyName: string;
    disabled?: boolean;
}

const TermsAndPreferencesSection: React.FC<Props> = ({ formData, onFormDataChange, formErrors, companyName, disabled = false }) => {
    const handleCheckboxChange = (e: ChangeEvent<HTMLInputElement>) => {
        onFormDataChange(e.target.name, e.target.checked);
    };

    return (
        <div className="md:col-span-2 space-y-3">
            <FormFieldWrapper label="" htmlFor="is_exclusive_wrapper" disabled={disabled}>
                <label className="flex items-center text-sm text-gray-700 cursor-pointer">
                    <input type="checkbox" name="is_exclusive" id="is_exclusive" checked={formData.is_exclusive} onChange={handleCheckboxChange}
                        className="h-4 w-4 text-gray-600 border-gray-300 rounded focus:ring-gray-500 mr-2" disabled={disabled} />
                    I am posting this property exclusively on {companyName}.
                </label>
            </FormFieldWrapper>
            <FormFieldWrapper label="Agree to Terms & Conditions" htmlFor="agree_terms_wrapper" required errorMessage={formErrors.agree_terms} disabled={disabled}>
                <label className="flex items-start text-sm text-gray-700 cursor-pointer">
                    <input type="checkbox" id="agree_terms" name="agree_terms" checked={formData.agree_terms} onChange={handleCheckboxChange}
                        className="h-4 w-4 text-gray-600 border-gray-300 rounded focus:ring-gray-500 mr-2 mt-0.5 flex-shrink-0" disabled={disabled} />
                    <span>
                        I agree to {companyName}'s <a href="/terms" target="_blank" rel="noopener noreferrer" className='text-gray-600 hover:underline'>Terms & Conditions</a> and <a href="/privacy" target="_blank" rel="noopener noreferrer" className='text-gray-600 hover:underline'>Privacy Policy</a>.
                    </span>
                </label>
            </FormFieldWrapper>
        </div>
    );
};

export default TermsAndPreferencesSection;