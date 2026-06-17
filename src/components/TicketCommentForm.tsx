import React, { useState } from 'react';
import api from '../lib/supabaseClient';
import { getBaseInputClasses, getPrimaryButtonClasses } from '../lib/twUtils';
import LoadingSpinner from './LoadingSpinner';
import { useNotification } from '../components/NotificationProvider';
import { IconSend } from '@tabler/icons-react';

interface TicketCommentFormProps {
    ticketId: number;
    onCommentAdded: () => void; // Callback to refresh comments list
}

function TicketCommentForm({ ticketId, onCommentAdded }: TicketCommentFormProps) {
    const [commentText, setCommentText] = useState('');
    const [loading, setLoading] = useState(false);
    const [error, setError] = useState<string | null>(null);
    const { showSuccessNotification, showErrorNotification } = useNotification();

    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault();
        if (!commentText.trim() || loading) return;

        setLoading(true);
        setError(null);
        try {
            const { error: commentError } = await api.addTicketComment({
                p_ticket_id_input: ticketId,
                p_comment_text: commentText.trim(),
            });
            if (commentError) throw commentError;

            showSuccessNotification('Comment Added', 'Your comment has been posted.');
            setCommentText(''); // Clear the form
            onCommentAdded(); // Trigger refresh in parent

        } catch (err: any) {
            const message = typeof err === 'string' ? err : err.message || 'Failed to add comment.';
            setError(message);
            showErrorNotification('Comment Failed', message);
        } finally {
            setLoading(false);
        }
    };

    return (
        <form onSubmit={handleSubmit} className="mt-4 pt-4 border-t border-gray-200">
            <label htmlFor="commentText" className="block text-sm font-medium text-gray-700 mb-1">
                Add a Comment
            </label>
            <textarea
                id="commentText"
                value={commentText}
                onChange={(e) => setCommentText(e.target.value)}
                className={`${getBaseInputClasses(!!error)} min-h-[80px]`}
                placeholder="Type your comment here..."
                rows={3}
                maxLength={500}
                required
                disabled={loading}
            />
            {error && <p className="mt-1 text-xs text-red-600">{error}</p>}
            <div className="mt-2 flex justify-end">
                <button
                    type="submit"
                    disabled={loading || !commentText.trim()}
                    className={`${getPrimaryButtonClasses()} !text-sm !px-4 !py-1.5 flex items-center gap-1 disabled:opacity-60`}
                >
                    {loading ? <LoadingSpinner size={16} /> : <IconSend size={16} />}
                    Send
                </button>
            </div>
        </form>
    );
}

export default TicketCommentForm;