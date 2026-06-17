import React, { useState, Fragment } from 'react';
import { useNavigate } from 'react-router-dom';
import { Dialog, Transition, TransitionChild, DialogPanel, DialogTitle } from '@headlessui/react';

import { BuildingDetailsSpecific, DetailedPropertyImage, HouseDetailsSpecific, LandDetailsSpecific, MyOccupiedProperties, MyRentDues } from '../lib/types';
import { getBaseCardClasses, getSecondaryButtonClasses, getTertiaryButtonClasses } from '../lib/twUtils';
import {
    IconBuilding, IconHome2, IconMapPin, IconMapPin2, IconTicket, IconUser,
    IconPhotoScan,
    IconX, IconFileDescription, IconAlertCircle, IconMail, IconPhone
} from '@tabler/icons-react';
import RentDueTenantCard from './RentDueTenantCard';
import api from '../lib/supabaseClient';
import LoadingSpinner from './LoadingSpinner';
import { useNotification } from './NotificationProvider';
import { Json } from '../database.types';

interface OccupiedPropertyCardProps {
    property: MyOccupiedProperties;
    rentDues: MyRentDues[];
}

function OccupiedPropertyCard({ property, rentDues }: OccupiedPropertyCardProps) {
    const navigate = useNavigate();
    const { showErrorNotification } = useNotification();

    const [isInternalImagesModalOpen, setIsInternalImagesModalOpen] = useState(false);
    const [internalImages, setInternalImages] = useState<DetailedPropertyImage[]>([]);
    const [internalImagesLoading, setInternalImagesLoading] = useState(false);
    const [internalImagesError, setInternalImagesError] = useState<string | null>(null);

    const {
        property_id,
        locality,
        city,
        address,
        property_type,
        landlord_name,
        landlord_email,
        landlord_phone,
        details,
    } = property;
    let image_url = "";
    if (property.property_images && property.property_images.length > 0) {
        image_url = property.property_images[0].image_url;
    }

    const PropertyIcon = property_type === 'LAND' ? IconMapPin2 :
        property_type === 'BUILDING' ? IconBuilding :
            IconHome2;

    const fallbackImageUrl = `https://placehold.co/300x200/e2e8f0/94a3b8?text=${encodeURIComponent(locality || 'Property')}`;

    // Derive Post Title
    let postTitle = locality || 'Property'; // Fallback
    if (details && typeof details === 'object') {
        const details = property.details as Json;
        if (property.property_type === 'HOUSE' && details && (details as HouseDetailsSpecific['details']).house_name) {
            postTitle = (details as HouseDetailsSpecific['details']).house_name;
        }
        if (property.property_type === 'LAND' && details && (details as LandDetailsSpecific['details']).land_name) {
            postTitle = (details as LandDetailsSpecific['details']).land_name;
        }
        if (property.property_type === 'BUILDING' && details && (details as BuildingDetailsSpecific['details']).building_name) {
            postTitle = (details as BuildingDetailsSpecific['details']).building_name;
        }
    }


    const handleCardClick = () => {
        navigate(`/my-properties/${property_id}`);
    };

    const handleCreateTicketClick = (e: React.MouseEvent) => {
        e.stopPropagation();
        navigate(`/create-ticket`, { state: { propertyId: property_id, propertyAddress: address } });
    };

    // --- Fetch and Show Internal Images ---
    const fetchAndShowInternalImages = async (e?: React.MouseEvent) => {
        e?.stopPropagation();
        setInternalImagesLoading(true);
        setInternalImagesError(null);
        setInternalImages([]);
        if (!isInternalImagesModalOpen) {
            setIsInternalImagesModalOpen(true);
        }

        try {
            // Tenants use the same function as owners to VIEW
            const { data, error } = await api.viewPropertyInternalImages(property_id);
            if (error) throw error;
            setInternalImages(data || []);
        } catch (err: any) {
            const message = typeof err === 'string' ? err : err.message || 'Failed to load internal images.';
            setInternalImagesError(message);
            showErrorNotification('Load Failed', message);
        } finally {
            setInternalImagesLoading(false);
        }
    };

    const closeModal = () => setIsInternalImagesModalOpen(false);

    return (
        <>
            <div
                className={`${getBaseCardClasses()} hover:shadow-lg transition-all duration-300 flex flex-col md:flex-row gap-4 cursor-pointer group`}
                onClick={handleCardClick}
                role="link"
                tabIndex={0}
                onKeyDown={(e) => e.key === 'Enter' && handleCardClick()}
            >
                {/* Image */}
                <div className="w-full md:w-48 h-48 flex-shrink-0 relative">
                    <img
                        src={image_url || fallbackImageUrl}
                        alt={`Property: ${postTitle}`}
                        className="w-full h-full object-cover rounded-md"
                        loading="lazy"
                        onError={(e) => { e.currentTarget.src = fallbackImageUrl; }}
                    />
                    <span className="absolute top-2 left-2 inline-flex items-center gap-1.5 px-2 py-0.5 rounded-full text-xs font-medium border bg-white/80 backdrop-blur-sm text-gray-700 border-gray-200 shadow-sm">
                        <PropertyIcon size={14} /> {property_type} (Rental)
                    </span>
                </div>

                {/* Content */}
                <div className="flex-grow flex flex-col justify-between">
                    <div>
                        {/* Property Info */}
                        <h2 className="text-lg font-semibold text-gray-800 mb-1 line-clamp-1 group-hover:text-gray-600 transition-colors" title={postTitle}>
                            {postTitle}
                        </h2>
                        <p className="text-sm text-gray-500 mb-1 flex items-center gap-1">
                            <IconMapPin size={14} /> {address}
                        </p>
                        <p className="text-xs text-gray-500 mb-3">
                            {locality}, {city}
                        </p>


                        {/* Landlord Info */}
                        <div className="mb-4 pt-3 border-t border-gray-100">
                            <h3 className="text-xs font-medium text-gray-500 mb-1.5 flex items-center gap-1">
                                <IconUser size={14} /> Landlord Info
                            </h3>
                            <div className="space-y-1 text-sm text-gray-700">
                                {landlord_name && <p>Name: {landlord_name}</p>}
                                {landlord_email && <p className='flex items-center gap-1'><IconMail size={12} /> <a href={`mailto:${landlord_email}`} onClick={(e) => e.stopPropagation()} className="text-gray-600 hover:underline">{landlord_email}</a></p>}
                                {landlord_phone && <p className='flex items-center gap-1'><IconPhone size={12} /> <a href={`tel:${landlord_phone}`} onClick={(e) => e.stopPropagation()} className="text-gray-600 hover:underline">+{landlord_phone}</a></p>}
                                {!landlord_name && !landlord_email && !landlord_phone && <p className="text-xs text-gray-500 italic">Contact info not available.</p>}
                            </div>
                        </div>

                        {/* Rent Dues Section */}
                        {rentDues && rentDues.length > 0 && (
                            <div className="mb-4">
                                <h3 className="text-sm font-medium text-gray-500 mb-1.5">Upcoming/Overdue Rent</h3>
                                {rentDues.map(due => <RentDueTenantCard key={due.rent_record_id} rentDue={due} />)}
                            </div>
                        )}
                    </div>

                    {/* Actions */}
                    <div className="mt-auto pt-3 border-t border-gray-100 flex flex-wrap gap-2 justify-end">
                        <button
                            onClick={fetchAndShowInternalImages}
                            className={getSecondaryButtonClasses() + " !text-xs !px-3 !py-1.5 flex items-center gap-1 whitespace-nowrap"}
                            title="View Internal Photos (Inspections, Documents, etc.)"
                            disabled={internalImagesLoading}
                        >
                            {internalImagesLoading ? <LoadingSpinner size={14} /> : <IconPhotoScan size={14} />}
                            {internalImagesLoading ? 'Loading...' : 'Internal Photos'}
                        </button>
                        <button
                            onClick={handleCreateTicketClick}
                            className={getSecondaryButtonClasses() + " !text-xs !px-3 !py-1.5 flex items-center gap-1"}
                            disabled={internalImagesLoading}
                        >
                            <IconTicket size={14} /> Raise a Ticket
                        </button>
                    </div>
                </div>
            </div>

            {/* Internal Images Modal */}
            <Transition appear show={isInternalImagesModalOpen} as={Fragment}>
                <Dialog as="div" className="relative z-50" onClose={closeModal}>
                    <TransitionChild as={Fragment} enter="ease-out duration-300" enterFrom="opacity-0" enterTo="opacity-100" leave="ease-in duration-200" leaveFrom="opacity-100" leaveTo="opacity-0">
                        <div className="fixed inset-0 bg-black/40 backdrop-blur-sm" />
                    </TransitionChild>

                    <div className="fixed inset-0 overflow-y-auto">
                        <div className="flex min-h-full items-center justify-center p-4 text-center">
                            <TransitionChild as={Fragment} enter="ease-out duration-300" enterFrom="opacity-0 scale-95" enterTo="opacity-100 scale-100" leave="ease-in duration-200" leaveFrom="opacity-100 scale-100" leaveTo="opacity-0 scale-95">
                                <DialogPanel className="w-full max-w-3xl transform overflow-hidden rounded-2xl bg-white p-6 text-left align-middle shadow-xl transition-all">
                                    <DialogTitle as="h3" className="text-lg font-semibold leading-6 text-gray-900 flex justify-between items-center">
                                        Internal Photos & Documents
                                        <button onClick={closeModal} className="text-gray-400 hover:text-gray-600"><IconX size={20} /></button>
                                    </DialogTitle>
                                    <p className="text-sm text-gray-500 mt-1 mb-4">For property: {postTitle} ({address})</p>

                                    <div className="mt-4 max-h-[60vh] overflow-y-auto custom-scrollbar pr-2">
                                        {internalImagesLoading ? (
                                            <div className="flex justify-center items-center h-40"><LoadingSpinner /></div>
                                        ) : internalImagesError ? (
                                            <div className="bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded-lg text-center flex flex-col items-center gap-2 shadow-sm">
                                                <IconAlertCircle size={24} /> Error loading images: {internalImagesError}
                                            </div>
                                        ) : internalImages.length === 0 ? (
                                            <p className="text-gray-500 text-center italic py-6">No internal images or documents found for this property.</p>
                                        ) : (
                                            <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 gap-4">
                                                {internalImages.map((image) => (
                                                    <div key={image.image_id} className="border rounded-lg overflow-hidden bg-gray-50 shadow-sm">
                                                        <a href={image.image_url} target="_blank" rel="noopener noreferrer" title="Click to view full size">
                                                            <img
                                                                src={image.image_url}
                                                                alt={image.description || 'Internal image'}
                                                                className="w-full h-48 object-cover cursor-pointer hover:opacity-90 transition-opacity"
                                                                loading="lazy"
                                                            />
                                                        </a>
                                                        <div className="p-3 text-xs">
                                                            {image.description && (
                                                                <p className="text-gray-800 mb-1 flex items-start gap-1.5">
                                                                    <IconFileDescription size={14} className="flex-shrink-0 mt-0.5 text-gray-400" />
                                                                    <span>{image.description}</span>
                                                                </p>
                                                            )}
                                                        </div>
                                                    </div>
                                                ))}
                                            </div>
                                        )}
                                    </div>

                                    <div className="mt-5 text-right">
                                        <button type="button" className={getTertiaryButtonClasses()} onClick={closeModal}> Close </button>
                                    </div>
                                </DialogPanel>
                            </TransitionChild>
                        </div>
                    </div>
                </Dialog>
            </Transition>
        </>
    );
}

export default OccupiedPropertyCard;