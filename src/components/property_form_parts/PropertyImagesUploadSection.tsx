import React, { ChangeEvent } from 'react';
import FormFieldWrapper from './FormFieldWrapper';
import { IconPhotoUp, IconX } from '@tabler/icons-react';

export interface ImageFileForUpload {
    file: File;
    previewUrl: string;
    description?: string;
}

interface Props {
    images: ImageFileForUpload[];
    onImageFilesSelected: (event: ChangeEvent<HTMLInputElement>) => void;
    onRemoveImage: (index: number) => void;
    formErrors: Partial<Record<'images', string>>;
    maxImages?: number;
    disabled?: boolean;
}

const PropertyImagesUploadSection: React.FC<Props> = ({
    images, onImageFilesSelected, onRemoveImage, formErrors, maxImages = 10, disabled = false
}) => {
    return (
        <div className="md:col-span-2">
            <FormFieldWrapper label={`Upload Photos (${images.length}/${maxImages})`} htmlFor="imageUpload" required errorMessage={formErrors.images} disabled={disabled}>
                <>
                    <label htmlFor="imageUpload" className={`
                        relative cursor-pointer bg-white rounded-md font-medium text-gray-800 hover:text-gray-500 focus-within:outline-none focus-within:ring-2 focus-within:ring-offset-2 focus-within:ring-gray-500 border border-gray-300 px-4 py-2 inline-flex items-center ${images.length >= maxImages || disabled ? 'opacity-50 cursor-not-allowed' : ''}
                    `}>
                        <IconPhotoUp size={20} className="mr-2" />
                        <span>Choose files</span>
                        <input
                            id="imageUpload" name="images" type="file" className="sr-only" multiple
                            accept="image/png,image/jpeg,image/webp"
                            onChange={onImageFilesSelected}
                            disabled={images.length >= maxImages || disabled}
                        />
                    </label>
                    <p className='mt-2 text-xs text-gray-500'>
                        Upload at least one photo. Max {maxImages}. Accepted: JPG, PNG, WebP. Max 5MB each. Rec. 1024x768.
                    </p>
                </>
            </FormFieldWrapper>

            {images.length > 0 && (
                <div className="mt-4 grid grid-cols-3 sm:grid-cols-4 md:grid-cols-5 gap-3">
                    {images.map((image, index) => (
                        <div key={index} className="relative group aspect-square border rounded-md overflow-hidden shadow-sm">
                            <img src={image.previewUrl} alt={image.description || `Preview ${index + 1}`} className="w-full h-full object-cover" />
                            {image.description && <div className="absolute bottom-0 left-0 right-0 bg-black/60 text-white text-[10px] p-1 truncate" title={image.description}>{image.description}</div>}
                            <button type="button" onClick={() => onRemoveImage(index)}
                                className="absolute top-1 right-1 bg-red-600 text-white rounded-full p-0.5 opacity-70 group-hover:opacity-100 transition-opacity focus:outline-none focus:ring-2 focus:ring-red-500 focus:ring-offset-1"
                                aria-label="Remove image" disabled={disabled}>
                                <IconX size={12} stroke={3} />
                            </button>
                        </div>
                    ))}
                </div>
            )}
        </div>
    );
};

export default PropertyImagesUploadSection;