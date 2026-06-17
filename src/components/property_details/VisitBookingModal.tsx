import React, { useState, Fragment, useEffect } from 'react';
import { Dialog, DialogPanel, DialogTitle, Transition, TransitionChild } from '@headlessui/react';
import { IconCalendarPlus, IconInfoCircle } from '@tabler/icons-react';
import { format } from 'date-fns';
import { getPrimaryButtonClasses, getSecondaryButtonClasses, getBaseInputClasses } from '../../lib/twUtils';
import LoadingSpinner from '../LoadingSpinner';

interface VisitBookingModalProps {
    isOpen: boolean;
    onClose: () => void;
    propertyName: string;
    onConfirmBooking: (selectedDate: string) => Promise<void>;
    isBookingLoading: boolean;
    minDate: string;
    maxDate: string;
    infoText?: string;
}

const VisitBookingModal: React.FC<VisitBookingModalProps> = ({
    isOpen,
    onClose,
    propertyName,
    onConfirmBooking,
    isBookingLoading,
    minDate,
    maxDate,
    infoText = "A visit request will use one visit credit. Check your wishlist for confirmation status."
}) => {
    const [selectedDateString, setSelectedDateString] = useState<string>('');

    const handleConfirm = async () => {
        if (!selectedDateString) return;
        await onConfirmBooking(selectedDateString);
    };

    useEffect(() => {
        if (!isOpen) {
            setSelectedDateString('');
        }
    }, [isOpen]);

    return (
        <Transition appear show={isOpen} as={Fragment}>
            <Dialog as="div" className="relative z-[60]" onClose={isBookingLoading ? () => { } : onClose}>
                <TransitionChild
                    as={Fragment}
                    enter="ease-out duration-300"
                    enterFrom="opacity-0"
                    enterTo="opacity-100"
                    leave="ease-in duration-200"
                    leaveFrom="opacity-100"
                    leaveTo="opacity-0"
                >
                    <div className="fixed inset-0 bg-black/40 backdrop-blur-sm" />
                </TransitionChild>
                <div className="fixed inset-0 overflow-y-auto">
                    <div className="flex min-h-full items-center justify-center p-4 text-center">
                        <TransitionChild
                            as={Fragment}
                            enter="ease-out duration-300"
                            enterFrom="opacity-0 scale-95"
                            enterTo="opacity-100 scale-100"
                            leave="ease-in duration-200"
                            leaveFrom="opacity-100 scale-100"
                            leaveTo="opacity-0 scale-95"
                        >
                            <DialogPanel className="w-full max-w-md transform overflow-hidden rounded-2xl bg-white p-6 text-left align-middle shadow-xl transition-all">
                                <DialogTitle as="h3" className="text-lg font-semibold leading-6 text-gray-900 mb-1">
                                    Request a Visit
                                </DialogTitle>
                                <p className="text-sm text-gray-500 mb-4 line-clamp-1" title={propertyName}>
                                    For: {propertyName}
                                </p>

                                <div className="mt-4 flex flex-col items-center gap-4">
                                    <label htmlFor="visitDateModal" className="text-sm font-medium text-gray-700 self-start flex items-center">
                                        <IconCalendarPlus size={16} className="mr-1.5 text-gray-500" stroke={1.5} />
                                        Select a date (within 3 weeks):
                                    </label>
                                    <input
                                        type="date"
                                        id="visitDateModal"
                                        value={selectedDateString}
                                        onChange={(e) => setSelectedDateString(e.target.value)}
                                        min={minDate}
                                        max={maxDate}
                                        className={`${getBaseInputClasses()} p-3`} // Ensure getBaseInputClasses is imported or defined
                                        disabled={isBookingLoading}
                                    />
                                    {selectedDateString && (
                                        <p className="mt-1 text-sm text-gray-700 bg-gray-50 px-4 py-2 rounded-lg w-full text-center">
                                            Selected: <span className="font-medium">{format(new Date(selectedDateString + 'T00:00:00'), 'PPP')}</span>
                                        </p>
                                    )}
                                    {infoText && (
                                        <div className="text-xs text-gray-500 mt-2 text-center p-3 bg-gray-50 rounded-lg w-full">
                                            <IconInfoCircle size={14} className="inline mr-1.5 text-gray-500" stroke={1.5} />
                                            {infoText}
                                        </div>
                                    )}
                                </div>
                                <div className="mt-6 flex justify-end gap-2">
                                    <button
                                        type="button"
                                        className={getSecondaryButtonClasses()}
                                        onClick={onClose}
                                        disabled={isBookingLoading}
                                    >
                                        Cancel
                                    </button>
                                    <button
                                        type="button"
                                        className={`${getPrimaryButtonClasses()} disabled:opacity-50`}
                                        onClick={handleConfirm}
                                        disabled={!selectedDateString || isBookingLoading}
                                    >
                                        {isBookingLoading ? <><LoadingSpinner /> Requesting...</> : 'Request Visit'}
                                    </button>
                                </div>
                            </DialogPanel>
                        </TransitionChild>
                    </div>
                </div>
            </Dialog>
        </Transition>
    );
};

export default VisitBookingModal;