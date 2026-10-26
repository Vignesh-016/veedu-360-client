import { IconArrowLeft, IconClock } from '@tabler/icons-react';
import { Link } from 'react-router-dom';

interface PropertyComingSoonProps {
    title?: string;
    description?: string;
}

function PropertyComingSoon({ title = 'Properties Coming Soon', description = 'There are currently no active listings matching your search.' }: PropertyComingSoonProps) {
    return (
        <div className="rounded-2xl border border-gray-200 bg-white px-6 py-14 text-center shadow-sm">
            <div className="mx-auto mb-5 w-fit rounded-full bg-[#2C4964]/10 p-4 text-[#2C4964]"><IconClock size={36} stroke={1.6} /></div>
            <h2 className="text-2xl font-bold text-[#2C4964]">{title}</h2>
            <p className="mx-auto mt-4 max-w-lg text-gray-600">{description}</p>
            <p className="mt-2 text-sm text-gray-500">We’re adding new verified properties regularly. Please check back soon or explore other available properties.</p>
            <Link to="/catalogue" className="mt-8 inline-flex items-center gap-2 rounded-lg bg-[#2C4964] px-6 py-3 text-sm font-semibold text-white shadow-sm transition hover:bg-[#1E3347]"><IconArrowLeft size={17} /> Browse Available Properties</Link>
        </div>
    );
}

export default PropertyComingSoon;
