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
    unavailableRestrictedPlans?: ManagementPlan[];
    onRequestPaidPlan?: () => void;
    requestSubmitted?: boolean;
}

const ManagementPlanSelectorSection: React.FC<Props> = ({
    managementPlans, selectedPlanId, onPlanSelect, loading, formErrors, disabled = false, unavailableRestrictedPlans = [], onRequestPaidPlan, requestSubmitted = false
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
                    {!loading && unavailableRestrictedPlans.length > 0 && (
                        <div className="mt-4 rounded-lg border border-amber-200 bg-amber-50 p-4 text-sm text-amber-900">
                            <p className="font-semibold">Paid plans are not currently available for this pincode.</p>
                            <p className="mt-1">You can continue with the Free Plan, or request admin approval for: {unavailableRestrictedPlans.map(plan => plan.name).join(', ')}.</p>
                            <button type="button" onClick={onRequestPaidPlan} disabled={requestSubmitted || disabled} className="mt-3 rounded-md bg-[#2C4964] px-4 py-2 text-sm font-semibold text-white disabled:opacity-60">
                                {requestSubmitted ? 'Request Sent — Continue with Free Plan' : 'Request Admin for Paid Plan'}
                            </button>
                        </div>
                    )}
                </>
            </FormFieldWrapper>
        </div>
    );
};

export default ManagementPlanSelectorSection;
