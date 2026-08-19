import React from 'react';
import FormFieldWrapper from './FormFieldWrapper';
import LoadingSpinner from '../LoadingSpinner';
import { ManagementPlan } from '../../lib/types';
import ServicePlanCard from '../ServicePlanCard';

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
                        <div className={`flex items-stretch overflow-x-auto space-x-5 px-1 py-2 pb-8 scrollbar-thin scrollbar-thumb-gray-300 scrollbar-track-gray-100 ${disabled ? 'cursor-not-allowed' : ''}`}>
                            {managementPlans.map(plan => (
                                <ServicePlanCard
                                    key={plan.plan_id}
                                    plan={plan}
                                    showIcon={false}
                                    selected={selectedPlanId === plan.plan_id}
                                    disabled={disabled}
                                    className="flex-shrink-0 w-[320px] h-[580px] ml-1"
                                    onSelect={() => onPlanSelect(selectedPlanId === plan.plan_id ? undefined : plan.plan_id)}
                                />
                            ))}
                        </div>
                    )}
                </>
            </FormFieldWrapper>
        </div>
    );
};

export default ManagementPlanSelectorSection;