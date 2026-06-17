import React from 'react';
import LoadingSpinner from './LoadingSpinner';

interface FullScreenLoaderProps {
    message?: string;
}

const FullScreenLoader: React.FC<FullScreenLoaderProps> = ({ message }) => {
    return (
        <div
            className="fixed inset-0 z-[150] flex flex-col items-center justify-center bg-opacity-75"
            aria-modal="true"
            role="dialog"
        >
            <LoadingSpinner size={48} className="text-white" />
            {message && <p className="mt-4 text-lg font-medium text-white">{message}</p>}
        </div>
    );
};

export default FullScreenLoader;