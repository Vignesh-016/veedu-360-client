import { useParams } from 'react-router-dom';
import PropertyComingSoon from '../components/PropertyComingSoon';

const categoryCopy: Record<string, { title: string; message: string }> = {
    'buy-buildings': { title: 'Buildings for Sale – Coming Soon', message: 'We’re currently adding verified building listings. Please check back soon.' },
    'buy-apartments': { title: 'Apartments for Sale – Coming Soon', message: 'We’re currently adding verified apartment listings. Please check back soon.' },
    'rent-land': { title: 'Land for Rent – Coming Soon', message: 'Rental land listings will be available soon.' },
};

function ComingSoon() {
    const { category } = useParams<{ category: string }>();
    const copy = categoryCopy[category || ''] || { title: 'Properties – Coming Soon', message: 'Properties in this category are currently unavailable. We’re working on adding more listings soon.' };
    return <main className="min-h-[60vh] bg-gray-50 px-4 py-16"><div className="mx-auto max-w-2xl"><PropertyComingSoon title={copy.title} description={copy.message} /></div></main>;
}

export default ComingSoon;
