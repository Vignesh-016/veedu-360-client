import React from 'react';

interface DetailSectionProps {
    title: string;
    icon: React.ElementType;
    children: React.ReactNode;
    className?: string;
    gridCols?: 1 | 2;
}

const DetailSection: React.FC<DetailSectionProps> = ({ title, icon: Icon, children, className = "", gridCols = 1 }) => {
    const contentGridClass = gridCols === 1 ? 'grid-cols-1' : 'sm:grid-cols-2';
    return (
        <section className={`bg-white p-6 rounded-lg border border-gray-200 shadow-sm ${className}`}>
            <h2 className="text-xl font-semibold text-gray-800 mb-4 pb-3 border-b border-gray-100 flex items-center gap-2">
                <Icon size={22} className="text-gray-600" stroke={1.5} />
                {title}
            </h2>
            <div className={`grid ${contentGridClass} gap-x-6 gap-y-0 text-sm text-gray-700`}>
                {children}
            </div>
        </section>
    );
};

export default DetailSection;