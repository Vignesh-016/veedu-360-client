import { format, parseISO } from 'date-fns';
import { TicketComment } from '../lib/types';
import { IconUserCircle } from '@tabler/icons-react';

interface TicketCommentCardProps {
    comment: TicketComment;
    isCurrentUserComment: boolean;
}

function TicketCommentCard({ comment, isCurrentUserComment }: TicketCommentCardProps) {
    const formattedDate = format(parseISO(comment.created_at), 'MMM d, yyyy, p');
    const alignClass = isCurrentUserComment ? 'items-end' : 'items-start';
    const bgClass = isCurrentUserComment ? 'bg-[#D9A619] text-white' : 'bg-gray-100 text-gray-800';
    const textAlignClass = isCurrentUserComment ? 'text-right' : 'text-left';

    const commenterDisplay = comment.user_name || 'Support Staff';

    return (
        <div className={`flex flex-col ${alignClass} mb-4`}>
            <div className={`flex items-center mb-1 ${isCurrentUserComment ? 'flex-row-reverse' : 'flex-row'}`}>
                <IconUserCircle size={20} className={`mx-1 text-gray-400`} />
                <span className={`text-xs font-medium ${isCurrentUserComment ? 'text-gray-600' : 'text-gray-500'}`} title={''}>
                    {isCurrentUserComment ? 'You' : commenterDisplay}
                </span>
            </div>
            <div className={`px-4 py-2 rounded-lg max-w-[80%] ${bgClass} shadow-sm`}>
                <p className="text-sm whitespace-pre-wrap">{comment.comment_text}</p>
            </div>
            <span className={`text-xs text-gray-400 mt-1 ${textAlignClass}`}>
                {formattedDate}
            </span>
        </div>
    );
}

export default TicketCommentCard;