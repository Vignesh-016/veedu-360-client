import React from 'react';
import { Link } from 'react-router-dom';
import { format, parseISO } from 'date-fns';
import { IconBuilding, IconCalendar, IconChevronRight, IconUser } from '@tabler/icons-react';
import { MyRentalApplication, RentalApplicationStatus } from '../lib/types';
import { getBaseCardClasses, getPrimaryButtonClasses, getSecondaryButtonClasses, getStatusBadgeClasses } from '../lib/twUtils';
import { rentalApplicationStatusMap, getDisplayValue } from '../lib/displayUtils';
import LoadingSpinner from './LoadingSpinner';

interface ApplicationCardProps {
    application: MyRentalApplication;
    onWithdraw: (applicationId: string) => Promise<void>;
    isWithdrawingThis: boolean;
}

const ApplicationCard: React.FC<ApplicationCardProps> = ({ application, onWithdraw, isWithdrawingThis }) => {
    const {
        application_id,
        property_name,
        property_address,
        property_locality,
        property_city,
        property_main_image_url,
        landlord_name,
        application_status,
        submitted_at,
        status_updated_at
    } = application;

    const fallbackImageUrl = `https://placehold.co/300x200/e2e8f0/94a3b8?text=${encodeURIComponent(property_name || 'Property')}`;
    const statusDisplay = getDisplayValue(rentalApplicationStatusMap, application_status as RentalApplicationStatus); // Cast if necessary

    // Determine if the "Withdraw" button should be shown
    const canWithdraw = [
        'SUBMITTED', 'REVIEW_IN_PROGRESS', 'AWAITING_LANDLORD_CONTACT',
        'LANDLORD_INFO_PENDING', 'DOCUMENTS_REQUESTED'
    ].includes(application_status);

    const displayAddress = `${property_address}, ${property_locality}, ${property_city}`;

    return (
        <div className={`${getBaseCardClasses()} flex flex-col md:flex-row gap-4 group`}>
            <div className="w-full md:w-40 h-40 flex-shrink-0 relative">
                <img
                    src={property_main_image_url || fallbackImageUrl}
                    alt={property_name || 'Property'}
                    className="w-full h-full object-cover rounded-md border border-gray-100"
                    onError={(e) => { e.currentTarget.src = fallbackImageUrl; }}
                    loading="lazy"
                />
            </div>
            <div className="flex-grow flex flex-col justify-between">
                <div>
                    <div className="flex justify-between items-start mb-1">
                        <Link to={`/my-applications/${application_id}`} className="hover:underline">
                            <h3 className="text-base font-semibold text-gray-800 group-hover:text-gray-600 line-clamp-1" title={property_name || displayAddress}>
                                {property_name || displayAddress}
                            </h3>
                        </Link>
                        <span className={`${getStatusBadgeClasses(application_status as any)} shadow-sm text-xs`}>{statusDisplay}</span>
                    </div>
                    <p className="text-xs text-gray-500 mb-2 flex items-center gap-1">
                        <IconBuilding size={12} /> {displayAddress}
                    </p>
                    {landlord_name && (
                        <p className="text-xs text-gray-500 mb-1 flex items-center gap-1">
                            <IconUser size={12} /> Landlord: {landlord_name}
                        </p>
                    )}
                    <p className="text-xs text-gray-500 mb-1 flex items-center gap-1">
                        <IconCalendar size={12} /> Submitted: {format(parseISO(submitted_at), 'PPP')}
                    </p>
                    <p className="text-xs text-gray-500 mb-3 flex items-center gap-1">
                        <IconCalendar size={12} /> Last Update: {format(parseISO(status_updated_at), 'PPP p')}
                    </p>
                </div>
                <div className="mt-auto pt-3 border-t border-gray-100 flex flex-col sm:flex-row gap-2 items-stretch sm:items-center justify-end">
                    {canWithdraw && (
                        <button
                            onClick={() => onWithdraw(application_id)}
                            disabled={isWithdrawingThis}
                            className={`${getSecondaryButtonClasses()} !border-red-500 !text-red-600 hover:!bg-red-50 text-xs !px-3 !py-1.5 w-full sm:w-auto`}
                        >
                            {isWithdrawingThis ? <LoadingSpinner size={14} /> : 'Withdraw Application'}
                        </button>
                    )}
                    <Link to={`/my-applications/${application_id}`} className={`${getPrimaryButtonClasses()} text-xs !px-3 !py-1.5 text-center w-full sm:w-auto`}>
                        View Details <IconChevronRight size={14} className="ml-1 inline-block" />
                    </Link>
                </div>
            </div>
        </div>
    );
};

export default ApplicationCard;