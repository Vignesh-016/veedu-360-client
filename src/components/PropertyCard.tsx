import React, { useState } from 'react';
import {
    IconBed, IconRuler, IconHeart, IconCalendarPlus, IconMapPin, IconShare,
    IconArrowRight, IconBuildingCommunity, IconCarGarage,
    IconCompass, IconHome2, IconMapPin2, IconBuildingWarehouse,
    IconArmchair, IconTag, IconBuildingSkyscraper, IconRoad, IconDimensions, IconBath,
    IconSparkles, IconClipboardCheck, IconExternalLink, IconRosetteDiscountCheck
} from '@tabler/icons-react';
import { useAuth } from '../lib/AuthContext';
import { Property, HouseDetailsSpecific, LandDetailsSpecific, BuildingDetailsSpecific } from '../lib/types';
import api from '../lib/supabaseClient';
import { getPrimaryButtonClasses, getSecondaryButtonClasses } from '../lib/twUtils';
import LoadingSpinner from './LoadingSpinner';
import { Link, useNavigate } from 'react-router-dom';
import { useNotification } from './NotificationProvider';
import { format, startOfTomorrow, addWeeks } from 'date-fns';
import { formatPrice } from '../lib/formatUtils';
import { areaUnitMap, getDisplayValue, houseTypeMap, furnishedStatusMap, directionMap, landTypeMap, buildingTypeMap, propertyTypeMap } from '../lib/displayUtils';
import { Json } from '../database.types';
import VisitBookingModal from './property_details/VisitBookingModal';
import RentalApplicationModal from './property_details/RentalApplicationModal';
import ShareSheetModal from './ShareSheetModal';

interface PropertyCardProps {
    property: Property;
    variant?: 'simple' | 'detailed';
    onInteractionUpdate?: () => void;
}

// --- Helper Function to Render Specific Details ---
const renderPropertySpecificDetails = (property: Property): React.ReactNode[] => {
    const details = property.details as Json | null;
    const nodes: React.ReactNode[] = [];
    const iconSize = 16;
    const iconClass = "mr-1.5 text-gray-500 flex-shrink-0";

    const addDetail = (key: string, icon: React.ElementType, label: string, value: string | number | boolean | undefined | null) => {
        if (value !== null && value !== undefined && value !== '') {
            let displayValue = String(value);
            if (typeof value === 'boolean') {
                displayValue = value ? 'Yes' : 'No';
            }
            nodes.push(
                <div key={key} className="flex items-center text-gray-700" title={label}>
                    {React.createElement(icon, { size: iconSize, className: iconClass, stroke: 1.5 })}
                    <span className="truncate">{displayValue}</span>
                </div>
            );
        }
    };

    if (property.property_type === 'HOUSE' && details && typeof details === 'object') {
        const houseDetails = details as HouseDetailsSpecific['details'];
        addDetail('house_type', IconHome2, 'Type', getDisplayValue(houseTypeMap, houseDetails.house_type));
        addDetail('bedrooms', IconBed, 'Beds', houseDetails.num_bedrooms ? `${houseDetails.num_bedrooms} bedroom${houseDetails.num_bedrooms > 1 ? 's' : ''}` : undefined);
        addDetail('bathrooms', IconBath, 'Baths', houseDetails.num_bathrooms ? `${houseDetails.num_bathrooms} bathroom${houseDetails.num_bathrooms > 1 ? 's' : ''}` : undefined);
        if (houseDetails.num_carparking && houseDetails.num_carparking > 0)
            addDetail('parking', IconCarGarage, 'Parking', `${houseDetails.num_carparking} parking${houseDetails.num_carparking > 1 ? 's' : ''}`);
        addDetail('furnishing', IconArmchair, 'Furnishing', getDisplayValue(furnishedStatusMap, houseDetails.furnished_status));
        if (houseDetails.facing_direction)
            addDetail('facing', IconCompass, 'Facing', getDisplayValue(directionMap, houseDetails.facing_direction) + ' facing');
    } else if (property.property_type === 'LAND' && details && typeof details === 'object') {
        const landDetails = details as LandDetailsSpecific['details'];
        addDetail('land_type', IconMapPin2, 'Type', getDisplayValue(landTypeMap, landDetails.land_type));
        addDetail('plot_dims', IconDimensions, 'Dimensions', landDetails.plot_dimensions);
        addDetail('road_width', IconRoad, 'Road Width', landDetails.road_access_width_ft ? `${landDetails.road_access_width_ft} ft` : null);
    } else if (property.property_type === 'BUILDING' && details && typeof details === 'object') {
        const buildingDetails = details as BuildingDetailsSpecific['details'];
        addDetail('building_type', IconBuildingSkyscraper, 'Type', getDisplayValue(buildingTypeMap, buildingDetails.building_type));
        addDetail('floors', IconBuildingWarehouse, 'Floors', buildingDetails.total_floors ? `${buildingDetails.total_floors} floor${buildingDetails.total_floors > 1 ? 's' : ''}` : undefined);
        addDetail('units', IconBuildingCommunity, 'Units', buildingDetails.num_units ? `${buildingDetails.num_units} unit${buildingDetails.num_units > 1 ? 's' : ''}` : undefined);
    }

    return nodes;
};


function PropertyCard({ property, variant = 'detailed', onInteractionUpdate }: PropertyCardProps) {
    const [wishlistLoading, setWishlistLoading] = useState(false);
    const [isWishlisted, setIsWishlisted] = useState(property.is_in_wishlist);
    const [bookingLoading, setBookingLoading] = useState(false);
    const [isVisitBookingModalOpen, setIsVisitBookingModalOpen] = useState(false);
    const [isRentalApplicationModalOpen, setIsRentalApplicationModalOpen] = useState(false);
    const [isShareModalOpen, setIsShareModalOpen] = useState(false);

    const { user, balance, refetchBalance } = useAuth();
    const navigate = useNavigate();
    const { showSuccessNotification, showErrorNotification, showInfoNotification } = useNotification();

    const {
        property_id, price, area, area_unit, locality, is_featured, listing_type, interaction_status, interaction_id
    } = property;
    let image_url = "";
    if (property.property_images && property.property_images.length > 0) {
        image_url = property.property_images[0].image_url;
    }

    let displayName = property.property_name;
    const priceFormatted = formatPrice(price);
    const areaFormatted = `${area} ${getDisplayValue(areaUnitMap, area_unit)}`;

    const handleWishlistToggle = async (event: React.MouseEvent) => {
        event.stopPropagation();
        if (wishlistLoading || bookingLoading) return;
        if (!user) { showErrorNotification('Login Required', 'Please log in to manage your wishlist.'); navigate('/login'); return; }
        setWishlistLoading(true);
        try {
            let error;
            if (isWishlisted) {
                ({ error } = await api.removeFromWishlist(property_id));
                if (!error) { setIsWishlisted(false); showSuccessNotification('Wishlist Updated', 'Removed from wishlist.'); onInteractionUpdate?.(); }
            } else {
                ({ error } = await api.addToWishlist(property_id));
                if (!error) { setIsWishlisted(true); showSuccessNotification('Wishlist Updated', 'Added to wishlist!'); onInteractionUpdate?.(); }
            }
            if (error) throw error;
        } catch (err: any) { showErrorNotification('Wishlist Error', err.message || `Failed to update wishlist.`); }
        finally { setWishlistLoading(false); }
    };

    const handleOpenVisitBookingModal = (event: React.MouseEvent) => {
        event.stopPropagation();
        if (!user) { showErrorNotification('Login Required', 'Please log in to book a visit.'); navigate('/login'); return; }
        if (balance === undefined || balance.visit_balance <= 0) { showErrorNotification('No Visits Left', 'Purchase a plan to book visits.'); navigate('/plans'); return; }
        setIsVisitBookingModalOpen(true);
    };

    const confirmVisitBooking = async (selectedDate: string) => {
        if (!selectedDate || bookingLoading) return;
        setBookingLoading(true);
        try {
            const localDate = new Date(selectedDate + 'T00:00:00');
            if (isNaN(localDate.getTime())) throw new Error('Invalid date selected.');
            if (!isWishlisted) {
                const { error: addError } = await api.addToWishlist(property_id);
                if (addError) throw new Error(`Failed to add to wishlist before booking: ${typeof addError === 'string' ? addError : addError.message}`);
                setIsWishlisted(true);
            }
            const { error: visitError } = await api.requestVisit(property_id, localDate);
            if (visitError) throw visitError;
            showSuccessNotification('Visit Requested', `Requested for ${format(localDate, 'PPP')}. Check your wishlist for status.`);
            refetchBalance();
            setIsVisitBookingModalOpen(false);
            onInteractionUpdate?.();
        } catch (err: any) { showErrorNotification('Booking Failed', typeof err === 'string' ? err : err.message || 'Could not request visit.'); }
        finally { setBookingLoading(false); }
    };

    const handleOpenRentalApplicationModal = (event: React.MouseEvent) => {
        event.stopPropagation();
        if (!user) { showErrorNotification('Login Required', 'Please log in to apply.'); navigate('/login'); return; }
        if (!interaction_id) {
            showErrorNotification('Error', 'Interaction ID missing. Cannot proceed with application.'); return;
        }
        setIsRentalApplicationModalOpen(true);
    };

    const handleApplicationSubmitted = () => {
        showInfoNotification("Application Submitted", "Your application has been submitted. You can track its status in 'My Applications'.");
        setIsRentalApplicationModalOpen(false);
        onInteractionUpdate?.();
    };


    const handleViewDetails = (event?: React.MouseEvent) => { event?.stopPropagation(); navigate(`/property/${property_id}`); };

    const fallbackImageUrl = `https://placehold.co/400x300/e2e8f0/94a3b8?text=${encodeURIComponent(locality)}`;
    const tomorrow = startOfTomorrow();
    const threeWeeksFromNow = addWeeks(tomorrow, 3);
    const minDateString = format(tomorrow, 'yyyy-MM-dd');
    const maxDateString = format(threeWeeksFromNow, 'yyyy-MM-dd');


    if (variant === 'simple') {
        renderPropertySpecificDetails(property); // Keeping call if it has side effects (unlikely) or just removing if pure. It seems pure.
        // Actually, renderPropertySpecificDetails is pure and returns nodes. Safe to remove call or ignore return.
        // specificDetailsNodes was unused.

        // Extract key details for tags
        let tags: string[] = [];
        if (property.property_type === 'HOUSE') {
            const details = property.details as any;
            if (details?.num_bedrooms) tags.push(`${details.num_bedrooms} Beds`);
            if (details?.furnished_status) tags.push(getDisplayValue(furnishedStatusMap, details.furnished_status));
            tags.push(getDisplayValue(propertyTypeMap, property.property_type));
        } else {
            tags.push(getDisplayValue(propertyTypeMap, property.property_type));
        }
        tags.push(areaFormatted);

        return (
            <div
                className="bg-white rounded-2xl overflow-hidden shadow-sm hover:shadow-xl border border-gray-100 transition-all duration-300 cursor-pointer group h-full flex flex-col relative"
                onClick={() => handleViewDetails()}
            >
                {/* Image Section */}
                <div className="relative h-44 overflow-hidden">
                    <img
                        src={image_url || fallbackImageUrl}
                        alt={displayName}
                        className="w-full h-full object-cover transition-transform duration-700 group-hover:scale-110"
                        loading="lazy"
                        onError={(e) => { e.currentTarget.src = fallbackImageUrl; }}
                    />

                    {/* Heart Icon (Top Right) */}
                    <button
                        className="absolute top-3 right-3 p-1.5 rounded-full bg-white/20 backdrop-blur-sm text-white hover:bg-white hover:text-red-500 transition-all duration-300 z-10"
                        onClick={handleWishlistToggle}
                        disabled={wishlistLoading || bookingLoading}
                    >
                        {wishlistLoading ? <div className="text-white"><LoadingSpinner size={18} /></div> :
                            <IconHeart size={18} fill={isWishlisted ? 'currentColor' : 'none'} className={isWishlisted ? 'text-red-500' : ''} />}
                    </button>

                    {/* Assured Badge (Overlapping) */}
                    <div className="absolute bottom-0 left-0">
                        <div className="bg-white py-1 px-3 rounded-tr-xl flex items-center gap-1.5 shadow-sm z-10">
                            <IconRosetteDiscountCheck size={16} className="text-green-600 fill-green-600/10" stroke={2.5} />
                            <span className="text-xs font-semibold text-gray-700">Veedu360 Assured</span>
                        </div>
                    </div>
                </div>

                {/* Content Section */}
                <div className="p-3.5 flex flex-col flex-grow">
                    {/* Title & Price */}
                    <div className="mb-3">
                        <h3 className="text-[17px] font-semibold text-[#2C4964] hover:text-[#D9A619] line-clamp-1 mb-1 leading-tight transition-colors" title={displayName}>
                            {displayName}
                        </h3>
                        <div className="flex items-baseline gap-1">
                            <span className="text-lg font-bold text-gray-900">{priceFormatted}</span>
                            {property.listing_type === 'RENTAL' && <span className="text-xs text-gray-500 font-medium">/month</span>}
                        </div>
                    </div>

                    {/* Tags / Pills */}
                    <div className="flex flex-wrap gap-2 mb-4">
                        {tags.slice(0, 3).map((tag, i) => (
                            <span key={i} className="px-2.5 py-1 bg-gray-50 rounded-md text-[11px] font-medium text-gray-600 transition-colors duration-300 hover:bg-[#2C4964] hover:text-white border border-gray-100">
                                {tag}
                            </span>
                        ))}
                    </div>

                    <div className="flex-grow" />

                    {/* Footer: Location */}
                    <div className="pt-2.5 border-t border-gray-100 flex items-center text-gray-500 text-xs mt-auto">
                        <IconMapPin size={14} className="mr-1.5 text-[#2C4964] transition-colors" />
                        <span className="truncate group-hover:text-gray-700 transition-colors">{locality}</span>
                    </div>
                </div>
            </div>
        );
    }

    // --- Detailed Variant ---
    const specificDetailsNodes = renderPropertySpecificDetails(property);
    let primaryActionElement: React.ReactNode;

    const applicationInProgress = interaction_status &&
        ['RENTAL_APPLICATION_SUBMITTED', 'REVIEW_IN_PROGRESS', 'AWAITING_LANDLORD_CONTACT', 'LANDLORD_INFO_PENDING', 'LANDLORD_APPROVED', 'DOCUMENTS_REQUESTED', 'DOCUMENTS_VERIFIED', 'APPROVED_AWAITING_PAYMENT', 'PAYMENT_CONFIRMED', 'LEASE_FINALIZED', 'TENANCY_ACTIVE'].includes(interaction_status);

    const isVisitInProgress = interaction_status &&
        ['VISIT_PENDING', 'VISIT_CONFIRMED_PENDING_SALES', 'VISIT_SCHEDULED_WITH_SALES'].includes(interaction_status);


    if (listing_type === 'RENTAL') {
        if (applicationInProgress) {
            primaryActionElement = (
                <Link
                    to="/my-applications"
                    onClick={(e) => e.stopPropagation()}
                    className={`${getPrimaryButtonClasses()} text-xs md:text-sm px-4 py-2 flex-1 sm:flex-none whitespace-nowrap flex items-center justify-center rounded-lg`}
                >
                    <IconExternalLink size={16} className='mr-1.5' stroke={1.5} /> View Application Status
                </Link>
            );
        } else if (interaction_status === 'VISIT_COMPLETED') {
            primaryActionElement = (
                <button
                    onClick={handleOpenRentalApplicationModal}
                    className={`${getPrimaryButtonClasses()} text-xs md:text-sm px-4 py-2 flex-1 sm:flex-none whitespace-nowrap flex items-center justify-center rounded-lg`}
                    disabled={bookingLoading || wishlistLoading}
                >
                    <IconClipboardCheck size={16} className='mr-1.5' stroke={1.5} /> Apply to Rent
                </button>
            );
        } else {
            if (balance && balance.visit_balance <= 0) {
                primaryActionElement = (
                    <Link
                        to="/plans"
                        className={`${getSecondaryButtonClasses()} text-xs md:text-sm px-4 py-2 !border-orange-500 !text-orange-600 hover:!bg-orange-50 flex-1 sm:flex-none whitespace-nowrap flex items-center justify-center rounded-lg`}
                        onClick={(e) => e.stopPropagation()}
                    >
                        <IconCalendarPlus size={16} className='mr-1.5' stroke={1.5} /> Buy Visits
                    </Link>
                );
            } else {
                primaryActionElement = (
                    <button
                        onClick={handleOpenVisitBookingModal}
                        className={`${getSecondaryButtonClasses()} text-xs md:text-sm px-4 py-2 flex-1 sm:flex-none whitespace-nowrap flex items-center justify-center rounded-lg`}
                        disabled={bookingLoading || wishlistLoading || isVisitInProgress}
                        title={isVisitInProgress ? "You already have a visit request in progress for this property." : "Book a property visit"}
                    >
                        <IconCalendarPlus size={16} className='mr-1.5' stroke={1.5} /> Book Visit
                        {balance && balance.visit_balance > 0 && !isVisitInProgress &&
                            <span className='ml-1 text-xs opacity-80'>({balance.visit_balance} left)</span>}
                    </button>
                );
            }
        }
    } else { // For SALE properties
        if (balance && balance.visit_balance <= 0) {
            primaryActionElement = (
                <Link
                    to="/plans"
                    className={`${getSecondaryButtonClasses()} text-xs md:text-sm px-4 py-2 !border-orange-500 !text-orange-600 hover:!bg-orange-50 flex-1 sm:flex-none whitespace-nowrap flex items-center justify-center rounded-lg`}
                    onClick={(e) => e.stopPropagation()}
                >
                    <IconCalendarPlus size={16} className='mr-1.5' stroke={1.5} /> Buy Visits
                </Link>
            );
        } else {
            primaryActionElement = (
                <button
                    onClick={handleOpenVisitBookingModal}
                    className={`${getSecondaryButtonClasses()} text-xs md:text-sm px-4 py-2 flex-1 sm:flex-none whitespace-nowrap flex items-center justify-center rounded-lg`}
                    disabled={bookingLoading || wishlistLoading || isVisitInProgress}
                    title={isVisitInProgress ? "You already have a visit request in progress for this property." : "Book a property visit"}
                >
                    <IconCalendarPlus size={16} className='mr-1.5' stroke={1.5} /> Book Visit
                    {balance && balance.visit_balance > 0 && !isVisitInProgress &&
                        <span className='ml-1 text-xs opacity-80'>({balance.visit_balance} left)</span>}
                </button>
            );
        }
    }

    const propertyTypeDisplay = getDisplayValue(propertyTypeMap, property.property_type, 'Property');


    return (
        <>
            <div className="bg-white rounded-xl overflow-hidden shadow-md border border-gray-100 flex flex-col sm:flex-row group transition-all duration-300 hover:shadow-lg hover:border-gray-200">
                <div className="w-full sm:w-1/3 md:w-2/5 lg:w-1/3 xl:w-2/5 flex-shrink-0 relative cursor-pointer overflow-hidden" onClick={() => handleViewDetails()}>
                    <img
                        src={image_url || fallbackImageUrl}
                        alt={displayName}
                        className="w-full h-56 sm:h-86 object-cover transition-transform duration-700 group-hover:scale-105"
                        loading="lazy"
                        onError={(e) => { e.currentTarget.src = fallbackImageUrl; }}
                    />
                    <div className="absolute top-3 left-3 flex flex-wrap gap-1.5">
                        <span className="bg-white/90 backdrop-blur-sm px-3 py-1 rounded-full text-xs font-medium text-gray-700 shadow-sm flex items-center gap-1.5">
                            <IconTag size={12} stroke={2} className={'text-[#D9A619]'} />
                            <span className={'text-gray-600'}>
                                {property.listing_type === 'RENTAL' ? 'For Rent' : 'For Sale'}
                            </span>
                        </span>
                        {is_featured && (
                            <span className="bg-gradient-to-r from-[#FFD700]/80 to-[#FFA500]/80 backdrop-blur-sm px-3 py-1 rounded-full text-xs font-bold text-gray-800 shadow-sm flex items-center gap-1.5" title="Featured Property">
                                <IconSparkles size={14} stroke={2} /> Featured
                            </span>
                        )}
                    </div>
                </div>

                <div className="p-5 md:p-6 flex flex-col justify-between flex-grow w-full sm:w-2/3 md:w-3/5 lg:w-2/3 xl:w-3/5">
                    <div>
                        <div className="flex justify-between items-start mb-2 gap-2">
                            <h3
                                className="text-base md:text-lg font-semibold text-gray-800 mr-2 line-clamp-2 cursor-pointer group-hover:text-gray-600 transition-colors leading-tight"
                                onClick={() => handleViewDetails()}
                                title={displayName}
                            >
                                {displayName}
                            </h3>
                            <div className="flex items-center gap-1 flex-shrink-0">
                                <button
                                    className="text-gray-400 hover:text-gray-600 p-1.5 rounded-full hover:bg-gray-100 transition-colors"
                                    onClick={(e) => { e.stopPropagation(); setIsShareModalOpen(true); }}
                                    title="Share Property"
                                >
                                    <IconShare size={18} stroke={1.5} /> <span className="sr-only">Share</span>
                                </button>
                                <button
                                    className={`p-1.5 rounded-full transition-all ${wishlistLoading || bookingLoading ? 'text-gray-400 cursor-not-allowed' : isWishlisted ? 'text-red-500 hover:bg-red-50' : 'text-gray-400 hover:text-red-500 hover:bg-red-50'}`}
                                    onClick={handleWishlistToggle}
                                    disabled={wishlistLoading || bookingLoading || !user}
                                    aria-label={isWishlisted ? "Remove from Wishlist" : "Add to Wishlist"}
                                    title={!user ? "Login to add to wishlist" : (isWishlisted ? "Remove from Wishlist" : "Add to Wishlist")} >
                                    {wishlistLoading ? <LoadingSpinner size={18} /> : <IconHeart size={18} fill={isWishlisted ? 'currentColor' : 'none'} stroke={1.5} className="transition-colors duration-300" />}
                                </button>
                            </div>
                        </div>
                        <div className="flex items-center text-xs md:text-sm text-gray-600 mb-3">
                            <IconMapPin size={16} className="mr-1.5 text-gray-400 flex-shrink-0" stroke={1.5} />
                            <span>{locality}</span>
                        </div>
                    </div>
                    <div className="mb-4">
                        <span className="text-lg md:text-xl font-bold text-gray-800">{priceFormatted}</span>
                        <span className="text-xs text-gray-500 ml-1">{property.listing_type === 'RENTAL' ? '/month' : ''}</span>
                    </div>
                    <div className="grid grid-cols-2 sm:grid-cols-3 gap-x-4 gap-y-3 text-xs md:text-sm text-gray-700 mb-4 py-4 border-y border-gray-100">
                        <div className="flex items-center" title="Area"><IconRuler size={16} className="mr-1.5 text-gray-500 flex-shrink-0" stroke={1.5} /><span className="font-medium">{areaFormatted}</span></div>
                        {specificDetailsNodes}
                    </div>
                    <div className="mt-auto pt-2">
                        <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-3">
                            <div className="flex items-center gap-2 w-full justify-end flex-wrap sm:flex-nowrap">
                                {primaryActionElement}
                                <button onClick={() => handleViewDetails()} className={`${getPrimaryButtonClasses()} text-xs md:text-sm px-4 py-2 flex-1 sm:flex-none whitespace-nowrap flex items-center justify-center rounded-lg`} >
                                    View Details <IconArrowRight size={14} className='ml-1.5' stroke={2} />
                                </button>
                            </div>
                        </div>
                    </div>
                </div>
            </div>

            <VisitBookingModal
                isOpen={isVisitBookingModalOpen}
                onClose={() => setIsVisitBookingModalOpen(false)}
                propertyName={displayName}
                onConfirmBooking={confirmVisitBooking}
                isBookingLoading={bookingLoading}
                minDate={minDateString}
                maxDate={maxDateString}
            />

            {interaction_id && listing_type === 'RENTAL' && (
                <RentalApplicationModal
                    isOpen={isRentalApplicationModalOpen}
                    onClose={() => setIsRentalApplicationModalOpen(false)}
                    propertyId={property_id}
                    interactionId={interaction_id}
                    propertyName={displayName}
                    onApplicationSubmitted={handleApplicationSubmitted}
                />
            )}

            <ShareSheetModal
                isOpen={isShareModalOpen}
                onClose={() => setIsShareModalOpen(false)}
                propertyId={property.property_id}
                propertyType={propertyTypeDisplay}
                propertyName={property.property_name}
            />
        </>
    );
}

export default PropertyCard;