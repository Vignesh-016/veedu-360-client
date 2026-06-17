import React, { useState } from 'react';
import {
    IconTrash, IconCalendarTime, IconHome2, IconMapPin2,
    IconBuildingCommunity, IconAlertCircle, IconX, IconBuilding, IconMapPin,
    IconClipboardCheck, IconExternalLink, IconUser, IconPhoneCall, IconMail
} from '@tabler/icons-react';
import { WishlistItem, InteractionStatus } from '../lib/types';
import { format, parseISO, startOfTomorrow, addWeeks, isPast, isToday } from 'date-fns';
import api from '../lib/supabaseClient';
import { getListingTypeBadgeClasses, getStatusBadgeClasses, getBaseCardClasses, getPrimaryButtonClasses, getSecondaryButtonClasses } from '../lib/twUtils';
import { useNotification } from './NotificationProvider';
import { useNavigate, Link } from 'react-router-dom';
import { formatPrice } from '../lib/formatUtils';
import { useAuth } from '../lib/AuthContext';
import { getDisplayValue, interactionStatusMap, propertyTypeMap } from '../lib/displayUtils';
import VisitBookingModal from './property_details/VisitBookingModal';
import RentalApplicationModal from './property_details/RentalApplicationModal';

interface WishlistItemCardProps {
    item: WishlistItem;
    onRemove: (propertyId: string) => void;
    onItemUpdate?: (updatedItem: WishlistItem) => void;
}

const formatDate = (dateString: string | null): string | null => {
    if (!dateString) return null;
    try { return format(parseISO(dateString), 'EEE, MMM d, yyyy'); } catch { return 'Invalid Date'; }
};

function WishlistItemCard({ item, onRemove, onItemUpdate }: WishlistItemCardProps) {
    const {
        property_id, property_type, listing_type, property_name, price, interaction_status, property_main_image_url,
        scheduled_for, visited_at, locality, city, interaction_id,
        assigned_sales_admin_name, assigned_sales_admin_email, assigned_sales_admin_phone
    } = item;

    const [isVisitBookingModalOpen, setIsVisitBookingModalOpen] = useState(false);
    const [isRentalApplicationModalOpen, setIsRentalApplicationModalOpen] = useState(false);
    const [actionLoading, setActionLoading] = useState(false);

    const { showSuccessNotification, showErrorNotification, showInfoNotification } = useNotification();
    const navigate = useNavigate();
    const { balance, refetchBalance, user } = useAuth();

    const tomorrow = startOfTomorrow();
    const threeWeeksFromNow = addWeeks(tomorrow, 3);
    const minDateString = format(tomorrow, 'yyyy-MM-dd');
    const maxDateString = format(threeWeeksFromNow, 'yyyy-MM-dd');

    const confirmVisitBooking = async (selectedDate: string) => {
        if (actionLoading || !property_id) return;
        if (balance === undefined || balance.visit_balance <= 0) {
            showErrorNotification('No Visits Left', 'Purchase a plan to book visits.');
            navigate('/plans');
            setIsVisitBookingModalOpen(false);
            return;
        }
        setActionLoading(true);
        try {
            const localDate = new Date(selectedDate + 'T00:00:00');
            if (isNaN(localDate.getTime())) throw new Error('Invalid date selected.');

            const { error } = await api.requestVisit(property_id, localDate);
            if (error) throw error;

            showSuccessNotification('Visit Requested', `Requested for ${format(localDate, 'PPP')}. Status updated.`);
            onItemUpdate?.({ ...item, interaction_status: 'VISIT_PENDING', scheduled_for: format(localDate, 'yyyy-MM-dd') });
            refetchBalance();
            setIsVisitBookingModalOpen(false);
        } catch (err: any) {
            showErrorNotification('Booking Failed', err.message || 'Failed to request visit.');
        } finally {
            setActionLoading(false);
        }
    };

    const handleApplicationSubmitted = () => {
        showInfoNotification("Application Submitted", "Your application details will update shortly.");
        setIsRentalApplicationModalOpen(false);
        if (onItemUpdate) {
            onItemUpdate({ ...item, interaction_status: 'RENTAL_APPLICATION_SUBMITTED' as InteractionStatus });
        } else {
            navigate('/my-applications', { replace: true });
        }
    };


    const handleMainCardClick = () => navigate(`/property/${property_id}`);
    const handleActionClick = (e: React.MouseEvent, action: () => void) => { e.stopPropagation(); action(); };

    // const handleBookVisitClick = (e: React.MouseEvent) => {
    //     e.stopPropagation();
    //     if (!user) { showErrorNotification('Login Required', 'Please log in.'); navigate('/login'); return; }
    //     if (balance === undefined || balance.visit_balance <= 0) {
    //         showInfoNotification('No Visits Left', 'Please purchase a plan to book more visits.');
    //         navigate('/plans');
    //         return;
    //     }
    //     setIsVisitBookingModalOpen(true);
    // };

    const handleApplyToRentClick = (e: React.MouseEvent) => {
        e.stopPropagation();
        if (!user) { showErrorNotification('Login Required', 'Please log in.'); navigate('/login'); return; }
        if (!interaction_id) {
            showErrorNotification('Error', 'Interaction ID missing. Cannot proceed with application.'); return;
        }
        setIsRentalApplicationModalOpen(true);
    };


    const PropertyIcon = property_type === 'LAND' ? IconMapPin2 : property_type === 'BUILDING' ? IconBuildingCommunity : IconHome2;
    const fallbackImageUrl = `https://placehold.co/300x200/e2e8f0/94a3b8?text=${encodeURIComponent(locality?.substring(0, 15) || 'Property')}`;
    const priceFormatted = formatPrice(price);
    const statusDisplay = getDisplayValue(interactionStatusMap, interaction_status, 'Unknown Status');
    const isScheduledDatePast = scheduled_for ? isPast(parseISO(scheduled_for)) && interaction_status !== 'VISIT_COMPLETED' && !isToday(parseISO(scheduled_for)) : false;
    const hasAgentDetails = !!assigned_sales_admin_name || !!assigned_sales_admin_phone || !!assigned_sales_admin_email;
    const displayTitle = property_name || locality || 'Unnamed Property';

    const renderActionButtons = () => {
        switch (interaction_status) {
            case 'WISHLISTED':
                return (
                    <>
                        <button
                            className={`${getSecondaryButtonClasses()} !border-red-500 !text-red-600 hover:!bg-red-50 w-full sm:w-auto text-sm px-3`}
                            onClick={(e) => handleActionClick(e, () => onRemove(property_id))}
                            aria-label="Remove from wishlist"
                            disabled={actionLoading}
                        >
                            <IconTrash size={16} /><span className="sr-only sm:not-sr-only sm:ml-1">Remove</span>
                        </button>
                    </>
                );
            case 'VISIT_COMPLETED':
                return (
                    <>
                        {listing_type === 'RENTAL' && (
                            <button
                                className={`${getPrimaryButtonClasses()} w-full sm:w-auto text-sm`}
                                onClick={handleApplyToRentClick}
                                disabled={actionLoading}
                            >
                                <IconClipboardCheck size={16} className="mr-1.5" /> Apply to Rent
                            </button>
                        )}
                        {listing_type !== 'RENTAL' && (
                            <button
                                onClick={handleMainCardClick}
                                className={`${getSecondaryButtonClasses()} w-full sm:w-auto text-sm px-4 py-1.5`}
                            >
                                View Details <IconExternalLink size={14} className='ml-1.5' stroke={1.5} />
                            </button>
                        )}
                    </>
                );
            case 'RENTAL_APPLICATION_SUBMITTED':
                return (
                    <Link
                        to={`/my-applications`}
                        onClick={(e) => e.stopPropagation()}
                        className={`${getPrimaryButtonClasses()} w-full sm:w-auto text-sm`}
                    >
                        View Application Status <IconExternalLink size={14} className='ml-1.5' stroke={1.5} />
                    </Link>
                );
            case 'LEASE_CONVERTED':
                return (
                    <button
                        onClick={handleMainCardClick}
                        className={`${getPrimaryButtonClasses()} w-full sm:w-auto text-sm !bg-green-600 hover:!bg-green-700`}
                    >
                        View Tenancy Details <IconExternalLink size={14} className='ml-1.5' stroke={1.5} />
                    </button>
                );
            default:
                return (
                    <button
                        onClick={handleMainCardClick}
                        className={`${getPrimaryButtonClasses()} w-full sm:w-auto text-sm px-4 py-1.5`}
                    >
                        View Details <IconExternalLink size={14} className='ml-1.5' stroke={1.5} />
                    </button>
                );
        }
    };

    return (
        <>
            <div
                className={`${getBaseCardClasses()} hover:shadow-lg transition-all duration-300 cursor-pointer flex flex-col w-full overflow-hidden relative group`}
                onClick={handleMainCardClick}
                aria-label={`Property ${displayTitle} - ${statusDisplay}`}
                role="link" tabIndex={0} onKeyDown={(e) => e.key === 'Enter' && handleMainCardClick()}
            >
                {/* Image and Header part remains the same */}
                <div className="relative w-full h-48 flex-shrink-0">
                    <img src={property_main_image_url || fallbackImageUrl} alt={`Property: ${displayTitle}`} className="w-full h-full object-cover" loading="lazy" onError={(e) => { e.currentTarget.src = fallbackImageUrl; }} />
                    <div className="absolute top-2 left-2">
                        <span className={`${getStatusBadgeClasses(interaction_status)} shadow-sm`}>
                            <span className="mr-1">{statusDisplay}</span>
                            {isScheduledDatePast && interaction_status === 'VISIT_PENDING' && (<IconAlertCircle size={14} className="text-orange-500" title="Scheduled date is in the past" />)}
                        </span>
                    </div>
                </div>
                <div className="p-4 flex flex-col justify-between flex-grow">
                    <div>
                        <div className="flex flex-col sm:flex-row justify-between items-start mb-2 gap-1">
                            <span className={getListingTypeBadgeClasses(listing_type?.toLowerCase() as any)}>
                                <PropertyIcon size={16} />{property_type ? `(${getDisplayValue(propertyTypeMap, property_type)})` : ''} {listing_type === 'RENTAL' ? 'Rental' : 'For Sale'}
                            </span>
                            <span className="text-lg font-bold text-black mt-1 sm:mt-0">{priceFormatted} {listing_type === 'RENTAL' && <span className="text-xs font-normal text-gray-500">/month</span>}</span>
                        </div>
                        <h2 className="text-lg font-semibold text-gray-800 mb-1 line-clamp-1 group-hover:text-gray-600 transition-colors" title={displayTitle}>{displayTitle}</h2>
                        <p className="text-xs text-gray-500 mb-3 flex items-center gap-1"><IconMapPin size={14} className="text-gray-400" /> {locality}{city ? `, ${city}` : ''}</p>
                        {hasAgentDetails && (
                            <div className="mb-3 pt-2 border-t border-gray-100">
                                <h3 className="text-xs font-medium text-gray-500 mb-1.5 flex items-center gap-1"><IconBuilding size={14} /> Agent Info</h3>
                                <div className="space-y-1 text-xs text-gray-700">
                                    {assigned_sales_admin_name && (<p className="flex items-center gap-1.5"><IconUser size={14} className="text-gray-400 flex-shrink-0" /><span>{assigned_sales_admin_name}</span></p>)}
                                    {assigned_sales_admin_phone && (<p className="flex items-center gap-1.5"><IconPhoneCall size={14} className="text-gray-400 flex-shrink-0" /><span><a href={`tel:${assigned_sales_admin_phone}`} onClick={(e) => e.stopPropagation()} className="hover:underline">{assigned_sales_admin_phone}</a></span></p>)}
                                    {assigned_sales_admin_email && (<p className="flex items-center gap-1.5"><IconMail size={14} className="text-gray-400 flex-shrink-0" /><span><a href={`mailto:${assigned_sales_admin_email}`} onClick={(e) => e.stopPropagation()} className="hover:underline">{assigned_sales_admin_email}</a></span></p>)}
                                </div>
                            </div>
                        )}
                    </div>
                    <div className="mb-3 space-y-1.5 text-sm">
                        {(interaction_status === "VISIT_PENDING" || interaction_status === "VISIT_SCHEDULED_WITH_SALES" || interaction_status === "VISIT_CONFIRMED_PENDING_SALES") && scheduled_for && (
                            <p className={`flex items-center gap-1.5 text-gray-700`}><IconCalendarTime size={16} className={`flex-shrink-0 ${isScheduledDatePast ? 'text-orange-500' : 'text-gray-500'}`} /><span>Scheduled: <span className="font-semibold">{formatDate(scheduled_for)}</span> {isScheduledDatePast && <span className="text-xs text-orange-600">(Past)</span>}</span></p>
                        )}
                        {interaction_status === "VISIT_COMPLETED" && visited_at && (<p className="flex items-center gap-1.5 text-gray-700"><IconCalendarTime size={16} className="flex-shrink-0" /><span>Visited: <span className="font-semibold">{formatDate(visited_at)}</span></span></p>)}
                        {interaction_status === 'VISIT_CANCELLED' && (<p className="flex items-center gap-1.5 text-gray-600"><IconX size={16} className="flex-shrink-0" /><span>Visit Cancelled</span></p>)}
                    </div>
                    <div className="flex flex-col sm:flex-row gap-2 items-stretch sm:items-center justify-end mt-auto pt-2 border-t border-gray-100">
                        {renderActionButtons()}
                    </div>
                </div>
            </div>

            <VisitBookingModal
                isOpen={isVisitBookingModalOpen}
                onClose={() => setIsVisitBookingModalOpen(false)}
                propertyName={displayTitle}
                onConfirmBooking={confirmVisitBooking}
                isBookingLoading={actionLoading}
                minDate={minDateString}
                maxDate={maxDateString}
            />

            {/* Rental Application Modal */}
            {item && interaction_id && listing_type === 'RENTAL' && (
                <RentalApplicationModal
                    isOpen={isRentalApplicationModalOpen}
                    onClose={() => setIsRentalApplicationModalOpen(false)}
                    propertyId={property_id}
                    interactionId={interaction_id}
                    propertyName={displayTitle}
                    onApplicationSubmitted={handleApplicationSubmitted}
                />
            )}
        </>
    );
}

export default WishlistItemCard;