import { Link } from 'react-router-dom';
import { MyTickets } from '../lib/types';
import { format } from 'date-fns';
import { getStatusBadgeClasses } from '../lib/twUtils';
import { IconBuilding, IconCalendar, IconChevronRight, IconTag } from '@tabler/icons-react';

interface TicketSummaryTenantCardProps {
    ticket: MyTickets;
}

function TicketSummaryTenantCard({ ticket }: TicketSummaryTenantCardProps) {
    const {
        ticket_id,
        property_address,
        subject,
        category,
        status,
        updated_at,
    } = ticket;

    const formattedDate = format(new Date(updated_at), 'PPP p'); // Use updated_at for recency
    const statusText = status.replace(/_/g, ' ').replace(/\b\w/g, l => l.toUpperCase());

    return (
        <Link
            to={`/ticket/${ticket_id}`}
            className="block bg-white p-4 rounded-lg shadow-sm border border-gray-200 hover:shadow-md hover:border-gray-300 transition-all duration-200 group"
        >
            <div className="flex flex-col sm:flex-row justify-between items-start gap-3">
                {/* Left Side: Info */}
                <div className="flex-grow min-w-0">
                    <div className="flex items-center gap-2 mb-2">
                        <span className="text-xs font-medium px-2 py-0.5 rounded bg-gray-100 text-gray-700 border border-gray-200">
                            ID: {ticket_id}
                        </span>
                        <span className={getStatusBadgeClasses(status) + ' shadow-sm'}>{statusText}</span>
                    </div>
                    <h3 className="text-base font-semibold text-gray-800 truncate group-hover:text-gray-600 mb-1" title={subject}>
                        {subject}
                    </h3>
                    <div className="text-xs text-gray-500 space-y-1">
                        <div className="flex items-center gap-1.5">
                            <IconBuilding size={14} />
                            <span className="truncate">{property_address}</span>
                        </div>
                        <div className="flex items-center gap-1.5">
                            <IconTag size={14} />
                            <span>{category?.replace(/_/g, ' ') || 'General'}</span>
                        </div>
                        <div className="flex items-center gap-1.5">
                            <IconCalendar size={14} />
                            <span>Last Updated: {formattedDate}</span>
                        </div>
                    </div>
                </div>
                {/* Right Side: Action */}
                <div className="flex items-center text-gray-400 group-hover:text-gray-600 transition-colors flex-shrink-0 mt-2 sm:mt-0">
                    <span className="text-xs mr-1">View Details</span>
                    <IconChevronRight size={16} />
                </div>
            </div>
        </Link>
    );
}

export default TicketSummaryTenantCard;