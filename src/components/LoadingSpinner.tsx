import { IconLoader2 } from '@tabler/icons-react';

interface LoadingSpinnerProps {
    size?: number;
    className?: string;
}

function LoadingSpinner({ size = 24, className = '' }: LoadingSpinnerProps) {
    return (
        <div className={`flex items-center justify-center ${className}`}>
            <IconLoader2 size={size} className="animate-spin text-gray-600" />
        </div>
    );
}

export default LoadingSpinner;