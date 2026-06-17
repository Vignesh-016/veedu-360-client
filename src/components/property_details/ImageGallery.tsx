import React, { useState, Fragment } from 'react';
import { PropertyImage } from '../../lib/types';
import { IconChevronLeft, IconChevronRight, IconLayoutGrid, IconX } from '@tabler/icons-react';
import { Dialog, DialogPanel, Transition, TransitionChild } from '@headlessui/react';

interface ImageGalleryProps {
    images: PropertyImage[];
    propertyName: string;
}

const ImageGallery: React.FC<ImageGalleryProps> = ({ images, propertyName }) => {
    const [currentIndex, setCurrentIndex] = useState(0);
    const [lightboxOpen, setLightboxOpen] = useState(false);
    const fallbackImageUrl = `https://placehold.co/1200x800/e2e8f0/94a3b8?text=${encodeURIComponent(propertyName)}`;

    if (!images || images.length === 0) {
        return <img src={fallbackImageUrl} alt={`Placeholder for ${propertyName}`} className="w-full aspect-[4/3] object-contain bg-gray-100 rounded-lg shadow-md border border-gray-200" />;
    }

    const sortedImages = [...images].sort((a, b) => a.display_order - b.display_order);

    const goToSlide = (index: number) => {
        let newIndex = index % sortedImages.length;
        if (newIndex < 0) {
            newIndex = sortedImages.length - 1;
        }
        setCurrentIndex(newIndex);
    };

    const openLightbox = (index: number) => {
        setCurrentIndex(index);
        setLightboxOpen(true);
    };

    const closeLightbox = () => {
        setLightboxOpen(false);
    };

    const mainImageUrl = sortedImages[currentIndex]?.image_url || fallbackImageUrl;

    return (
        <div className="space-y-3">
            {/* Main Display Image */}
            <div
                className="relative w-full aspect-[16/10] sm:aspect-[2/1] overflow-hidden rounded-lg shadow-md border border-gray-200 bg-gray-100 group cursor-pointer"
                onClick={() => openLightbox(currentIndex)}
            >
                <img
                    src={mainImageUrl}
                    alt={`${propertyName} - Image ${currentIndex + 1}`}
                    className="w-full h-full object-contain transition-transform duration-300 group-hover:scale-105" // Changed from object-cover to object-contain
                    onError={(e) => { (e.target as HTMLImageElement).src = fallbackImageUrl; }}
                    loading="lazy"
                />
                {sortedImages.length > 1 && (
                    <>
                        <button onClick={(e) => { e.stopPropagation(); goToSlide(currentIndex - 1); }} className="absolute top-1/2 left-3 transform -translate-y-1/2 bg-black/50 text-white p-2 rounded-full hover:bg-black/70 transition-colors focus:outline-none z-10"> <IconChevronLeft size={20} /></button>
                        <button onClick={(e) => { e.stopPropagation(); goToSlide(currentIndex + 1); }} className="absolute top-1/2 right-3 transform -translate-y-1/2 bg-black/50 text-white p-2 rounded-full hover:bg-black/70 transition-colors focus:outline-none z-10"> <IconChevronRight size={20} /></button>
                        <div className="absolute bottom-3 right-3 bg-black/60 text-white text-xs px-2 py-0.5 rounded-full">{currentIndex + 1} / {sortedImages.length}</div>
                    </>
                )}
                {/* Removed gradient overlay as it might not look good with object-contain if there's letterboxing */}
                {/* <div className="absolute inset-0 bg-gradient-to-t from-black/30 via-transparent to-transparent opacity-70"></div> */}
                <div className="absolute bottom-3 left-3 flex items-center gap-1 text-white text-sm bg-black/50 px-2 py-1 rounded">
                    <IconLayoutGrid size={16} /> View Gallery
                </div>
            </div>

            {/* Thumbnails */}
            {sortedImages.length > 1 && (
                <div className="grid grid-cols-4 sm:grid-cols-5 md:grid-cols-6 gap-2">
                    {sortedImages.map((image, index) => (
                        <button
                            key={image.image_id || index}
                            onClick={() => setCurrentIndex(index)}
                            className={`aspect-[4/3] rounded-md overflow-hidden border-2 focus:outline-none focus:ring-gray-500 focus:ring-offset-1 transition-all bg-gray-100 ${currentIndex === index ? 'border-gray-500 shadow-md scale-105' : 'border-transparent hover:border-gray-400'}`}
                        >
                            <img
                                src={image.image_url || fallbackImageUrl}
                                alt={`Thumbnail ${index + 1}`}
                                className="w-full h-full object-cover" // Thumbnails can remain object-cover for a consistent grid
                                onError={(e) => { (e.target as HTMLImageElement).src = fallbackImageUrl; }}
                                loading="lazy"
                            />
                        </button>
                    ))}
                </div>
            )}

            {/* Lightbox Modal */}
            <Transition appear show={lightboxOpen} as={Fragment}>
                <Dialog as="div" className="relative z-[100]" onClose={closeLightbox}>
                    <TransitionChild as={Fragment} enter="ease-out duration-300" enterFrom="opacity-0" enterTo="opacity-100" leave="ease-in duration-200" leaveFrom="opacity-100" leaveTo="opacity-0">
                        <div className="fixed inset-0 bg-black/80 backdrop-blur-sm" />
                    </TransitionChild>
                    <div className="fixed inset-0 overflow-y-auto">
                        <div className="flex min-h-full items-center justify-center p-4">
                            <TransitionChild as={Fragment} enter="ease-out duration-300" enterFrom="opacity-0 scale-95" enterTo="opacity-100 scale-100" leave="ease-in duration-200" leaveFrom="opacity-100 scale-100" leaveTo="opacity-0 scale-95">
                                <DialogPanel className="w-full max-w-4xl transform overflow-hidden rounded-lg bg-gray-900 p-2 text-left align-middle shadow-xl transition-all relative"> {/* Changed lightbox background to dark */}
                                    <button onClick={closeLightbox} className="absolute top-2 right-2 bg-black/40 text-white p-1.5 rounded-full hover:bg-black/60 focus:outline-none z-20"><IconX size={20} /></button>
                                    <img
                                        src={sortedImages[currentIndex]?.image_url || fallbackImageUrl}
                                        alt={`Lightbox ${currentIndex + 1}`}
                                        className="w-full max-h-[85vh] object-contain" // Ensure max-h to fit viewport, object-contain
                                        onError={(e) => { (e.target as HTMLImageElement).src = fallbackImageUrl; }}
                                    />
                                    {sortedImages.length > 1 && (
                                        <>
                                            <button onClick={(e) => { e.stopPropagation(); goToSlide(currentIndex - 1); }} className="absolute top-1/2 left-3 transform -translate-y-1/2 bg-black/50 text-white p-2 rounded-full hover:bg-black/70 transition-colors focus:outline-none z-10"> <IconChevronLeft size={24} /></button>
                                            <button onClick={(e) => { e.stopPropagation(); goToSlide(currentIndex + 1); }} className="absolute top-1/2 right-3 transform -translate-y-1/2 bg-black/50 text-white p-2 rounded-full hover:bg-black/70 transition-colors focus:outline-none z-10"> <IconChevronRight size={24} /></button>
                                        </>
                                    )}
                                    <div className="absolute bottom-2 left-1/2 -translate-x-1/2 bg-black/60 text-white text-xs px-3 py-1 rounded-full">
                                        {currentIndex + 1} / {sortedImages.length}
                                    </div>
                                </DialogPanel>
                            </TransitionChild>
                        </div>
                    </div>
                </Dialog>
            </Transition>
        </div>
    );
};

export default ImageGallery;