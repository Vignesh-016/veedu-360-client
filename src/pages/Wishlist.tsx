import { useEffect, useState, useMemo, useCallback } from 'react';
import WishlistItemCard from '../components/WishlistItemCard';

import { useAuth } from '../lib/AuthContext';
import { WishlistItem, InteractionStatus } from '../lib/types';
import api from '../lib/supabaseClient';
import { parseISO, compareDesc, compareAsc } from 'date-fns';
import { IconHeart, IconAlertCircle } from '@tabler/icons-react';
import LoadingSpinner from '../components/LoadingSpinner';
import { useNotification } from '../components/NotificationProvider';
import { Link } from 'react-router-dom';
import { getPrimaryButtonClasses } from '../lib/twUtils';
import { getDisplayValue, interactionStatusMap } from '../lib/displayUtils';

const STATUS_ORDER: InteractionStatus[] = [
    "WISHLISTED",
    "VISIT_PENDING",
    "VISIT_CONFIRMED_PENDING_SALES",
    "VISIT_SCHEDULED_WITH_SALES",
    "VISIT_COMPLETED",
    "RENTAL_APPLICATION_SUBMITTED",
    "LEASE_CONVERTED",
    "VISIT_CANCELLED",
];


function Wishlist() {
    const [wishlistItems, setWishlistItems] = useState<WishlistItem[]>([]);
    const [loading, setLoading] = useState(false);
    const [error, setError] = useState<string | null>(null);
    const [activeTab, setActiveTab] = useState<InteractionStatus>('WISHLISTED');
    const { user } = useAuth();
    const { showSuccessNotification, showErrorNotification } = useNotification();

    const fetchWishlist = useCallback(async () => {
        if (!user) return;
        setLoading(true);
        setError(null);
        try {
            const { data, error: fetchError } = await api.getWishlist();
            if (fetchError) throw fetchError;
            setWishlistItems(data || []);
        } catch (err: any) {
            setError(err.message || 'Failed to fetch wishlist.');
            showErrorNotification('Load Failed', err.message || 'Failed to fetch wishlist.');
            setWishlistItems([]);
        } finally {
            setLoading(false);
        }
    }, [user, showErrorNotification]);

    useEffect(() => {
        fetchWishlist();
    }, [fetchWishlist]);

    // --- Grouping and Sorting Logic ---
    const groupedAndSortedItems = useMemo(() => {
        const groups: Record<string, WishlistItem[]> = {};
        STATUS_ORDER.forEach(status => { groups[status] = []; });

        wishlistItems.forEach(item => {
            if (item.interaction_status && groups[item.interaction_status]) {
                groups[item.interaction_status].push(item);
            } else if (item.interaction_status === null) { // Handle potential null status
                if (!groups['WISHLISTED']) groups['WISHLISTED'] = [];
                groups['WISHLISTED'].push(item);
            }
        });

        // Sort within each group
        const sortByScheduledAsc = (a: WishlistItem, b: WishlistItem) =>
            a.scheduled_for && b.scheduled_for ? compareAsc(parseISO(a.scheduled_for), parseISO(b.scheduled_for)) : 0;
        if (groups.VISIT_CONFIRMED_PENDING_SALES) groups.VISIT_CONFIRMED_PENDING_SALES.sort(sortByScheduledAsc);
        if (groups.VISIT_SCHEDULED_WITH_SALES) groups.VISIT_SCHEDULED_WITH_SALES.sort(sortByScheduledAsc);
        if (groups.VISIT_PENDING) groups.VISIT_PENDING.sort(sortByScheduledAsc);

        if (groups.WISHLISTED) groups.WISHLISTED.sort((a, b) => compareDesc(parseISO(a.created_at), parseISO(b.created_at)));
        if (groups.VISIT_COMPLETED) groups.VISIT_COMPLETED.sort((a, b) => a.visited_at && b.visited_at ? compareDesc(parseISO(a.visited_at), parseISO(b.visited_at)) : 0);

        const sortByUpdatedAtDesc = (a: WishlistItem, b: WishlistItem) => compareDesc(parseISO(a.updated_at), parseISO(b.updated_at));
        if (groups.RENTAL_APPLICATION_SUBMITTED) groups.RENTAL_APPLICATION_SUBMITTED.sort(sortByUpdatedAtDesc);
        if (groups.LEASE_CONVERTED) groups.LEASE_CONVERTED.sort(sortByUpdatedAtDesc);
        if (groups.VISIT_CANCELLED) groups.VISIT_CANCELLED.sort(sortByUpdatedAtDesc);

        return groups;
    }, [wishlistItems]);


    // --- Event Handlers ---
    const handleRemoveFromWishlist = async (propertyId: string) => {
        if (!user) return;
        const originalItems = [...wishlistItems];
        setWishlistItems(prevItems => prevItems.filter(item => !(item.property_id === propertyId && item.interaction_status === 'WISHLISTED')));

        try {
            const { error: removeError } = await api.removeFromWishlist(propertyId);
            if (removeError) {
                setWishlistItems(originalItems);
                throw removeError;
            }
            showSuccessNotification("Removed", "Property removed from your wishlist.");
        } catch (err: any) {
            showErrorNotification('Removal Failed', err.message || 'Could not remove item.');
        }
    };

    const handleItemUpdate = (updatedItem: WishlistItem) => {
        setWishlistItems(prevItems =>
            prevItems.map(item =>
                item.interaction_id === updatedItem.interaction_id ? { ...item, ...updatedItem } : item
            )
        );
    };

    // --- Render Logic ---
    const renderContent = () => {
        if (loading) {
            return (
                <div className="flex justify-center items-center py-20">
                    <LoadingSpinner />
                </div>
            );
        }

        if (error) {
            return (
                <div className="bg-gray-50 border border-gray-200 text-gray-700 px-4 py-3 rounded-lg text-center flex flex-col items-center gap-2 shadow-sm">
                    <IconAlertCircle size={24} />
                    <p>Error loading wishlist: {error}</p>
                    <button onClick={fetchWishlist} className={getPrimaryButtonClasses() + " !bg-gray-600 hover:!bg-gray-700 text-xs py-1 px-3"}>
                        Try Again
                    </button>
                </div>
            );
        }

        if (wishlistItems.length === 0) {
            return (
                <div className="bg-white rounded-lg p-10 shadow-sm text-center border border-gray-200">
                    <IconHeart size={48} className="mx-auto text-gray-300 mb-4" stroke={1} />
                    <h2 className="text-xl font-medium text-gray-700 mb-2">Your Wishlist is Empty</h2>
                    <p className="text-gray-500 mb-6">Save properties you love to keep track of them here.</p>
                    <Link to="/catalogue" className={getPrimaryButtonClasses()}>
                        Explore Properties
                    </Link>
                </div>
            );
        }

        const tabsToShow = STATUS_ORDER.filter(status =>
            status === 'WISHLISTED' || (groupedAndSortedItems[status] && groupedAndSortedItems[status].length > 0)
        );

        const activeItems = groupedAndSortedItems[activeTab] || [];

        return (
            <div>
                <div className="border-b border-gray-200 mb-6">
                    <nav className="-mb-px flex space-x-6 overflow-x-auto" aria-label="Tabs">
                        {tabsToShow.map(status => (
                            <button
                                key={status}
                                onClick={() => setActiveTab(status)}
                                className={`
                                    whitespace-nowrap py-3 px-1 border-b-2 font-medium text-sm transition-colors
                                    ${activeTab === status
                                        ? 'border-[#D9A619] text-[#D9A619]'
                                        : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
                                    }
                                `}
                            >
                                {getDisplayValue(interactionStatusMap, status)}
                                <span className={`ml-2 text-xs font-semibold px-2 py-0.5 rounded-full ${activeTab === status ? 'bg-[#D9A619] text-white' : 'bg-gray-200 text-gray-600'}`}>
                                    {groupedAndSortedItems[status]?.length || 0}
                                </span>
                            </button>
                        ))}
                    </nav>
                </div>

                <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6">
                    {activeItems.length > 0 ? (
                        activeItems.map(item => (
                            <WishlistItemCard
                                key={item.interaction_id}
                                item={item}
                                onRemove={handleRemoveFromWishlist}
                                onItemUpdate={handleItemUpdate}
                            />
                        ))
                    ) : (
                        <div className="text-center py-12 text-gray-500">
                            <p>No items in the "{getDisplayValue(interactionStatusMap, activeTab)}" category.</p>
                        </div>
                    )}
                </div>
            </div>
        );
    };
    const companyName = import.meta.env.VITE_COMPANY_NAME;


    return (
        <>
            <title>My Wishlist | {companyName}</title>
            <div className="bg-gray-50 min-h-screen">
                <div className="container mx-auto px-4 py-8">
                    <h1 className="text-3xl font-bold text-gray-800 mb-6">My Wishlist & Interactions</h1>
                    {renderContent()}
                </div>
            </div>
        </>
    );
}

export default Wishlist;