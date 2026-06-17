import React, { useState, Fragment } from 'react';
import { useNavigate } from 'react-router-dom';
import {
    IconBuildingCommunity, IconHeart, IconHome2, IconListDetails,
    IconMapPin, IconMapPin2, IconSparkles, IconUserCheck,
    IconAlertCircle, IconReceipt, IconTicket,
    IconHistory, IconUser, IconMail, IconPhone, IconEdit, IconPhotoPlus,
    IconX, IconMessagePlus, IconCircleCheck
} from '@tabler/icons-react';
import { Dialog, DialogPanel, DialogTitle, Transition, TransitionChild } from '@headlessui/react';

import { MyProperties, PropertyRentDues, MyPropertyTickets, HouseDetailsSpecific, LandDetailsSpecific, BuildingDetailsSpecific } from '../lib/types';
import { getListingTypeBadgeClasses, getTertiaryButtonClasses, getStatusBadgeClasses } from '../lib/twUtils';
import { formatPrice } from '../lib/formatUtils';
import { getDisplayValue, propertyTypeMap, propertyAdminStatusMap } from '../lib/displayUtils';
import api from '../lib/supabaseClient';
import LoadingSpinner from './LoadingSpinner';
import { useNotification } from './NotificationProvider';
import RentDueLandlordCard from './RentDueLandlordCard';
import TicketSummaryLandlordCard from './TicketSummaryLandlordCard';
import PropertyPaymentHistoryModal from './PropertyPaymentHistoryModal';
import PropertyImageManagementModal from './PropertyImageManagementModal';
import { Json } from '../database.types';


interface ListedPropertyCardProps {
    property: MyProperties;
    onPropertyUpdate: () => void;
}

function ListedPropertyCard({ property, onPropertyUpdate }: ListedPropertyCardProps) {
    const navigate = useNavigate();
    const { showErrorNotification } = useNotification();

    const [isDuesModalOpen, setIsDuesModalOpen] = useState(false);
    const [duesData, setDuesData] = useState<PropertyRentDues[]>([]);
    const [isDuesLoading, setDuesLoading] = useState(false);
    const [duesError, setDuesError] = useState<string | null>(null);

    const [isTicketsModalOpen, setIsTicketsModalOpen] = useState(false);
    const [ticketsData, setTicketsData] = useState<MyPropertyTickets[]>([]);
    const [isTicketsLoading, setTicketsLoading] = useState(false);
    const [ticketsError, setTicketsError] = useState<string | null>(null);

    const [isPaymentHistoryModalOpen, setIsPaymentHistoryModalOpen] = useState(false);
    const [isImageManagementModalOpen, setIsImageManagementModalOpen] = useState(false);


    const {
        property_id,
        locality,
        address,
        price,
        property_type,
        listing_type,
        interaction_count,
        is_featured,
        admin_status,
        property_images,
        tenant_info,
    } = property;

    const publicImages = property_images.filter(img => !img.is_internal_image);
    const mainImageUrl = publicImages.length > 0 ? publicImages[0].image_url : null;

    // Derive Post Title
    const getPostTitle = (prop: MyProperties): string => {
        const propDetails = prop.details as Json;
        if (prop.property_type === 'HOUSE' && propDetails && (propDetails as HouseDetailsSpecific['details']).house_name) {
            return (propDetails as HouseDetailsSpecific['details']).house_name;
        }
        if (prop.property_type === 'LAND' && propDetails && (propDetails as LandDetailsSpecific['details']).land_name) {
            return (propDetails as LandDetailsSpecific['details']).land_name;
        }
        if (prop.property_type === 'BUILDING' && propDetails && (propDetails as BuildingDetailsSpecific['details']).building_name) {
            return (propDetails as BuildingDetailsSpecific['details']).building_name;
        }
        return prop.locality || 'Property Listing';
    };
    const postTitle = getPostTitle(property);


    const PropertyIcon = property_type === 'LAND' ? IconMapPin2 :
        property_type === 'BUILDING' ? IconBuildingCommunity :
            IconHome2;

    const fallbackImageUrl = `https://placehold.co/300x200/e2e8f0/94a3b8?text=${encodeURIComponent(locality || 'Property')}`;
    const priceFormatted = formatPrice(price);
    const statusDisplay = getDisplayValue(propertyAdminStatusMap, admin_status);


    const handleNavigateToDetails = () => {
        navigate(`/my-properties/${property_id}`);
    };

    const handleNavigateToEdit = (e: React.MouseEvent) => {
        e.stopPropagation();
        navigate(`/my-properties/edit/${property_id}`);
    };

    const handleViewDues = async (e: React.MouseEvent) => {
        e.stopPropagation();
        setDuesLoading(true);
        setDuesError(null);
        setDuesData([]);
        setIsDuesModalOpen(true);
        try {
            const { data, error } = await api.getPropertyRentDues(property_id);
            if (error) throw error;
            setDuesData(data || []);
        } catch (err: any) {
            const message = typeof err === 'string' ? err : err.message || 'Failed to load rent dues.';
            setDuesError(message);
            showErrorNotification('Load Failed', message);
        } finally {
            setDuesLoading(false);
        }
    };

    const handleViewTickets = async (e: React.MouseEvent) => {
        e.stopPropagation();
        setTicketsLoading(true);
        setTicketsError(null);
        setTicketsData([]);
        setIsTicketsModalOpen(true);
        try {
            const { data, error } = await api.getPropertyTickets(property_id, 0, 50); // Fetch up to 50 tickets
            if (error) throw error;
            setTicketsData(data || []);
        } catch (err: any) {
            const message = typeof err === 'string' ? err : err.message || 'Failed to load support tickets.';
            setTicketsError(message);
            showErrorNotification('Load Failed', message);
        } finally {
            setTicketsLoading(false);
        }
    };

    const handleViewPaymentHistory = (e: React.MouseEvent) => {
        e.stopPropagation();
        setIsPaymentHistoryModalOpen(true);
    };

    const handleManageImages = (e: React.MouseEvent) => {
        e.stopPropagation();
        setIsImageManagementModalOpen(true);
    };

    const handleCreateTicketClick = (e: React.MouseEvent) => {
        e.stopPropagation();
        navigate(`/create-ticket`, { state: { propertyId: property_id, propertyAddress: address } });
    };


    const closeDuesModal = () => setIsDuesModalOpen(false);
    const closeTicketsModal = () => setIsTicketsModalOpen(false);
    const closePaymentHistoryModal = () => setIsPaymentHistoryModalOpen(false);
    const closeImageManagementModal = () => setIsImageManagementModalOpen(false);

    const canHaveDuesOrTickets = !!tenant_info;

    // Derive verification status from admin_status
    const isVerified = ['OWNER_VERIFIED', 'MARKETING_VERIFIED', 'AWAITING_LISTING', 'RENTED', 'SOLD'].includes(admin_status);

    return (
        <>
            <div
                className="bg-white border border-gray-200 shadow-[0_2px_12px_rgba(44,73,100,0.06)] rounded-2xl flex flex-col md:flex-row w-full overflow-hidden relative group hover:shadow-[0_6px_20px_rgba(44,73,100,0.1)] transition-all duration-250 cursor-pointer"
                onClick={handleNavigateToDetails}
                role="link"
                tabIndex={0}
                onKeyPress={(e) => e.key === 'Enter' && handleNavigateToDetails()}
            >
                {/* Image Section */}
                <div className="w-full md:w-48 h-48 md:h-auto min-h-[192px] flex-shrink-0 relative bg-gray-100 overflow-hidden">
                    <img
                        src={mainImageUrl || fallbackImageUrl}
                        alt={`Property: ${postTitle}`}
                        className="w-full h-full object-cover group-hover:scale-102 transition-transform duration-300"
                        loading="lazy"
                        onError={(e) => { e.currentTarget.src = fallbackImageUrl; }}
                    />
                    {is_featured && (
                        <div className="absolute top-2.5 left-2.5 pointer-events-none">
                            <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-[10px] font-bold border bg-gradient-to-r from-yellow-100 via-amber-100 to-orange-100 text-amber-800 border-amber-300 shadow-sm">
                                <IconSparkles size={12} stroke={2} className="text-amber-600" /> Featured
                            </span>
                        </div>
                    )}
                </div>

                {/* Content Section */}
                <div className="flex-grow p-5 flex flex-col justify-between">
                    <div>
                        {/* Placements - Top Badges Row inside content area */}
                        <div className="flex flex-wrap gap-2 mb-3">
                            {/* Verification Badge */}
                            {isVerified ? (
                                <span className="inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full text-[10px] font-medium bg-emerald-50 text-emerald-700 border border-emerald-200">
                                    <IconCircleCheck size={12} /> Owner Verified
                                </span>
                            ) : (
                                <span className="inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full text-[10px] font-medium bg-amber-50 text-amber-700 border border-amber-200">
                                    <IconAlertCircle size={12} /> Under Review
                                </span>
                            )}

                            {/* Status Badge */}
                            <span className={getStatusBadgeClasses(admin_status) + ' text-[10px]'}>
                                {statusDisplay}
                            </span>

                            {/* Property & Listing Type Badge */}
                            <span className={getListingTypeBadgeClasses(listing_type?.toLowerCase() as any) + ' flex items-center gap-1 text-[10px]'}>
                                <PropertyIcon size={12} />
                                {property_type ? `${getDisplayValue(propertyTypeMap, property_type)}` : ''}
                                ({listing_type === 'RENTAL' ? 'Rent' : 'Sale'})
                            </span>
                        </div>

                        {/* Placements - Title and Price aligned on the same row */}
                        <div className="flex flex-col sm:flex-row sm:justify-between sm:items-start gap-2 mb-2">
                            <div>
                                <h2 className="text-lg font-semibold text-gray-800 line-clamp-1 group-hover:text-gray-600 transition-colors" title={postTitle}>
                                    {postTitle}
                                </h2>
                                <p className="text-sm text-gray-500 mt-1 flex items-center gap-1" title={address}>
                                    <IconMapPin size={14} className="text-gray-400" /> {locality}
                                </p>
                            </div>
                            <div className="sm:text-right shrink-0">
                                <span className="text-lg font-bold text-[#2C4964]">
                                    {priceFormatted}
                                </span>
                                {listing_type === 'RENTAL' && <span className="text-xs text-gray-500 font-normal">/month</span>}
                            </div>
                        </div>

                        {/* Divider */}
                        <hr className="my-3 border-gray-100" />

                        {/* Placements - Quick Metrics Section */}
                        <div className="grid grid-cols-2 gap-3 text-xs mb-3">
                            <div className="flex items-center gap-1.5 text-gray-600" title={`${interaction_count} users wishlisted`}>
                                <IconHeart size={14} className="text-gray-400" />
                                <span>Wishlisted: <span className="font-medium">{interaction_count}</span></span>
                            </div>
                            <div className="flex items-center gap-1.5 text-gray-600">
                                <IconUserCheck size={14} className="text-gray-400" />
                                <span>Occupied: <span className={`font-medium ${tenant_info ? 'text-green-700' : 'text-gray-500'}`}>{tenant_info ? 'Yes' : 'No'}</span></span>
                            </div>
                        </div>

                        {/* Tenant Info Section */}
                        {tenant_info && (tenant_info.name || tenant_info.email || tenant_info.phone) && (
                            <div className="mt-3 p-3 bg-gray-50 border border-gray-100 rounded-xl space-y-1">
                                <span className="text-[10px] font-semibold text-gray-400 uppercase tracking-wider block">Tenant Details</span>
                                <div className="grid grid-cols-1 sm:grid-cols-2 gap-x-4 gap-y-1">
                                    {tenant_info.name && (
                                        <p className='flex items-center gap-1 text-xs text-gray-600'>
                                            <IconUser size={12} /> {tenant_info.name}
                                        </p>
                                    )}
                                    {tenant_info.email && (
                                        <p className='flex items-center gap-1 text-xs text-gray-600 truncate'>
                                            <IconMail size={12} /> 
                                            <a href={`mailto:${tenant_info.email}`} onClick={(e) => e.stopPropagation()} className='hover:underline text-[#2C4964]'>{tenant_info.email}</a>
                                        </p>
                                    )}
                                    {tenant_info.phone && (
                                        <p className='flex items-center gap-1 text-xs text-gray-600 col-span-1 sm:col-span-2'>
                                            <IconPhone size={12} /> 
                                            <a href={`tel:${tenant_info.phone}`} onClick={(e) => e.stopPropagation()} className='hover:underline text-[#2C4964]'>+{tenant_info.phone}</a>
                                        </p>
                                    )}
                                </div>
                            </div>
                        )}
                    </div>

                    {/* Placements - Action Buttons */}
                    <div className="mt-4 pt-3 border-t border-gray-100 flex flex-wrap gap-2 items-center justify-end">
                        {canHaveDuesOrTickets && (
                            <>
                                <button 
                                    onClick={handleViewDues} 
                                    className="px-3 py-1 bg-white border border-gray-300 text-gray-700 hover:bg-gray-50 rounded-xl text-xs flex items-center gap-1 whitespace-nowrap transition-colors" 
                                    title="View Rent Dues" 
                                    disabled={isDuesLoading}
                                >
                                    {isDuesLoading ? <LoadingSpinner size={14} /> : <IconReceipt size={14} />} Dues
                                </button>
                                <button 
                                    onClick={handleViewPaymentHistory} 
                                    className="px-3 py-1 bg-white border border-gray-300 text-gray-700 hover:bg-gray-50 rounded-xl text-xs flex items-center gap-1 whitespace-nowrap transition-colors" 
                                    title="View Payment History"
                                >
                                    <IconHistory size={14} /> Payments
                                </button>
                                <button 
                                    onClick={handleViewTickets} 
                                    className="px-3 py-1 bg-white border border-gray-300 text-gray-700 hover:bg-gray-50 rounded-xl text-xs flex items-center gap-1 whitespace-nowrap transition-colors" 
                                    title="View Support Tickets for this property (tenant raised)" 
                                    disabled={isTicketsLoading}
                                >
                                    {isTicketsLoading ? <LoadingSpinner size={14} /> : <IconTicket size={14} />} View Tickets
                                </button>
                            </>
                        )}
                        <button
                            onClick={handleCreateTicketClick}
                            className="px-3 py-1 bg-white border border-gray-300 text-[#2C4964] hover:bg-gray-50 rounded-xl text-xs flex items-center gap-1 whitespace-nowrap transition-colors"
                            title="Create a Support Ticket for this Property"
                        >
                            <IconMessagePlus size={14} /> Raise Ticket
                        </button>
                        <button 
                            onClick={handleManageImages} 
                            className="px-3 py-1 bg-white border border-gray-300 text-[#2C4964] hover:bg-gray-50 rounded-xl text-xs flex items-center gap-1 whitespace-nowrap transition-colors" 
                            title="Manage All Property Images/Documents"
                        >
                            <IconPhotoPlus size={14} /> Manage Images
                        </button>
                        <button 
                            onClick={handleNavigateToEdit} 
                            className="px-3 py-1 bg-white border border-gray-300 text-[#2C4964] hover:bg-gray-50 rounded-xl text-xs flex items-center gap-1 whitespace-nowrap transition-colors" 
                            title="Edit Property Details"
                        >
                            <IconEdit size={14} /> Edit Details
                        </button>
                        <button 
                            onClick={handleNavigateToDetails} 
                            className="px-4 py-1.5 bg-[#2C4964] text-white hover:bg-[#1E3347] rounded-xl text-xs flex items-center gap-1 whitespace-nowrap transition-colors shadow-sm font-medium" 
                            title="View Full Property Details"
                        >
                            <IconListDetails size={14} /> View Details
                        </button>
                    </div>
                </div>
            </div>

            {/* Dues Modal */}
            <Transition appear show={isDuesModalOpen} as={Fragment}>
                <Dialog as="div" className="relative z-50" onClose={closeDuesModal}>
                    <TransitionChild as={Fragment} enter="ease-out duration-300" enterFrom="opacity-0" enterTo="opacity-100" leave="ease-in duration-200" leaveFrom="opacity-100" leaveTo="opacity-0">
                        <div className="fixed inset-0 bg-black/40 backdrop-blur-sm" />
                    </TransitionChild>
                    <div className="fixed inset-0 overflow-y-auto">
                        <div className="flex min-h-full items-center justify-center p-4 text-center">
                            <TransitionChild as={Fragment} enter="ease-out duration-300" enterFrom="opacity-0 scale-95" enterTo="opacity-100 scale-100" leave="ease-in duration-200" leaveFrom="opacity-100 scale-100" leaveTo="opacity-0 scale-95">
                                <DialogPanel className="w-full max-w-2xl transform overflow-hidden rounded-2xl bg-white p-6 text-left align-middle shadow-xl transition-all">
                                    <DialogTitle as="h3" className="text-lg font-semibold leading-6 text-gray-900 flex justify-between items-center">
                                        Outstanding Rent Dues
                                        <button onClick={closeDuesModal} className="text-gray-400 hover:text-gray-600"><IconX size={20} /></button>
                                    </DialogTitle>
                                    <p className="text-sm text-gray-500 mt-1 mb-4">For property: {postTitle} ({address})</p>
                                    <div className="mt-4 max-h-[60vh] overflow-y-auto custom-scrollbar pr-2">
                                        {isDuesLoading ? (
                                            <div className="flex justify-center items-center h-40"><LoadingSpinner /></div>
                                        ) : duesError ? (
                                            <div className="bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded-lg text-center flex flex-col items-center gap-2 shadow-sm"> <IconAlertCircle size={24} /> Error loading dues: {duesError} </div>
                                        ) : duesData.length === 0 ? (
                                            <p className="text-gray-500 text-center italic py-6">No outstanding rent dues found for this property.</p>
                                        ) : (
                                            <div className="space-y-3">
                                                {duesData.map((due) => <RentDueLandlordCard key={due.rent_record_id} rentDue={due} />)}
                                            </div>
                                        )}
                                    </div>
                                    <div className="mt-5 text-right">
                                        <button type="button" className={getTertiaryButtonClasses()} onClick={closeDuesModal}> Close </button>
                                    </div>
                                </DialogPanel>
                            </TransitionChild>
                        </div>
                    </div>
                </Dialog>
            </Transition>

            {/* Tickets Modal */}
            <Transition appear show={isTicketsModalOpen} as={Fragment}>
                <Dialog as="div" className="relative z-50" onClose={closeTicketsModal}>
                    <TransitionChild as={Fragment} enter="ease-out duration-300" enterFrom="opacity-0" enterTo="opacity-100" leave="ease-in duration-200" leaveFrom="opacity-100" leaveTo="opacity-0">
                        <div className="fixed inset-0 bg-black/40 backdrop-blur-sm" />
                    </TransitionChild>
                    <div className="fixed inset-0 overflow-y-auto">
                        <div className="flex min-h-full items-center justify-center p-4 text-center">
                            <TransitionChild as={Fragment} enter="ease-out duration-300" enterFrom="opacity-0 scale-95" enterTo="opacity-100 scale-100" leave="ease-in duration-200" leaveFrom="opacity-100 scale-100" leaveTo="opacity-0 scale-95">
                                <DialogPanel className="w-full max-w-2xl transform overflow-hidden rounded-2xl bg-white p-6 text-left align-middle shadow-xl transition-all">
                                    <DialogTitle as="h3" className="text-lg font-semibold leading-6 text-gray-900 flex justify-between items-center">
                                        Support Tickets
                                        <button onClick={closeTicketsModal} className="text-gray-400 hover:text-gray-600"><IconX size={20} /></button>
                                    </DialogTitle>
                                    <p className="text-sm text-gray-500 mt-1 mb-4">For property: {postTitle} ({address})</p>
                                    <div className="mt-4 max-h-[60vh] overflow-y-auto custom-scrollbar pr-2">
                                        {isTicketsLoading ? (
                                            <div className="flex justify-center items-center h-40"><LoadingSpinner /></div>
                                        ) : ticketsError ? (
                                            <div className="bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded-lg text-center flex flex-col items-center gap-2 shadow-sm"> <IconAlertCircle size={24} /> Error loading tickets: {ticketsError} </div>
                                        ) : ticketsData.length === 0 ? (
                                            <p className="text-gray-500 text-center italic py-6">No support tickets found for this property.</p>
                                        ) : (
                                            <div className="space-y-3">
                                                {ticketsData.map((ticket) => <TicketSummaryLandlordCard key={ticket.ticket_id} ticket={ticket} />)}
                                            </div>
                                        )}
                                    </div>
                                    <div className="mt-5 text-right">
                                        <button type="button" className={getTertiaryButtonClasses()} onClick={closeTicketsModal}> Close </button>
                                    </div>
                                </DialogPanel>
                            </TransitionChild>
                        </div>
                    </div>
                </Dialog>
            </Transition>

            {/* Payment History Modal */}
            <PropertyPaymentHistoryModal
                isOpen={isPaymentHistoryModalOpen}
                onClose={closePaymentHistoryModal}
                propertyId={property_id}
                propertyAddress={postTitle}
            />

            {/* Image Management Modal */}
            {isImageManagementModalOpen && (
                <PropertyImageManagementModal
                    isOpen={isImageManagementModalOpen}
                    onClose={closeImageManagementModal}
                    propertyId={property_id}
                    initialImages={property_images}
                    onImagesUpdated={() => {
                        onPropertyUpdate();
                        closeImageManagementModal();
                    }}
                />
            )}
        </>
    );
}

export default ListedPropertyCard;