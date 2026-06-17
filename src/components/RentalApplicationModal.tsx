import React, { useState, FormEvent, useEffect } from 'react';
import { Dialog, DialogPanel, DialogTitle, Transition, TransitionChild } from '@headlessui/react';
import { IconX, IconInfoCircle, IconClipboardText, IconCalendarEvent, IconUsers } from '@tabler/icons-react';
import { format, addDays, parseISO } from 'date-fns';
import api from '../lib/supabaseClient';
import { RentalApplicationData } from '../lib/types';
import LoadingSpinner from './LoadingSpinner';
import { getPrimaryButtonClasses, getSecondaryButtonClasses, getBaseInputClasses } from '../lib/twUtils';
import { useNotification } from './NotificationProvider';

interface RentalApplicationModalProps {
    isOpen: boolean;
    onClose: () => void;
    propertyId: string;
    interactionId: string;
    propertyName: string;
    onApplicationSubmitted: () => void;
}

const RentalApplicationModal: React.FC<RentalApplicationModalProps> = ({
    isOpen, onClose, propertyId, interactionId, propertyName, onApplicationSubmitted
}) => {
    const today = new Date();
    const minMoveInDate = format(addDays(today, 1), 'yyyy-MM-dd');

    const [moveInDate, setMoveInDate] = useState('');
    const [numOccupants, setNumOccupants] = useState<number | ''>(1);
    const [applicantNotes, setApplicantNotes] = useState('');

    const [submitting, setSubmitting] = useState(false);
    const [error, setError] = useState<string | null>(null);
    const { showSuccessNotification, showErrorNotification } = useNotification();

    useEffect(() => {
        if (isOpen) {
            setMoveInDate('');
            setNumOccupants(1);
            setApplicantNotes('');
            setError(null);
        }
    }, [isOpen, propertyId]);


    const validateForm = (): boolean => {
        if (!moveInDate) {
            setError('Please select a proposed move-in date.');
            return false;
        }
        try {
            const selected = parseISO(moveInDate);
            if (selected < addDays(today, 0)) {
                setError('Move-in date cannot be in the past.');
                return false;
            }
        } catch {
            setError('Invalid move-in date format.');
            return false;
        }

        if (numOccupants === '' || Number(numOccupants) <= 0) {
            setError('Number of occupants must be a positive number.');
            return false;
        }
        if (applicantNotes.length > 300) {
            setError('Notes cannot exceed 300 characters.');
            return false;
        }
        setError(null);
        return true;
    };

    const handleSubmit = async (e: FormEvent) => {
        e.preventDefault();
        if (!validateForm()) return;

        setError(null);
        setSubmitting(true);

        const applicationData: RentalApplicationData = {
            move_in_date: moveInDate,
            num_occupants: Number(numOccupants),
            applicant_notes: applicantNotes.trim() || undefined,
        };

        try {
            const { data: newApplicationId, error: submissionError } = await api.submitRentalApplication({
                p_property_id: propertyId,
                p_interaction_id: interactionId,
                p_application_data: applicationData
            });

            if (submissionError || !newApplicationId) {
                throw new Error(typeof submissionError === 'string' ? submissionError : (submissionError?.message || 'Failed to submit application.'));
            }

            showSuccessNotification('Application Submitted!', `Your application for ${propertyName} has been sent.`);
            onApplicationSubmitted();
            onClose();
        } catch (err: any) {
            setError(err.message || 'An unexpected error occurred.');
            showErrorNotification('Submission Failed', err.message || 'Could not submit your application.');
        } finally {
            setSubmitting(false);
        }
    };

    return (
        <Transition appear show={isOpen} as={React.Fragment}>
            <Dialog as="div" className="relative z-[100]" onClose={submitting ? () => { } : onClose}>
                <TransitionChild as={React.Fragment} enter="ease-out duration-300" enterFrom="opacity-0" enterTo="opacity-100" leave="ease-in duration-200" leaveFrom="opacity-100" leaveTo="opacity-0">
                    <div className="fixed inset-0 bg-black/60 backdrop-blur-sm" />
                </TransitionChild>
                <div className="fixed inset-0 overflow-y-auto">
                    <div className="flex min-h-full items-center justify-center p-4 text-center">
                        <TransitionChild as={React.Fragment} enter="ease-out duration-300" enterFrom="opacity-0 scale-95" enterTo="opacity-100 scale-100" leave="ease-in duration-200" leaveFrom="opacity-100 scale-100" leaveTo="opacity-0 scale-95">
                            <DialogPanel className="w-full max-w-lg transform overflow-hidden rounded-2xl bg-white p-6 text-left align-middle shadow-xl transition-all">
                                <DialogTitle as="h3" className="text-xl font-semibold leading-6 text-gray-900 flex justify-between items-center">
                                    Rental Application
                                    <button onClick={onClose} disabled={submitting} className="text-gray-400 hover:text-gray-600 disabled:opacity-50"><IconX size={20} /></button>
                                </DialogTitle>
                                <p className="text-sm text-gray-500 mt-1 mb-4 truncate" title={propertyName}>For: {propertyName}</p>

                                {error && (
                                    <div className="my-3 p-3 bg-red-50 border border-red-200 rounded-md text-red-700 text-sm flex items-center gap-2">
                                        <IconInfoCircle className="h-5 w-5 flex-shrink-0" /> {error}
                                    </div>
                                )}

                                <form onSubmit={handleSubmit} className="space-y-4 mt-4">
                                    <div>
                                        <label htmlFor="moveInDate" className="text-sm font-medium text-gray-700 mb-1 flex items-center"><IconCalendarEvent size={16} className="mr-1.5 text-gray-400" />Proposed Move-in Date <span className="text-red-500 ml-1">*</span></label>
                                        <input type="date" id="moveInDate" value={moveInDate} onChange={(e) => setMoveInDate(e.target.value)}
                                            className={getBaseInputClasses(!moveInDate && !!error)} required min={minMoveInDate} disabled={submitting} />
                                    </div>
                                    <div>
                                        <label htmlFor="numOccupants" className="text-sm font-medium text-gray-700 mb-1 flex items-center"><IconUsers size={16} className="mr-1.5 text-gray-400" />Number of Occupants <span className="text-red-500 ml-1">*</span></label>
                                        <input type="number" id="numOccupants" value={numOccupants} onChange={(e) => setNumOccupants(e.target.value === '' ? '' : parseInt(e.target.value))}
                                            className={getBaseInputClasses((numOccupants === '' || (typeof numOccupants === 'number' && numOccupants <= 0)) && !!error)} required min="1" step="1" placeholder="e.g., 2" disabled={submitting} />
                                    </div>
                                    <div>
                                        <label htmlFor="applicantNotes" className="text-sm font-medium text-gray-700 mb-1 flex items-center"><IconClipboardText size={16} className="mr-1.5 text-gray-400" />Notes for Landlord/Agent (Optional)</label>
                                        <textarea id="applicantNotes" value={applicantNotes} onChange={(e) => setApplicantNotes(e.target.value)}
                                            className={`${getBaseInputClasses()} min-h-[80px]`} rows={3} maxLength={300} placeholder="Any specific requests or a brief introduction..." disabled={submitting} />
                                        <p className="text-xs text-gray-400 mt-1 text-right">{applicantNotes.length}/300</p>
                                    </div>
                                    <div className="text-xs text-gray-500 p-3 bg-gray-50 rounded-md border">
                                        <IconInfoCircle size={14} className="inline mr-1 text-gray-400" />
                                        Submitting this application indicates your strong interest. Our team will contact you for the next steps.
                                    </div>
                                    <div className="mt-6 flex justify-end gap-3 pt-4 border-t border-gray-100">
                                        <button type="button" className={getSecondaryButtonClasses()} onClick={onClose} disabled={submitting}>Cancel</button>
                                        <button type="submit" className={getPrimaryButtonClasses()} disabled={submitting || !moveInDate || numOccupants === '' || (typeof numOccupants === 'number' && numOccupants <= 0)}>
                                            {submitting ? <><LoadingSpinner size={16} /> Submitting...</> : 'Submit Application'}
                                        </button>
                                    </div>
                                </form>
                            </DialogPanel>
                        </TransitionChild>
                    </div>
                </div>
            </Dialog>
        </Transition>
    );
};

export default RentalApplicationModal;