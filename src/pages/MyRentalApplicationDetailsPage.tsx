import React, { useState, useEffect, useCallback } from 'react';

import { Link, useParams } from 'react-router-dom';
import { format, parseISO } from 'date-fns';
import { IconAlertCircle, IconArrowLeft, IconCalendarEvent, IconUsers, IconFileText, IconUser, IconHome, IconInfoCircle } from '@tabler/icons-react';

import api from '../lib/supabaseClient';
import { MyRentalApplicationDetails, RentalApplicationStatus } from '../lib/types';
import { useAuth } from '../lib/AuthContext';
import { useNotification } from '../components/NotificationProvider';
import LoadingSpinner from '../components/LoadingSpinner';
import FullScreenLoader from '../components/FullScreenLoader';
import { getSecondaryButtonClasses, getStatusBadgeClasses, getPrimaryButtonClasses } from '../lib/twUtils';
import { rentalApplicationStatusMap, getDisplayValue, listingTypeMap } from '../lib/displayUtils';
import { formatPrice } from '../lib/formatUtils';

interface DetailItemProps {
    label: string;
    value: string | number | React.ReactNode | null | undefined;
    icon?: React.ElementType;
    className?: string;
    fullWidth?: boolean;
}
const DetailItem: React.FC<DetailItemProps> = ({ label, value, icon: Icon, className = "", fullWidth = false }) => {
    if (value === null || value === undefined || value === '') return null;
    return (
        <div className={`py-2 ${className} ${fullWidth ? 'sm:col-span-2' : ''}`}>
            <span className="text-xs text-gray-500 flex items-center">
                {Icon && <Icon size={14} className="mr-1.5 text-gray-400" />}
                {label}
            </span>
            <span className="text-sm font-medium text-gray-800 block mt-0.5">{value}</span>
        </div>
    );
};

function MyRentalApplicationDetailsPage() {
    const { applicationId } = useParams<{ applicationId: string }>();
    const [details, setDetails] = useState<MyRentalApplicationDetails | null>(null);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState<string | null>(null);
    const [isWithdrawing, setIsWithdrawing] = useState(false);

    const { user } = useAuth();
    const { showSuccessNotification, showErrorNotification } = useNotification();

    const fetchApplicationDetails = useCallback(async () => {
        if (!applicationId) {
            setError("Application ID is missing.");
            setLoading(false);
            return;
        }
        if (!user) return;

        setLoading(true); setError(null);
        try {
            const { data, error: fetchError } = await api.getMyRentalApplicationDetails(applicationId);
            if (fetchError) throw fetchError;
            if (!data) throw new Error("Application not found or access denied.");
            setDetails(data);
        } catch (err: any) {
            const message = typeof err === 'string' ? err : err.message || 'Failed to load application details.';
            setError(message);
            showErrorNotification('Load Failed', message);
            setDetails(null);
        } finally {
            setLoading(false);
        }
    }, [applicationId, user, showErrorNotification]);

    useEffect(() => {
        fetchApplicationDetails();
    }, [fetchApplicationDetails]);

    const handleWithdrawApplication = async () => {
        if (!applicationId || !details) return;
        if (!window.confirm("Are you sure you want to withdraw this application? This action cannot be undone.")) return;

        setIsWithdrawing(true);
        try {
            const { error: withdrawError } = await api.withdrawRentalApplication(applicationId);
            if (withdrawError) throw withdrawError;
            showSuccessNotification('Application Withdrawn', 'Your application has been successfully withdrawn.');
            fetchApplicationDetails();
        } catch (err: any) {
            showErrorNotification('Withdrawal Failed', typeof err === 'string' ? err : err.message || 'Could not withdraw application.');
        } finally {
            setIsWithdrawing(false);
        }
    };

    const companyName = import.meta.env.VITE_COMPANY_NAME;

    if (loading) return <FullScreenLoader message="Loading application details..." />;
    if (error) return (
        <div className="min-h-screen flex flex-col items-center justify-center text-center p-4">
            <title>Error | {companyName}</title>
            <IconAlertCircle size={48} className="text-red-500 mb-4" />
            <h1 className="text-xl font-semibold mb-2">Error Loading Application</h1>
            <p className="text-gray-600 mb-4">{error}</p>
            <Link to="/my-applications" className={getSecondaryButtonClasses()}>Back to My Applications</Link>
        </div>
    );
    if (!details) return (
        <div className="min-h-screen flex flex-col items-center justify-center text-center p-4">
            <title>Not Found | {companyName}</title>
            <IconAlertCircle size={48} className="text-gray-400 mb-4" />
            <h1 className="text-xl font-semibold mb-2">Application Not Found</h1>
            <Link to="/my-applications" className={getPrimaryButtonClasses()}>Back to My Applications</Link>
        </div>
    );

    const appData = details.application_data as { move_in_date: string; num_occupants: number; applicant_notes?: string };
    const statusDisplay = getDisplayValue(rentalApplicationStatusMap, details.application_status as RentalApplicationStatus);
    const canWithdraw = [
        'SUBMITTED', 'REVIEW_IN_PROGRESS', 'AWAITING_LANDLORD_CONTACT',
        'LANDLORD_INFO_PENDING', 'DOCUMENTS_REQUESTED'
    ].includes(details.application_status);
    const fallbackImageUrl = `https://placehold.co/600x400/e2e8f0/94a3b8?text=${encodeURIComponent(details.property_name || 'Property')}`;
    const displayAddress = `${details.property_address}, ${details.property_locality}, ${details.property_city}${details.property_pincode ? ` - ${details.property_pincode}` : ''}`;


    return (
        <div className="bg-gray-50 min-h-screen py-8">
            <title>Application #{details.application_id.substring(0, 8)}... | {companyName}</title>
            <div className="container mx-auto px-4 max-w-3xl">
                <Link to="/my-applications" className="text-sm text-gray-600 hover:underline mb-4 inline-flex items-center group">
                    <IconArrowLeft size={16} className="mr-1 group-hover:-translate-x-1 transition-transform" /> Back to My Applications
                </Link>

                {/* Header Section */}
                <div className="bg-white p-6 rounded-lg shadow border border-gray-200 mb-6">
                    <div className="flex flex-col sm:flex-row justify-between items-start gap-3 mb-3">
                        <div>
                            <h1 className="text-xl md:text-2xl font-bold text-gray-800">
                                Rental Application Details
                            </h1>
                            <p className="text-xs text-gray-500">ID: {details.application_id}</p>
                        </div>
                        <span className={`${getStatusBadgeClasses(details.application_status as any)} shadow-sm text-sm`}>{statusDisplay}</span>
                    </div>
                    <div className="grid grid-cols-1 md:grid-cols-2 gap-x-6 gap-y-1 text-sm border-t pt-3">
                        <DetailItem label="Submitted On" value={format(parseISO(details.submitted_at), 'PPP p')} icon={IconCalendarEvent} />
                        <DetailItem label="Last Status Update" value={format(parseISO(details.status_updated_at), 'PPP p')} icon={IconCalendarEvent} />
                    </div>
                </div>

                {/* Property Snapshot Section */}
                <div className="bg-white p-6 rounded-lg shadow border border-gray-200 mb-6">
                    <h2 className="text-lg font-semibold text-gray-700 mb-3 flex items-center gap-2"><IconHome size={18} /> Property Information</h2>
                    <div className="flex flex-col sm:flex-row gap-4 items-start">
                        <img
                            src={details.property_main_image_url || fallbackImageUrl}
                            alt={details.property_name}
                            className="w-full sm:w-40 h-32 object-cover rounded-md border"
                            onError={(e) => { e.currentTarget.src = fallbackImageUrl; }}
                            loading="lazy"
                        />
                        <div className="flex-grow">
                            <Link to={`/my-properties/${details.property_id}`} className="hover:underline">
                                <h3 className="text-md font-semibold text-gray-800">{details.property_name}</h3>
                            </Link>
                            <p className="text-xs text-gray-500" title={displayAddress}>{displayAddress}</p>
                            <div className="grid grid-cols-2 gap-x-4 mt-2 text-xs">
                                <DetailItem label="Type" value={`${getDisplayValue(listingTypeMap, details.property_listing_type)}`} />
                                <DetailItem label="Rent" value={formatPrice(details.property_price) + "/month"} />
                                {details.property_advance_amount > 0 && <DetailItem label="Advance" value={formatPrice(details.property_advance_amount)} />}
                            </div>
                        </div>
                    </div>
                </div>

                {/* Landlord Information Section */}
                <div className="bg-white p-6 rounded-lg shadow border border-gray-200 mb-6">
                    <h2 className="text-lg font-semibold text-gray-700 mb-3 flex items-center gap-2"><IconUser size={18} /> Landlord Information</h2>
                    <DetailItem label="Landlord Name" value={details.landlord_name || 'N/A'} />
                    {details.landlord_phone && <DetailItem label="Landlord Phone" value={`+${details.landlord_phone}`} />}
                    {details.landlord_email && <DetailItem label="Landlord Email" value={details.landlord_email} />}
                    {(!details.landlord_phone && !details.landlord_email) &&
                        <p className="text-xs text-gray-500 mt-2"><IconInfoCircle size={12} className="inline mr-0.5" /> Contact details may be shared by our team if your application progresses.</p>
                    }
                </div>

                {/* Your Application Details Section */}
                <div className="bg-white p-6 rounded-lg shadow border border-gray-200 mb-6">
                    <h2 className="text-lg font-semibold text-gray-700 mb-3 flex items-center gap-2"><IconFileText size={18} /> Your Application</h2>
                    <div className="grid grid-cols-1 sm:grid-cols-2 gap-x-6">
                        <DetailItem label="Proposed Move-in Date" value={format(parseISO(appData.move_in_date), 'PPP')} icon={IconCalendarEvent} />
                        <DetailItem label="Number of Occupants" value={appData.num_occupants} icon={IconUsers} />
                    </div>
                    {appData.applicant_notes && (
                        <DetailItem label="Your Notes/Message" value={<p className="whitespace-pre-wrap text-sm">{appData.applicant_notes}</p>} className="mt-2 pt-2 border-t" fullWidth />
                    )}
                </div>

                {/* Admin Notes for Customer (if any) */}
                {details.admin_notes_for_customer && (
                    <div className="bg-[#2C4964]/5 p-4 rounded-lg shadow-sm border border-[#2C4964]/20 mb-6">
                        <h2 className="text-md font-semibold text-[#2C4964] mb-2 flex items-center gap-1.5">
                            <IconInfoCircle size={16} /> Message from Our Team
                        </h2>
                        <p className="text-sm text-[#1E3347] whitespace-pre-wrap">{details.admin_notes_for_customer}</p>
                    </div>
                )}

                {/* Actions Section */}
                {canWithdraw && (
                    <div className="mt-6 text-center">
                        <button
                            onClick={handleWithdrawApplication}
                            disabled={isWithdrawing}
                            className={`${getSecondaryButtonClasses()} !border-red-500 !text-red-600 hover:!bg-red-50`}
                        >
                            {isWithdrawing ? <LoadingSpinner /> : 'Withdraw Application'}
                        </button>
                    </div>
                )}
            </div>
        </div>
    );
}

export default MyRentalApplicationDetailsPage;