import React, { useEffect, useState } from 'react';
import { useParams, useNavigate, Link } from 'react-router-dom';

import {
    IconMapPin, IconHome2, IconMapPin2, IconAlertCircle, IconArrowLeft,
    IconListDetails, IconFileDescription, IconMessageCircle, IconPhoto, IconEdit,
    IconMap, IconUsers, IconFileText,
    IconListCheck
} from '@tabler/icons-react';

import api from '../lib/supabaseClient';
import { MyProperties, HouseDetailsSpecific, LandDetailsSpecific, BuildingDetailsSpecific, DetailedPropertyImage } from '../lib/types';
import { useAuth } from '../lib/AuthContext';
import { useNotification } from '../components/NotificationProvider';
import { getPrimaryButtonClasses, getSecondaryButtonClasses } from '../lib/twUtils';
import { formatPrice } from '../lib/formatUtils';
import { areaUnitMap, getDisplayValue, houseTypeMap, furnishedStatusMap, directionMap, landTypeMap, buildingTypeMap, propertyAdminStatusMap, waterSourceMap, powerBackupMap, proximityUnitMap, availabilityStatusMap, submitterTypeMap, propertyTypeMap, listingTypeMap } from '../lib/displayUtils';
import PropertyMap from '../components/property_details/PropertyMapDisplay';
import FullScreenLoader from '../components/FullScreenLoader';
import PropertyImageManagementModal from '../components/PropertyImageManagementModal';
import { Json } from '../database.types';

// --- Detail Section Component ---
interface DetailSectionProps {
    title: string;
    icon: React.ElementType;
    children: React.ReactNode;
    className?: string;
    gridCols?: 1 | 2;
}

function DetailSection({ title, icon: Icon, children, className = "", gridCols = 2 }: DetailSectionProps) {
    const gridClass = gridCols === 1 ? 'grid-cols-1' : 'sm:grid-cols-2';
    return (
        <section className={`bg-white p-6 rounded-lg border border-gray-200 shadow-sm ${className}`}>
            <h2 className="text-xl font-semibold text-gray-800 mb-4 pb-3 border-b border-gray-100 flex items-center gap-2">
                <Icon size={22} className="text-gray-600" stroke={1.5} />
                {title}
            </h2>
            <div className={`grid ${gridClass} gap-x-6 gap-y-3 text-sm text-gray-700`}>
                {children}
            </div>
        </section>
    );
}

// --- Detail Item for Lists ---
function DetailListItem({ label, value, fullWidth = false }: { label: string, value: string | number | React.ReactNode | null | undefined, fullWidth?: boolean }) {
    if (value === null || value === undefined || value === '' || (typeof value === 'boolean' && !value)) return null;
    return (
        <div className={`py-1.5 ${fullWidth ? 'col-span-full' : ''}`}>
            <span className="text-gray-600 block text-xs">{label}:</span>
            <span className="font-medium text-gray-800 block mt-0.5">{typeof value === 'boolean' && value === true ? 'Yes' : value}</span>
        </div>
    );
}

// --- Image Display for Owner (includes internal) ---
function OwnerImageGallery({ images, propertyName }: { images: DetailedPropertyImage[], propertyName: string }) {
    if (!images || images.length === 0) {
        return <div className="text-center py-10 text-gray-500 border rounded-md bg-gray-50"><IconPhoto size={32} className="mx-auto text-gray-400 mb-2" stroke={1.5} /><p>No images uploaded yet.</p></div>;
    }
    const sortedImages = [...images].sort((a, b) => a.display_order - b.display_order);
    const fallbackImageUrl = `https://placehold.co/300x200/e2e8f0/94a3b8?text=${encodeURIComponent(propertyName)}`;

    return (
        <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 gap-3">
            {sortedImages.map((image, index) => (
                <div key={image.image_id || index} className="relative group aspect-[4/3] rounded-lg overflow-hidden shadow-sm border border-gray-200">
                    <img
                        src={image.image_url || fallbackImageUrl}
                        alt={image.description || `Image ${index + 1}`}
                        className="w-full h-full object-cover"
                        onError={(e) => { e.currentTarget.src = fallbackImageUrl; }}
                        loading="lazy"
                    />
                    <div className={`absolute top-1.5 left-1.5 px-1.5 py-0.5 rounded-sm text-[10px] font-semibold text-white ${image.is_internal_image ? 'bg-[#2C4964]' : 'bg-green-500'}`}>
                        {image.is_internal_image ? 'Internal' : 'Public'}
                    </div>
                    {image.description && <div className="absolute bottom-0 left-0 right-0 bg-black/60 text-white text-[10px] p-1 truncate" title={image.description}>{image.description}</div>}
                </div>
            ))}
        </div>
    );
}

function MyPropertyDetailsPage() {
    const { propertyId } = useParams<{ propertyId: string }>();
    const navigate = useNavigate();
    const { user } = useAuth();
    const { showErrorNotification } = useNotification();

    const [details, setDetails] = useState<MyProperties | null>(null);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState<string | null>(null);
    const [isImageModalOpen, setIsImageModalOpen] = useState(false);

    const fetchPropertyDetails = React.useCallback(async () => {
        if (!propertyId || !user) return;
        setLoading(true); setError(null);
        try {
            const { data, error: fetchError } = await api.getMyPropertyWithId(propertyId);
            if (fetchError) throw fetchError;
            if (data) {
                setDetails(data);
            } else {
                setError("Property not found or access denied.");
                setDetails(null);
            }
        } catch (err: any) {
            setError(err.message || 'Failed to load your property details.');
            showErrorNotification('Load Failed', err.message || 'Failed to load details.');
            setDetails(null);
        } finally {
            setLoading(false);
        }
    }, [propertyId, user, showErrorNotification]);

    useEffect(() => {
        fetchPropertyDetails();
    }, [fetchPropertyDetails]);


    const renderSpecificDetailsList = () => {
        if (!details?.details || typeof details.details !== 'object') return <p className="text-gray-500 italic">No specific details available.</p>;

        const propertyDetails = details.details as Json;
        const detailEntries: React.ReactNode[] = [];

        const addListItem = (label: string, value: any, fullWidth = false) => {
            // Add key prop here, using JSX syntax for DetailListItem
            if (!(value === null || value === undefined || value === '' || (typeof value === 'boolean' && !value))) {
                detailEntries.push(<DetailListItem key={label} label={label} value={value} fullWidth={fullWidth} />);
            }
        };

        if (details.property_type === 'HOUSE') {
            const house = propertyDetails as HouseDetailsSpecific['details'];
            addListItem("Type of House", getDisplayValue(houseTypeMap, house.house_type));
            if (house.num_bedrooms) addListItem("Bedrooms", house.num_bedrooms);
            if (house.num_bathrooms) addListItem("Bathrooms", house.num_bathrooms);
            if (house.num_balconies) addListItem("Balconies", house.num_balconies);
            if (house.total_floors) addListItem("Total Floors (Building)", house.total_floors);
            if (house.floor_number) addListItem("Floor Number", house.floor_number);
            if (house.num_carparking) addListItem("Car Parking Spaces", house.num_carparking);
            if (house.furnished_status) addListItem("Furnishing", getDisplayValue(furnishedStatusMap, house.furnished_status));
            if (house.facing_direction) addListItem("Facing Direction", getDisplayValue(directionMap, house.facing_direction));
            addListItem("Corner Plot/House", house.is_corner_plot);
            if (house.water_source) addListItem("Water Source", getDisplayValue(waterSourceMap, house.water_source));
            if (house.power_backup) addListItem("Power Backup", getDisplayValue(powerBackupMap, house.power_backup));
            if (house.house_type === 'APARTMENT_FLAT') {
                addListItem("Lift Facility Available", house.lift_facility_available);
            }
        } else if (details.property_type === 'LAND') {
            const land = propertyDetails as LandDetailsSpecific['details'];
            addListItem("Type of Land", getDisplayValue(landTypeMap, land.land_type));
            if (land.plot_dimensions) addListItem("Plot Dimensions", land.plot_dimensions);
            if (land.road_access_width_ft) addListItem("Road Access Width", `${land.road_access_width_ft} ft`);
            addListItem("Corner Plot", land.is_corner_plot);
        } else if (details.property_type === 'BUILDING') {
            const building = propertyDetails as BuildingDetailsSpecific['details'];
            addListItem("Type of Building", getDisplayValue(buildingTypeMap, building.building_type));
            if (building.total_floors) addListItem("Total Floors", building.total_floors);
            if (building.num_units) addListItem("Total Units", building.num_units);
            if (building.available_units) addListItem("Available Units", building.available_units);
            if (building.common_amenities && (building.common_amenities as string[]).length > 0) {
                addListItem("Common Amenities", (building.common_amenities as string[]).join(', '), true);
            }
        }
        return detailEntries.length > 0 ? <>{detailEntries}</> : <p className="text-gray-500 italic">No specific details provided.</p>;
    };

    const renderNearbyAmenitiesList = () => {
        if (!details) return null;
        const amenities = [
            { key: 'nearest_hospital', label: 'Hospital' }, { key: 'nearest_busstop', label: 'Bus Stop' },
            { key: 'nearest_school', label: 'School' }, { key: 'nearest_gym', label: 'Gym' },
            { key: 'nearest_park', label: 'Park' }, { key: 'nearest_swimmingpool', label: 'Pool' },
        ] as const;

        const availableAmenities = amenities
            .map(a => ({ label: a.label, distance: details[a.key] }))
            .filter(a => a.distance !== null && a.distance !== undefined && a.distance > 0);

        if (availableAmenities.length === 0) return <p className="text-gray-500 italic">No proximity data available.</p>;
        const unit = getDisplayValue(proximityUnitMap, details.proximity_unit, '');
        return (
            <>
                {availableAmenities.map(a => (
                    <DetailListItem key={a.label} label={a.label} value={`${a.distance} ${unit}`} />
                ))}
            </>
        );
    };

    const companyName = import.meta.env.VITE_COMPANY_NAME;

    if (loading) return <FullScreenLoader message="Loading your property details..." />;
    if (error) return (
        <div className="min-h-screen flex flex-col items-center justify-center text-center p-4">
            <title>Error | {companyName}</title>
            <IconAlertCircle size={48} className="text-red-500 mb-4" />
            <h1 className="text-2xl font-semibold text-gray-700 mb-2">Error Loading Property</h1>
            <p className="text-gray-600 mb-4">{error}</p>
            <button onClick={() => navigate('/my-properties')} className={getSecondaryButtonClasses()}>
                <IconArrowLeft size={16} className="mr-1" /> Back to My Properties
            </button>
        </div>
    );
    if (!details) return (
        <div className="min-h-screen flex flex-col items-center justify-center text-center p-4">
            <title>Not Found | {companyName}</title>
            <IconAlertCircle size={48} className="text-gray-500 mb-4" />
            <h1 className="text-2xl font-semibold text-gray-700 mb-2">Property Not Found</h1>
            <p className="text-gray-600 mb-4">This property might have been removed or you do not have access.</p>
            <Link to="/my-properties" className={getPrimaryButtonClasses()}>
                Back to My Properties
            </Link>
        </div>
    );

    const propertyDetailsJson = details.details as Json;
    const postTitle = (details.property_type === 'HOUSE' ? (propertyDetailsJson as any)?.house_name :
        details.property_type === 'LAND' ? (propertyDetailsJson as any)?.land_name :
            details.property_type === 'BUILDING' ? (propertyDetailsJson as any)?.building_name :
                details.locality) || details.locality;


    return (
        <>
            <title>My Property: {postTitle} | {companyName}</title>
            <div className="bg-gray-50 min-h-screen py-8">
                <div className="container mx-auto px-4">
                    <div className="mb-6 flex justify-between items-center">
                        <Link to="/my-properties" className="text-sm text-gray-800 hover:underline hover:text-[#D9A619] inline-flex items-center group">
                            <IconArrowLeft size={16} className="mr-1 group-hover:-translate-x-1 transition-transform" /> Back to My Properties
                        </Link>
                        <Link to={`/my-properties/edit/${details.property_id}`} className={`${getPrimaryButtonClasses()} !text-xs !px-3 !py-1.5`}>
                            <IconEdit size={14} className="mr-1.5" /> Edit Property Details
                        </Link>
                    </div>

                    <div className="bg-white p-6 rounded-lg border border-gray-200 shadow-sm mb-6">
                        <div className="flex flex-col md:flex-row justify-between md:items-center mb-3">
                            <h1 className="text-2xl md:text-3xl font-bold text-gray-900 mb-1 md:mb-0">{postTitle}</h1>
                            <span className={`px-3 py-1 rounded-full text-xs font-semibold
                                ${details.is_listed ? 'bg-green-100 text-green-700 border border-green-200' : 'bg-yellow-100 text-yellow-700 border border-yellow-200'}`}>
                                {details.is_listed ? 'Publicly Listed' : 'Not Publicly Listed'}
                            </span>
                        </div>
                        <div className="flex items-center text-sm text-gray-600 mb-1">
                            <IconMapPin size={16} className="mr-1.5 text-gray-400" />
                            {details.address}, {details.locality}, {details.city} - {details.pincode}
                        </div>
                        <div className="text-xs text-gray-500">
                            Admin Status: <span className="font-medium">{getDisplayValue(propertyAdminStatusMap, details.admin_status)}</span>
                        </div>
                        {details.admin_status === 'REJECTED' && (
                            <div className="mt-3 p-3 bg-red-50 border border-red-200 rounded-md text-sm text-red-700">
                                <p className="font-medium">Submission Rejected</p>
                                <p className="text-xs">Your property submission was rejected. Please review any feedback from our team (check admin notes or contact support) and edit your submission if necessary.</p>
                            </div>
                        )}
                        {details.admin_status === 'SUBMITTED' && (
                            <div className="mt-3 p-3 bg-[#2C4964]/5 border border-[#2C4964]/20 rounded-md text-sm text-[#2C4964]">
                                <p className="font-medium">Under Review</p>
                                <p className="text-xs">Your property submission is currently under review by our team. You can edit details until it moves to the next stage.</p>
                            </div>
                        )}
                    </div>


                    <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
                        <div className="lg:col-span-2 space-y-6">
                            <DetailSection title="Property Overview" icon={IconHome2} gridCols={2}>
                                <DetailListItem label="Property Type" value={getDisplayValue(propertyTypeMap, details.property_type)} />
                                <DetailListItem label="Listing For" value={getDisplayValue(listingTypeMap, details.listing_type)} />
                                <DetailListItem label="Price" value={formatPrice(details.price) + (details.listing_type === 'RENTAL' ? ' /month' : '')} />
                                {details.listing_type === 'RENTAL' && details.advance_amount && <DetailListItem label="Advance Amount" value={formatPrice(details.advance_amount)} />}
                                <DetailListItem label="Total Area" value={`${details.area} ${getDisplayValue(areaUnitMap, details.area_unit)}`} />
                                {details.year_built && <DetailListItem label="Year Built" value={details.year_built} />}
                                <DetailListItem label="Availability" value={getDisplayValue(availabilityStatusMap, details.availability_status)} />
                                <DetailListItem label="Submitted As" value={getDisplayValue(submitterTypeMap, details.submitter_type)} />
                            </DetailSection>

                            <DetailSection title="Detailed Specifications" icon={IconListDetails} gridCols={2}>
                                {renderSpecificDetailsList()}
                            </DetailSection>

                            <DetailSection title="Nearby Amenities" icon={IconMapPin2} gridCols={2}>
                                {renderNearbyAmenitiesList()}
                                {details.proximity_unit && <DetailListItem label="Proximity Unit" value={getDisplayValue(proximityUnitMap, details.proximity_unit)} fullWidth />}
                            </DetailSection>

                            {details.description && (
                                <DetailSection title="Description" icon={IconFileDescription} gridCols={1}>
                                    <p className="whitespace-pre-wrap leading-relaxed">{details.description}</p>
                                </DetailSection>
                            )}
                            {details.submitter_notes && (
                                <DetailSection title="Your Notes (Internal)" icon={IconMessageCircle} gridCols={1}>
                                    <p className="whitespace-pre-wrap leading-relaxed bg-yellow-50 p-3 rounded-md border border-yellow-200 text-yellow-800">{details.submitter_notes}</p>
                                </DetailSection>
                            )}
                        </div>

                        <div className="lg:col-span-1 space-y-6">
                            <DetailSection title="Images & Documents" icon={IconPhoto} gridCols={1}>
                                <OwnerImageGallery images={details.property_images} propertyName={postTitle} />
                                <button
                                    onClick={() => setIsImageModalOpen(true)}
                                    className={`${getSecondaryButtonClasses()} w-full mt-4 text-sm`}
                                >
                                    Manage Images & Docs
                                </button>
                            </DetailSection>

                            {details.latitude && details.longitude && (
                                <DetailSection title="Location on Map" icon={IconMap} gridCols={1}>
                                    <PropertyMap latitude={details.latitude} longitude={details.longitude} popupContent={postTitle} />
                                </DetailSection>
                            )}
                            <DetailSection title="Tenant Information" icon={IconUsers} gridCols={1}>
                                {details.tenant_info ? (
                                    <>
                                        <DetailListItem label="Tenant Name" value={details.tenant_info.name} />
                                        <DetailListItem label="Tenant Email" value={details.tenant_info.email} />
                                        <DetailListItem label="Tenant Phone" value={details.tenant_info.phone ? `+${details.tenant_info.phone}` : 'N/A'} />
                                    </>
                                ) : (
                                    <p className="text-gray-500 italic">No tenant currently assigned.</p>
                                )}
                            </DetailSection>
                            <DetailSection title="Management Plan" icon={IconFileText} gridCols={1}>
                                {details.management_plan_name ? (
                                    <DetailListItem label="Selected Plan" value={details.management_plan_name} />
                                ) : (
                                    <p className="text-gray-500 italic">No management plan selected.</p>
                                )}
                            </DetailSection>
                            <DetailSection title="Preferences" icon={IconListCheck} gridCols={1}>
                                <DetailListItem label="Exclusive Listing" value={details.is_exclusive ? "Yes" : "No"} />
                            </DetailSection>
                        </div>
                    </div>
                </div>
            </div>
            {details && propertyId && (
                <PropertyImageManagementModal
                    isOpen={isImageModalOpen}
                    onClose={() => setIsImageModalOpen(false)}
                    propertyId={propertyId}
                    initialImages={details.property_images || []}
                    onImagesUpdated={fetchPropertyDetails}
                />
            )}
        </>
    );
}

export default MyPropertyDetailsPage;