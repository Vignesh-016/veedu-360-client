import React, { ChangeEvent } from 'react';
import FormFieldWrapper from './FormFieldWrapper';
import FormSegmentedControl from './FormSegmentedControl';
import { ListingType, AvailabilityStatus } from '../../lib/types';

interface Props {
    formData: {
        price: number | null | undefined;
        advance_amount: number | null | undefined;
        availability_status: AvailabilityStatus;
    };
    listingType: ListingType;
    onFormDataChange: (fieldName: string, value: any) => void;
    formErrors: Partial<Record<keyof Props['formData'], string>>;
    disabledFields?: Partial<Record<keyof Props['formData'], boolean>>;
}

const PricingAvailabilitySection: React.FC<Props> = ({ formData, listingType, onFormDataChange, formErrors, disabledFields = {} }) => {
    const handleInputChange = (e: ChangeEvent<HTMLInputElement | HTMLSelectElement>) => {
        const { name, value } = e.target;
        if (['price', 'advance_amount'].includes(name)) {
            onFormDataChange(name, value === '' ? null : Number(value));
        } else {
            onFormDataChange(name, value as AvailabilityStatus);
        }
    };

    const baseInputStyleCore = "block w-full border rounded-xl shadow-sm placeholder-gray-400 focus:outline-none focus:ring-2 focus:border-transparent transition-all duration-200 ease-in-out bg-gray-50";

    const largeInputClasses = (hasError?: boolean): string => {
        return `
            ${baseInputStyleCore}
            text-lg font-bold px-5 py-3 
            ${hasError ? 'border-red-400 focus:ring-red-500' : 'border-gray-300 focus:ring-primary'}
        `;
    };

    return (
        <>
            <div className="md:col-span-2">
                <FormFieldWrapper label="Availability Status" htmlFor="availability_status" required errorMessage={formErrors.availability_status} disabled={disabledFields.availability_status}>
                    <FormSegmentedControl
                        name="availability_status"
                        value={formData.availability_status}
                        onChange={(value) => onFormDataChange('availability_status', value as AvailabilityStatus)}
                        options={[{ label: 'Ready to Move', value: 'READY_TO_MOVE' }, { label: 'Under Construction', value: 'UNDER_CONSTRUCTION' }]}
                        disabled={disabledFields.availability_status}
                    />
                </FormFieldWrapper>
            </div>
            <div className="md:col-span-2">
                <FormFieldWrapper label={`Expected Price ${listingType === 'RENTAL' ? 'Per Month' : ''}`} htmlFor="price" required errorMessage={formErrors.price} disabled={disabledFields.price}>
                    <input type="number" name="price" id="price" value={formData.price ?? ''} onChange={handleInputChange}
                        className={largeInputClasses(!!formErrors.price)}
                        placeholder="Enter amount" min="1" disabled={disabledFields.price} />
                </FormFieldWrapper>
            </div>
            {listingType === 'RENTAL' && (
                <FormFieldWrapper label="Advance Amount (Optional)" htmlFor="advance_amount" errorMessage={formErrors.advance_amount} disabled={disabledFields.advance_amount}>
                    <input type="number" name="advance_amount" id="advance_amount" value={formData.advance_amount ?? ''} onChange={handleInputChange}
                        className={largeInputClasses(!!formErrors.advance_amount)}
                        placeholder="e.g., 50000" min="0" disabled={disabledFields.advance_amount} />
                </FormFieldWrapper>
            )}
        </>
    );
};

export default PricingAvailabilitySection;