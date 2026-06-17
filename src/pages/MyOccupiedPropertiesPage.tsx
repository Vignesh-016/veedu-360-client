import { useState, useEffect, useCallback } from 'react';

import api from '../lib/supabaseClient';
import { MyOccupiedProperties, MyRentDues } from '../lib/types';
import LoadingSpinner from '../components/LoadingSpinner';
import OccupiedPropertyCard from '../components/OccupiedPropertyCard';
import { useNotification } from '../components/NotificationProvider';
import { Link } from 'react-router-dom';
import { IconAlertCircle, IconHomeQuestion, IconRepeat } from '@tabler/icons-react';
import { getPrimaryButtonClasses, getTertiaryButtonClasses } from '../lib/twUtils';

function MyOccupiedPropertiesPage() {
    const [properties, setProperties] = useState<MyOccupiedProperties[]>([]);
    const [rentDues, setRentDues] = useState<MyRentDues[]>([]);
    const [loadingProps, setLoadingProps] = useState(true);
    const [loadingDues, setLoadingDues] = useState(true);
    const [error, setError] = useState<string | null>(null);
    const { showErrorNotification } = useNotification();

    const fetchData = useCallback(async () => {
        setLoadingProps(true);
        setLoadingDues(true);
        setError(null);
        let fetchError: string | null = null;

        try {
            // Fetch properties and dues concurrently
            const [propsResult, duesResult] = await Promise.all([
                api.viewMyOccupiedProperties(),
                api.getMyRentDues()
            ]);

            if (propsResult.error) {
                fetchError = typeof propsResult.error === 'string' ? propsResult.error : propsResult.error.message;
                setProperties([]);
            } else {
                setProperties(propsResult.data || []);
            }

            if (duesResult.error) {
                // Append or set error, prioritize property loading error if both fail
                const duesErrorMsg = typeof duesResult.error === 'string' ? duesResult.error : duesResult.error.message;
                fetchError = fetchError ? `${fetchError}; ${duesErrorMsg}` : duesErrorMsg;
                setRentDues([]);
            } else {
                setRentDues(duesResult.data || []);
            }

            if (fetchError) {
                throw new Error(fetchError);
            }

        } catch (err: any) {
            const message = err.message || 'Failed to load your rental information.';
            setError(message);
            showErrorNotification('Load Failed', message);
            setProperties([]);
            setRentDues([]);
        } finally {
            setLoadingProps(false);
            setLoadingDues(false);
        }
    }, [showErrorNotification]);

    useEffect(() => {
        fetchData();
    }, [fetchData]);

    const isLoading = loadingProps || loadingDues;

    const renderContent = () => {
        if (isLoading) {
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
                    <p>Error loading rental information: {error}</p>
                    <button onClick={fetchData} className={`${getTertiaryButtonClasses()} !text-red-700 hover:!bg-red-100 text-xs py-1 px-3`}>
                        <IconRepeat size={14} className="mr-1" /> Try Again
                    </button>
                </div>
            );
        }

        const companyName = import.meta.env.VITE_COMPANY_NAME;
        if (!loadingProps && properties.length === 0) {
            return (
                <div className="bg-white p-8 rounded-lg shadow-sm text-center border border-gray-200">
                    <IconHomeQuestion size={48} className="mx-auto text-gray-300 mb-4" stroke={1} />
                    <h2 className="text-xl font-medium text-gray-700 mb-2">No Occupied Properties Found</h2>
                    <p className="text-gray-500 mb-6">It looks like you are not currently listed as a tenant for any properties managed through {companyName}.</p>
                    <Link to="/catalogue" className={getPrimaryButtonClasses()}>
                        Explore Properties
                    </Link>
                </div>
            );
        }

        return (
            <div className="space-y-6">
                {properties.map((prop) => {
                    // Filter rent dues for this specific property
                    const associatedDues = rentDues.filter(due => due.property_id === prop.property_id);
                    return (
                        <OccupiedPropertyCard key={prop.property_id} property={prop} rentDues={associatedDues} />
                    );
                })}
            </div>
        );
    };

    const companyName = import.meta.env.VITE_COMPANY_NAME;

    return (
        <div className="bg-gray-50 min-h-screen py-8">
            <title>My Rentals | {companyName}</title>
            <div className="container mx-auto px-4 max-w-4xl">
                <h1 className="text-2xl md:text-3xl font-bold text-gray-800 mb-6">
                    My Rentals & Dues
                </h1>
                {renderContent()}
            </div>
        </div>
    );
}

export default MyOccupiedPropertiesPage;