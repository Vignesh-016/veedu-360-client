import { MyPropertyTickets } from '../lib/types';
import { format, parseISO } from 'date-fns';
import { getStatusBadgeClasses } from '../lib/twUtils';
import { IconUser, IconCalendar, IconTag, IconMail, IconPhone } from '@tabler/icons-react';

interface TicketSummaryLandlordCardProps {
    ticket: MyPropertyTickets;
}

function TicketSummaryLandlordCard({ ticket }: TicketSummaryLandlordCardProps) {
    const {
        ticket_id,
        subject,
        category,
        status,
        updated_at,
        raiser_name,
        raiser_email,
        raiser_phone,
    } = ticket;

    const formattedDate = format(parseISO(updated_at), 'PPP p');
    const statusText = status.replace(/_/g, ' ').replace(/\b\w/g, l => l.toUpperCase());

    return (
        <div className="block bg-white p-4 rounded-lg shadow-sm border border-gray-200 transition-all duration-200 group">
            <div className="flex flex-col sm:flex-row justify-between items-start gap-3">
                {/* Left Side: Info */}
                <div className="flex-grow min-w-0">
                    <div className="flex items-center gap-2 mb-2 flex-wrap">
                        <span className="text-xs font-medium px-2 py-0.5 rounded bg-gray-100 text-gray-700 border border-gray-200">
                            ID: {ticket_id}
                        </span>
                        <span className={getStatusBadgeClasses(status) + ' shadow-sm'}>{statusText}</span>
                        {/* Tenant Info Badge */}
                        {(raiser_name || raiser_email) && (
                            <span className="text-xs font-medium px-2 py-0.5 rounded bg-[#2C4964]/10 text-[#2C4964] border border-[#2C4964]/20 flex items-center gap-1">
                                <IconUser size={12} /> {raiser_name || raiser_email}
                            </span>
                        )}
                    </div>
                    <h3 className="text-base font-semibold text-gray-800 truncate group-hover:text-gray-600 mb-1" title={subject}>
                        {subject}
                    </h3>
                    <div className="text-xs text-gray-500 space-y-1">
                        <div className="flex items-center gap-1.5">
                            <IconTag size={14} />
                            <span>{category?.replace(/_/g, ' ') || 'General'}</span>
                        </div>
                        <div className="flex items-center gap-1.5">
                            <IconCalendar size={14} />
                            <span>Last Updated: {formattedDate}</span>
                        </div>
                        {raiser_email && (
                            <div className="flex items-center gap-1.5">
                                <IconMail size={14} />
                                <a href={`mailto:${raiser_email}`} className="text-gray-600 hover:underline">{raiser_email}</a>
                            </div>
                        )}
                        {raiser_phone && (
                            <div className="flex items-center gap-1.5">
                                <IconPhone size={14} />
                                <a href={`tel:${raiser_phone}`} className="text-gray-600 hover:underline">+{raiser_phone}</a>
                            </div>
                        )}
                    </div>
                </div>
            </div>
        </div>
    );
}

export default TicketSummaryLandlordCard;