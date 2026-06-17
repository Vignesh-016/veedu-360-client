import React, { useState, useEffect, ChangeEvent } from 'react';
import { useLocation, useNavigate, Link } from 'react-router-dom';

import { useAuth } from '../lib/AuthContext';
import api from '../lib/supabaseClient';
import { TicketCategory } from '../lib/types';
import { getPrimaryButtonClasses, getBaseInputClasses } from '../lib/twUtils';
import LoadingSpinner from '../components/LoadingSpinner';
import { useNotification } from '../components/NotificationProvider';
import { IconAlertCircle, IconArrowLeft, IconBuilding, IconInfoCircle, IconPhotoUp, IconX } from '@tabler/icons-react';
import { Constants } from '../database.types';
import { compressAndResizeImage } from '../lib/imageUtils';

interface ImageFile {
    file: File;
    previewUrl: string;
}

// Define a type for form errors specific to this form
type CreateTicketFormErrorKeys = 'subject' | 'description' | 'category' | 'images';
type FormErrors = Partial<Record<CreateTicketFormErrorKeys, string>>;


function CreateTicket() {
    const { user } = useAuth();
    const navigate = useNavigate();
    const location = useLocation();
    const { showSuccessNotification, showErrorNotification, showInfoNotification } = useNotification();

    // State from navigation
    const propertyId = location.state?.propertyId as string | undefined;
    const propertyAddress = location.state?.propertyAddress as string | undefined;

    const [subject, setSubject] = useState('');
    const [description, setDescription] = useState('');
    const [category, setCategory] = useState<TicketCategory>('GENERAL_INQUIRY');
    const [images, setImages] = useState<ImageFile[]>([]);
    const [loading, setLoading] = useState(false);
    const [uploadingImages, setUploadingImages] = useState(false);
    const [error, setError] = useState<string | null>(null);
    const [formErrors, setFormErrors] = useState<FormErrors>({});

    useEffect(() => {
        if (!propertyId) {
            showErrorNotification('Missing Info', 'Property ID not provided.');
            navigate('/my-rentals');
        }
        // Cleanup object URLs on unmount
        return () => {
            images.forEach(img => URL.revokeObjectURL(img.previewUrl));
        };
    }, [propertyId, navigate, showErrorNotification, images]);

    const validateForm = (): boolean => {
        const errors: FormErrors = {};
        if (!subject.trim()) errors.subject = 'Subject is required.';
        if (subject.length > 100) errors.subject = 'Subject cannot exceed 100 characters.';
        if (!description.trim()) errors.description = 'Description is required.';
        if (description.length > 1000) errors.description = 'Description cannot exceed 1000 characters.';
        if (!category) errors.category = 'Category is required.';

        setFormErrors(errors);
        return Object.keys(errors).length === 0;
    };

    // --- Image Handling ---
    const handleImageChange = async (event: ChangeEvent<HTMLInputElement>) => {
        if (formErrors.images) {
            setFormErrors(prev => {
                const { images, ...rest } = prev;
                return rest;
            });
        }
        const files = event.target.files;
        if (!files || files.length === 0) return;

        const maxImages = 5;
        if (images.length + files.length > maxImages) {
            showErrorNotification('Upload Limit', `You can upload a maximum of ${maxImages} images.`);
            return;
        }

        setUploadingImages(true);
        try {
            const newImages: ImageFile[] = [];
            for (const file of Array.from(files)) {
                if (images.length + newImages.length >= maxImages) break;
                if (file.size > 5 * 1024 * 1024) { // 5MB limit
                    showErrorNotification('File Too Large', `Skipping ${file.name}, size exceeds 5MB.`);
                    continue;
                }
                try {
                    const compressedFile = await compressAndResizeImage(file);
                    const previewUrl = URL.createObjectURL(compressedFile);
                    newImages.push({ file: compressedFile, previewUrl });
                } catch (compError: any) {
                    showErrorNotification('Compression Failed', `Could not process ${file.name}: ${compError.message}`);
                    console.error(`Compression failed for ${file.name}:`, compError);
                }
            }
            setImages(prev => [...prev, ...newImages]);
        } catch (err: any) {
            showErrorNotification('Image Error', 'An error occurred while adding images.');
            console.error(err);
        } finally {
            setUploadingImages(false);
            event.target.value = ''; // Clear file input
        }
    };

    const removeImage = (index: number) => {
        URL.revokeObjectURL(images[index].previewUrl);
        setImages(prev => prev.filter((_, i) => i !== index));
    };
    // --- End Image Handling ---

    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault();
        setError(null);
        if (!validateForm() || !propertyId || !user) {
            if (!user) setError("You must be logged in.");
            if (!propertyId) setError("Property ID is missing.");
            return;
        }

        setLoading(true);
        let createdTicketId: number | null = null;
        let imagesFailed = false;

        try {
            // Step 1: Create the ticket without images
            showInfoNotification('Submitting Request', 'Creating your ticket...');
            const { data: ticketId, error: createError } = await api.createTicket({
                p_property_id: propertyId,
                p_subject: subject.trim(),
                p_description: description.trim(),
                p_category: category,
            });

            if (createError || !ticketId) throw createError || new Error("Failed to get ticket ID after creation.");
            createdTicketId = ticketId;
            showInfoNotification('Ticket Created', `Ticket #${createdTicketId} created. Uploading images...`);

            // Step 2: Upload images if any were selected
            if (images.length > 0) {
                setUploadingImages(true);
                const imageFilesOnly = images.map(img => img.file);
                const { error: imageError } = await api.uploadTicketImages(createdTicketId, imageFilesOnly);
                setUploadingImages(false);

                if (imageError) {
                    imagesFailed = true;
                    // Don't throw, just notify, as ticket is created
                    showErrorNotification('Image Upload Failed', `Ticket created, but image upload failed: ${imageError}. You can add them later.`);
                    console.error("Error uploading ticket images:", imageError);
                }
            }

            if (!imagesFailed) {
                showSuccessNotification('Ticket Submitted Successfully', `Your request (ID: ${createdTicketId}) has been submitted.`);
            }
            navigate('/my-tickets'); // Redirect even if images failed

        } catch (err: any) {
            console.error("Error during ticket submission process:", err);
            const message = typeof err === 'string' ? err : err.message || 'Failed to submit ticket.';
            setError(message);
            showErrorNotification('Submission Failed', message);
            // If ticket creation failed, we stop here. If image upload failed, we already navigated.
        } finally {
            setLoading(false); // Reset overall loading state
            setUploadingImages(false); // Ensure image upload state is reset
        }
    };

    const ticketCategoryOptions = Constants.public.Enums.ticket_category_enum;

    const companyName = import.meta.env.VITE_COMPANY_NAME;

    return (
        <div className="bg-gray-50 min-h-screen py-8">
            <title>Submit Request | {companyName}</title>
            <div className="container mx-auto px-4 max-w-2xl">
                <Link to="/my-rentals" className="text-sm text-gray-600 hover:underline mb-4 inline-flex items-center">
                    <IconArrowLeft size={16} className="mr-1" /> Back to My Rentals
                </Link>
                <h1 className="text-2xl md:text-3xl font-bold text-gray-800 mb-2">
                    Submit Request / Inquiry
                </h1>
                {propertyAddress && (
                    <p className="text-sm text-gray-500 mb-6 flex items-center gap-1">
                        <IconBuilding size={14} /> For Property: {propertyAddress}
                    </p>
                )}

                <form onSubmit={handleSubmit} noValidate className="bg-white p-6 rounded-lg shadow border border-gray-200 space-y-4">
                    {error && (
                        <div className="bg-red-50 border border-red-200 text-red-700 px-4 py-2 rounded-md text-sm flex items-center gap-2" role="alert">
                            <IconAlertCircle className="h-5 w-5 flex-shrink-0" />
                            <span>{error}</span>
                        </div>
                    )}

                    {!propertyId && (
                        <div className="bg-yellow-50 border border-yellow-200 text-yellow-700 px-4 py-2 rounded-md text-sm flex items-center gap-2">
                            <IconInfoCircle className="h-5 w-5 flex-shrink-0" />
                            <span>Property information is missing. Please navigate from 'My Rentals'.</span>
                        </div>
                    )}

                    {/* Subject */}
                    <div>
                        <label htmlFor="subject" className="block text-sm font-medium text-gray-700 mb-1">
                            Subject <span className="text-red-500">*</span>
                        </label>
                        <input
                            type="text" id="subject" value={subject}
                            onChange={(e) => setSubject(e.target.value)}
                            className={getBaseInputClasses(!!formErrors.subject)}
                            maxLength={100} placeholder="e.g., Leaking faucet in kitchen, Rent payment query" required
                        />
                        {formErrors.subject && <p className="mt-1 text-xs text-red-600">{formErrors.subject}</p>}
                    </div>

                    {/* Category */}
                    <div>
                        <label htmlFor="category" className="block text-sm font-medium text-gray-700 mb-1">
                            Category <span className="text-red-500">*</span>
                        </label>
                        <select
                            id="category" value={category}
                            onChange={(e) => setCategory(e.target.value as TicketCategory)}
                            className={getBaseInputClasses(!!formErrors.category)} required
                        >
                            {ticketCategoryOptions.map(cat => (
                                <option key={cat} value={cat}>
                                    {cat.replace(/_/g, ' ').replace(/\b\w/g, l => l.toUpperCase())}
                                </option>
                            ))}
                        </select>
                        {formErrors.category && <p className="mt-1 text-xs text-red-600">{formErrors.category}</p>}
                    </div>

                    {/* Description */}
                    <div>
                        <label htmlFor="description" className="block text-sm font-medium text-gray-700 mb-1">
                            Description <span className="text-red-500">*</span>
                        </label>
                        <textarea
                            id="description" value={description}
                            onChange={(e) => setDescription(e.target.value)}
                            className={`${getBaseInputClasses(!!formErrors.description)} min-h-[120px]`}
                            maxLength={1000} placeholder="Please provide details about your request or inquiry..." required
                        />
                        <p className="mt-1 text-xs text-gray-500">{description.length}/1000 characters</p>
                        {formErrors.description && <p className="mt-1 text-xs text-red-600">{formErrors.description}</p>}
                    </div>

                    {/* Image Upload */}
                    <div>
                        <label htmlFor="imageUpload" className="block text-sm font-medium text-gray-700 mb-1">
                            Attach Images (Optional, Max 5)
                        </label>
                        <label htmlFor="imageUpload" className={`
                            relative cursor-pointer bg-white rounded-md font-medium text-gray-600 hover:text-gray-500 focus-within:outline-none focus-within:ring-2 focus-within:ring-offset-2 focus-within:ring-indigo-500 border border-gray-300 px-4 py-2 inline-flex items-center ${images.length >= 5 || uploadingImages || loading ? 'opacity-50 cursor-not-allowed' : ''}
                        `}>
                            <IconPhotoUp size={20} className="mr-2" />
                            <span>{uploadingImages ? 'Processing...' : 'Choose Files'}</span>
                            <input
                                id="imageUpload" name="images" type="file" className="sr-only" multiple
                                accept="image/png, image/jpeg, image/webp"
                                onChange={handleImageChange}
                                disabled={images.length >= 5 || uploadingImages || loading}
                            />
                        </label>
                        <p className="mt-1 text-xs text-gray-500">Max 5MB per image. JPG, PNG, WebP accepted.</p>
                        {formErrors.images && <p className="mt-1 text-xs text-red-600">{formErrors.images}</p>}

                        {/* Image Previews */}
                        {images.length > 0 && (
                            <div className="mt-4 grid grid-cols-3 sm:grid-cols-4 md:grid-cols-5 gap-3">
                                {images.map((image, index) => (
                                    <div key={index} className="relative group aspect-square border rounded-md overflow-hidden shadow-sm">
                                        <img src={image.previewUrl} alt={`Preview ${index + 1}`} className="w-full h-full object-cover" />
                                        <button
                                            type="button"
                                            onClick={() => removeImage(index)}
                                            className="absolute top-1 right-1 bg-red-600 text-white rounded-full p-0.5 opacity-70 group-hover:opacity-100 transition-opacity focus:outline-none focus:ring-2 focus:ring-red-500 focus:ring-offset-1"
                                            aria-label="Remove image"
                                            disabled={loading || uploadingImages}
                                        >
                                            <IconX size={12} stroke={3} />
                                        </button>
                                    </div>
                                ))}
                            </div>
                        )}
                    </div>

                    {/* Submit Button */}
                    <div className="pt-4 flex justify-end">
                        <button
                            type="submit"
                            disabled={loading || uploadingImages || !propertyId}
                            className={`${getPrimaryButtonClasses()} px-6 py-2 disabled:opacity-50`}
                        >
                            {loading ? <LoadingSpinner /> : 'Submit Ticket'}
                        </button>
                    </div>
                </form>
            </div>
        </div>
    );
}

export default CreateTicket;