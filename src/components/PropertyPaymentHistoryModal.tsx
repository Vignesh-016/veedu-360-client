import { useState, useEffect, Fragment } from 'react';
import { Dialog, Transition, TransitionChild, DialogPanel, DialogTitle } from '@headlessui/react';
import { IconX, IconAlertCircle, IconReceipt2, IconBuilding } from '@tabler/icons-react';
import { format, parseISO } from 'date-fns';
import api from '../lib/supabaseClient';
import { PropertyPaymentHistory } from '../lib/types';
import LoadingSpinner from './LoadingSpinner';
import { getTertiaryButtonClasses } from '../lib/twUtils';
import { formatPrice } from '../lib/formatUtils';

interface PropertyPaymentHistoryModalProps {
    isOpen: boolean;
    onClose: () => void;
    propertyId: string;
    propertyAddress: string;
}

function PropertyPaymentHistoryModal({ isOpen, onClose, propertyId, propertyAddress }: PropertyPaymentHistoryModalProps) {
    const [payments, setPayments] = useState<PropertyPaymentHistory[]>([]);
    const [loading, setLoading] = useState(false);
    const [error, setError] = useState<string | null>(null);

    useEffect(() => {
        if (isOpen && propertyId) {
            setLoading(true);
            setError(null);
            api.getPropertyPaymentHistory(propertyId)
                .then(({ data, error: fetchError }) => {
                    if (fetchError) {
                        setError(typeof fetchError === 'string' ? fetchError : fetchError.message || 'Failed to load payment history.');
                        setPayments([]);
                    } else {
                        setPayments(data || []);
                    }
                })
                .catch((err) => {
                    setError(err.message || 'An unexpected error occurred.');
                    setPayments([]);
                })
                .finally(() => {
                    setLoading(false);
                });
        } else {
            // Reset state when modal is closed or propertyId is missing
            setPayments([]);
            setLoading(false);
            setError(null);
        }
    }, [isOpen, propertyId]);

    // --- Render Logic ---
    const renderContent = () => {
        if (loading) {
            return <div className="flex justify-center items-center h-40"><LoadingSpinner /></div>;
        }

        if (error) {
            return (
                <div className="bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded-lg text-center flex flex-col items-center gap-2 shadow-sm">
                    <IconAlertCircle size={24} /> Error loading history: {error}
                </div>
            );
        }

        if (payments.length === 0) {
            return <p className="text-gray-500 text-center italic py-6">No payment history found for this property.</p>;
        }

        // Table display
        return (
            <div className="mt-4 max-h-[60vh] overflow-y-auto custom-scrollbar pr-2">
                <table className="min-w-full divide-y divide-gray-200 text-sm">
                    <thead className="bg-gray-50 sticky top-0">
                        <tr>
                            <th scope="col" className="px-4 py-2 text-left font-medium text-gray-500 tracking-wider">Payment Date</th>
                            <th scope="col" className="px-4 py-2 text-left font-medium text-gray-500 tracking-wider">Amount Paid</th>
                            <th scope="col" className="px-4 py-2 text-left font-medium text-gray-500 tracking-wider">Tenant</th>
                            <th scope="col" className="px-4 py-2 text-left font-medium text-gray-500 tracking-wider">For Period</th>
                            <th scope="col" className="px-4 py-2 text-left font-medium text-gray-500 tracking-wider">Method</th>
                        </tr>
                    </thead>
                    <tbody className="bg-white divide-y divide-gray-200">
                        {payments.map((payment) => (
                            <tr key={payment.payment_id}>
                                <td className="px-4 py-3 whitespace-nowrap">{format(parseISO(payment.payment_date), 'MMM d, yyyy, p')}</td>
                                <td className="px-4 py-3 whitespace-nowrap font-medium">{formatPrice(payment.amount_paid)}</td>
                                <td className="px-4 py-3 whitespace-nowrap">
                                    <div className="flex flex-col">
                                        <span>{payment.tenant_name || payment.tenant_email || 'Unknown Tenant'}</span>
                                        {payment.tenant_phone && <span className="text-xs text-gray-500">{"+" + payment.tenant_phone}</span>}
                                    </div>
                                </td>
                                <td className="px-4 py-3 whitespace-nowrap">{format(parseISO(payment.rent_period_start_date), 'MMM d')} - {format(parseISO(payment.rent_period_end_date), 'd, yyyy')}</td>
                                <td className="px-4 py-3 whitespace-nowrap">{payment.payment_method || 'N/A'}</td>
                            </tr>
                        ))}
                    </tbody>
                </table>
            </div>
        );
    }


    return (
        <Transition appear show={isOpen} as={Fragment}>
            <Dialog as="div" className="relative z-50" onClose={onClose}>
                {/* Overlay */}
                <TransitionChild as={Fragment} enter="ease-out duration-300" enterFrom="opacity-0" enterTo="opacity-100" leave="ease-in duration-200" leaveFrom="opacity-100" leaveTo="opacity-0">
                    <div className="fixed inset-0 bg-black/40 backdrop-blur-sm" />
                </TransitionChild>

                {/* Modal Content */}
                <div className="fixed inset-0 overflow-y-auto">
                    <div className="flex min-h-full items-center justify-center p-4 text-center">
                        <TransitionChild as={Fragment} enter="ease-out duration-300" enterFrom="opacity-0 scale-95" enterTo="opacity-100 scale-100" leave="ease-in duration-200" leaveFrom="opacity-100 scale-100" leaveTo="opacity-0 scale-95">
                            <DialogPanel className="w-full max-w-4xl transform overflow-hidden rounded-2xl bg-white p-6 text-left align-middle shadow-xl transition-all">
                                {/* Title and Close Button */}
                                <DialogTitle as="h3" className="text-lg font-semibold leading-6 text-gray-900 flex justify-between items-center">
                                    <div className='flex items-center gap-2'>
                                        <IconReceipt2 /> Payment History
                                    </div>
                                    <button onClick={onClose} className="text-gray-400 hover:text-gray-600"><IconX size={20} /></button>
                                </DialogTitle>
                                {/* Property Address Subtitle */}
                                <p className="text-sm text-gray-500 mt-1 mb-4">
                                    <IconBuilding size={14} className='inline mr-1' /> For property: {propertyAddress} ({propertyId.substring(0, 8)}...)
                                </p>

                                {/* Main Content Area */}
                                {renderContent()}

                                {/* Close Button */}
                                <div className="mt-5 text-right">
                                    <button type="button" className={getTertiaryButtonClasses()} onClick={onClose}> Close </button>
                                </div>
                            </DialogPanel>
                        </TransitionChild>
                    </div>
                </div>
            </Dialog>
        </Transition>
    );
}

export default PropertyPaymentHistoryModal;