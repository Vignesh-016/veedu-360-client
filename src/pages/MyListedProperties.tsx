import { useState, useEffect, useCallback } from 'react';

import api from '../lib/supabaseClient';
import { MyProperties } from '../lib/types';
import LoadingSpinner from '../components/LoadingSpinner';
import PaginationControls from '../components/PaginationControls';
import ListedPropertyCard from '../components/ListedPropertyCard';
import { useNotification } from '../components/NotificationProvider';
import { Link } from 'react-router-dom';
import { IconAlertCircle, IconRepeat, IconHomePlus, IconBuildingStore } from '@tabler/icons-react';
import { getPrimaryButtonClasses, getTertiaryButtonClasses } from '../lib/twUtils';

const ITEMS_PER_PAGE = 10;

function MyListedProperties() {
    const [properties, setProperties] = useState<MyProperties[]>([]);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState<string | null>(null);
    const [currentPage, setCurrentPage] = useState(1);
    const [totalProperties, setTotalProperties] = useState(0);
    const { showErrorNotification } = useNotification();

    const fetchProperties = useCallback(async (page: number) => {
        setLoading(true);
        setError(null);
        const offset = (page - 1) * ITEMS_PER_PAGE;

        try {
            const { data, error: fetchError } = await api.getMyProperties(offset, ITEMS_PER_PAGE);
            if (fetchError) throw fetchError;

            const fetchedProperties = data || [];
            setProperties(fetchedProperties);

            if (fetchedProperties.length > 0 && fetchedProperties[0].total_count !== undefined) {
                setTotalProperties(fetchedProperties[0].total_count);
            } else if (page === 1) {
                setTotalProperties(0);
            }
        } catch (err: any) {
            const message = typeof err === 'string' ? err : err.message || 'Failed to load your properties.';
            setError(message);
            showErrorNotification('Load Failed', message);
            setProperties([]);
            setTotalProperties(0);
        } finally {
            setLoading(false);
        }
    }, [showErrorNotification]);

    useEffect(() => {
        fetchProperties(currentPage);
    }, [currentPage, fetchProperties]);

    const handlePageChange = (newPage: number) => {
        if (newPage !== currentPage) {
            setCurrentPage(newPage);
            window.scrollTo({ top: 0, behavior: 'smooth' });
        }
    };

    const handlePropertyUpdate = () => {
        fetchProperties(currentPage);
    };

    const totalPages = Math.ceil(totalProperties / ITEMS_PER_PAGE);

    const companyName = import.meta.env.VITE_COMPANY_NAME;

    const renderContent = () => {
        if (loading && properties.length === 0) {
            return (
                <div className="flex justify-center items-center py-16">
                    <LoadingSpinner />
                </div>
            );
        }

        if (error) {
            return (
                <div className="bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded-lg text-center flex flex-col items-center gap-2 shadow-sm">
                    <IconAlertCircle size={24} />
                    <p>Error loading your properties: {error}</p>
                    <button onClick={() => fetchProperties(currentPage)} className={`${getTertiaryButtonClasses()} !text-red-700 hover:!bg-red-100 text-xs py-1 px-3`}>
                        <IconRepeat size={14} className="mr-1" /> Try Again
                    </button>
                </div>
            );
        }

        if (!loading && totalProperties === 0) {
            return (
                <div className="bg-white p-8 rounded-lg shadow-sm text-center border border-gray-200">
                    <IconBuildingStore size={48} className="mx-auto text-gray-300 mb-4" stroke={1} />
                    <h2 className="text-xl font-medium text-gray-700 mb-2">No Properties Found</h2>
                    <p className="text-gray-500 mb-6">You haven't listed any properties through {companyName} yet.</p>
                    <Link to="/submit-property" className={getPrimaryButtonClasses()}>
                        <IconHomePlus size={18} className="mr-2" /> List Your First Property
                    </Link>
                </div>
            );
        }

        return (
            <div className="space-y-6 relative">
                {loading && properties.length > 0 && (
                    <div className="absolute inset-0 bg-white/70 flex items-center justify-center z-10 rounded-lg">
                        <LoadingSpinner />
                    </div>
                )}
                {properties.map((prop) => (
                    <ListedPropertyCard
                        key={prop.property_id}
                        property={prop}
                        onPropertyUpdate={handlePropertyUpdate}
                    />
                ))}
                {totalPages > 1 && (
                    <PaginationControls
                        currentPage={currentPage}
                        totalPages={totalPages}
                        onPageChange={handlePageChange}
                        itemsPerPage={ITEMS_PER_PAGE}
                        totalItems={totalProperties}
                    />
                )}
            </div>
        );
    };

    return (
        <div className="bg-gray-50 min-h-screen py-8">
            <title>My Properties | {companyName}</title>
            <div className="container mx-auto px-4 max-w-5xl">
                <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center mb-6 gap-4">
                    <h1 className="text-2xl md:text-3xl font-bold text-gray-800">
                        My Properties
                    </h1>
                    <Link to="/submit-property" className={`${getPrimaryButtonClasses()} flex-shrink-0 !text-sm !px-4 !py-2`}>
                        <IconHomePlus size={18} className="mr-1.5" /> List New Property
                    </Link>
                </div>
                {renderContent()}
            </div>
        </div>
    );
}

export default MyListedProperties;