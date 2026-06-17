import React, { useEffect, useState, useCallback } from 'react';
import { useParams, useNavigate, Link } from 'react-router-dom';

import {
    IconArrowLeft, IconAlertCircle, IconBuildingCommunity,
    IconHome2, IconMapPin2, IconFileDescription, IconListDetails, IconSparkles,
    IconMap, IconVideo, IconInfoCircle
} from '@tabler/icons-react';
import { format, startOfTomorrow, addWeeks } from 'date-fns';

import api from '../lib/supabaseClient';
import { Property, HouseDetailsSpecific, LandDetailsSpecific, BuildingDetailsSpecific } from '../lib/types';
import FullScreenLoader from '../components/FullScreenLoader';
import { useAuth } from '../lib/AuthContext';
import { useNotification } from '../components/NotificationProvider';
import { getPrimaryButtonClasses, getSecondaryButtonClasses } from '../lib/twUtils';
import { getDisplayValue, houseTypeMap, directionMap, waterSourceMap, powerBackupMap, proximityUnitMap, propertyTypeMap } from '../lib/displayUtils';
import { Json } from '../database.types';

import PropertyHeader from '../components/property_details/PropertyHeader';
import ImageGallery from '../components/property_details/ImageGallery';
import KeyFeatures from '../components/property_details/KeyFeatures';
import DetailSection from '../components/property_details/DetailSection';
import DetailListItem from '../components/property_details/DetailListItem';
import PropertyMapDisplay from '../components/property_details/PropertyMapDisplay';
import ActionCard from '../components/property_details/ActionCard';
import VisitBookingModal from '../components/property_details/VisitBookingModal';
import RentalApplicationModal from '../components/property_details/RentalApplicationModal';
import ShareSheetModal from '../components/ShareSheetModal';


const getVideoIdFromUrl = (url: string) => {
    const match = url.match(/(?:youtube\.com\/(?:[^\/]+\/.+\/|(?:v|e(?:mbed)?)\/|.*[?&]v=)|youtu\.be\/)([^"&?\/\s]{11})/);
    return match ? match[1] : null;
};

function PropertyDetailsPage() {
    const { propertyId } = useParams<{ propertyId: string }>();
    const navigate = useNavigate();
    const { user, balance, refetchBalance } = useAuth();
    const { showSuccessNotification, showErrorNotification, showInfoNotification } = useNotification();

    const [details, setDetails] = useState<Property | null>(null);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState<string | null>(null);
    const [isWishlisted, setIsWishlisted] = useState(false);
    const [wishlistLoading, setWishlistLoading] = useState(false);

    const [isVisitBookingModalOpen, setIsVisitBookingModalOpen] = useState(false);
    const [isRentalApplicationModalOpen, setIsRentalApplicationModalOpen] = useState(false);
    const [primaryActionLoading, setPrimaryActionLoading] = useState(false);
    const [isShareModalOpen, setIsShareModalOpen] = useState(false);

    const fetchDetails = useCallback(async () => {
        if (!propertyId) { setError("Property ID is missing."); setLoading(false); return; }
        setLoading(true); setError(null);
        try {
            const { data, error: fetchError } = await api.getPropertyFromId(propertyId);
            if (fetchError) throw fetchError;
            if (data && data.length > 0) {
                setDetails(data[0]);
                setIsWishlisted(data[0].is_in_wishlist);
            } else { setError("Property not found."); setDetails(null); }
        } catch (err: any) {
            setError(err.message || 'Failed to load property details.');
            showErrorNotification('Load Failed', err.message || 'Failed to load details.');
            setDetails(null);
        } finally { setLoading(false); }
    }, [propertyId, showErrorNotification]);

    useEffect(() => { fetchDetails(); }, [fetchDetails]);

    const handleWishlistToggle = async () => {
        if (!user) { showErrorNotification('Login Required', 'Please log in.'); navigate('/login', { state: { from: location.pathname } }); return; }
        if (!details || wishlistLoading || primaryActionLoading) return;
        setWishlistLoading(true);
        try {
            const { error: toggleError } = isWishlisted ? await api.removeFromWishlist(details.property_id) : await api.addToWishlist(details.property_id);
            if (toggleError) throw toggleError;
            setIsWishlisted(!isWishlisted);
            showSuccessNotification('Wishlist Updated', `${isWishlisted ? 'Removed from' : 'Added to'} wishlist.`);
        } catch (err: any) { showErrorNotification('Wishlist Error', typeof err === 'string' ? err : err.message || `Failed to update.`); }
        finally { setWishlistLoading(false); }
    };

    const handleOpenVisitModal = () => {
        if (!user) {
            showErrorNotification('Login Required', 'Please log in to book a visit.');
            navigate('/login', { state: { from: location.pathname } });
            return;
        }
        if (balance && balance.visit_balance > 0) {
            setIsVisitBookingModalOpen(true);
        } else if (balance && balance.visit_balance <= 0) {
            showErrorNotification('No Visits Left', 'Purchase a plan to book visits.');
            navigate('/plans');
        } else {
            showInfoNotification('Checking Balance', 'Please wait while we check your visit credits.');
        }
    };

    const handlePrimaryAction = () => {
        if (!user) {
            showErrorNotification('Login Required', 'Please log in to proceed.');
            navigate('/login', { state: { from: location.pathname } });
            return;
        }
        if (!details) return;

        if (details.listing_type === 'RENTAL' && details.interaction_status === 'VISIT_COMPLETED') {
            setIsRentalApplicationModalOpen(true);
        } else {
            handleOpenVisitModal();
        }
    };


    const confirmVisitBooking = async (selectedDate: string) => {
        if (primaryActionLoading || !details) return;
        setPrimaryActionLoading(true);
        try {
            const localDate = new Date(selectedDate + 'T00:00:00');
            if (isNaN(localDate.getTime())) throw new Error('Invalid date selected.');
            if (!isWishlisted) {
                const { error: addError } = await api.addToWishlist(details.property_id);
                if (addError) throw new Error(`Failed to add to wishlist before booking: ${typeof addError === 'string' ? addError : addError.message}`);
                setIsWishlisted(true);
            }
            const { error: visitError } = await api.requestVisit(details.property_id, localDate);
            if (visitError) throw visitError;
            showSuccessNotification('Visit Requested', `Requested for ${format(localDate, 'PPP')}.`);
            refetchBalance();
            setIsVisitBookingModalOpen(false);
            fetchDetails();
        } catch (err: any) { showErrorNotification('Booking Failed', typeof err === 'string' ? err : err.message || 'Could not request visit.'); }
        finally { setPrimaryActionLoading(false); }
    };

    const handleApplicationSubmitted = () => {
        setIsRentalApplicationModalOpen(false);
        fetchDetails();
    };


    const tomorrow = startOfTomorrow();
    const threeWeeksFromNow = addWeeks(tomorrow, 3);
    const minDateString = format(tomorrow, 'yyyy-MM-dd');
    const maxDateString = format(threeWeeksFromNow, 'yyyy-MM-dd');

    const renderSpecificDetailsList = () => {
        if (!details?.details || typeof details.details !== 'object') return <p className="text-gray-500 italic">No specific details available.</p>;
        const propertyDetails = details.details as Json;
        const detailEntries: React.ReactNode[] = [];

        const addListItem = (label: string, value: any) => {
            if (!(value === null || value === undefined || value === '' || (typeof value === 'boolean' && !value))) {
                detailEntries.push(<DetailListItem key={label} label={label} value={value} />);
            }
        };

        if (details.property_type === 'HOUSE') {
            const house = propertyDetails as HouseDetailsSpecific['details'];
            addListItem("Type", getDisplayValue(houseTypeMap, house.house_type));
            if (house.num_balconies) addListItem("Balconies", house.num_balconies);
            if (house.total_floors) addListItem("Total Floors (Building)", house.total_floors);
            if (house.floor_number) addListItem("Floor Number", house.floor_number);
            if (house.facing_direction) addListItem("Facing", getDisplayValue(directionMap, house.facing_direction));
            addListItem("Corner Plot", house.is_corner_plot);
            if (house.water_source) addListItem("Water Source", getDisplayValue(waterSourceMap, house.water_source));
            if (house.power_backup) addListItem("Power Backup", getDisplayValue(powerBackupMap, house.power_backup));
            if (house.house_type === 'APARTMENT_FLAT') addListItem("Lift Facility", house.lift_facility_available);
        } else if (details.property_type === 'LAND') {
            const land = propertyDetails as LandDetailsSpecific['details'];
            if (land.road_access_width_ft) addListItem("Road Access Width", `${land.road_access_width_ft} ft`);
            addListItem("Corner Plot", land.is_corner_plot);
        } else if (details.property_type === 'BUILDING') {
            const building = propertyDetails as BuildingDetailsSpecific['details'];
            if (building.num_units) addListItem("Total Units", building.num_units);
            if (building.available_units) addListItem("Available Units", building.available_units);
            if (building.common_amenities && (building.common_amenities as string[]).length > 0) addListItem("Common Amenities", (building.common_amenities as string[]).join(', '));
        }
        return detailEntries.length > 0 ? <>{detailEntries}</> : <p className="text-gray-500 italic">No further specific details.</p>;
    };

    const renderNearbyAmenitiesList = () => {
        if (!details) return null;
        const amenities = [
            { key: 'nearest_hospital', label: 'Hospital' }, { key: 'nearest_busstop', label: 'Bus Stop' },
            { key: 'nearest_school', label: 'School' }, { key: 'nearest_gym', label: 'Gym' },
            { key: 'nearest_park', label: 'Park' }, { key: 'nearest_swimmingpool', label: 'Pool' },
        ] as const;
        const availableAmenities = amenities.map(a => ({ label: a.label, distance: details[a.key] })).filter(a => a.distance !== null && a.distance !== undefined && a.distance > 0);
        if (availableAmenities.length === 0) return <p className="text-gray-500 italic">No proximity data.</p>;
        const unit = getDisplayValue(proximityUnitMap, details.proximity_unit, '');
        return <ul className="grid grid-cols-1 sm:grid-cols-2 gap-x-4 gap-y-2">{availableAmenities.map(a => <li key={a.label} className="flex items-center"><IconInfoCircle size={16} className="inline-block mr-1.5 text-gray-500 flex-shrink-0" />{a.label}: <span className="font-medium ml-1">{a.distance} {unit}</span></li>)}</ul>;
    };

    const companyName = import.meta.env.VITE_COMPANY_NAME;

    if (loading) return <FullScreenLoader message="Loading property details..." />;
    if (error) return (
        <div className="min-h-screen flex flex-col items-center justify-center text-center p-4">
            <title>Error | {companyName}</title>
            <IconAlertCircle size={48} className="text-red-500 mb-4" />
            <h1 className="text-2xl font-semibold text-gray-700 mb-2">Error Loading Property</h1>
            <p className="text-gray-600 mb-4">{error}</p>
            <button onClick={() => navigate(-1)} className={getSecondaryButtonClasses()}><IconArrowLeft size={16} className="mr-1" /> Go Back</button>
        </div>
    );
    if (!details) return (
        <div className="min-h-screen flex flex-col items-center justify-center text-center p-4">
            <title>Not Found | {companyName}</title>
            <IconAlertCircle size={48} className="text-gray-500 mb-4" />
            <h1 className="text-2xl font-semibold text-gray-700 mb-2">Property Not Found</h1>
            <Link to="/catalogue" className={getPrimaryButtonClasses()}>Back to Catalogue</Link>
        </div>
    );

    const displayName = details.property_name;
    let PropertyIconComponent: React.ElementType = IconHome2;
    if (details.property_type === 'HOUSE' && details.details && typeof details.details === 'object') {
        const houseDetails = details.details as HouseDetailsSpecific['details'];
        PropertyIconComponent = houseDetails.house_type === 'APARTMENT_FLAT' ? IconBuildingCommunity : IconHome2;
    } else if (details.property_type === 'LAND') PropertyIconComponent = IconMapPin2;
    else if (details.property_type === 'BUILDING') PropertyIconComponent = IconBuildingCommunity;

    const propertyTypeDisplay = getDisplayValue(propertyTypeMap, details.property_type, 'Property');

    return (
        <>
            <title>{displayName} | {companyName}</title>
            <meta name="description" content={details.description || `Details for property ${displayName}`} />
            <div className="bg-gray-50 min-h-screen py-8">
                <div className="container mx-auto px-4">
                    <button onClick={() => navigate(-1)} className="text-sm text-gray-800 hover:underline hover:text-[#D9A619] mb-4 inline-flex items-center group">
                        <IconArrowLeft size={16} className="mr-1 group-hover:-translate-x-1 transition-transform" /> Back to results
                    </button>
                    <div className="grid grid-cols-1 lg:grid-cols-3 gap-8 items-start">
                        <div className="lg:col-span-2 space-y-6">
                            <ImageGallery images={details.property_images} propertyName={displayName} />
                            <PropertyHeader details={details} displayName={displayName} PropertyIcon={PropertyIconComponent} />
                            <KeyFeatures details={details} />
                            {details.description && (
                                <DetailSection title="Description" icon={IconFileDescription} gridCols={1}>
                                    <p className="whitespace-pre-wrap leading-relaxed">{details.description}</p>
                                </DetailSection>
                            )}
                            <DetailSection title="Specifications" icon={IconListDetails} gridCols={2}>
                                {renderSpecificDetailsList()}
                            </DetailSection>
                            <DetailSection title="Nearby Amenities" icon={IconSparkles} gridCols={2}>
                                {renderNearbyAmenitiesList()}
                            </DetailSection>
                            {details.youtube_url && getVideoIdFromUrl(details.youtube_url) && (
                                <DetailSection title="Video Tour" icon={IconVideo} gridCols={1}>
                                    <div className="aspect-video"><iframe className="w-full h-full rounded-md" src={`https://www.youtube.com/embed/${getVideoIdFromUrl(details.youtube_url)}?autoplay=0&mute=0&rel=0`} title="Property Video" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture" allowFullScreen></iframe></div>
                                </DetailSection>
                            )}
                        </div>
                        <div className="lg:col-span-1 sticky top-24 space-y-6">
                            <ActionCard
                                details={details}
                                isWishlisted={isWishlisted}
                                onWishlistToggle={handleWishlistToggle}
                                onPrimaryAction={handlePrimaryAction}
                                onBookAnotherVisit={handleOpenVisitModal}
                                wishlistLoading={wishlistLoading}
                                primaryActionLoading={primaryActionLoading}
                                balance={balance}
                                onShare={() => setIsShareModalOpen(true)}
                            />
                            {details.latitude && details.longitude && (
                                <DetailSection title="Location on Map" icon={IconMap} gridCols={1}>
                                    <PropertyMapDisplay latitude={details.latitude} longitude={details.longitude} popupContent={displayName} />
                                </DetailSection>
                            )}
                        </div>
                    </div>
                </div>
            </div>

            <VisitBookingModal
                isOpen={isVisitBookingModalOpen}
                onClose={() => setIsVisitBookingModalOpen(false)}
                propertyName={displayName}
                onConfirmBooking={confirmVisitBooking}
                isBookingLoading={primaryActionLoading}
                minDate={minDateString}
                maxDate={maxDateString}
            />

            {details && details.interaction_id && details.listing_type === 'RENTAL' && (
                <RentalApplicationModal
                    isOpen={isRentalApplicationModalOpen}
                    onClose={() => setIsRentalApplicationModalOpen(false)}
                    propertyId={details.property_id}
                    interactionId={details.interaction_id}
                    propertyName={displayName}
                    onApplicationSubmitted={handleApplicationSubmitted}
                />
            )}

            {details && (
                <ShareSheetModal
                    isOpen={isShareModalOpen}
                    onClose={() => setIsShareModalOpen(false)}
                    propertyId={details.property_id}
                    propertyType={propertyTypeDisplay}
                    propertyName={displayName}
                />
            )}
        </>
    );
}

export default PropertyDetailsPage;