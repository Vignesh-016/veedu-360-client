import React, { ChangeEvent } from 'react';
import FormFieldWrapper from './FormFieldWrapper';
import FormSegmentedControl from './FormSegmentedControl';
import { HouseType, FurnishedStatus, Direction, WaterSource, PowerBackup } from '../../lib/types';
import { getBaseInputClasses } from '../../lib/twUtils';
import { directionMap, furnishedStatusMap, powerBackupMap, waterSourceMap } from '../../lib/displayUtils';

interface Props {
    formData: {
        num_bedrooms: number | null | undefined;
        num_bathrooms: number | null | undefined;
        num_balconies: number | null | undefined;
        total_floors_house: number | null | undefined;
        floor_number: number | null | undefined;
        num_carparking: number | null | undefined;
        furnished_status: FurnishedStatus | null | undefined;
        facing_direction: Direction | null | undefined;
        is_corner_plot: boolean;
        water_source: WaterSource | null | undefined;
        power_backup: PowerBackup | null | undefined;
        lift_facility_available?: boolean;
        house_type: HouseType | null | undefined;
    };
    onFormDataChange: (fieldName: string, value: any) => void;
    formErrors: Partial<Record<keyof Props['formData'], string>>;
    disabledFields?: Partial<Record<keyof Props['formData'], boolean>>;
}

const HouseFeaturesSection: React.FC<Props> = ({ formData, onFormDataChange, formErrors, disabledFields = {} }) => {
    const handleInputChange = (e: ChangeEvent<HTMLInputElement | HTMLSelectElement>) => {
        const { name, value, type } = e.target;
        if (type === 'checkbox') {
            onFormDataChange(name, (e.target as HTMLInputElement).checked);
        } else if (['num_bedrooms', 'num_bathrooms', 'num_balconies', 'total_floors_house', 'floor_number', 'num_carparking'].includes(name)) {
            onFormDataChange(name, value === '' ? null : Number(value));
        } else {
            onFormDataChange(name, value || null);
        }
    };

    const isApartment = formData.house_type === 'APARTMENT_FLAT';
    const showLiftFacilityOption = isApartment && formData.total_floors_house !== undefined && formData.total_floors_house && formData.total_floors_house > 1;

    return (
        <>
            <FormFieldWrapper label="Number of Bedrooms" htmlFor="num_bedrooms" required errorMessage={formErrors.num_bedrooms} disabled={disabledFields.num_bedrooms}>
                <input type="number" name="num_bedrooms" id="num_bedrooms" value={formData.num_bedrooms ?? ''} onChange={handleInputChange}
                    className={getBaseInputClasses(!!formErrors.num_bedrooms)} placeholder="e.g., 3" min="1" step="1" disabled={disabledFields.num_bedrooms} />
            </FormFieldWrapper>
            <FormFieldWrapper label="Number of Bathrooms" htmlFor="num_bathrooms" required errorMessage={formErrors.num_bathrooms} disabled={disabledFields.num_bathrooms}>
                <input type="number" name="num_bathrooms" id="num_bathrooms" value={formData.num_bathrooms ?? ''} onChange={handleInputChange}
                    className={getBaseInputClasses(!!formErrors.num_bathrooms)} placeholder="e.g., 2" min="1" step="1" disabled={disabledFields.num_bathrooms} />
            </FormFieldWrapper>
            <FormFieldWrapper label="Number of Balconies (Optional)" htmlFor="num_balconies" errorMessage={formErrors.num_balconies} disabled={disabledFields.num_balconies}>
                <input type="number" name="num_balconies" id="num_balconies" value={formData.num_balconies ?? ''} onChange={handleInputChange}
                    className={getBaseInputClasses()} placeholder="e.g., 1" min="0" step="1" disabled={disabledFields.num_balconies} />
            </FormFieldWrapper>
            <FormFieldWrapper label="Total Floors (in Building/Villa, Optional)" htmlFor="total_floors_house" errorMessage={formErrors.total_floors_house} disabled={disabledFields.total_floors_house}>
                <input type="number" name="total_floors_house" id="total_floors_house" value={formData.total_floors_house ?? ''} onChange={handleInputChange}
                    className={getBaseInputClasses()} placeholder="e.g., 10" min="0" step="1" disabled={disabledFields.total_floors_house} />
            </FormFieldWrapper>
            <FormFieldWrapper label="Floor No. (if Apartment, Optional)" htmlFor="floor_number" errorMessage={formErrors.floor_number} disabled={disabledFields.floor_number}>
                <input type="number" name="floor_number" id="floor_number" value={formData.floor_number ?? ''} onChange={handleInputChange}
                    className={getBaseInputClasses()} placeholder="e.g., 5" min="0" step="1" disabled={disabledFields.floor_number} />
            </FormFieldWrapper>
            <FormFieldWrapper label="Car Parking Spaces (Optional)" htmlFor="num_carparking" errorMessage={formErrors.num_carparking} disabled={disabledFields.num_carparking}>
                <input type="number" name="num_carparking" id="num_carparking" value={formData.num_carparking ?? ''} onChange={handleInputChange}
                    className={getBaseInputClasses()} placeholder="e.g., 1" min="0" step="1" disabled={disabledFields.num_carparking} />
            </FormFieldWrapper>
            <FormFieldWrapper label="Facing Direction (Optional)" htmlFor="facing_direction" errorMessage={formErrors.facing_direction} disabled={disabledFields.facing_direction}>
                <select name="facing_direction" id="facing_direction" value={formData.facing_direction ?? ''} onChange={handleInputChange}
                    className={getBaseInputClasses()} disabled={disabledFields.facing_direction}>
                    <option value="">Select direction</option>
                    {Object.entries(directionMap).map(([value, label]) => <option key={value} value={value}>{label}</option>)}
                </select>
            </FormFieldWrapper>
            <div className="md:col-span-2">
                <FormFieldWrapper label="Furnished Status (Optional)" htmlFor="furnished_status" errorMessage={formErrors.furnished_status} disabled={disabledFields.furnished_status}>
                    <FormSegmentedControl
                        name="furnished_status"
                        value={formData.furnished_status}
                        onChange={(value) => onFormDataChange('furnished_status', value as FurnishedStatus)}
                        options={Object.entries(furnishedStatusMap).map(([value, label]) => ({ label, value }))}
                        disabled={disabledFields.furnished_status}
                    />
                </FormFieldWrapper>
            </div>
            <FormFieldWrapper label="Water Source (Optional)" htmlFor="water_source" errorMessage={formErrors.water_source} disabled={disabledFields.water_source}>
                <select name="water_source" id="water_source" value={formData.water_source ?? ''} onChange={handleInputChange}
                    className={getBaseInputClasses()} disabled={disabledFields.water_source}>
                    <option value="">Select water source</option>
                    {Object.entries(waterSourceMap).map(([value, label]) => <option key={value} value={value}>{label}</option>)}
                </select>
            </FormFieldWrapper>
            <FormFieldWrapper label="Inverter / Generator Backup (Optional)" htmlFor="power_backup" errorMessage={formErrors.power_backup} disabled={disabledFields.power_backup}>
                <select name="power_backup" id="power_backup" value={formData.power_backup ?? ''} onChange={handleInputChange}
                    className={getBaseInputClasses()} disabled={disabledFields.power_backup}>
                    <option value="">Select power backup</option>
                    {Object.entries(powerBackupMap).map(([value, label]) => <option key={value} value={value}>{label}</option>)}
                </select>
            </FormFieldWrapper>

            {!isApartment && (
                <div className="md:col-span-2 mt-2 flex items-start">
                    <input type="checkbox" id="is_corner_plot_house" name="is_corner_plot" checked={!!formData.is_corner_plot} onChange={handleInputChange}
                        className="h-4 w-4 text-gray-600 border-gray-300 rounded focus:ring-gray-500 mr-2 mt-1" disabled={disabledFields.is_corner_plot} />
                    <label htmlFor="is_corner_plot_house" className="text-sm text-gray-700">Is this a Corner Plot/House?</label>
                </div>
            )}
            {showLiftFacilityOption && (
                 <div className="md:col-span-2 mt-2 flex items-start">
                    <input type="checkbox" id="lift_facility_available" name="lift_facility_available" checked={!!formData.lift_facility_available} onChange={handleInputChange}
                        className="h-4 w-4 text-gray-600 border-gray-300 rounded focus:ring-gray-500 mr-2 mt-1" disabled={disabledFields.lift_facility_available} />
                    <label htmlFor="lift_facility_available" className="text-sm text-gray-700">Lift Facility Available?</label>
                </div>
            )}
        </>
    );
};

export default HouseFeaturesSection;