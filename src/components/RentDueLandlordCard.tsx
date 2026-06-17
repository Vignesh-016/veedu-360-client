import { PropertyRentDues, RentStatus } from '../lib/types';
import { format, parseISO } from 'date-fns';
import { IconAlertTriangle, IconCalendarDue, IconCash, IconCircleCheck, IconProgress, IconUser, IconMail, IconPhone } from '@tabler/icons-react';
import { formatPrice } from '../lib/formatUtils';

interface RentDueLandlordCardProps {
    rentDue: PropertyRentDues;
}

function RentDueLandlordCard({ rentDue }: RentDueLandlordCardProps) {
    const {
        due_date,
        period_start_date,
        period_end_date,
        amount_due,
        amount_paid,
        status,
        tenant_name,
        tenant_email,
        tenant_phone,
    } = rentDue;

    const formattedDueDate = format(parseISO(due_date), 'PPP');
    const formattedPeriod = `${format(parseISO(period_start_date), 'MMM d')} - ${format(parseISO(period_end_date), 'MMM d, yyyy')}`;
    const formattedAmountDue = formatPrice(amount_due);
    const formattedAmountPaid = formatPrice(amount_paid);
    const amountRemaining = amount_due - amount_paid;
    const formattedAmountRemaining = formatPrice(amountRemaining);

    const getStatusInfo = (status: RentStatus): { text: string; color: string; Icon: React.ElementType } => {
        switch (status) {
            case 'PAID': return { text: 'Paid', color: 'green', Icon: IconCircleCheck };
            case 'PARTIALLY_PAID': return { text: 'Partially Paid', color: 'blue', Icon: IconProgress };
            case 'OVERDUE': return { text: 'Overdue', color: 'red', Icon: IconAlertTriangle };
            case 'DUE': return { text: 'Due', color: 'yellow', Icon: IconCalendarDue };
            case 'CANCELLED': return { text: 'Cancelled', color: 'gray', Icon: IconCircleCheck };
            default: return { text: status, color: 'gray', Icon: IconCalendarDue };
        }
    };

    const statusInfo = getStatusInfo(status);
    const tenantInfoAvailable = tenant_name || tenant_email || tenant_phone;

    return (
        <div className={`border-l-4 border-${statusInfo.color}-500 bg-white p-3 rounded-r-md shadow-sm my-2 border border-gray-200`}>
            {/* Tenant Info */}
            {tenantInfoAvailable && (
                <div className="mb-2 pb-2 border-b border-gray-100">
                    <h4 className="text-xs font-medium text-gray-500 mb-1 flex items-center gap-1"><IconUser size={14} /> Tenant Info</h4>
                    <div className="space-y-0.5 text-xs text-gray-700">
                        {tenant_name && <p>Name: {tenant_name}</p>}
                        {tenant_email && <p className='flex items-center gap-1'><IconMail size={12} /> <a href={`mailto:${tenant_email}`} className="text-gray-600 hover:underline">{tenant_email}</a></p>}
                        {tenant_phone && <p className='flex items-center gap-1'><IconPhone size={12} /> <a href={`tel:${tenant_phone}`} className="text-gray-600 hover:underline">+{tenant_phone}</a></p>}
                    </div>
                </div>
            )}

            {/* Due Details */}
            <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-2 mb-2">
                <div>
                    <div className="flex items-center gap-1.5 text-sm font-semibold text-gray-800">
                        <IconCalendarDue size={16} className="text-gray-500" />
                        <span>Due: {formattedDueDate}</span>
                    </div>
                    <div className="text-xs text-gray-600 mt-0.5">
                        Rent for period: {formattedPeriod}
                    </div>
                </div>
                <div className={`px-2 py-0.5 rounded-full text-xs font-medium border bg-${statusInfo.color}-100 text-${statusInfo.color}-700 border-${statusInfo.color}-200 inline-flex items-center gap-1`}>
                    <statusInfo.Icon size={14} />
                    {statusInfo.text}
                </div>
            </div>

            {/* Amount */}
            <div className="flex flex-col sm:flex-row justify-between items-baseline text-sm mt-2 pt-2 border-t border-gray-100">
                <div className="flex items-center gap-1.5 text-gray-700">
                    <IconCash size={16} className="text-gray-500" />
                    <span>Total Due:</span>
                    <span className="font-medium">{formattedAmountDue}</span>
                </div>
                {amount_paid >= 0 && status !== 'PAID' && (
                    <div className="text-xs text-gray-600 mt-1 sm:mt-0">
                        (Paid: {formattedAmountPaid} | Remaining: {formattedAmountRemaining})
                    </div>
                )}
                {status === 'PAID' && (
                    <div className="text-xs text-green-600 mt-1 sm:mt-0">
                        (Paid: {formattedAmountPaid})
                    </div>
                )}
            </div>
        </div>
    );
}

export default RentDueLandlordCard;