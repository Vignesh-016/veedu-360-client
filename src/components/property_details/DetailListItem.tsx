import React from 'react';

interface DetailListItemProps {
    label: string;
    value: string | number | React.ReactNode | null | undefined;
    className?: string;
}

const DetailListItem: React.FC<DetailListItemProps> = ({ label, value, className = "" }) => {
    if (value === null || value === undefined || value === '' || (typeof value === 'boolean' && !value)) {
        return null;
    }
    return (
        <div className={`flex justify-between py-1.5 border-b border-gray-100 last:border-b-0 ${className}`}>
            <span className="text-gray-600">{label}:</span>
            <span className="font-medium text-gray-800 text-right">
                {typeof value === 'boolean' && value === true ? 'Yes' : value}
            </span>
        </div>
    );
};

export default DetailListItem;