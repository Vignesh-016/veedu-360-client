import React from 'react';
import { Property, VisitStatus, InteractionStatus } from '../../lib/types';
import { formatPrice } from '../../lib/formatUtils';
import { getPrimaryButtonClasses, getSecondaryButtonClasses, getTertiaryButtonClasses } from '../../lib/twUtils';
import LoadingSpinner from '../LoadingSpinner';
import { Link } from 'react-router-dom';
import { IconCalendarPlus, IconHeart, IconShare, IconInfoCircle, IconCash, IconClipboardCheck, IconExternalLink } from '@tabler/icons-react';
import { useAuth } from '../../lib/AuthContext';

interface ActionCardProps {
    details: Property;
    isWishlisted: boolean;
    onWishlistToggle: () => void;
    onPrimaryAction: () => void;
    onBookAnotherVisit: () => void;
    wishlistLoading: boolean;
    primaryActionLoading: boolean;
    balance: VisitStatus | undefined;
    onShare: () => void;
}

const ActionCard: React.FC<ActionCardProps> = ({
    details, isWishlisted, onWishlistToggle, onPrimaryAction, onBookAnotherVisit,
    wishlistLoading, primaryActionLoading, balance, onShare
}) => {
    const { user } = useAuth();
    const priceFormatted = formatPrice(details.price);

    let primaryActionText = "Book a Visit";
    let PrimaryActionIcon: React.ElementType = IconCalendarPlus;
    let isLinkAction = false;
    let linkToAction = "";
    let infoText = "Booking uses 1 visit credit. Status in Wishlist.";
    let showBookAnotherVisit = false;

    const isVisitInProgress = details.interaction_status && ['VISIT_PENDING', 'VISIT_CONFIRMED_PENDING_SALES', 'VISIT_SCHEDULED_WITH_SALES'].includes(details.interaction_status);

    if (details.listing_type === 'RENTAL') {
        switch (details.interaction_status as InteractionStatus | null) {
            case 'VISIT_COMPLETED':
                primaryActionText = "Apply to Rent";
                PrimaryActionIcon = IconClipboardCheck;
                infoText = "Submit your application to start the rental process.";
                showBookAnotherVisit = true; // Show the "Book Another Visit" button
                break;
            case 'RENTAL_APPLICATION_SUBMITTED':
            case 'LEASE_CONVERTED':
                primaryActionText = "View Application Status";
                PrimaryActionIcon = IconExternalLink;
                isLinkAction = true;
                linkToAction = "/my-applications";
                infoText = "Track your rental application progress.";
                break;
            default:
                break;
        }
    }

    let primaryActionDisabled = primaryActionLoading || wishlistLoading || isVisitInProgress;
    if (primaryActionText === "Book a Visit" && balance && balance.visit_balance <= 0 && !isLinkAction) {
        primaryActionText = "Buy Visits to Book";
        PrimaryActionIcon = IconCalendarPlus;
        isLinkAction = true;
        linkToAction = "/plans";
        primaryActionDisabled = false;
        infoText = "You have no visit credits left. Purchase a plan to book more visits.";
    }


    const getPrimaryActionElement = () => {
        if (isLinkAction) {
            const buttonClasses = `${getPrimaryButtonClasses()} w-full text-sm ${primaryActionText === "Buy Visits to Book" ? "!bg-orange-500 hover:!bg-orange-600" : ""}`;
            return (
                <Link to={linkToAction} className={buttonClasses}>
                    <PrimaryActionIcon size={18} className="mr-1.5" />
                    {primaryActionText}
                </Link>
            );
        }
        return (
            <button
                onClick={onPrimaryAction}
                disabled={primaryActionDisabled}
                className={`${getPrimaryButtonClasses()} w-full text-sm`}
                title={isVisitInProgress ? "A visit for this property is already in progress." : ""}
            >
                {primaryActionLoading ? <LoadingSpinner size={18} /> : <PrimaryActionIcon size={18} className="mr-1.5" />}
                {primaryActionText}
                {primaryActionText === "Book a Visit" && balance && balance.visit_balance > 0 && !isVisitInProgress &&
                    <span className='ml-1 text-xs opacity-80'>({balance.visit_balance} left)</span>
                }
            </button>
        );
    };

    return (
        <div className="bg-white p-5 rounded-lg border border-gray-200 shadow-sm">
            <div className="mb-4 pb-4 border-b border-gray-100">
                <span className="block text-sm text-gray-500 mb-1">{details.listing_type === 'RENTAL' ? 'Rent Per Month' : 'Price'}</span>
                <span className="text-3xl font-bold text-gray-800">{priceFormatted}</span>
                {details.listing_type === 'RENTAL' && details.advance_amount && details.advance_amount > 0 && (
                    <div className="mt-2 flex items-center text-sm text-gray-600">
                        <IconCash size={16} className="mr-1.5 text-gray-400" />
                        <span>Advance: <span className="font-medium">{formatPrice(details.advance_amount)}</span></span>
                    </div>
                )}
            </div>
            <div className="space-y-3">
                {getPrimaryActionElement()}

                {showBookAnotherVisit && (
                    <button
                        onClick={onBookAnotherVisit} // Use the new, specific handler
                        disabled={primaryActionLoading || wishlistLoading || (balance && balance.visit_balance <= 0)}
                        className={`${getSecondaryButtonClasses()} w-full text-sm`}
                    >
                        <IconCalendarPlus size={16} className="mr-1.5" />
                        Book Another Visit
                    </button>
                )}

                <div className="flex items-center gap-2">
                    <button
                        onClick={onWishlistToggle}
                        disabled={wishlistLoading || primaryActionLoading || !user}
                        className={`${getSecondaryButtonClasses()} w-full text-sm ${isWishlisted ? '!border-pink-500 !text-pink-600 hover:!bg-pink-50' : ''}`}
                        title={!user ? "Login to add to wishlist" : (isWishlisted ? "Remove from Wishlist" : "Add to Wishlist")}
                    >
                        {wishlistLoading ? <LoadingSpinner size={16} /> : <IconHeart size={16} fill={isWishlisted ? 'currentColor' : 'none'} className="mr-1.5" />}
                        {isWishlisted ? 'Wishlisted' : 'Add to Wishlist'}
                    </button>
                    <button
                        onClick={onShare}
                        className={getTertiaryButtonClasses() + " px-3 border border-gray-300 text-gray-500 hover:bg-gray-100"}
                        aria-label="Share Property"
                        title="Share Property"
                    >
                        <IconShare size={18} />
                    </button>
                </div>
            </div>
            {infoText && (
                <p className="text-xs text-gray-500 mt-4 text-center">
                    <IconInfoCircle size={14} className="inline mr-1" />
                    {infoText}
                </p>
            )}
        </div>
    );
};

export default ActionCard;