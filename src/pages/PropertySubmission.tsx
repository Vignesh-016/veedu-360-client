import { useState, FormEvent, ChangeEvent, useEffect, useCallback } from 'react';

import {
    AreaUnit, ListingType, PropertyType, SubmitterType,
    AvailabilityStatus, HouseType, BuildingType, LandType,
    ManagementPlan, InsertPropertyPayload,
    ProximityUnit, FurnishedStatus, Direction,
    WaterSource, PowerBackup, VisitPlan,
} from '../lib/types';
import { LatLngTuple } from 'leaflet';
import api from '../lib/supabaseClient';
import { compressAndResizeImage } from '../lib/imageUtils';
import {
    IconInfoCircle, IconMap, IconPhoto, IconUser,
    IconCoins, IconDimensions, IconBuildingWarehouse, IconListCheck,
    IconHome2, IconMapPin2, IconBuildingCommunity, IconFileDescription,
    IconChevronRight, IconChevronLeft, IconCheck
} from '@tabler/icons-react';
import { useNavigate, Link } from 'react-router-dom';
import { useNotification } from '../components/NotificationProvider';
import LoadingSpinner from '../components/LoadingSpinner';
import { useAuth } from '../lib/AuthContext';
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
import PropertyImagesUploadSection, { ImageFileForUpload } from '../components/property_form_parts/PropertyImagesUploadSection';
import ManagementPlanSelectorSection from '../components/property_form_parts/ManagementPlanSelectorSection';
import TermsAndPreferencesSection from '../components/property_form_parts/TermsAndPreferencesSection';

const initialFormData = {
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
    agree_terms: false,
};

type FormDataState = typeof initialFormData;
type FormErrorKeys = keyof FormDataState | 'images' | 'details';
type FormErrors = Partial<Record<FormErrorKeys, string>>;

const STEPS = [
    { id: 1, title: 'Basic Info', icon: IconBuildingCommunity },
    { id: 2, title: 'Location', icon: IconMap },
    { id: 3, title: 'Details', icon: IconHome2 },
    { id: 4, title: 'Pricing & Status', icon: IconCoins },
    { id: 5, title: 'Photos & Extras', icon: IconPhoto },
    { id: 6, title: 'Finalize', icon: IconListCheck },
];

function PropertySubmission() {
    const navigate = useNavigate();
    const { user, currentCity: authCity, geolocationData, geolocationLoading } = useAuth();
    const [formData, setFormData] = useState<FormDataState>(initialFormData);
    const [images, setImages] = useState<ImageFileForUpload[]>([]);
    const [loading, setLoading] = useState(false);
    const [imageUploadProgress, setImageUploadProgress] = useState(0);
    const [pageError, setPageError] = useState<string | null>(null);
    const [userHasTypedCity, setUserHasTypedCity] = useState(false);
    const [formErrors, setFormErrors] = useState<FormErrors>({});
    const { showSuccessNotification, showErrorNotification, showInfoNotification } = useNotification();

    const [managementPlans, setManagementPlans] = useState<ManagementPlan[]>([]);
    const [managementPlansLoading, setManagementPlansLoading] = useState(true);
    const [initialMapCenter, setInitialMapCenter] = useState<LatLngTuple>([8.7139, 77.7567]); // Default to Tirunelveli

    // NEW: Step State
    const [currentStep, setCurrentStep] = useState(1);
    const MAX_STEPS = STEPS.length;

    // Listing Quota & Payment States
    const [propertyCount, setPropertyCount] = useState(0);
    const [paidListingCount, setPaidListingCount] = useState(0);
    const [listingPlan, setListingPlan] = useState<VisitPlan | null>(null);
    const [loadingPricingCheck, setLoadingPricingCheck] = useState(true);
    const [showSuccessModal, setShowSuccessModal] = useState(false);

    const needsPayment = propertyCount >= 1 && paidListingCount < propertyCount;

    const checkListingQuota = useCallback(async () => {
        if (!user) return;
        setLoadingPricingCheck(true);
        try {
            // 1. Fetch properties count
            const { data: propertiesData } = await api.getMyProperties(0, 1);
            const propCount = propertiesData && propertiesData.length > 0 ? Number(propertiesData[0].total_count) : 0;
            setPropertyCount(propCount);

            // 2. Fetch transactions to find paid listing plans
            const { data: transactionsData } = await api.getMyTransactions(0, 100);
            const paidListings = transactionsData
                ? transactionsData.filter(t => 
                    t.status === 'paid' && 
                    (t.plan_name?.toLowerCase().includes('listing') || t.plan_name?.toLowerCase().includes('property'))
                  ).length
                : 0;
            setPaidListingCount(paidListings);

            // 3. Fetch active plans to find the listing fee plan
            const { data: plansData } = await api.getVisitPlans();
            const activePlans = plansData || [];
            const plan = activePlans.find(p => 
                p.name.toLowerCase().includes('listing') || 
                p.name.toLowerCase().includes('property') ||
                p.name.toLowerCase().includes('post')
            );
            if (plan) {
                setListingPlan(plan);
            }
        } catch (err) {
            console.error("Error checking listing quota:", err);
        } finally {
            setLoadingPricingCheck(false);
        }
    }, [user]);

    useEffect(() => {
        if (user) {
            checkListingQuota();
        }
    }, [user, checkListingQuota]);

    const fetchManagementPlans = useCallback(async () => {
        setManagementPlansLoading(true);
        try {
            const { data, error } = await api.getManagementPlans();
            if (error) throw error;
            if (data) {
                const activePlans = data.sort((a, b) => a.percentage - b.percentage);
                setManagementPlans(activePlans);
            }
        } catch (err: any) {
            console.error("Failed to fetch management plans:", err);
            showErrorNotification("Load Error", err.message || "Could not load management plans.");
        } finally {
            setManagementPlansLoading(false);
        }
    }, [showErrorNotification]);

    useEffect(() => {
        fetchManagementPlans();
    }, [fetchManagementPlans]);

    useEffect(() => {
        if (!geolocationLoading) {
            if (geolocationData?.lat && geolocationData?.lon) {
                const lat = parseFloat(geolocationData.lat);
                const lon = parseFloat(geolocationData.lon);
                if (!isNaN(lat) && !isNaN(lon)) {
                    setInitialMapCenter([lat, lon]);
                }
            }
            if (!userHasTypedCity && authCity) {
                setFormData(prev => ({ ...prev, city: authCity }));
            } else if (!userHasTypedCity && !authCity) { // If no authCity and user hasn't typed, set default
                setFormData(prev => ({ ...prev, city: DEFAULT_CITY }));
            }
        }
    }, [authCity, geolocationData, geolocationLoading, userHasTypedCity]);

    const handleFormDataChange = (fieldName: string, value: any) => {
        if (formErrors[fieldName as FormErrorKeys]) {
            setFormErrors(prev => ({ ...prev, [fieldName]: undefined }));
        }
        if (fieldName === 'city') {
            setUserHasTypedCity(true);
        }
        setFormData(prev => ({ ...prev, [fieldName]: value }));
    };


    const handleImageFilesSelected = async (event: ChangeEvent<HTMLInputElement>) => {
        setPageError(null);
        if (formErrors.images) {
            setFormErrors(prev => ({ ...prev, images: undefined }));
        }

        const files = event.target.files;
        if (!files || files.length === 0) return;

        const currentImageCount = images.length;
        const maxImages = 10;

        if (files.length + currentImageCount > maxImages) {
            showErrorNotification('Upload Limit', `You can upload a maximum of ${maxImages} images.`);
            return;
        }
        showInfoNotification('Processing Images', 'Compressing and preparing images...');
        try {
            const newImages: ImageFileForUpload[] = [];
            const fileListArray = Array.from(files);

            for (const file of fileListArray) {
                if (newImages.length + currentImageCount >= maxImages) break;
                if (file.size > 5 * 1024 * 1024) {
                    showErrorNotification('File Too Large', `Skipping ${file.name}, size exceeds 5MB.`);
                    continue;
                }
                try {
                    const compressedFile = await compressAndResizeImage(file);
                    const previewUrl = URL.createObjectURL(compressedFile);
                    newImages.push({ file: compressedFile, previewUrl, description: undefined });
                } catch (compError) {
                    showErrorNotification('Compression Failed', `Could not process ${file.name}. Please try a different image.`);
                    console.error(`Compression failed for ${file.name}:`, compError);
                }
            }
            setImages(prev => [...prev, ...newImages]);
        } catch (err) {
            showErrorNotification('Image Error', 'An error occurred while adding images.');
            console.error(err);
        } finally {
            event.target.value = '';
        }
    };

    const removeImage = (index: number) => {
        URL.revokeObjectURL(images[index].previewUrl);
        setImages(prev => prev.filter((_, i) => i !== index));
    };

    // Modified validation for steps
    const validateStep = (step: number): boolean => {
        const errors: FormErrors = {};

        if (step === 1) { // Basic Info
            if (!formData.submitter_type) errors.submitter_type = 'Your role is required.';
            if (!formData.listing_type) errors.listing_type = 'Listing type is required.';
            if (!formData.property_type) errors.property_type = 'Property type is required.';
            // Validate Post Title based on type
            if (formData.property_type === 'HOUSE' && !formData.house_name.trim()) errors.house_name = 'Post Title is required.';
            if (formData.property_type === 'LAND' && !formData.land_name.trim()) errors.land_name = 'Post Title is required.';
            if (formData.property_type === 'BUILDING' && !formData.building_name.trim()) errors.building_name = 'Post Title is required.';
        }

        if (step === 2) { // Location
            if (!formData.city.trim()) errors.city = 'City is required.';
            if (!formData.locality.trim()) errors.locality = 'Locality is required.';
            if (!formData.address.trim()) errors.address = 'Full address is required.';
            if (!formData.pincode || formData.pincode.toString().length !== 6) errors.pincode = 'Valid Pincode (6 digits) is required.';
            // Coords check optional but encouraged? enforcing valid range if present
            if (formData.latitude !== undefined && (isNaN(formData.latitude) || formData.latitude < -90 || formData.latitude > 90)) {
                errors.latitude = 'Valid latitude (-90 to 90) is required if entered.';
            }
            if (formData.longitude !== undefined && (isNaN(formData.longitude) || formData.longitude < -180 || formData.longitude > 180)) {
                errors.longitude = 'Valid longitude (-180 to 180) is required if entered.';
            }
        }

        if (step === 3) { // Property Details
            if (formData.area === null || formData.area <= 0) errors.area = 'Valid Area (>0) is required.';
            if (!formData.area_unit) errors.area_unit = 'Area unit is required.';

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
        }

        if (step === 4) { // Pricing & Status
            if (formData.price === null || formData.price <= 0) errors.price = 'Expected Price (>0) is required.';
        }

        if (step === 5) { // Photos
            if (images.length === 0) errors.images = 'Please upload at least one photo for the property.';
            if (formData.youtube_url && !/^(https?:\/\/)?(www\.)?(youtube\.com|youtu\.?be)\/.+$/.test(formData.youtube_url)) {
                errors.youtube_url = 'Please enter a valid YouTube URL.';
            }
        }

        if (step === 6) { // Finalize
            if (!formData.agree_terms) errors.agree_terms = 'You must agree to the terms and conditions.';
        }

        setFormErrors(errors);

        // Show notification for errors
        if (Object.keys(errors).length > 0) {
            showErrorNotification('Incomplete Details', 'Please fill in all required fields to proceed.');
        }

        return Object.keys(errors).length === 0;
    };


    const handleNextStep = () => {
        if (validateStep(currentStep)) {
            setCurrentStep(prev => Math.min(prev + 1, MAX_STEPS));
            window.scrollTo(0, 0);
        }
    };

    const handlePrevStep = () => {
        setCurrentStep(prev => Math.max(prev - 1, 1));
        window.scrollTo(0, 0);
    };

    const companyName = import.meta.env.VITE_COMPANY_NAME;

    const proceedToSubmitProperty = async () => {
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

        const submissionPayload: InsertPropertyPayload = {
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
            p_can_reachout: formData.can_reachout,
            p_management_plan_id: formData.management_plan_id,
            p_advance_amount: formData.listing_type === 'RENTAL' ? formData.advance_amount : undefined,
        };

        let newPropertyId: string | null = null;
        const imageUploadErrors: { name: string, error: string }[] = [];

        try {
            const { data: propertyIdData, error: dataError } = await api.insertProperty(submissionPayload);
            if (dataError || !propertyIdData) {
                throw new Error(typeof dataError === 'string' ? dataError : 'Failed to submit property data.');
            }
            newPropertyId = propertyIdData;
            showInfoNotification('Data Submitted', `Property data for ID ${newPropertyId} submitted. Now uploading images...`);

            if (images.length > 0 && newPropertyId) {
                for (let i = 0; i < images.length; i++) {
                    const imageFile = images[i];
                    try {
                        const { error: imageUploadError } = await api.uploadPropertyImage(newPropertyId, imageFile.file, imageFile.description);
                        if (imageUploadError) throw new Error(typeof imageUploadError === 'string' ? imageUploadError : `Failed to upload ${imageFile.file.name}`);
                        setImageUploadProgress(Math.round(((i + 1) / images.length) * 100));
                    } catch (indUploadError: any) {
                        imageUploadErrors.push({ name: imageFile.file.name, error: indUploadError.message || 'Unknown upload error' });
                    }
                }
            }

            if (imageUploadErrors.length > 0) {
                showErrorNotification('Image Upload Issues', `Property data submitted, but ${imageUploadErrors.length} image(s) failed. Manage images from "My Properties".`);
                imageUploadErrors.forEach(err => console.error(`Failed: ${err.name}, Reason: ${err.error}`));
                setShowSuccessModal(true);
            } else {
                showSuccessNotification('Submission Successful!', `Property (ID: ${newPropertyId}) and all images submitted.`);
                setShowSuccessModal(true);
            }

        } catch (err: any) {
            const generalError = err.message || 'An unexpected error occurred during submission.';
            setPageError(generalError);
            showErrorNotification('Submission Failed', generalError);
        } finally {
            setLoading(false);
            setImageUploadProgress(0);
        }
    };

    const handleSubmit = async (event: FormEvent) => {
        event.preventDefault();
        setPageError(null);
        setFormErrors({});

        if (!validateStep(MAX_STEPS)) {
            // Validate final step specifically (Terms agreement) before submitting
            return;
        }

        if (loading) return;

        if (needsPayment) {
            if (!listingPlan) {
                showErrorNotification('Payment Setup Error', 'Listing plan is not available. Please contact support.');
                return;
            }
            setLoading(true);
            try {
                showInfoNotification('Processing Payment', 'Creating payment order...');
                const { data: orderData, error: orderError } = await api.createPaymentOrder({
                    plan_id: listingPlan.plan_id,
                });

                if (orderError || !orderData) {
                    throw new Error(orderError as string || 'Failed to create payment order.');
                }

                const { orderId, amount, keyId } = orderData;

                const options = {
                    key: keyId,
                    amount: amount,
                    currency: "INR",
                    name: companyName + " Property Listing",
                    description: `Listing Fee: ${listingPlan.name}`,
                    order_id: orderId,
                    // eslint-disable-next-line @typescript-eslint/no-explicit-any
                    handler: async (response: any) => {
                        setLoading(true);
                        showInfoNotification('Processing Payment', 'Verifying payment details...');
                        try {
                            const payload = {
                                razorpay_order_id: response.razorpay_order_id,
                                razorpay_payment_id: response.razorpay_payment_id,
                                razorpay_signature: response.razorpay_signature,
                            };
                            const { data: verifyData, error: verifyError } = await api.verifyPayment(payload);
                            if (verifyError || !verifyData?.success) {
                                throw new Error(verifyError as string || 'Payment verification failed.');
                            }

                            showSuccessNotification('Payment Verified!', 'Proceeding to submit your property listing...');
                            await proceedToSubmitProperty();
                        } catch (verificationError: any) {
                            showErrorNotification('Verification Failed', verificationError.message || 'Could not verify payment. Please contact support.');
                            setPageError(verificationError.message || 'Payment verification failed.');
                            setLoading(false);
                        }
                    },
                    modal: {
                        ondismiss: () => {
                            setLoading(false);
                            showInfoNotification('Payment Cancelled', 'You cancelled the payment. The property has not been posted.');
                        }
                    },
                    prefill: {
                        name: user?.user_metadata?.full_name || user?.email,
                        email: user?.email,
                        contact: user?.phone || user?.user_metadata?.phone,
                    },
                    notes: {
                        plan_id: listingPlan.plan_id,
                        user_id: user?.id,
                    },
                    theme: {
                        color: "#2C4964"
                    }
                };

                await api.openRazorpayCheckout(options);
            } catch (err: any) {
                console.error("Payment initiation error:", err);
                showErrorNotification('Payment Error', err.message || 'Could not initiate payment.');
                setPageError(err.message || 'Failed to start payment.');
                setLoading(false);
            }
        } else {
            setLoading(true);
            await proceedToSubmitProperty();
        }
    };

    return (
        <>
            {loading && <FullScreenLoader message={imageUploadProgress > 0 ? `Uploading images: ${imageUploadProgress}%` : "Submitting property..."} />}
            {showSuccessModal && (
                <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/60 backdrop-blur-sm animate-fade-in">
                    <div className="bg-white rounded-2xl max-w-md w-full p-6 shadow-2xl border border-slate-100 transform scale-100 transition-all duration-300">
                        <div className="flex flex-col items-center text-center">
                            {/* Success Icon */}
                            <div className="w-16 h-16 bg-emerald-100 rounded-full flex items-center justify-center mb-4 text-emerald-600">
                                <IconCheck size={32} stroke={3} />
                            </div>
                            
                            {/* Title */}
                            <h3 className="text-xl font-bold text-slate-900 mb-2">
                                Property Listed Successfully!
                            </h3>
                            
                            {/* Message */}
                            <p className="text-sm text-gray-500 mb-6">
                                Your property listing has been created and published. 
                                {needsPayment && " Your payment of ₹1.00 has been processed and verified successfully."}
                            </p>
                            
                            {/* Buttons */}
                            <div className="flex flex-col sm:flex-row gap-3 w-full">
                                <button
                                    type="button"
                                    onClick={() => {
                                        setShowSuccessModal(false);
                                        navigate('/my-properties');
                                    }}
                                    className="flex-1 bg-slate-950 text-white font-semibold py-3 px-4 rounded-xl hover:bg-slate-900 transition-all shadow-md hover:shadow-lg text-sm"
                                >
                                    Go to My Properties
                                </button>
                                <button
                                    type="button"
                                    onClick={() => {
                                        setShowSuccessModal(false);
                                        navigate('/catalogue');
                                    }}
                                    className="flex-1 bg-slate-100 text-slate-800 font-semibold py-3 px-4 rounded-xl hover:bg-slate-200 transition-all text-sm border border-slate-200"
                                >
                                    View Catalog
                                </button>
                            </div>
                        </div>
                    </div>
                </div>
            )}
            {/* Hero Section Matching Terms Page */}
            <section className="relative h-[280px] md:h-[350px] flex items-center justify-center overflow-hidden">
                <div
                    className="absolute inset-0 bg-cover bg-center z-0"
                    style={{
                        backgroundImage: 'url("/images/about/hero-house.png")',
                        filter: 'brightness(0.6)'
                    }}
                />
                <div className="relative z-10 text-center container mx-auto px-4">
                    <h1 className="text-3xl md:text-5xl font-bold text-white mb-3 tracking-tight drop-shadow-lg">
                        List Your Property
                    </h1>
                    <nav className="flex justify-center items-center space-x-2 text-white/90 font-medium text-sm md:text-base">
                        <Link to="/" className="hover:text-white transition-colors">Home</Link>
                        <span>•</span>
                        <span className="text-white">List Property</span>
                    </nav>
                </div>
            </section>
            <title>List Your Property | {companyName}</title>

            <div className="bg-gray-50 min-h-screen pb-20 pt-8 relative">
                <div className="container mx-auto px-4 md:px-8 max-w-6xl">

                    {/* Stepper Navigation (Visual) */}
                    <div className="mb-8 hidden md:block">
                        <div className="flex items-center justify-between relative px-2">
                            {/* Progress Bar Background */}
                            <div className="absolute left-0 right-0 top-1/2 h-1 bg-gray-200 -z-0 -translate-y-1/2 rounded-full mx-8"></div>
                            {/* Active Progress Bar */}
                            <div
                                className="absolute left-0 top-1/2 h-1 bg-slate-900 -z-0 -translate-y-1/2 rounded-full mx-8 transition-all duration-300 ease-out"
                                style={{ width: `${((currentStep - 1) / (MAX_STEPS - 1)) * 100}%` }}
                            ></div>

                            {STEPS.map((step) => {
                                const isActive = currentStep === step.id;
                                const isCompleted = currentStep > step.id;

                                return (
                                    <div key={step.id} className="relative z-10 flex flex-col items-center group">
                                        <div
                                            className={`w-10 h-10 rounded-full flex items-center justify-center border-4 transition-all duration-300 
                                                ${isActive ? 'bg-slate-900 border-slate-200 text-white shadow-lg scale-110' :
                                                    isCompleted ? 'bg-emerald-600 border-white text-white' :
                                                        'bg-white border-gray-100 text-gray-400'}`}
                                        >
                                            {isCompleted ? <IconCheck size={18} stroke={3} /> : <step.icon size={18} />}
                                        </div>
                                        <span className={`text-xs font-semibold mt-2 absolute -bottom-6 w-32 text-center transition-colors duration-300
                                            ${isActive ? 'text-slate-900' : isCompleted ? 'text-emerald-600' : 'text-gray-400'}`}>
                                            {step.title}
                                        </span>
                                    </div>
                                );
                            })}
                        </div>
                    </div>

                    {/* Mobile Stepper */}
                    <div className="mb-6 md:hidden flex justify-between items-center text-sm font-medium text-gray-600 bg-white p-3 rounded-xl shadow-sm border border-gray-100">
                        <span className="text-slate-900 flex items-center gap-2">
                            {(() => {
                                const Icon = STEPS[currentStep - 1].icon;
                                return Icon ? <Icon size={18} /> : null;
                            })()}
                            {STEPS[currentStep - 1].title}
                        </span>
                        <div className="flex gap-1">
                            {STEPS.map(s => (
                                <div key={s.id} className={`h-1.5 w-4 rounded-full ${s.id === currentStep ? 'bg-slate-900' : s.id < currentStep ? 'bg-emerald-500' : 'bg-gray-200'}`} />
                            ))}
                        </div>
                    </div>


                    <form onSubmit={handleSubmit} noValidate>
                        {pageError && (
                            <div className="bg-red-50 border-l-4 border-red-500 text-red-700 p-4 rounded-lg mb-6 shadow-sm flex items-start gap-3 animate-fade-in" role="alert">
                                <IconInfoCircle size={20} className="flex-shrink-0 mt-0.5" />
                                <div>
                                    <p className="font-semibold">Submission Error</p>
                                    <p className="text-sm">{pageError}</p>
                                </div>
                            </div>
                        )}

                        <div className="min-h-[400px]">
                            {/* Step 1: Basic Info */}
                            {currentStep === 1 && (
                                <div className="animate-fade-in-up">
                                    <SectionWrapper title="Property & Listing Type" icon={IconBuildingCommunity} defaultOpen={true}>
                                        <PropertyTypeListingSection
                                            formData={formData}
                                            onFormDataChange={handleFormDataChange}
                                            formErrors={formErrors}
                                        />
                                    </SectionWrapper>
                                    <SectionWrapper title="Property Title & Description" icon={IconFileDescription} defaultOpen={true}>
                                        <PropertyTitleDescriptionSection
                                            propertyType={formData.property_type}
                                            formData={formData}
                                            onFormDataChange={handleFormDataChange}
                                            formErrors={formErrors}
                                        />
                                    </SectionWrapper>
                                </div>
                            )}

                            {/* Step 2: Location */}
                            {currentStep === 2 && (
                                <div className="animate-fade-in-up">
                                    <SectionWrapper title="Location Details" icon={IconMap} defaultOpen={true}>
                                        <LocationDetailsSection
                                            formData={formData}
                                            onFormDataChange={handleFormDataChange}
                                            formErrors={formErrors}
                                            initialMapCenter={initialMapCenter}
                                            userHasTypedCity={userHasTypedCity}
                                            geolocationLoading={geolocationLoading}
                                        />
                                    </SectionWrapper>
                                </div>
                            )}

                            {/* Step 3: Details */}
                            {currentStep === 3 && (
                                <div className="animate-fade-in-up">
                                    {formData.property_type === 'HOUSE' && (
                                        <SectionWrapper title="House Features" icon={IconHome2} defaultOpen={true}>
                                            <HouseFeaturesSection
                                                formData={formData}
                                                onFormDataChange={handleFormDataChange}
                                                formErrors={formErrors}
                                            />
                                        </SectionWrapper>
                                    )}
                                    {formData.property_type === 'LAND' && (
                                        <SectionWrapper title="Land Features" icon={IconMapPin2} defaultOpen={true}>
                                            <LandFeaturesSection
                                                formData={formData}
                                                onFormDataChange={handleFormDataChange}
                                                formErrors={formErrors}
                                            />
                                        </SectionWrapper>
                                    )}
                                    {formData.property_type === 'BUILDING' && (
                                        <SectionWrapper title="Building Features" icon={IconBuildingWarehouse} defaultOpen={true}>
                                            <BuildingFeaturesSection
                                                formData={formData}
                                                onFormDataChange={handleFormDataChange}
                                                formErrors={formErrors}
                                            />
                                        </SectionWrapper>
                                    )}
                                    <SectionWrapper title="Area & Dimensions" icon={IconDimensions} defaultOpen={true}>
                                        <AreaDimensionsSection
                                            formData={formData}
                                            onFormDataChange={handleFormDataChange}
                                            formErrors={formErrors}
                                        />
                                    </SectionWrapper>
                                    <SectionWrapper title="Additional Details" icon={IconInfoCircle} defaultOpen={false}>
                                        <AdditionalPropertyInfoSection
                                            formData={formData}
                                            onFormDataChange={handleFormDataChange}
                                            formErrors={formErrors}
                                        />
                                    </SectionWrapper>
                                </div>
                            )}

                            {/* Step 4: Pricing */}
                            {currentStep === 4 && (
                                <div className="animate-fade-in-up">
                                    <SectionWrapper title="Pricing & Availability" icon={IconCoins} defaultOpen={true}>
                                        <PricingAvailabilitySection
                                            formData={formData}
                                            listingType={formData.listing_type}
                                            onFormDataChange={handleFormDataChange}
                                            formErrors={formErrors}
                                        />
                                    </SectionWrapper>
                                    <SectionWrapper title="Management Plan (Optional)" icon={IconListCheck} gridCols="1" defaultOpen={true}>
                                        <ManagementPlanSelectorSection
                                            managementPlans={managementPlans}
                                            selectedPlanId={formData.management_plan_id}
                                            onPlanSelect={(planId) => handleFormDataChange('management_plan_id', planId)}
                                            loading={managementPlansLoading}
                                            formErrors={formErrors}
                                            disabled={loading}
                                        />
                                    </SectionWrapper>
                                </div>
                            )}

                            {/* Step 5: Photos & Amenities */}
                            {currentStep === 5 && (
                                <div className="animate-fade-in-up">
                                    <SectionWrapper title="Property Photos" icon={IconPhoto} gridCols="1" defaultOpen={true}>
                                        <PropertyImagesUploadSection
                                            images={images}
                                            onImageFilesSelected={handleImageFilesSelected}
                                            onRemoveImage={removeImage}
                                            formErrors={formErrors}
                                            disabled={loading}
                                        />
                                    </SectionWrapper>
                                    <SectionWrapper title="Nearby Amenities (Optional)" icon={IconMapPin2} defaultOpen={false}>
                                        <NearbyAmenitiesSection
                                            formData={formData}
                                            onFormDataChange={handleFormDataChange}
                                            formErrors={formErrors}
                                        />
                                    </SectionWrapper>
                                </div>
                            )}

                            {/* Step 6: Finalize */}
                            {currentStep === 6 && (
                                <div className="animate-fade-in-up">
                                    <SectionWrapper title="Review & Preferences" icon={IconUser} gridCols="1" defaultOpen={true}>
                                        <div className="bg-slate-50 p-4 rounded-lg mb-4 text-sm text-slate-700 border border-slate-200">
                                            <p className="font-semibold flex items-center gap-2">
                                                <IconInfoCircle size={16} /> Nearly there!
                                            </p>
                                            <p className="mt-1">Please review your pricing breakdown and agreements below, then click to post your listing.</p>
                                        </div>

                                        {loadingPricingCheck ? (
                                            <div className="bg-white p-6 rounded-lg mb-6 border border-gray-100 flex flex-col items-center justify-center">
                                                <LoadingSpinner size={24} className="text-indigo-600 mb-2" />
                                                <span className="text-sm text-gray-500">Checking listing quota...</span>
                                            </div>
                                        ) : (
                                            <div className="bg-white p-6 rounded-xl mb-6 border border-gray-200/80 shadow-sm">
                                                <h3 className="text-base font-bold text-slate-900 mb-4 flex items-center gap-2">
                                                    <IconCoins className="text-indigo-600" size={20} />
                                                    Listing Quota & Pricing Breakdown
                                                </h3>
                                                
                                                <div className="space-y-3">
                                                    <div className="flex justify-between items-center text-sm pb-2 border-b border-gray-100">
                                                        <span className="text-gray-600">Properties already listed</span>
                                                        <span className="font-semibold text-slate-800">{propertyCount}</span>
                                                    </div>
                                                    
                                                    {needsPayment ? (
                                                        <>
                                                            <div className="flex justify-between items-center text-sm pb-2 border-b border-gray-100">
                                                                <span className="text-gray-600">Free Listings Quota (1 property)</span>
                                                                <span className="font-medium text-amber-600 bg-amber-50 px-2 py-0.5 rounded text-xs">Used</span>
                                                            </div>
                                                            <div className="flex justify-between items-center text-sm pb-2 border-b border-gray-100">
                                                                <span className="text-gray-600">Additional Listing Fee ({listingPlan?.name || 'Property Listing Fee'})</span>
                                                                <span className="font-semibold text-slate-800">₹{(listingPlan?.price ?? 1).toFixed(2)}</span>
                                                            </div>
                                                            <div className="flex justify-between items-center pt-2">
                                                                <span className="font-bold text-slate-900">Total Amount Due</span>
                                                                <span className="text-lg font-bold text-indigo-600">₹{(listingPlan?.price ?? 1).toFixed(2)}</span>
                                                            </div>
                                                            <div className="mt-4 bg-indigo-50/50 border border-indigo-100 rounded-lg p-3 text-xs text-indigo-800 leading-relaxed">
                                                                <strong>Note:</strong> Since this is your second or subsequent property listing, a listing fee of ₹{(listingPlan?.price ?? 1).toFixed(2)} is required. The property will be published instantly once the payment is completed securely via Razorpay.
                                                            </div>
                                                        </>
                                                    ) : (
                                                        <>
                                                            <div className="flex justify-between items-center text-sm pb-2 border-b border-gray-100">
                                                                <span className="text-gray-600">Free Listings Quota (1 property)</span>
                                                                <span className="font-medium text-emerald-600 bg-emerald-50 px-2 py-0.5 rounded text-xs">Available</span>
                                                            </div>
                                                            <div className="flex justify-between items-center pt-2">
                                                                <span className="font-bold text-slate-900">Total Amount Due</span>
                                                                <span className="text-lg font-bold text-emerald-600">₹0.00 (Free)</span>
                                                            </div>
                                                            <div className="mt-4 bg-emerald-50/50 border border-emerald-100 rounded-lg p-3 text-xs text-emerald-800 leading-relaxed">
                                                                <strong>Note:</strong> Excellent! This is your first property listing, so it is completely free of charge. No payment is required.
                                                            </div>
                                                        </>
                                                    )}
                                                    
                                                    {needsPayment && !listingPlan && (
                                                        <div className="mt-4 bg-red-50 border border-red-200 rounded-lg p-3 text-xs text-red-800 font-medium">
                                                            Warning: The property listing fee plan was not found in the database. Please verify with the administrator.
                                                        </div>
                                                    )}
                                                </div>
                                            </div>
                                        )}

                                        <TermsAndPreferencesSection
                                            formData={formData}
                                            onFormDataChange={(fieldName, value) => handleFormDataChange(fieldName, value)}
                                            formErrors={formErrors}
                                            companyName={companyName}
                                            disabled={loading}
                                        />
                                    </SectionWrapper>
                                </div>
                            )}
                        </div>

                        {/* Navigation Buttons */}
                        <div className="mt-8 flex justify-between items-center bg-white p-4 rounded-xl shadow-xl border border-gray-100 sticky bottom-4 z-40 animate-fade-in-up">
                            {/* Back Button */}
                            <button
                                type="button"
                                onClick={handlePrevStep}
                                disabled={currentStep === 1 || loading}
                                className={`flex items-center gap-2 px-6 py-3 rounded-lg font-medium transition-all
                                    ${currentStep === 1
                                        ? 'bg-gray-200 text-gray-400 cursor-not-allowed'
                                        : 'bg-gray-200 text-gray-800 hover:bg-gray-300'}`}
                            >
                                <IconChevronLeft size={20} />
                                Back
                            </button>

                            {/* Next / Submit Button */}
                            {currentStep < MAX_STEPS ? (
                                <button
                                    type="button"
                                    onClick={handleNextStep}
                                    className="flex items-center gap-2 bg-gradient-to-r from-indigo-600 to-purple-600 hover:from-indigo-500 hover:to-purple-500 text-white px-8 py-3 rounded-lg font-semibold shadow-md hover:shadow-lg transition-all transform hover:scale-105"
                                >
                                    Next Step
                                    <IconChevronRight size={20} />
                                </button>
                            ) : (
                                <button
                                    type="submit"
                                    disabled={loading || loadingPricingCheck || (needsPayment && !listingPlan)}
                                    className="flex items-center gap-2 bg-gradient-to-r from-indigo-600 to-purple-600 hover:from-indigo-500 hover:to-purple-500 text-white px-8 py-3 rounded-lg font-semibold shadow-md hover:shadow-lg transition-all transform hover:scale-105 disabled:opacity-50 disabled:cursor-not-allowed"
                                >
                                    {loading ? (
                                        <>
                                            <LoadingSpinner size={20} className="text-white" />
                                            <span>{needsPayment ? "Processing Payment..." : "Submitting..."}</span>
                                        </>
                                    ) : (
                                        <>
                                            <IconCheck size={20} />
                                            <span>{needsPayment ? `Pay & Post Property (₹${(listingPlan?.price ?? 1).toFixed(2)})` : "Post Property"}</span>
                                        </>
                                    )}
                                </button>
                            )}
                        </div>
                    </form>
                </div>
            </div>
        </>
    );
}

export default PropertySubmission;