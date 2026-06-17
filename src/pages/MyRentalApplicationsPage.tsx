import { useState, useEffect, useCallback } from 'react';

import { Link } from 'react-router-dom';
import { IconAlertCircle, IconClipboardList, IconRepeat } from '@tabler/icons-react';

import api from '../lib/supabaseClient';
import { MyRentalApplication } from '../lib/types';
import { useAuth } from '../lib/AuthContext';
import { useNotification } from '../components/NotificationProvider';
import LoadingSpinner from '../components/LoadingSpinner';
import PaginationControls from '../components/PaginationControls';
import ApplicationCard from '../components/RentalApplicationCard';
import { getPrimaryButtonClasses, getTertiaryButtonClasses } from '../lib/twUtils';

const ITEMS_PER_PAGE = 10;

function MyRentalApplicationsPage() {
    const [applications, setApplications] = useState<MyRentalApplication[]>([]);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState<string | null>(null);
    const [currentPage, setCurrentPage] = useState(1);
    const [totalApplications, setTotalApplications] = useState(0);
    const [withdrawingId, setWithdrawingId] = useState<string | null>(null);

    const { user } = useAuth();
    const { showSuccessNotification, showErrorNotification } = useNotification();

    const fetchApplications = useCallback(async (page: number) => {
        if (!user) return;
        setLoading(true);
        setError(null);
        const offset = (page - 1) * ITEMS_PER_PAGE;

        try {
            const { data, error: fetchError } = await api.getMyRentalApplications(offset, ITEMS_PER_PAGE);
            if (fetchError) throw fetchError;

            const fetchedApps = data || [];
            setApplications(fetchedApps);
            if (fetchedApps.length > 0 && fetchedApps[0].total_count !== undefined) {
                setTotalApplications(fetchedApps[0].total_count);
            } else if (page === 1) {
                setTotalApplications(0);
            }
        } catch (err: any) {
            const message = typeof err === 'string' ? err : err.message || 'Failed to load your rental applications.';
            setError(message);
            showErrorNotification('Load Failed', message);
            setApplications([]);
            setTotalApplications(0);
        } finally {
            setLoading(false);
        }
    }, [user, showErrorNotification]);

    useEffect(() => {
        fetchApplications(currentPage);
    }, [currentPage, fetchApplications]);

    const handlePageChange = (newPage: number) => {
        if (newPage !== currentPage) {
            setCurrentPage(newPage);
            window.scrollTo({ top: 0, behavior: 'smooth' });
        }
    };

    const handleWithdrawApplication = async (applicationId: string) => {
        if (!window.confirm("Are you sure you want to withdraw this application? This action cannot be undone.")) return;
        setWithdrawingId(applicationId);
        try {
            const { error: withdrawError } = await api.withdrawRentalApplication(applicationId);
            if (withdrawError) throw withdrawError;
            showSuccessNotification('Application Withdrawn', 'Your application has been successfully withdrawn.');
            fetchApplications(currentPage);
        } catch (err: any) {
            showErrorNotification('Withdrawal Failed', typeof err === 'string' ? err : err.message || 'Could not withdraw application.');
        } finally {
            setWithdrawingId(null);
        }
    };

    const totalPages = Math.ceil(totalApplications / ITEMS_PER_PAGE);
    const companyName = import.meta.env.VITE_COMPANY_NAME;

    const renderContent = () => {
        if (loading && applications.length === 0) {
            return <div className="flex justify-center py-16"><LoadingSpinner /></div>;
        }
        if (error) {
            return (
                <div className="bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded-lg text-center flex flex-col items-center gap-2 shadow-sm">
                    <IconAlertCircle size={24} /> <p>Error: {error}</p>
                    <button onClick={() => fetchApplications(currentPage)} className={`${getTertiaryButtonClasses()} !text-red-700 hover:!bg-red-100 text-xs py-1 px-3`}>
                        <IconRepeat size={14} className="mr-1" /> Try Again
                    </button>
                </div>
            );
        }
        if (!loading && totalApplications === 0) {
            return (
                <div className="bg-white p-8 rounded-lg shadow-sm text-center border border-gray-200">
                    <IconClipboardList size={48} className="mx-auto text-gray-300 mb-4" stroke={1} />
                    <h2 className="text-xl font-medium text-gray-700 mb-2">No Rental Applications Found</h2>
                    <p className="text-gray-500 mb-6">You haven't applied for any properties yet. Complete a visit and then apply!</p>
                    <Link to="/catalogue" className={getPrimaryButtonClasses()}>Browse Rental Properties</Link>
                </div>
            );
        }
        return (
            <div className="space-y-4 relative">
                {loading && applications.length > 0 && (
                    <div className="absolute inset-0 bg-white/70 flex items-center justify-center z-10 rounded-lg"><LoadingSpinner /></div>
                )}
                {applications.map(app => (
                    <ApplicationCard
                        key={app.application_id}
                        application={app}
                        onWithdraw={handleWithdrawApplication}
                        isWithdrawingThis={withdrawingId === app.application_id}
                    />
                ))}
                {totalPages > 1 && (
                    <PaginationControls
                        currentPage={currentPage}
                        totalPages={totalPages}
                        onPageChange={handlePageChange}
                        itemsPerPage={ITEMS_PER_PAGE}
                        totalItems={totalApplications}
                    />
                )}
            </div>
        );
    };

    return (
        <div className="bg-gray-50 min-h-screen py-8">
            <title>My Rental Applications | {companyName}</title>
            <div className="container mx-auto px-4 max-w-4xl">
                <h1 className="text-2xl md:text-3xl font-bold text-gray-800 mb-6">
                    My Rental Applications
                </h1>
                {renderContent()}
            </div>
        </div>
    );
}

export default MyRentalApplicationsPage;