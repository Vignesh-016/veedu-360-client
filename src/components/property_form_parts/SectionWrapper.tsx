import { useState } from 'react';
import { IconChevronDown, IconChevronUp } from '@tabler/icons-react';

interface SectionWrapperProps {
    title: string;
    icon: React.ElementType;
    children: React.ReactNode;
    className?: string;
    gridCols?: '1' | '2'; // md:grid-cols- value
    defaultOpen?: boolean;
}

const SectionWrapper: React.FC<SectionWrapperProps> = ({
    title,
    icon: Icon,
    children,
    className = "",
    gridCols = '2',
    defaultOpen = true,
}) => {
    const [isOpen, setIsOpen] = useState(defaultOpen);
    const gridClass = gridCols === '1' ? 'grid-cols-1' : 'md:grid-cols-2';

    return (
        <div className={`mb-6 bg-white/95 backdrop-blur-sm rounded-2xl shadow-xl border border-gray-100 overflow-hidden transition-all duration-300 hover:shadow-2xl ${className}`} >
            {/* Modern Header with gradient accent */}
            <div
                className="bg-white border-b border-gray-100 px-6 py-4 flex justify-between items-center group relative"
                onClick={() => setIsOpen(!isOpen)}
            >
                <h2 className="text-lg font-semibold text-slate-900 flex items-center gap-3">
                    <div className="p-2 bg-slate-100 rounded-lg group-hover:bg-slate-200 transition-colors">
                        <div className="absolute left-0 top-0 bottom-0 w-1 bg-gradient-to-b from-indigo-400 via-purple-400 to-pink-400"></div>
                        <Icon size={20} stroke={1.5} className="text-slate-700" />
                    </div>
                    {title}
                </h2>
                <div className="text-gray-400 group-hover:text-slate-600 transition-colors">
                    {isOpen ? <IconChevronUp size={24} /> : <IconChevronDown size={24} />}
                </div>
            </div>
            {/* Content area with refined spacing */}
            <div
                className={`transition-all duration-300 ease-in-out ${isOpen ? 'max-h-[2000px] opacity-100' : 'max-h-0 opacity-0'} overflow-hidden`}
            >
                <div className={`p-6 grid grid-cols-1 ${gridClass} gap-x-6 gap-y-4`}>
                    {children}
                </div>
            </div>
        </div>
    );
};

export default SectionWrapper;
