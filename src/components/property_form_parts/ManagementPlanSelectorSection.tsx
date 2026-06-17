import React from 'react';
import FormFieldWrapper from './FormFieldWrapper';
import LoadingSpinner from '../LoadingSpinner';
import { ManagementPlan } from '../../lib/types';

interface Props {
    managementPlans: ManagementPlan[];
    selectedPlanId: string | undefined;
    onPlanSelect: (planId: string | undefined) => void;
    loading: boolean;
    formErrors: Partial<Record<'management_plan_id', string>>;
    disabled?: boolean;
}

const ManagementPlanSelectorSection: React.FC<Props> = ({
    managementPlans, selectedPlanId, onPlanSelect, loading, formErrors, disabled = false
}) => {
    return (
        <div className="md:col-span-2">
            <FormFieldWrapper label="Select a Management Plan" htmlFor="management_plan_id" errorMessage={formErrors.management_plan_id} disabled={disabled}>
                <>
                    {loading && <div className="flex justify-center items-center p-4"><LoadingSpinner /> <span className="ml-2">Loading plans...</span></div>}
                    {!loading && managementPlans.length === 0 && (
                        <p className="text-sm text-gray-500 p-4 text-center">No active management plans available.</p>
                    )}
                    {!loading && managementPlans.length > 0 && (
                        <div className={`flex overflow-x-auto space-x-4 py-2 scrollbar-thin scrollbar-thumb-gray-300 scrollbar-track-gray-100 ${disabled ? 'opacity-70 cursor-not-allowed' : ''}`}>
                            {managementPlans.map(plan => (
                                <div
                                    key={plan.plan_id}
                                    onClick={() => !disabled && onPlanSelect(selectedPlanId === plan.plan_id ? undefined : plan.plan_id)}
                                    className={`
                                        flex-shrink-0 w-64 p-4 border rounded-lg transition-all duration-200 ml-1
                                        ${disabled ? 'cursor-not-allowed bg-gray-50' : 'cursor-pointer'}
                                        ${selectedPlanId === plan.plan_id
                                            ? (disabled ? 'border-gray-300 bg-gray-100 text-gray-500' : 'border-gray-600 bg-gray-50 shadow-md ring-2 ring-gray-500 ring-offset-1')
                                            : (disabled ? 'border-gray-200 bg-gray-50' : 'border-gray-300 bg-white hover:shadow-lg hover:border-gray-400')
                                        }
                                    `}
                                >
                                    <h3 className={`font-semibold text-md ${selectedPlanId === plan.plan_id && !disabled ? 'text-gray-800' : 'text-gray-700'}`}>{plan.name}</h3>
                                    {plan.percentage > 0 && <p className="text-sm text-gray-600 mt-1">Starting at {plan.percentage}% of the rental value + GST</p>}
                                    {plan.percentage === 0 && <p className="text-sm text-gray-600 mt-1">0% - Free Service</p>}
                                    {plan.description && (
                                        <ul className="text-xs text-gray-500 mt-3 space-y-1.5 list-disc list-inside">
                                            {plan.description.split(',').map(item => item.trim()).filter(Boolean).map((point, index) => (
                                                <li key={index} className="font-semibold text-gray-700">
                                                    {point}
                                                </li>
                                            ))}
                                        </ul>
                                    )}
                                </div>
                            ))}
                        </div>
                    )}
                </>
            </FormFieldWrapper>
        </div>
    );
};

export default ManagementPlanSelectorSection;