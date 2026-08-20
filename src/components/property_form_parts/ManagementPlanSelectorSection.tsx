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
                        <div className={`grid grid-cols-1 gap-5 px-1 py-2 md:grid-cols-2 xl:grid-cols-3 ${disabled ? 'cursor-not-allowed' : ''}`}>
                            {managementPlans.map(plan => (
                                <div key={plan.plan_id} className="relative min-w-0">
                                    <ServicePlanCard
                                        plan={plan}
                                        showIcon={false}
                                        selected={selectedPlanId === plan.plan_id}
                                        disabled={disabled}
                                        className="w-full min-h-[520px]"
                                        onSelect={() => onPlanSelect(selectedPlanId === plan.plan_id ? undefined : plan.plan_id)}
                                    />
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
