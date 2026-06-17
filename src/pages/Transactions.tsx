import { useState, useEffect, useCallback } from 'react';

import api from '../lib/supabaseClient';
import { MyTransactions } from '../lib/types';
import LoadingSpinner from '../components/LoadingSpinner';
import TransactionCard from '../components/TransactionCard';
import PaginationControls from '../components/PaginationControls';
import { useNotification } from '../components/NotificationProvider';
import { Link } from 'react-router-dom';
import { IconAlertCircle, IconReceiptOff, IconRepeat } from '@tabler/icons-react';
import { getPrimaryButtonClasses, getTertiaryButtonClasses } from '../lib/twUtils';

const ITEMS_PER_PAGE = 10;

function Transactions() {
    const [transactions, setTransactions] = useState<MyTransactions[]>([]);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState<string | null>(null);
    const [currentPage, setCurrentPage] = useState(1);
    const [totalTransactions, setTotalTransactions] = useState(0);
    const { showErrorNotification } = useNotification();

    const fetchTransactions = useCallback(async (page: number) => {
        setLoading(true);
        setError(null);
        const offset = (page - 1) * ITEMS_PER_PAGE;

        try {
            const { data, error: fetchError } = await api.getMyTransactions(offset, ITEMS_PER_PAGE);
            if (fetchError) throw fetchError;

            const fetchedTransactions = data || [];
            setTransactions(fetchedTransactions);

            // Read total_count from the first item if available
            if (fetchedTransactions.length > 0 && fetchedTransactions[0].total_count !== undefined) {
                setTotalTransactions(fetchedTransactions[0].total_count);
            } else if (page === 1) {
                // If first page is empty, total is 0
                setTotalTransactions(0);
            } // Otherwise, keep the previous total if subsequent pages are somehow empty

        } catch (err: any) {
            console.error("Error fetching transactions:", err);
            const message = typeof err === 'string' ? err : err.message || 'Failed to load transaction history.';
            setError(message);
            showErrorNotification('Load Failed', message);
            setTransactions([]);
            setTotalTransactions(0);
        } finally {
            setLoading(false);
        }
    }, [showErrorNotification]);

    useEffect(() => {
        fetchTransactions(currentPage);
    }, [currentPage, fetchTransactions]);

    const handlePageChange = (newPage: number) => {
        if (newPage !== currentPage) {
            setCurrentPage(newPage);
            window.scrollTo({ top: 0, behavior: 'smooth' });
        }
    };

    const totalPages = Math.ceil(totalTransactions / ITEMS_PER_PAGE);

    const renderContent = () => {
        if (loading && transactions.length === 0) {
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
                    <p>Error loading transactions: {error}</p>
                    <button onClick={() => fetchTransactions(currentPage)} className={`${getTertiaryButtonClasses()} !text-red-700 hover:!bg-red-100 text-xs py-1 px-3`}>
                        <IconRepeat size={14} className="mr-1" /> Try Again
                    </button>
                </div>
            );
        }

        if (!loading && totalTransactions === 0) {
            return (
                <div className="bg-white p-8 rounded-lg shadow-sm text-center border border-gray-200">
                    <IconReceiptOff size={48} className="mx-auto text-gray-300 mb-4" stroke={1} />
                    <h2 className="text-xl font-medium text-gray-700 mb-2">No Transactions Found</h2>
                    <p className="text-gray-500 mb-6">You haven't purchased any visit plans yet.</p>
                    <Link to="/plans" className={getPrimaryButtonClasses()}>
                        View Visit Plans
                    </Link>
                </div>
            );
        }

        return (
            <div className="space-y-4 relative">
                {loading && transactions.length > 0 && (
                    <div className="absolute inset-0 bg-white/70 flex items-center justify-center z-10 rounded-lg">
                        <LoadingSpinner />
                    </div>
                )}
                {transactions.map((tx) => (
                    <TransactionCard key={tx.transaction_id} transaction={tx} />
                ))}
                {totalPages > 1 && (
                    <PaginationControls
                        currentPage={currentPage}
                        totalPages={totalPages}
                        onPageChange={handlePageChange}
                        itemsPerPage={ITEMS_PER_PAGE}
                        totalItems={totalTransactions}
                    />
                )}
            </div>
        );
    };
    const companyName = import.meta.env.VITE_COMPANY_NAME;

    return (
        <div className="bg-gray-50 min-h-screen py-8">
            <title>My Transactions | {companyName}</title>
            <div className="container mx-auto px-4 max-w-3xl">
                <h1 className="text-2xl md:text-3xl font-bold text-gray-800 mb-6">
                    My Transactions
                </h1>
                {renderContent()}
            </div>
        </div>
    );
}

export default Transactions;