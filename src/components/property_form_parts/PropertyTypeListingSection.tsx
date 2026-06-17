import React, { ChangeEvent } from 'react';
import FormFieldWrapper from './FormFieldWrapper';
import FormSegmentedControl from './FormSegmentedControl';
import { PropertyType, ListingType, SubmitterType, HouseType, LandType, BuildingType } from '../../lib/types';
import { getBaseInputClasses } from '../../lib/twUtils';

interface Props {
    formData: {
        submitter_type: SubmitterType;
        listing_type: ListingType;
        property_type: PropertyType;
        house_type: HouseType | null | undefined;
        land_type: LandType | null | undefined;
        building_type: BuildingType | null | undefined;
    };
    onFormDataChange: (fieldName: string, value: any) => void;
    formErrors: Partial<Record<keyof Props['formData'], string>>;
    disabledFields?: Partial<Record<keyof Props['formData'], boolean>>;
}

const PropertyTypeListingSection: React.FC<Props> = ({ formData, onFormDataChange, formErrors, disabledFields = {} }) => {
    const handleInputChange = (e: ChangeEvent<HTMLSelectElement>) => {
        onFormDataChange(e.target.name, e.target.value || null);
    };

    return (
        <>
            <div className="md:col-span-2">
                <FormFieldWrapper label="You are a" htmlFor="submitter_type" required errorMessage={formErrors.submitter_type} disabled={disabledFields.submitter_type}>
                    <FormSegmentedControl
                        name="submitter_type"
                        value={formData.submitter_type}
                        onChange={(value) => onFormDataChange('submitter_type', value as SubmitterType)}
                        options={[
                            { label: 'Agent', value: 'AGENT' },
                            { label: 'Owner', value: 'OWNER' },
                            { label: 'Builder', value: 'BUILDER' },
                        ]}
                        disabled={disabledFields.submitter_type}
                    />
                </FormFieldWrapper>
            </div>
            <div className="md:col-span-2">
                <FormFieldWrapper label="I am looking to" htmlFor="listing_type" required errorMessage={formErrors.listing_type} disabled={disabledFields.listing_type}>
                    <FormSegmentedControl
                        name="listing_type"
                        value={formData.listing_type}
                        onChange={(value) => onFormDataChange('listing_type', value as ListingType)}
                        options={[{ label: 'Sell Property', value: 'SALE' }, { label: 'Rent out Property', value: 'RENTAL' }]}
                        disabled={disabledFields.listing_type}
                    />
                </FormFieldWrapper>
            </div>
            <FormFieldWrapper label="Property Type" htmlFor="property_type" required errorMessage={formErrors.property_type} disabled={disabledFields.property_type}>
                <select name="property_type" id="property_type" value={formData.property_type}
                    onChange={(e) => onFormDataChange('property_type', e.target.value as PropertyType)}
                    className={getBaseInputClasses(!!formErrors.property_type)} disabled={disabledFields.property_type}>
                    <option value="HOUSE">House / Villa / Apartment</option>
                    <option value="LAND">Land / Plot</option>
                    <option value="BUILDING">Building (Commercial/Residential)</option>
                </select>
            </FormFieldWrapper>

            {formData.property_type === 'HOUSE' && (
                <FormFieldWrapper label="Type of House" htmlFor="house_type" required errorMessage={formErrors.house_type} disabled={disabledFields.house_type}>
                    <select name="house_type" id="house_type" value={formData.house_type ?? ''} onChange={handleInputChange}
                        className={getBaseInputClasses(!!formErrors.house_type)} disabled={disabledFields.house_type}>
                        <option value="">Select type of house</option>
                        <option value="INDEPENDENT_VILLA">Independent House / Villa</option>
                        <option value="APARTMENT_FLAT">Flat / Apartment</option>
                        <option value="HOSTEL_PG">Hostel / PG</option>
                    </select>
                </FormFieldWrapper>
            )}
            {formData.property_type === 'LAND' && (
                <FormFieldWrapper label="Type of Land" htmlFor="land_type" required errorMessage={formErrors.land_type} disabled={disabledFields.land_type}>
                    <select name="land_type" id="land_type" value={formData.land_type ?? ''} onChange={handleInputChange}
                        className={getBaseInputClasses(!!formErrors.land_type)} disabled={disabledFields.land_type}>
                        <option value="">Select type of land</option>
                        <option value="RESIDENTIAL">Residential</option>
                        <option value="COMMERCIAL">Commercial</option>
                        <option value="AGRICULTURAL">Agricultural</option>
                    </select>
                </FormFieldWrapper>
            )}
            {formData.property_type === 'BUILDING' && (
                <FormFieldWrapper label="Type of Building" htmlFor="building_type" required errorMessage={formErrors.building_type} disabled={disabledFields.building_type}>
                    <select name="building_type" id="building_type" value={formData.building_type ?? ''} onChange={handleInputChange}
                        className={getBaseInputClasses(!!formErrors.building_type)} disabled={disabledFields.building_type}>
                        <option value="">Select type of building</option>
                        <option value="OFFICE">Office Space</option>
                        <option value="RETAIL">Retail Shop</option>
                        <option value="WAREHOUSE">Warehouse / Godown</option>
                        <option value="INDUSTRIAL">Industrial</option>
                        <option value="HOSPITALITY">Hospitality (Hotel, etc)</option>
                    </select>
                </FormFieldWrapper>
            )}
        </>
    );
};

export default PropertyTypeListingSection;