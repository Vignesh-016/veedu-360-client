// src/components/ShareSheetModal.tsx
import React, { Fragment } from 'react';
import { Dialog, Transition, TransitionChild, DialogPanel } from '@headlessui/react';
import {
    IconX,
    IconBrandWhatsapp,
    IconBrandInstagram,
    IconBrandFacebook,
    IconBrandX, // Using IconBrandX for X (Twitter)
    IconLink,
} from '@tabler/icons-react';
import { useNotification } from './NotificationProvider';

interface ShareSheetModalProps {
    isOpen: boolean;
    onClose: () => void;
    propertyId: string;
    propertyType: string; // e.g., "House", "Land", "Apartment". Should be human-readable.
    propertyName?: string; // Optional: For future use or if specific platforms could use it
}

const ShareSheetModal: React.FC<ShareSheetModalProps> = ({
    isOpen,
    onClose,
    propertyId,
    propertyType,
    // propertyName, // Currently not used in the share message as per template
}) => {
    const { showSuccessNotification, showErrorNotification } = useNotification();
    const companyName = import.meta.env.VITE_COMPANY_NAME || 'Our Company';
    const baseUrl = typeof window !== 'undefined' ? window.location.origin : '';
    const propertyUrl = `${baseUrl}/property/${propertyId}`;

    // Prepare share messages
    const shareTitleText = `Check out this ${propertyType.toLowerCase()} from ${companyName}`;
    const fullShareMessageWithLink = `${shareTitleText}\n${propertyUrl}`;

    const handleCopyToClipboard = async (textToCopy: string, successMessage: string) => {
        try {
            await navigator.clipboard.writeText(textToCopy);
            showSuccessNotification('Copied!', successMessage);
        } catch (err) {
            console.error('Failed to copy text: ', err);
            showErrorNotification('Copy Failed', 'Could not copy to clipboard. Your browser might not support this feature or permissions might be denied.');
        }
    };

    const socialPlatforms = [
        {
            name: 'WhatsApp',
            icon: IconBrandWhatsapp,
            colorClass: 'text-green-500 hover:bg-green-50',
            action: () => {
                const whatsappUrl = `https://api.whatsapp.com/send?text=${encodeURIComponent(fullShareMessageWithLink)}`;
                window.open(whatsappUrl, '_blank', 'noopener,noreferrer');
            },
        },
        {
            name: 'Facebook',
            icon: IconBrandFacebook,
            colorClass: 'text-blue-600 hover:bg-blue-50',
            action: () => {
                const facebookUrl = `https://www.facebook.com/sharer/sharer.php?u=${encodeURIComponent(propertyUrl)}"e=${encodeURIComponent(shareTitleText)}`;
                window.open(facebookUrl, '_blank', 'noopener,noreferrer');
            },
        },
        {
            name: 'X',
            icon: IconBrandX,
            colorClass: 'text-black hover:bg-gray-100',
            action: () => {
                const twitterUrl = `https://twitter.com/intent/tweet?url=${encodeURIComponent(propertyUrl)}&text=${encodeURIComponent(shareTitleText)}`;
                window.open(twitterUrl, '_blank', 'noopener,noreferrer');
            },
        },
        {
            name: 'Instagram',
            icon: IconBrandInstagram,
            colorClass: 'text-pink-500 hover:bg-pink-50',
            action: () => handleCopyToClipboard(fullShareMessageWithLink, 'Message & link copied! Paste it in your Instagram post or story.'),
        },
    ];

    return (
        <Transition appear show={isOpen} as={Fragment}>
            <Dialog as="div" className="relative z-50" onClose={onClose}>
                <TransitionChild
                    as={Fragment}
                    enter="ease-out duration-300"
                    enterFrom="opacity-0"
                    enterTo="opacity-100"
                    leave="ease-in duration-200"
                    leaveFrom="opacity-100"
                    leaveTo="opacity-0"
                >
                    <div className="fixed inset-0 bg-black/30 backdrop-blur-sm" />
                </TransitionChild>

                <div className="fixed inset-0 overflow-y-auto">
                    <div className="flex min-h-full items-center justify-center p-4 text-center">
                        <TransitionChild
                            as={Fragment}
                            enter="ease-out duration-300"
                            enterFrom="opacity-0 scale-95"
                            enterTo="opacity-100 scale-100"
                            leave="ease-in duration-200"
                            leaveFrom="opacity-100 scale-100"
                            leaveTo="opacity-0 scale-95"
                        >
                            <DialogPanel className="w-full max-w-md transform overflow-hidden rounded-2xl bg-white p-6 text-left align-middle shadow-xl transition-all">
                                <div className="flex justify-between items-center mb-4">
                                    <h3 className="text-lg font-medium leading-6 text-gray-900">
                                        Share this Property
                                    </h3>
                                    <button
                                        type="button"
                                        className="p-1 rounded-full text-gray-400 hover:bg-gray-100 hover:text-gray-600 focus:outline-none focus:ring-2 focus:ring-gray-500 focus:ring-offset-1"
                                        onClick={onClose}
                                        aria-label="Close share modal"
                                    >
                                        <IconX size={20} />
                                    </button>
                                </div>

                                <div className="mt-2 space-y-3">
                                    <p className="text-sm text-gray-500 mb-4">
                                        {shareTitleText}
                                    </p>
                                    <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
                                        {socialPlatforms.map((platform) => (
                                            <button
                                                key={platform.name}
                                                onClick={platform.action}
                                                className={`flex flex-col items-center justify-center p-3 sm:p-4 border border-gray-200 rounded-lg transition-colors duration-150 ${platform.colorClass} focus:outline-none focus:ring-2 focus:ring-offset-1 focus:ring-gray-400 aspect-square`}
                                                title={`Share on ${platform.name}`}
                                            >
                                                <platform.icon size={28} className="mb-1.5" />
                                                <span className="text-xs font-medium text-gray-700">{platform.name}</span>
                                            </button>
                                        ))}
                                    </div>

                                    <div className="mt-4 pt-4 border-t border-gray-200">
                                        <button
                                            onClick={() => handleCopyToClipboard(propertyUrl, 'Property link copied to clipboard!')}
                                            className="w-full flex items-center justify-center px-4 py-2.5 border border-gray-300 rounded-lg text-sm font-medium text-gray-700 bg-gray-50 hover:bg-gray-100 focus:outline-none focus:ring-2 focus:ring-offset-1 focus:ring-gray-400"
                                        >
                                            <IconLink size={18} className="mr-2" />
                                            Copy Property Link
                                        </button>
                                    </div>
                                </div>
                            </DialogPanel>
                        </TransitionChild>
                    </div>
                </div>
            </Dialog>
        </Transition>
    );
};

export default ShareSheetModal;