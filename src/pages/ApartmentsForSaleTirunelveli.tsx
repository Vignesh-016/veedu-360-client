import { Link } from 'react-router-dom';
import { IconArrowRight, IconBuildingCommunity, IconCheck, IconHome2, IconMapPin, IconRulerMeasure, IconShieldCheck } from '@tabler/icons-react';

const catalogueUrl = '/catalogue?p_listing_types=SALE&p_property_types=HOUSE&p_house_types=APARTMENT_FLAT&p_location_search=Tirunelveli';

const apartmentTypes = ['2 BHK apartments for sale in Tirunelveli', '3 BHK apartments for sale in Tirunelveli', 'Ready-to-move apartments', 'New apartments and residential projects', 'Resale flats', 'Budget-friendly and premium apartments'];
const localities = [
    ['Palayamkottai', 'Explore apartments in one of Tirunelveli’s prominent residential areas.'],
    ['KTC Nagar', 'Compare flats and apartments by your preferred budget and requirements.'],
    ['NGO Colony', 'Look for apartments, houses and other residential properties.'],
    ['Tirunelveli Junction', 'Consider a well-connected location close to the city’s essentials.'],
    ['Maharaja Nagar', 'Browse another popular residential locality in Tirunelveli.'],
    ['Perumalpuram', 'Discover homes in and around Tirunelveli city.'],
];
const faqs = [
    ['Which type of apartments are available for sale in Tirunelveli?', 'Depending on current listings, you can find 2 BHK and 3 BHK flats, new apartments, ready-to-move properties and resale flats.'],
    ['Which are the popular areas to buy apartments in Tirunelveli?', 'Popular areas searched by apartment buyers include Palayamkottai, KTC Nagar, NGO Colony, Tirunelveli Junction, Maharaja Nagar and Perumalpuram.'],
    ['Are 2 BHK flats available for sale in Tirunelveli?', 'Yes. 2 BHK apartments are commonly searched residential property types. Availability, price and specifications vary by locality and property.'],
    ['Can I find ready-to-move apartments in Tirunelveli?', 'Yes. Availability changes over time, so check the latest Veedu 360 listings for currently available homes.'],
    ['Is buying an apartment in Tirunelveli a good investment?', 'It depends on the location, purchase price, rental demand, property condition, connectivity and future development. Evaluate each property individually before investing.'],
    ['How can I find an apartment for sale in Tirunelveli?', 'Explore current Veedu 360 listings, compare by location, BHK and budget, and shortlist apartments that match your requirements.'],
];

function ApartmentsForSaleTirunelveli() {
    return (
        <div className="min-h-screen bg-gray-50">
            <title>Apartments for Sale in Tirunelveli | Veedu 360</title>

            <section className="relative h-[410px] bg-cover bg-center sm:h-[450px] md:h-[500px]" style={{ backgroundImage: "url('https://images.unsplash.com/photo-1564013799919-ab600027ffc6?auto=format&fit=crop&w=1920&q=85')" }}>
                <div className="absolute inset-0 bg-[#1E3347]/70" />
                <div className="relative z-10 mx-auto flex h-full max-w-7xl items-center px-4 sm:px-6">
                    <div className="max-w-3xl">
                        <div className="mb-4 inline-flex items-center gap-1.5 rounded-full bg-white/15 px-3 py-1.5 text-xs font-semibold text-white backdrop-blur-sm"><IconMapPin size={15} className="text-[#f4ca42]" /> Tirunelveli, Tamil Nadu</div>
                        <h1 className="text-3xl font-extrabold leading-tight tracking-tight text-white sm:text-4xl md:text-5xl">Apartments for Sale in Tirunelveli</h1>
                        <p className="mt-4 max-w-2xl text-sm leading-7 text-gray-100 sm:text-base">Find the right flat for your family, lifestyle and budget. Explore apartments across Palayamkottai, KTC Nagar, NGO Colony, Tirunelveli Junction, Maharaja Nagar, Perumalpuram and nearby localities.</p>
                        <Link to={catalogueUrl} className="mt-6 inline-flex items-center gap-2 rounded-lg bg-[#D9A619] px-5 py-2.5 text-sm font-bold text-[#2C4964] no-underline shadow-md transition-all hover:-translate-y-0.5 hover:bg-[#f0c13d]">Browse Apartments <IconArrowRight size={17} /></Link>
                    </div>
                </div>
            </section>

            <section className="mx-auto max-w-7xl px-4 py-14 sm:px-6 md:py-20">
                <div className="grid items-center gap-10 md:grid-cols-2 md:gap-12">
                    <div><span className="text-xs font-bold uppercase tracking-widest text-gray-500">Find the right flat</span><h2 className="mt-3 text-3xl font-bold leading-tight text-[#2C4964]">A better way to explore apartments in Tirunelveli.</h2><p className="mt-4 text-sm leading-7 text-gray-600 sm:text-base">Buying an apartment is an important decision. Veedu 360 helps you discover properties based on location, BHK configuration, budget and property type—so it is easier to compare choices and shortlist the homes that fit.</p><Link to={catalogueUrl} className="mt-6 inline-flex items-center justify-center gap-2 rounded-lg bg-[#2C4964] px-6 py-2.5 text-sm font-bold text-white no-underline shadow-md transition-all hover:-translate-y-0.5 hover:bg-[#1E3347] hover:shadow-lg">Browse Apartments <IconArrowRight size={17} /></Link></div>
                    <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">{apartmentTypes.map((item) => <div key={item} className="flex items-start gap-3 rounded-xl border border-gray-100 bg-white p-4 shadow-sm transition-shadow hover:shadow-md"><span className="flex h-8 w-8 shrink-0 items-center justify-center rounded-lg bg-[#2C4964] text-white"><IconCheck size={17} /></span><p className="pt-1 text-sm font-medium leading-5 text-gray-700">{item}</p></div>)}</div>
                </div>
            </section>

            <section className="bg-white py-14 md:py-20"><div className="mx-auto max-w-7xl px-4 sm:px-6"><div className="text-center"><span className="text-xs font-bold uppercase tracking-widest text-gray-500">Choose your home</span><h2 className="mt-3 text-3xl font-bold text-[#2C4964]">2 BHK and 3 BHK apartments</h2><p className="mx-auto mt-3 max-w-2xl text-sm leading-7 text-gray-500">Whether you need an efficient family home or room to grow, compare the floor area, layout, location and amenities that matter to you.</p></div><div className="mt-10 grid gap-6 md:grid-cols-2">
                <article className="rounded-2xl border border-gray-200 bg-white p-6 shadow-sm transition-shadow hover:shadow-lg"><div className="flex h-11 w-11 items-center justify-center rounded-lg bg-[#2C4964] text-white"><IconHome2 size={25} /></div><h3 className="mt-5 text-xl font-bold text-gray-800">2 BHK Flats for Sale</h3><p className="mt-3 text-sm leading-7 text-gray-600">A 2 BHK flat in Tirunelveli is a popular choice for small and medium-sized families, first-time homebuyers and investors looking for a practical blend of space, comfort and affordability.</p><Link to={catalogueUrl} className="mt-5 inline-flex items-center gap-2 text-sm font-bold text-[#2C4964] no-underline hover:text-[#D9A619]">Explore 2 BHK apartments <IconArrowRight size={16} /></Link></article>
                <article className="rounded-2xl border border-gray-200 bg-white p-6 shadow-sm transition-shadow hover:shadow-lg"><div className="flex h-11 w-11 items-center justify-center rounded-lg bg-[#2C4964] text-white"><IconBuildingCommunity size={25} /></div><h3 className="mt-5 text-xl font-bold text-gray-800">3 BHK Apartments for Sale</h3><p className="mt-3 text-sm leading-7 text-gray-600">Three-bedroom apartments offer more room for children, guests, a home office or other family requirements. Compare 3 BHK flats in different parts of Tirunelveli.</p><Link to={catalogueUrl} className="mt-5 inline-flex items-center gap-2 text-sm font-bold text-[#2C4964] no-underline hover:text-[#D9A619]">Explore 3 BHK apartments <IconArrowRight size={16} /></Link></article>
            </div></div></section>

            <section className="mx-auto max-w-7xl px-4 py-14 sm:px-6 md:py-20"><div className="grid gap-8 md:grid-cols-[.85fr_1.15fr] md:items-end"><div><span className="text-xs font-bold uppercase tracking-widest text-gray-500">Popular areas</span><h2 className="mt-3 text-3xl font-bold leading-tight text-[#2C4964]">Where would you like to live?</h2></div><p className="text-sm leading-7 text-gray-600">Tirunelveli offers homes in established neighbourhoods and developing areas. Start with the locality that suits your routine, then compare available properties by size and budget.</p></div><div className="mt-10 grid gap-4 sm:grid-cols-2 lg:grid-cols-3">{localities.map(([name, description]) => <article key={name} className="rounded-xl border border-gray-200 bg-white p-5 shadow-sm transition-all hover:-translate-y-0.5 hover:shadow-md"><div className="flex items-center gap-2 text-[#D9A619]"><IconMapPin size={19} /><h3 className="text-lg font-bold text-gray-800">{name}</h3></div><p className="mt-3 text-sm leading-6 text-gray-500">{description}</p></article>)}</div></section>

            <section className="bg-white py-14 md:py-20"><div className="mx-auto grid max-w-7xl gap-10 px-4 sm:px-6 md:grid-cols-2 md:items-center"><div className="relative h-64 overflow-hidden rounded-2xl shadow-lg md:h-[360px]"><img src="https://images.unsplash.com/photo-1600585154340-be6161a56a0c?auto=format&fit=crop&w=1000&q=85" alt="Apartment building for sale" className="h-full w-full object-cover" /><div className="absolute inset-0 bg-black/10" /></div><div><span className="text-xs font-bold uppercase tracking-widest text-gray-500">Apartments at every budget</span><h2 className="mt-3 text-3xl font-bold leading-tight text-[#2C4964]">Compare what matters before you decide.</h2><p className="mt-4 text-sm leading-7 text-gray-600">Whether you are looking for an affordable flat, a mid-range family apartment or a premium property, compare the details carefully before making your decision.</p><div className="mt-6 grid grid-cols-2 gap-3 text-sm text-gray-600">{['Total price', 'Price per sq. ft.', 'Built-up & carpet area', 'Parking & amenities', 'Construction status', 'Connectivity'].map((item) => <div key={item} className="flex gap-2"><IconCheck size={17} className="shrink-0 text-[#D9A619]" />{item}</div>)}</div></div></div></section>

            <section className="mx-auto max-w-7xl px-4 py-14 sm:px-6 md:py-20"><div className="grid gap-8 md:grid-cols-2"><div className="rounded-2xl bg-[#2C4964] p-7 text-white sm:p-8"><IconShieldCheck className="text-[#D9A619]" size={32} /><h2 className="mt-5 text-2xl font-bold">New apartments and resale flats</h2><p className="mt-3 text-sm leading-7 text-slate-200">New apartments may appeal if you prefer newer construction, modern layouts and contemporary amenities. Resale flats can be useful for buyers looking for established properties and ready-to-move homes.</p></div><div className="rounded-2xl border border-gray-200 bg-white p-7 shadow-sm sm:p-8"><IconRulerMeasure className="text-[#2C4964]" size={32} /><h2 className="mt-5 text-2xl font-bold text-gray-800">Why buy in Tirunelveli?</h2><p className="mt-3 text-sm leading-7 text-gray-600">Buyers can find apartments across different budgets, sizes and locations, with access to schools, hospitals, shopping areas and everyday amenities depending on the locality.</p></div></div></section>

            <section className="bg-white py-14 md:py-20"><div className="mx-auto max-w-5xl px-4 sm:px-6"><div className="text-center"><span className="text-xs font-bold uppercase tracking-widest text-gray-500">Frequently asked questions</span><h2 className="mt-3 text-3xl font-bold text-[#2C4964]">Helpful answers for apartment buyers</h2></div><div className="mt-8 divide-y divide-gray-200 rounded-xl border border-gray-200 bg-white px-5">{faqs.map(([question, answer]) => <details key={question} className="group py-4"><summary className="cursor-pointer list-none pr-6 text-sm font-bold text-gray-800">{question}<span className="float-right text-xl font-normal text-[#2C4964] transition-transform group-open:rotate-45">+</span></summary><p className="pt-3 pr-4 text-sm leading-6 text-gray-600">{answer}</p></details>)}</div></div></section>

            <section className="px-4 py-14 sm:px-6 md:py-20"><div className="mx-auto max-w-7xl rounded-2xl bg-[#2C4964] px-6 py-10 text-center shadow-lg sm:px-10"><h2 className="text-3xl font-bold text-white">Ready to find your apartment?</h2><p className="mx-auto mt-3 max-w-2xl text-sm leading-7 text-slate-200">Browse available listings, compare properties and shortlist apartments that match your requirements.</p><Link to={catalogueUrl} className="mt-6 inline-flex items-center justify-center gap-2 rounded-lg bg-[#D9A619] px-6 py-2.5 text-sm font-bold text-[#2C4964] no-underline shadow-md transition-all hover:-translate-y-0.5 hover:bg-[#f0c13d]">Explore Apartments in Tirunelveli <IconArrowRight size={17} /></Link></div></section>
        </div>
    );
}

export default ApartmentsForSaleTirunelveli;
