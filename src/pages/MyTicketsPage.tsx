import { useState, useEffect, useCallback } from 'react';

import api from '../lib/supabaseClient';
import { MyTickets } from '../lib/types';
import LoadingSpinner from '../components/LoadingSpinner';
import PaginationControls from '../components/PaginationControls';
import TicketSummaryTenantCard from '../components/TicketSummaryTenantCard';
import { useNotification } from '../components/NotificationProvider';
import { Link } from 'react-router-dom';
import { IconAlertCircle, IconTicketOff, IconRepeat } from '@tabler/icons-react';
import { getPrimaryButtonClasses, getTertiaryButtonClasses } from '../lib/twUtils';

const ITEMS_PER_PAGE = 10;

function MyTicketsPage() {
    const [tickets, setTickets] = useState<MyTickets[]>([]);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState<string | null>(null);
    const [currentPage, setCurrentPage] = useState(1);
    const [totalTickets, setTotalTickets] = useState(0);
    const { showErrorNotification } = useNotification();

    const fetchTickets = useCallback(async (page: number) => {
        setLoading(true);
        setError(null);
        const offset = (page - 1) * ITEMS_PER_PAGE;

        try {
            const { data, error: fetchError } = await api.getMyTickets(offset, ITEMS_PER_PAGE);
            if (fetchError) throw fetchError;

            const fetchedTickets = data || [];
            setTickets(fetchedTickets);

            if (fetchedTickets.length > 0 && fetchedTickets[0].total_count !== undefined) {
                setTotalTickets(fetchedTickets[0].total_count);
            } else if (page === 1) {
                setTotalTickets(0);
            }

        } catch (err: any) {
            console.error("Error fetching tickets:", err);
            const message = typeof err === 'string' ? err : err.message || 'Failed to load tickets.';
            setError(message);
            showErrorNotification('Load Failed', message);
            setTickets([]);
            setTotalTickets(0);
        } finally {
            setLoading(false);
        }
    }, [showErrorNotification]);

    useEffect(() => {
        fetchTickets(currentPage);
    }, [currentPage, fetchTickets]);

    const handlePageChange = (newPage: number) => {
        if (newPage !== currentPage) {
            setCurrentPage(newPage);
            window.scrollTo({ top: 0, behavior: 'smooth' });
        }
    };

    const totalPages = Math.ceil(totalTickets / ITEMS_PER_PAGE);

    const renderContent = () => {
        if (loading && tickets.length === 0) {
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
                    <p>Error loading tickets: {error}</p>
                    <button onClick={() => fetchTickets(currentPage)} className={`${getTertiaryButtonClasses()} !text-red-700 hover:!bg-red-100 text-xs py-1 px-3`}>
                        <IconRepeat size={14} className="mr-1" /> Try Again
                    </button>
                </div>
            );
        }

        if (!loading && totalTickets === 0) {
            return (
                <div className="bg-white p-8 rounded-lg shadow-sm text-center border border-gray-200">
                    <IconTicketOff size={48} className="mx-auto text-gray-300 mb-4" stroke={1} />
                    <h2 className="text-xl font-medium text-gray-700 mb-2">No Tickets Found</h2>
                    <p className="text-gray-500 mb-6">You haven't submitted any maintenance requests or inquiries yet.</p>
                    <Link to="/my-rentals" className={getPrimaryButtonClasses()}> {/* Link to rentals to initiate */}
                        Go to My Rentals
                    </Link>
                </div>
            );
        }

        return (
            <div className="space-y-4 relative">
                {loading && tickets.length > 0 && (
                    <div className="absolute inset-0 bg-white/70 flex items-center justify-center z-10 rounded-lg">
                        <LoadingSpinner />
                    </div>
                )}
                {tickets.map((ticket) => (
                    <TicketSummaryTenantCard key={ticket.ticket_id} ticket={ticket} />
                ))}
                {totalPages > 1 && (
                    <PaginationControls
                        currentPage={currentPage}
                        totalPages={totalPages}
                        onPageChange={handlePageChange}
                        itemsPerPage={ITEMS_PER_PAGE}
                        totalItems={totalTickets}
                    />
                )}
            </div>
        );
    };


    const companyName = import.meta.env.VITE_COMPANY_NAME;
    return (
        <div className="bg-gray-50 min-h-screen py-8">
            <title>My Support Tickets | {companyName}</title>
            <div className="container mx-auto px-4 max-w-3xl">
                <h1 className="text-2xl md:text-3xl font-bold text-gray-800 mb-6">
                    My Support Tickets
                </h1>
                {renderContent()}
            </div>
        </div>
    );
}

export default MyTicketsPage;