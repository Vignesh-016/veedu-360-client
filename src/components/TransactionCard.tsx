import { MyTransactions } from '../lib/types';
import { format } from 'date-fns';
import { getStatusBadgeClasses } from '../lib/twUtils';
import { IconAlertCircle, IconCalendar, IconHelpCircle, IconReceipt, IconTag } from '@tabler/icons-react';
import { formatPrice } from '../lib/formatUtils';

interface TransactionCardProps {
    transaction: MyTransactions;
}

function TransactionCard({ transaction }: TransactionCardProps) {
    const {
        plan_name,
        amount,
        status,
        razorpay_order_id,
        razorpay_payment_id,
        error_message,
        created_at,
        updated_at // Use updated_at to show when it was paid/failed if different from created_at
    } = transaction;

    const displayDate = status === 'created' ? created_at : updated_at;
    const formattedDate = displayDate ? format(new Date(displayDate), 'PPP p') : 'N/A';
    const formattedAmount = formatPrice(amount);
    const statusText = status.charAt(0).toUpperCase() + status.slice(1);

    // Use a helper to display IDs conditionally
    const renderId = (label: string, id: string | null | undefined) => {
        if (!id) return null;
        return (
            <div className="flex items-center gap-1 text-xs text-gray-500">
                <IconReceipt size={14} />
                <span>{label}:</span>
                <span className="font-mono break-all" title={id}>{id.length > 15 ? `${id.substring(0, 15)}...` : id}</span>
            </div>
        );
    }

    return (
        <div className="bg-white p-4 rounded-lg shadow-sm border border-gray-200 flex flex-col sm:flex-row justify-between items-start gap-4">
            {/* Left Side: Plan Info & Date */}
            <div className="flex-grow">
                <div className="flex items-center gap-2 mb-1">
                    <IconTag size={18} className="text-gray-500" />
                    <h3 className="text-base font-semibold text-gray-800">{plan_name || 'Unknown Plan'}</h3>
                </div>
                <div className="flex items-center gap-1 text-xs text-gray-500 mb-3">
                    <IconCalendar size={14} />
                    <span>{formattedDate}</span>
                </div>
                {renderId('Order ID', razorpay_order_id)}
                {renderId('Payment ID', razorpay_payment_id)}
            </div>

            {/* Right Side: Amount & Status */}
            <div className="flex flex-col items-start sm:items-end flex-shrink-0 w-full sm:w-auto">
                <div className="text-lg font-bold text-gray-700 mb-1">{formattedAmount}</div>
                <div className="mb-2">
                    <span className={getStatusBadgeClasses(status) + ' shadow-sm'}>
                        {statusText}
                        {status === 'failed' && !error_message && <IconHelpCircle size={14} className="ml-1" title="No specific error message recorded." />}
                        {status === 'failed' && error_message && <IconAlertCircle size={14} className="ml-1" title={`Error: ${error_message}`} />}
                    </span>
                </div>
                {status === 'failed' && error_message && (
                    <p className="text-xs text-red-600 bg-red-50 p-1.5 rounded border border-red-100 max-w-xs text-right">
                        <IconAlertCircle size={14} className="inline mr-1" /> {error_message}
                    </p>
                )}
            </div>
        </div>
    );
}

export default TransactionCard;