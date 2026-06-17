import { useEffect, useState, useCallback } from 'react';
import { useParams, useNavigate, Link } from 'react-router-dom';

import { format, parseISO } from 'date-fns';
import {
    IconAlertCircle, IconArrowLeft, IconBuilding, IconCalendar, IconCategory, IconClipboardText, IconInfoCircle,
    IconMessageCircle, IconPaperclip, IconPencil, IconTag, IconTicket, IconUser, IconMail, IconPhone
} from '@tabler/icons-react';

import api from '../lib/supabaseClient';
import { TicketDetails } from '../lib/types';
import LoadingSpinner from '../components/LoadingSpinner';
import { useAuth } from '../lib/AuthContext';
import { useNotification } from '../components/NotificationProvider';
import { getSecondaryButtonClasses, getStatusBadgeClasses } from '../lib/twUtils';
import TicketCommentForm from '../components/TicketCommentForm';
import TicketCommentCard from '../components/TicketCommentCard';

// Helper to get status text
const getStatusText = (status: string | null | undefined) => {
    return status ? status.replace(/_/g, ' ').replace(/\b\w/g, l => l.toUpperCase()) : 'Unknown';
};

function TicketDetailsPage() {
    const { ticketId } = useParams<{ ticketId: string }>();
    const navigate = useNavigate();
    const { user } = useAuth();
    const { showErrorNotification } = useNotification();

    const [details, setDetails] = useState<TicketDetails | null>(null);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState<string | null>(null);

    const fetchTicketDetails = useCallback(async () => {
        if (!ticketId || isNaN(Number(ticketId))) {
            setError("Invalid Ticket ID.");
            setLoading(false);
            return;
        }

        setLoading(true);
        setError(null);

        try {
            const { data, error: fetchError } = await api.getTicketDetailsCustomer(Number(ticketId));

            if (fetchError) throw fetchError;

            if (data) {
                setDetails(data);
            } else {
                setError("Ticket not found or you don't have permission to view it.");
                setDetails(null);
            }
        } catch (err: any) {
            const message = typeof err === 'string' ? err : err.message || 'Failed to load ticket details.';
            setError(message);
            showErrorNotification('Load Failed', message);
            setDetails(null);
        } finally {
            setLoading(false);
        }
    }, [ticketId, showErrorNotification]);

    useEffect(() => {
        fetchTicketDetails();
    }, [fetchTicketDetails]);

    const handleCommentAdded = () => {
        fetchTicketDetails();
    };

    // --- Rendering ---
    if (loading) {
        return <div className="min-h-screen flex items-center justify-center"><LoadingSpinner /></div>;
    }
    const companyName = import.meta.env.VITE_COMPANY_NAME;

    if (error) {
        return (
            <div className="min-h-screen flex flex-col items-center justify-center text-center p-4">
                <title>Error | {companyName}</title>
                <IconAlertCircle size={48} className="text-red-500 mb-4" />
                <h1 className="text-2xl font-semibold text-gray-700 mb-2">Error Loading Ticket</h1>
                <p className="text-gray-600 mb-4">{error}</p>
                <button onClick={() => navigate('/my-tickets')} className={getSecondaryButtonClasses()}>
                    <IconArrowLeft size={16} className="mr-1" /> Back to My Tickets
                </button>
            </div>
        );
    }

    if (!details) {
        return <div className="min-h-screen flex items-center justify-center">Ticket not found.</div>;
    }

    const statusText = getStatusText(details.status);
    const formattedDate = (dateString: string | null | undefined) => dateString ? format(parseISO(dateString), 'PPP p') : 'N/A';

    const isCurrentUserRaiser = user?.id === details.raised_by_user_id;
    const raiserDisplay = isCurrentUserRaiser ? 'You' : details.raiser_name || details.raiser_email || 'Unknown User';


    return (
        <div className="bg-gray-50 min-h-screen py-8">
            <title>{"Ticket #" + details.ticket_id + ": " + details.subject + " | " + companyName}</title>
            <div className="container mx-auto px-4 max-w-3xl">
                {/* Back Button */}
                <Link to="/my-tickets" className="text-sm text-gray-600 hover:underline mb-4 inline-flex items-center group">
                    <IconArrowLeft size={16} className="mr-1 group-hover:-translate-x-1 transition-transform" /> Back to My Tickets
                </Link>

                {/* Header */}
                <div className="bg-white p-6 rounded-lg shadow border border-gray-200 mb-6">
                    <div className="flex flex-col sm:flex-row justify-between items-start gap-3 mb-4">
                        <div>
                            <div className="flex items-center gap-2 mb-1">
                                <IconTicket size={20} className="text-gray-500" />
                                <h1 className="text-xl md:text-2xl font-bold text-gray-800">
                                    Ticket #{details.ticket_id}: {details.subject}
                                </h1>
                            </div>
                            <p className="text-sm text-gray-500 flex items-center gap-1">
                                <IconBuilding size={14} /> Property: {details.property_address}
                            </p>
                        </div>
                        <span className={getStatusBadgeClasses(details.status) + ' shadow-sm text-sm'}>
                            {statusText}
                        </span>
                    </div>

                    {/* Key Details */}
                    <div className="grid grid-cols-1 sm:grid-cols-2 gap-x-6 gap-y-2 text-sm border-t pt-4">
                        <div className="flex items-center gap-1.5 text-gray-700" title={details.raiser_email ?? ''}>
                            <IconUser size={16} className="text-gray-400" /> Raised By: <span className="font-medium">{raiserDisplay}</span>
                        </div>
                        {details.raiser_phone && !isCurrentUserRaiser && (
                            <div className="flex items-center gap-1.5 text-gray-700">
                                <IconPhone size={16} className="text-gray-400" /> Phone: <span className="font-medium">+{details.raiser_phone}</span>
                            </div>
                        )}
                        {details.raiser_email && !isCurrentUserRaiser && (
                            <div className="flex items-center gap-1.5 text-gray-700">
                                <IconMail size={16} className="text-gray-400" /> Email: <span className="font-medium">{details.raiser_email}</span>
                            </div>
                        )}
                        {/* End Raiser Details */}

                        <div className="flex items-center gap-1.5 text-gray-700">
                            <IconCategory size={16} className="text-gray-400" /> Category: <span className="font-medium">{details.category.replace(/_/g, ' ')}</span>
                        </div>
                        <div className="flex items-center gap-1.5 text-gray-700">
                            <IconTag size={16} className="text-gray-400" /> Priority: <span className="font-medium">{details.priority}</span>
                        </div>
                        <div className="flex items-center gap-1.5 text-gray-700">
                            <IconCalendar size={16} className="text-gray-400" /> Created: <span className="font-medium">{formattedDate(details.created_at)}</span>
                        </div>
                        <div className="flex items-center gap-1.5 text-gray-700">
                            <IconPencil size={16} className="text-gray-400" /> Last Updated: <span className="font-medium">{formattedDate(details.updated_at)}</span>
                        </div>
                        {details.resolved_at && (
                            <div className="flex items-center gap-1.5 text-green-700">
                                <IconCalendar size={16} className="text-green-400" /> Resolved: <span className="font-medium">{formattedDate(details.resolved_at)}</span>
                            </div>
                        )}
                        {details.closed_at && (
                            <div className="flex items-center gap-1.5 text-gray-700">
                                <IconCalendar size={16} className="text-gray-400" /> Closed: <span className="font-medium">{formattedDate(details.closed_at)}</span>
                            </div>
                        )}
                    </div>
                </div>

                {/* Description */}
                <div className="bg-white p-6 rounded-lg shadow border border-gray-200 mb-6">
                    <h2 className="text-lg font-semibold text-gray-800 mb-3 flex items-center gap-2">
                        <IconClipboardText size={18} /> Description
                    </h2>
                    <p className="text-sm text-gray-700 whitespace-pre-wrap leading-relaxed">
                        {details.description}
                    </p>
                </div>

                {/* Attachments */}
                {details.images && details.images.length > 0 && (
                    <div className="bg-white p-6 rounded-lg shadow border border-gray-200 mb-6">
                        <h2 className="text-lg font-semibold text-gray-800 mb-3 flex items-center gap-2">
                            <IconPaperclip size={18} /> Attachments ({details.images.length})
                        </h2>
                        <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 gap-3">
                            {details.images.map(image => (
                                <a key={image.image_id} href={image.image_url} target="_blank" rel="noopener noreferrer" className="block group aspect-square border rounded-md overflow-hidden shadow-sm hover:shadow-md transition-shadow relative">
                                    <img src={image.image_url} alt={image.description || 'Ticket attachment'} className="w-full h-full object-cover" />
                                    <div className="absolute inset-0 bg-black/10 group-hover:bg-black/30 transition-colors flex items-center justify-center">
                                    </div>
                                    {image.description && (
                                        <div className="absolute bottom-0 left-0 right-0 bg-black/60 text-white text-xs p-1 truncate" title={image.description}>
                                            {image.description}
                                        </div>
                                    )}
                                </a>
                            ))}
                        </div>
                    </div>
                )}

                {/* Comments Section */}
                <div className="bg-white p-6 rounded-lg shadow border border-gray-200">
                    <h2 className="text-lg font-semibold text-gray-800 mb-4 flex items-center gap-2">
                        <IconMessageCircle size={18} /> Conversation
                    </h2>
                    <div className="max-h-[400px] overflow-y-auto mb-4 pr-2 custom-scrollbar">
                        {details.comments && details.comments.length > 0 ? (
                            details.comments.map(comment => (
                                <TicketCommentCard
                                    key={comment.comment_id}
                                    comment={comment}
                                    isCurrentUserComment={comment.user_id === user?.id}
                                />
                            ))
                        ) : (
                            <p className="text-sm text-gray-500 italic text-center py-4">No comments yet.</p>
                        )}
                    </div>
                    {/* Add Comment Form - Only if ticket is not Closed/Cancelled */}
                    {details.status !== 'CLOSED' && details.status !== 'CANCELLED' && (
                        <TicketCommentForm ticketId={details.ticket_id} onCommentAdded={handleCommentAdded} />
                    )}
                    {(details.status === 'CLOSED' || details.status === 'CANCELLED') && (
                        <div className="text-center text-sm text-gray-500 italic border-t pt-4 mt-4">
                            <IconInfoCircle size={16} className="inline mr-1" />
                            This ticket is {statusText.toLowerCase()} and comments are disabled.
                        </div>
                    )}
                </div>
            </div>
        </div>
    );
}

export default TicketDetailsPage;