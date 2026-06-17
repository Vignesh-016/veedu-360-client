import React, { ChangeEvent } from 'react';
import FormFieldWrapper from './FormFieldWrapper';
import { getBaseInputClasses } from '../../lib/twUtils';

interface Props {
    formData: {
        plot_dimensions: string;
        road_access_width_ft: number | null | undefined;
        is_corner_plot: boolean;
    };
    onFormDataChange: (fieldName: string, value: any) => void;
    formErrors: Partial<Record<keyof Props['formData'], string>>;
    disabledFields?: Partial<Record<keyof Props['formData'], boolean>>;
}

const LandFeaturesSection: React.FC<Props> = ({ formData, onFormDataChange, formErrors, disabledFields = {} }) => {
    const handleInputChange = (e: ChangeEvent<HTMLInputElement>) => {
        const { name, value, type } = e.target;
        if (type === 'checkbox') {
            onFormDataChange(name, (e.target as HTMLInputElement).checked);
        } else if (name === 'road_access_width_ft') {
            onFormDataChange(name, value === '' ? null : Number(value));
        } else {
            onFormDataChange(name, value);
        }
    };

    return (
        <>
            <FormFieldWrapper label="Plot Dimensions (Optional, e.g., 60x40 ft)" htmlFor="plot_dimensions" errorMessage={formErrors.plot_dimensions} disabled={disabledFields.plot_dimensions}>
                <input type="text" name="plot_dimensions" id="plot_dimensions" value={formData.plot_dimensions} onChange={handleInputChange}
                    className={getBaseInputClasses()} placeholder="e.g., 60x40 ft or 30x50 m" disabled={disabledFields.plot_dimensions} />
            </FormFieldWrapper>
            <FormFieldWrapper label="Road Access Width (ft, Optional)" htmlFor="road_access_width_ft" errorMessage={formErrors.road_access_width_ft} disabled={disabledFields.road_access_width_ft}>
                <input type="number" name="road_access_width_ft" id="road_access_width_ft" value={formData.road_access_width_ft ?? ''} onChange={handleInputChange}
                    className={getBaseInputClasses()} placeholder="e.g., 30" min="0" step="1" disabled={disabledFields.road_access_width_ft} />
            </FormFieldWrapper>
            <div className="md:col-span-2 mt-2 flex items-start">
                <input type="checkbox" id="is_corner_plot_land" name="is_corner_plot" checked={!!formData.is_corner_plot} onChange={handleInputChange}
                    className="h-4 w-4 text-gray-600 border-gray-300 rounded focus:ring-gray-500 mr-2 mt-1" disabled={disabledFields.is_corner_plot} />
                <label htmlFor="is_corner_plot_land" className="text-sm text-gray-700">Is this a Corner Plot?</label>
            </div>
        </>
    );
};

export default LandFeaturesSection;