import { useState, FormEvent, useEffect } from 'react';

import { useParams, useNavigate, Link } from 'react-router-dom';
import {
    AreaUnit, ListingType, PropertyType, SubmitterType,
    AvailabilityStatus, HouseType, BuildingType, LandType,
    Direction, WaterSource, PowerBackup, ProximityUnit,
    ManagementPlan, UpdatePropertyPayload, MyProperties,
    FurnishedStatus
} from '../lib/types';
import { LatLngTuple } from 'leaflet';
import api from '../lib/supabaseClient';
import {
    IconInfoCircle, IconMap, IconUser,
    IconCoins, IconDimensions, IconBuildingWarehouse, IconListCheck,
    IconAlertCircle, IconArrowLeft, IconPencil, IconHome2, IconMapPin2, IconBuildingCommunity, IconFileDescription
} from '@tabler/icons-react';
import { getPrimaryButtonClasses, getSecondaryButtonClasses } from '../lib/twUtils';
import { useNotification } from '../components/NotificationProvider';
import LoadingSpinner from '../components/LoadingSpinner';
import FullScreenLoader from '../components/FullScreenLoader';
import { DEFAULT_CITY } from '../lib/geoUtils';
import { Json } from '../database.types';

import SectionWrapper from '../components/property_form_parts/SectionWrapper';
import PropertyTypeListingSection from '../components/property_form_parts/PropertyTypeListingSection';
import PropertyTitleDescriptionSection from '../components/property_form_parts/PropertyTitleDescriptionSection';
import LocationDetailsSection from '../components/property_form_parts/LocationDetailsSection';
import HouseFeaturesSection from '../components/property_form_parts/HouseFeaturesSection';
import LandFeaturesSection from '../components/property_form_parts/LandFeaturesSection';
import BuildingFeaturesSection from '../components/property_form_parts/BuildingFeaturesSection';
import AreaDimensionsSection from '../components/property_form_parts/AreaDimensionsSection';
import AdditionalPropertyInfoSection from '../components/property_form_parts/AdditionalPropertyInfoSection';
import NearbyAmenitiesSection from '../components/property_form_parts/NearbyAmenitiesSection';
import PricingAvailabilitySection from '../components/property_form_parts/PricingAvailabilitySection';
import ManagementPlanSelectorSection from '../components/property_form_parts/ManagementPlanSelectorSection';
import TermsAndPreferencesSection from '../components/property_form_parts/TermsAndPreferencesSection';


const initialFormStructure = {
    submitter_type: 'OWNER' as SubmitterType,
    listing_type: 'SALE' as ListingType,
    property_type: 'HOUSE' as PropertyType,
    house_name: '',
    land_name: '',
    building_name: '',
    description: '',
    city: DEFAULT_CITY,
    locality: '',
    address: '',
    pincode: undefined as number | undefined,
    youtube_url: '',
    latitude: undefined as number | undefined,
    longitude: undefined as number | undefined,
    house_type: null as HouseType | null,
    num_bedrooms: null as number | null,
    num_bathrooms: null as number | null,
    num_balconies: null as number | null,
    total_floors_house: null as number | null,
    floor_number: null as number | null,
    num_carparking: null as number | null,
    furnished_status: null as FurnishedStatus | null,
    facing_direction: null as Direction | null,
    is_corner_plot: false,
    water_source: null as WaterSource | null,
    power_backup: null as PowerBackup | null,
    lift_facility_available: false,
    land_type: null as LandType | null,
    plot_dimensions: '',
    road_access_width_ft: null as number | null,
    building_type: null as BuildingType | null,
    total_floors_building: null as number | null,
    num_units: null as number | null,
    available_units: null as number | null,
    common_amenities: '',
    area: null as number | null,
    area_unit: 'SQ_FT' as AreaUnit,
    availability_status: 'READY_TO_MOVE' as AvailabilityStatus,
    price: null as number | null,
    advance_amount: undefined as number | undefined,
    year_built: undefined as number | undefined,
    nearest_hospital: undefined as number | undefined,
    nearest_busstop: undefined as number | undefined,
    nearest_gym: undefined as number | undefined,
    nearest_park: undefined as number | undefined,
    nearest_school: undefined as number | undefined,
    nearest_swimmingpool: undefined as number | undefined,
    proximity_unit: 'KM' as ProximityUnit,
    inventory_details: {} as Json,
    notes: '',
    management_plan_id: undefined as string | undefined,
    can_reachout: true,
    is_exclusive: false,
    agree_terms: true,
};

type FormDataState = typeof initialFormStructure;
type FormErrorKeys = keyof FormDataState | 'details';
type FormErrors = Partial<Record<FormErrorKeys, string>>;


function EditPropertyPage() {
    const { propertyId } = useParams<{ propertyId: string }>();
    const navigate = useNavigate();
    const { showSuccessNotification, showErrorNotification } = useNotification();

    const [formData, setFormData] = useState<FormDataState>(initialFormStructure);
    const [originalProperty, setOriginalProperty] = useState<MyProperties | null>(null);
    const [loading, setLoading] = useState(true);
    const [isSubmitting, setIsSubmitting] = useState(false);
    const [pageError, setPageError] = useState<string | null>(null);
    const [formErrors, setFormErrors] = useState<FormErrors>({});
    const [managementPlans, setManagementPlans] = useState<ManagementPlan[]>([]);
    const [initialMapCenter, setInitialMapCenter] = useState<LatLngTuple>([8.7139, 77.7567]);

    useEffect(() => {
        const fetchData = async () => {
            if (!propertyId) {
                showErrorNotification("Error", "Property ID is missing.");
                navigate("/my-properties");
                return;
            }
            setLoading(true);
            setPageError(null);

            try {
                const propertyResultPromise = api.getMyPropertyWithId(propertyId);
                const plansResultPromise = api.getManagementPlans(); // Fetch plans for dropdown

                const [propertyRes, plansRes] = await Promise.all([propertyResultPromise, plansResultPromise]);

                if (propertyRes.error || !propertyRes.data) {
                    throw new Error(typeof propertyRes.error === 'string' ? propertyRes.error : "Failed to load property data or property not found.");
                }
                const foundProperty = propertyRes.data;
                setOriginalProperty(foundProperty);

                const propertyType = foundProperty.property_type;
                const details = foundProperty.details as Json;

                let amenitiesString = '';
                if (propertyType === 'BUILDING' && details && typeof details === 'object' && Array.isArray((details as any).common_amenities)) {
                    amenitiesString = ((details as any).common_amenities as string[]).join(', ');
                }

                setFormData({
                    submitter_type: foundProperty.submitter_type || 'OWNER',
                    listing_type: foundProperty.listing_type,
                    property_type: foundProperty.property_type,
                    house_name: propertyType === 'HOUSE' && details ? (details as any).house_name || '' : '',
                    land_name: propertyType === 'LAND' && details ? (details as any).land_name || '' : '',
                    building_name: propertyType === 'BUILDING' && details ? (details as any).building_name || '' : '',
                    description: foundProperty.description || '',
                    city: foundProperty.city || DEFAULT_CITY,
                    locality: foundProperty.locality || '',
                    address: foundProperty.address || '',
                    pincode: foundProperty.pincode ?? undefined,
                    youtube_url: foundProperty.youtube_url || '',
                    latitude: foundProperty.latitude ?? undefined,
                    longitude: foundProperty.longitude ?? undefined,

                    house_type: propertyType === 'HOUSE' && details ? (details as any).house_type : null,
                    num_bedrooms: propertyType === 'HOUSE' && details ? (details as any).num_bedrooms : null,
                    num_bathrooms: propertyType === 'HOUSE' && details ? (details as any).num_bathrooms : null,
                    num_balconies: propertyType === 'HOUSE' && details ? (details as any).num_balconies : null,
                    total_floors_house: propertyType === 'HOUSE' && details ? (details as any).total_floors : null,
                    floor_number: propertyType === 'HOUSE' && details ? (details as any).floor_number : null,
                    num_carparking: propertyType === 'HOUSE' && details ? (details as any).num_carparking : null,
                    furnished_status: propertyType === 'HOUSE' && details ? (details as any).furnished_status : null,
                    facing_direction: propertyType === 'HOUSE' && details ? (details as any).facing_direction : null,
                    is_corner_plot: !!(details && (details as any).is_corner_plot),
                    water_source: propertyType === 'HOUSE' && details ? (details as any).water_source : null,
                    power_backup: propertyType === 'HOUSE' && details ? (details as any).power_backup : null,
                    lift_facility_available: propertyType === 'HOUSE' && details && (details as any).house_type === 'APARTMENT_FLAT' ? !!(details as any).lift_facility_available : false,

                    land_type: propertyType === 'LAND' && details ? (details as any).land_type : null,
                    plot_dimensions: propertyType === 'LAND' && details ? (details as any).plot_dimensions || '' : '',
                    road_access_width_ft: propertyType === 'LAND' && details ? (details as any).road_access_width_ft : null,

                    building_type: propertyType === 'BUILDING' && details ? (details as any).building_type : null,
                    total_floors_building: propertyType === 'BUILDING' && details ? (details as any).total_floors : null,
                    num_units: propertyType === 'BUILDING' && details ? (details as any).num_units : null,
                    available_units: propertyType === 'BUILDING' && details ? (details as any).available_units : null,
                    common_amenities: amenitiesString,

                    area: foundProperty.area,
                    area_unit: foundProperty.area_unit,
                    availability_status: foundProperty.availability_status || 'READY_TO_MOVE',
                    price: foundProperty.price,
                    advance_amount: foundProperty.advance_amount ?? undefined,
                    year_built: foundProperty.year_built ?? undefined,
                    nearest_hospital: foundProperty.nearest_hospital ?? undefined,
                    nearest_busstop: foundProperty.nearest_busstop ?? undefined,
                    nearest_gym: foundProperty.nearest_gym ?? undefined,
                    nearest_park: foundProperty.nearest_park ?? undefined,
                    nearest_school: foundProperty.nearest_school ?? undefined,
                    nearest_swimmingpool: foundProperty.nearest_swimmingpool ?? undefined,
                    proximity_unit: foundProperty.proximity_unit || 'KM',
                    inventory_details: foundProperty.inventory_details || {},
                    notes: foundProperty.submitter_notes || '',
                    management_plan_id: foundProperty.management_plan_id ?? undefined,
                    can_reachout: true,
                    is_exclusive: foundProperty.is_exclusive,
                    agree_terms: true,
                });

                if (foundProperty.latitude && foundProperty.longitude) {
                    setInitialMapCenter([foundProperty.latitude, foundProperty.longitude]);
                }

                if (plansRes.data) {
                    setManagementPlans(plansRes.data.sort((a, b) => a.percentage - b.percentage));
                } else if (plansRes.error) {
                    showErrorNotification("Plan Load Error", typeof plansRes.error === 'string' ? plansRes.error : "Could not load management plans.");
                }

            } catch (err: any) {
                const message = typeof err === 'string' ? err : (err.message || "Failed to load property data for editing.");
                setPageError(message);
                showErrorNotification("Load Error", message);
            } finally {
                setLoading(false);
            }
        };
        fetchData();
    }, [propertyId, navigate, showErrorNotification]);

    const handleFormDataChange = (fieldName: string, value: any) => {
        if (formErrors[fieldName as FormErrorKeys]) {
            setFormErrors(prev => ({ ...prev, [fieldName]: undefined }));
        }
        setFormData(prev => ({ ...prev, [fieldName]: value }));
    };

    const validateForm = (): boolean => {
        const errors: FormErrors = {};
        if (!formData.listing_type) errors.listing_type = 'Listing type is required.';
        if (!formData.property_type) errors.property_type = 'Property type is required.';

        if (formData.property_type === 'HOUSE' && !formData.house_name.trim()) errors.house_name = 'Post Title is required.';
        if (formData.property_type === 'LAND' && !formData.land_name.trim()) errors.land_name = 'Post Title is required.';
        if (formData.property_type === 'BUILDING' && !formData.building_name.trim()) errors.building_name = 'Post Title is required.';

        if (!formData.city.trim()) errors.city = 'City is required.';
        if (!formData.locality.trim()) errors.locality = 'Locality is required.';
        if (!formData.address.trim()) errors.address = 'Full address is required.';
        if (!formData.pincode || formData.pincode.toString().length !== 6) errors.pincode = 'Valid Pincode (6 digits) is required.';
        if (formData.area === null || formData.area <= 0) errors.area = 'Valid Area (>0) is required.';
        if (!formData.area_unit) errors.area_unit = 'Area unit is required.';
        if (formData.price === null || formData.price <= 0) errors.price = 'Expected Price (>0) is required.';

        if (formData.property_type === 'HOUSE') {
            if (!formData.house_type) errors.house_type = 'Type of House is required.';
            if (formData.num_bedrooms === null || formData.num_bedrooms <= 0) errors.num_bedrooms = 'Bedrooms (>0) required.';
            if (formData.num_bathrooms === null || formData.num_bathrooms <= 0) errors.num_bathrooms = 'Bathrooms (>0) required.';
        } else if (formData.property_type === 'LAND') {
            if (!formData.land_type) errors.land_type = 'Type of Land is required.';
        } else if (formData.property_type === 'BUILDING') {
            if (!formData.building_type) errors.building_type = 'Type of Building is required.';
            if (formData.total_floors_building === null || formData.total_floors_building <= 0) errors.total_floors_building = 'Total floors (>0) required.';
        }

        if (formData.latitude !== undefined && (isNaN(formData.latitude) || formData.latitude < -90 || formData.latitude > 90)) {
            errors.latitude = 'Valid latitude (-90 to 90) is required if entered.';
        }
        if (formData.longitude !== undefined && (isNaN(formData.longitude) || formData.longitude < -180 || formData.longitude > 180)) {
            errors.longitude = 'Valid longitude (-180 to 180) is required if entered.';
        }
        if (formData.youtube_url && !/^(https?:\/\/)?(www\.)?(youtube\.com|youtu\.?be)\/.+$/.test(formData.youtube_url)) {
            errors.youtube_url = 'Please enter a valid YouTube URL.';
        }
        if (!formData.agree_terms) errors.agree_terms = 'You must agree to the terms and conditions.';

        setFormErrors(errors);
        return Object.keys(errors).length === 0;
    };

    const handleSubmit = async (event: FormEvent) => {
        event.preventDefault();
        if (!propertyId) {
            showErrorNotification("Error", "Property ID is missing for update.");
            return;
        }
        setPageError(null);
        setFormErrors({});

        if (!validateForm()) {
            showErrorNotification('Validation Error', 'Please fix the errors in the form.');
            const firstErrorField = document.querySelector('[class*="border-red-400"]');
            if (firstErrorField) (firstErrorField as HTMLElement).focus();
            return;
        }

        if (isSubmitting) return;
        setIsSubmitting(true);

        const detailsJson: Record<string, Json | undefined | null> = {};
        if (formData.property_type === 'HOUSE') {
            detailsJson.house_name = formData.house_name;
            detailsJson.house_type = formData.house_type;
            detailsJson.num_bedrooms = formData.num_bedrooms;
            detailsJson.num_bathrooms = formData.num_bathrooms;
            if (formData.num_balconies !== null) detailsJson.num_balconies = formData.num_balconies;
            if (formData.total_floors_house !== null) detailsJson.total_floors = formData.total_floors_house;
            if (formData.floor_number !== null) detailsJson.floor_number = formData.floor_number;
            if (formData.num_carparking !== null) detailsJson.num_carparking = formData.num_carparking;
            if (formData.furnished_status) detailsJson.furnished_status = formData.furnished_status;
            if (formData.facing_direction) detailsJson.facing_direction = formData.facing_direction;
            if (formData.house_type === 'APARTMENT_FLAT') {
                detailsJson.lift_facility_available = formData.lift_facility_available;
            } else {
                detailsJson.is_corner_plot = formData.is_corner_plot;
            }
            if (formData.water_source) detailsJson.water_source = formData.water_source;
            if (formData.power_backup) detailsJson.power_backup = formData.power_backup;
        } else if (formData.property_type === 'LAND') {
            detailsJson.land_name = formData.land_name;
            detailsJson.land_type = formData.land_type;
            if (formData.plot_dimensions) detailsJson.plot_dimensions = formData.plot_dimensions;
            if (formData.road_access_width_ft !== null) detailsJson.road_access_width_ft = formData.road_access_width_ft;
            detailsJson.is_corner_plot = formData.is_corner_plot;
        } else if (formData.property_type === 'BUILDING') {
            detailsJson.building_name = formData.building_name;
            detailsJson.building_type = formData.building_type;
            detailsJson.total_floors = formData.total_floors_building;
            if (formData.num_units !== null) detailsJson.num_units = formData.num_units;
            if (formData.available_units !== null) detailsJson.available_units = formData.available_units;
            if (formData.common_amenities) {
                detailsJson.common_amenities = formData.common_amenities.split(',').map(s => s.trim()).filter(Boolean);
            }
        }

        const updatePayload: UpdatePropertyPayload = {
            p_property_id: propertyId,
            p_property_type: formData.property_type,
            p_listing_type: formData.listing_type,
            p_price: formData.price!,
            p_area: formData.area!,
            p_area_unit: formData.area_unit,
            p_details: detailsJson,
            p_locality: formData.locality,
            p_city: formData.city,
            p_address: formData.address,
            p_pincode: formData.pincode!,
            p_submitter_type: formData.submitter_type,
            p_year_built: formData.year_built,
            p_description: formData.description || undefined,
            p_youtube_url: formData.youtube_url || undefined,
            p_latitude: formData.latitude,
            p_longitude: formData.longitude,
            p_nearest_hospital: formData.nearest_hospital,
            p_nearest_busstop: formData.nearest_busstop,
            p_nearest_gym: formData.nearest_gym,
            p_nearest_park: formData.nearest_park,
            p_nearest_school: formData.nearest_school,
            p_nearest_swimmingpool: formData.nearest_swimmingpool,
            p_proximity_unit: formData.proximity_unit,
            p_inventory_details: formData.inventory_details,
            p_is_exclusive: formData.is_exclusive,
            p_submitter_notes: formData.notes || undefined,
            p_availability_status: formData.availability_status,
            p_can_reachout: true,
            p_management_plan_id: formData.management_plan_id,
            p_advance_amount: formData.listing_type === 'RENTAL' ? formData.advance_amount : undefined,
        };

        try {
            const { error: updateError } = await api.updateProperty(updatePayload);
            if (updateError) {
                throw new Error(typeof updateError === 'string' ? updateError : 'Failed to update property data.');
            }
            showSuccessNotification('Update Successful!', 'Property details updated. Status set to "Pending Review".');
            navigate(`/my-properties/${propertyId}`);
        } catch (err: any) {
            setPageError(err.message || 'An unexpected error occurred during update.');
            showErrorNotification('Update Failed', err.message || 'Failed to update property.');
        } finally {
            setIsSubmitting(false);
        }
    };

    const companyName = import.meta.env.VITE_COMPANY_NAME;

    if (loading && !originalProperty) {
        return <FullScreenLoader message="Loading property data..." />;
    }

    if (pageError && !originalProperty) {
        return (
            <div className="min-h-screen flex flex-col items-center justify-center text-center p-4">
                <IconAlertCircle size={48} className="text-red-500 mb-4" />
                <h1 className="text-xl font-semibold mb-2">Error Loading Property</h1>
                <p className="text-gray-600 mb-4">{pageError}</p>
                <Link to="/my-properties" className={getSecondaryButtonClasses()}>
                    <IconArrowLeft size={16} className="mr-1" /> Back to My Properties
                </Link>
            </div>
        );
    }

    return (
        <>
            {isSubmitting && <FullScreenLoader message="Saving changes..." />}
            <title>Edit Property: {formData.house_name || formData.land_name || formData.building_name || originalProperty?.locality || '...'} | {companyName}</title>
            <div className="bg-gray-50 py-8">
                <div className="container mx-auto px-4 max-w-4xl">
                    <div className="flex justify-between items-center mb-6">
                        <h1 className="text-2xl md:text-3xl font-bold text-gray-800">
                            Edit Property
                        </h1>
                        <Link to={`/my-properties/${propertyId}`} className={`${getSecondaryButtonClasses()} !text-xs`}>
                            <IconArrowLeft size={16} className="mr-1" /> Cancel & View Details
                        </Link>
                    </div>

                    <form onSubmit={handleSubmit} noValidate>
                        {pageError && !isSubmitting && (
                            <div className="bg-red-50 border-l-4 border-red-500 text-red-700 p-4 rounded mb-6 shadow-sm" role="alert">
                                <p className="font-medium">Error: {pageError}</p>
                            </div>
                        )}
                        {/* Use the new form part components */}
                        <SectionWrapper title="Property Title & Description" icon={IconFileDescription}>
                            <PropertyTitleDescriptionSection
                                propertyType={formData.property_type}
                                formData={formData}
                                onFormDataChange={handleFormDataChange}
                                formErrors={formErrors}
                                disabledFields={{ description: isSubmitting }} // Example of disabling a field
                            />
                        </SectionWrapper>

                        <SectionWrapper title="Location Details" icon={IconMap}>
                            <LocationDetailsSection
                                formData={formData}
                                onFormDataChange={handleFormDataChange}
                                formErrors={formErrors}
                                initialMapCenter={initialMapCenter}
                                userHasTypedCity={true} // For edit, assume user has already set/confirmed city
                                geolocationLoading={false} // Not relevant for edit page usually
                                disabledFields={{ city: isSubmitting, locality: isSubmitting, address: isSubmitting }}
                            />
                        </SectionWrapper>

                        <SectionWrapper title="Property & Listing Type" icon={IconBuildingCommunity}>
                            <PropertyTypeListingSection
                                formData={formData}
                                onFormDataChange={handleFormDataChange}
                                formErrors={formErrors}
                                disabledFields={{ submitter_type: true }} // Submitter type usually not editable
                            />
                        </SectionWrapper>

                        {formData.property_type === 'HOUSE' && (
                            <SectionWrapper title="House Features" icon={IconHome2}>
                                <HouseFeaturesSection
                                    formData={formData}
                                    onFormDataChange={handleFormDataChange}
                                    formErrors={formErrors}
                                />
                            </SectionWrapper>
                        )}
                        {formData.property_type === 'LAND' && (
                            <SectionWrapper title="Land Features" icon={IconMapPin2}>
                                <LandFeaturesSection
                                    formData={formData}
                                    onFormDataChange={handleFormDataChange}
                                    formErrors={formErrors}
                                />
                            </SectionWrapper>
                        )}
                        {formData.property_type === 'BUILDING' && (
                            <SectionWrapper title="Building Features" icon={IconBuildingWarehouse}>
                                <BuildingFeaturesSection
                                    formData={formData}
                                    onFormDataChange={handleFormDataChange}
                                    formErrors={formErrors}
                                />
                            </SectionWrapper>
                        )}

                        <SectionWrapper title="Area & Dimensions" icon={IconDimensions}>
                            <AreaDimensionsSection
                                formData={formData}
                                onFormDataChange={handleFormDataChange}
                                formErrors={formErrors}
                            />
                        </SectionWrapper>

                        <SectionWrapper title="Pricing & Availability" icon={IconCoins}>
                            <PricingAvailabilitySection
                                formData={formData}
                                listingType={formData.listing_type}
                                onFormDataChange={handleFormDataChange}
                                formErrors={formErrors}
                            />
                        </SectionWrapper>

                        <SectionWrapper title="Nearby Amenities (Optional)" icon={IconMapPin2}>
                            <NearbyAmenitiesSection
                                formData={formData}
                                onFormDataChange={handleFormDataChange}
                                formErrors={formErrors}
                            />
                        </SectionWrapper>

                        <SectionWrapper title="Additional Details" icon={IconInfoCircle}>
                            <AdditionalPropertyInfoSection
                                formData={formData}
                                onFormDataChange={handleFormDataChange}
                                formErrors={formErrors}
                            />
                        </SectionWrapper>

                        <SectionWrapper title="Management Plan (Optional)" icon={IconListCheck} gridCols="1">
                            <ManagementPlanSelectorSection
                                managementPlans={managementPlans}
                                selectedPlanId={formData.management_plan_id}
                                onPlanSelect={(planId) => handleFormDataChange('management_plan_id', planId)}
                                loading={loading && managementPlans.length === 0} // Show loading if main form loading & plans not yet set
                                formErrors={formErrors}
                                disabled={isSubmitting}
                            />
                        </SectionWrapper>

                        <SectionWrapper title="Preferences & Agreement" icon={IconUser} gridCols="1">
                            <TermsAndPreferencesSection
                                formData={formData}
                                onFormDataChange={(fieldName, value) => handleFormDataChange(fieldName, value)}
                                formErrors={formErrors}
                                companyName={companyName}
                                disabled={isSubmitting}
                            />
                        </SectionWrapper>

                        <div className="mt-8 text-center">
                            <button type="submit" disabled={isSubmitting || loading}
                                className={`${getPrimaryButtonClasses()} px-8 py-3 text-base disabled:opacity-50 flex items-center justify-center min-w-[200px]`}>
                                {isSubmitting ? (
                                    <><LoadingSpinner size={20} /> <span className="ml-2">Saving Changes...</span></>
                                ) : (
                                    <><IconPencil size={18} className="mr-2" /> Save Changes</>
                                )}
                            </button>
                        </div>
                        <div className="mt-4 text-center text-xs text-gray-500">
                            <IconInfoCircle size={14} className="inline mr-1" />
                            Editing property details will reset its verification status to "Pending Review".
                        </div>
                    </form>
                </div>
            </div>
        </>
    );
}

export default EditPropertyPage;