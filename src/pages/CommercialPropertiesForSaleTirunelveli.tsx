import { Link } from 'react-router-dom';
import { IconArrowRight, IconBuildingSkyscraper, IconCheck, IconMapPin, IconRulerMeasure, IconShieldCheck, IconBuildingStore, IconBriefcase, IconRoad } from '@tabler/icons-react';

const catalogueUrl = '/catalogue?p_listing_types=SALE&p_property_types=BUILDING&p_location_search=Tirunelveli';

const propertyTypes = [
    ['Commercial Shops for Sale', 'Find commercial shops suitable for retail stores, supermarkets, pharmacies, salons, boutiques, restaurants and other businesses. Choose a shop based on location, floor area, accessibility and your business requirements.', IconBuildingStore],
    ['Office Spaces for Sale', 'Explore office properties suitable for startups, professional services, corporate offices, consulting firms and other businesses. Look for spaces that offer convenient access and the layout your business needs.', IconBriefcase],
    ['Showrooms for Sale', 'A well-located showroom can provide excellent visibility for businesses that depend on customer traffic. Explore showroom properties suitable for retail, automobiles, furniture, electronics and other businesses.', IconBuildingSkyscraper],
    ['Commercial Buildings for Sale', 'For buyers looking for larger commercial investments, explore independent commercial buildings and properties with multiple shops or office spaces. These properties can be suitable for business operations as well as rental-oriented investment strategies.', IconBuildingSkyscraper],
    ['Commercial Land for Sale', 'Investors and business owners can also explore commercial land for sale in Tirunelveli for future development. Commercial plots can provide flexibility for constructing a property according to specific business requirements.', IconRoad],
];

const localities = ['Palayamkottai', 'KTC Nagar', 'Vannarpettai', 'Thachanallur', 'Maharaja Nagar', 'Krishnapuram', 'Perumalpuram', 'Santhi Nagar', 'Melapalayam', 'Other developing areas of Tirunelveli'];

const factors = ['Location and accessibility', 'Road frontage and visibility', 'Built-up and land area', 'Parking availability', 'Property age and condition', 'Surrounding commercial activity', 'Development potential', 'Documentation and ownership details', 'Budget and financing requirements'];

const faqs = [
    ['What types of commercial properties are available for sale in Tirunelveli?', 'Commercial properties may include shops, offices, showrooms, commercial buildings and commercial plots. Availability varies by location, size and budget.'],
    ['Where can I find commercial properties in Tirunelveli?', 'Commercial properties are available across several parts of Tirunelveli, including Palayamkottai, KTC Nagar, Vannarpettai, Thachanallur, Maharaja Nagar and other established and developing localities.'],
    ['Is buying a commercial property a good investment?', 'A commercial property can be considered for both business use and investment. However, the potential of a property depends on factors such as location, demand, price, rental prospects and future development.'],
    ['Can I buy a shop for my business in Tirunelveli?', "Yes. Commercial shops can be suitable for retail stores, restaurants, offices, pharmacies, salons and various other businesses, subject to the property's permitted use and local regulations."],
    ['How can Veedu 360 help me find a commercial property?', 'Veedu 360 helps you explore commercial property options in Tirunelveli based on factors such as location, property type, size and budget, making it easier to shortlist properties that match your requirements.'],
];

function CommercialPropertiesForSaleTirunelveli() {
    return (
        <div className="min-h-screen bg-gray-50">
            <title>Commercial Properties for Sale in Tirunelveli | Veedu 360</title>

            <section className="relative h-[410px] bg-cover bg-center sm:h-[450px] md:h-[500px]" style={{ backgroundImage: "url('https://images.unsplash.com/photo-1486406146926-c627a92ad1ab?auto=format&fit=crop&w=1920&q=85')" }}>
                <div className="absolute inset-0 bg-[#1E3347]/75" />
                <div className="relative z-10 mx-auto flex h-full max-w-7xl items-center px-4 sm:px-6">
                    <div className="max-w-3xl">
                        <div className="mb-4 inline-flex items-center gap-1.5 rounded-full bg-white/15 px-3 py-1.5 text-xs font-semibold text-white backdrop-blur-sm"><IconMapPin size={15} className="text-[#f4ca42]" /> Tirunelveli, Tamil Nadu</div>
                        <h1 className="text-3xl font-extrabold leading-tight tracking-tight text-white sm:text-4xl md:text-5xl">Commercial Properties for Sale in Tirunelveli</h1>
                        <p className="mt-4 max-w-2xl text-sm font-semibold leading-7 text-gray-100 sm:text-base">Find Commercial Properties for Sale in Tirunelveli with Veedu 360</p>
                        <Link to={catalogueUrl} className="mt-6 inline-flex items-center gap-2 rounded-lg bg-[#D9A619] px-5 py-2.5 text-sm font-bold text-[#2C4964] no-underline shadow-md transition-all hover:-translate-y-0.5 hover:bg-[#f0c13d]">Browse commercial properties today <IconArrowRight size={17} /></Link>
                    </div>
                </div>
            </section>

            <section className="mx-auto max-w-7xl px-4 py-14 sm:px-6 md:py-20">
                <div className="grid items-center gap-10 md:grid-cols-2 md:gap-12">
                    <div>
                        <span className="text-xs font-bold uppercase tracking-widest text-gray-500">Explore Commercial Property in Tirunelveli</span>
                        <h2 className="mt-3 text-3xl font-bold leading-tight text-[#2C4964]">Find Commercial Properties for Sale in Tirunelveli with Veedu 360</h2>
                        <p className="mt-4 text-sm leading-7 text-gray-600 sm:text-base">Looking for commercial properties for sale in Tirunelveli? Veedu 360 helps you discover commercial spaces that suit your business requirements and investment goals. Whether you are planning to start a new business, expand an existing operation, or invest in a property with long-term potential, explore a range of commercial property options across Tirunelveli.</p>
                        <p className="mt-4 text-sm leading-7 text-gray-600">From commercial shops and office spaces to showrooms, commercial buildings and commercial plots, Veedu 360 makes it easier to find the right property in a location that works for your business.</p>
                        <Link to={catalogueUrl} className="mt-6 inline-flex items-center justify-center gap-2 rounded-lg bg-[#2C4964] px-6 py-2.5 text-sm font-bold text-white no-underline shadow-md transition-all hover:-translate-y-0.5 hover:bg-[#1E3347] hover:shadow-lg">Explore Listings <IconArrowRight size={17} /></Link>
                    </div>
                    <div className="rounded-2xl border border-gray-200 bg-white p-6 shadow-sm sm:p-7">
                        <div className="flex h-11 w-11 items-center justify-center rounded-lg bg-[#2C4964] text-white"><IconBuildingSkyscraper size={25} /></div>
                        <p className="mt-5 text-sm leading-7 text-gray-600">Tirunelveli offers opportunities for businesses across retail, offices, services, healthcare, education, hospitality and other commercial activities. Popular areas such as Palayamkottai, KTC Nagar, Vannarpettai, Thachanallur, Maharaja Nagar and Krishnapuram feature a variety of commercial property options.</p>
                        <p className="mt-4 text-sm leading-7 text-gray-600">At Veedu 360, you can explore properties based on location, property type, size and budget, helping you narrow down your search and make a more informed property decision.</p>
                    </div>
                </div>
            </section>

            <section className="bg-white py-14 md:py-20">
                <div className="mx-auto max-w-7xl px-4 sm:px-6">
                    <div className="text-center"><span className="text-xs font-bold uppercase tracking-widest text-gray-500">Types of Commercial Properties Available</span><h2 className="mt-3 text-3xl font-bold text-[#2C4964]">Types of Commercial Properties Available</h2></div>
                    <div className="mt-10 grid gap-5 sm:grid-cols-2 lg:grid-cols-3">{propertyTypes.map(([name, description, Icon]) => <article key={name as string} className="rounded-2xl border border-gray-200 bg-white p-6 shadow-sm transition-all hover:-translate-y-0.5 hover:shadow-lg"><div className="flex h-11 w-11 items-center justify-center rounded-lg bg-[#2C4964] text-white"><Icon size={24} /></div><h3 className="mt-5 text-xl font-bold text-gray-800">{name as string}</h3><p className="mt-3 text-sm leading-7 text-gray-600">{description as string}</p><Link to={catalogueUrl} className="mt-5 inline-flex items-center gap-2 text-sm font-bold text-[#2C4964] no-underline hover:text-[#D9A619]">Explore options <IconArrowRight size={16} /></Link></article>)}</div>
                </div>
            </section>

            <section className="mx-auto max-w-7xl px-4 py-14 sm:px-6 md:py-20">
                <div className="grid gap-8 md:grid-cols-[.85fr_1.15fr] md:items-end">
                    <div><span className="text-xs font-bold uppercase tracking-widest text-gray-500">Find Commercial Property in Prime Locations</span><h2 className="mt-3 text-3xl font-bold leading-tight text-[#2C4964]">Find Commercial Property in Prime Locations</h2></div>
                    <p className="text-sm leading-7 text-gray-600">Veedu 360 helps you explore commercial properties across important areas of Tirunelveli, including:</p>
                </div>
                <div className="mt-10 grid gap-4 sm:grid-cols-2 lg:grid-cols-5">{localities.map((area) => <article key={area} className="flex items-center gap-3 rounded-xl border border-gray-200 bg-white p-4 shadow-sm transition-all hover:-translate-y-0.5 hover:shadow-md"><IconMapPin size={19} className="shrink-0 text-[#D9A619]" /><h3 className="text-sm font-bold text-gray-800">{area}</h3></article>)}</div>
                <p className="mt-6 text-sm leading-7 text-gray-600">Whether you need a property on a busy road, a shop in a commercial locality, an office space or a larger commercial building, explore available options based on your requirements.</p>
            </section>

            <section className="bg-white py-14 md:py-20">
                <div className="mx-auto grid max-w-7xl gap-10 px-4 sm:px-6 md:grid-cols-2 md:items-center">
                    <div className="relative h-64 overflow-hidden rounded-2xl shadow-lg md:h-[360px]"><img src="https://images.unsplash.com/photo-1497366754035-f200968a6e72?auto=format&fit=crop&w=1000&q=85" alt="Modern commercial office space" className="h-full w-full object-cover" /><div className="absolute inset-0 bg-black/10" /></div>
                    <div><span className="text-xs font-bold uppercase tracking-widest text-gray-500">Commercial Property for Business or Investment</span><h2 className="mt-3 text-3xl font-bold leading-tight text-[#2C4964]">Commercial Property for Business or Investment</h2><p className="mt-4 text-sm leading-7 text-gray-600">A commercial property can serve two important purposes: business use and investment.</p><p className="mt-4 text-sm leading-7 text-gray-600">Business owners can purchase a property instead of paying rent over the long term, while investors may consider properties with rental potential depending on the location, tenant demand and property characteristics.</p><p className="mt-4 text-sm font-semibold leading-7 text-gray-700">Before purchasing, consider factors such as:</p><div className="mt-4 grid grid-cols-1 gap-3 text-sm text-gray-600 sm:grid-cols-2">{factors.map((item) => <div key={item} className="flex gap-2"><IconCheck size={17} className="shrink-0 text-[#D9A619]" />{item}</div>)}</div></div>
                </div>
            </section>

            <section className="mx-auto max-w-7xl px-4 py-14 sm:px-6 md:py-20">
                <div className="grid gap-8 md:grid-cols-2">
                    <div className="rounded-2xl bg-[#2C4964] p-7 text-white sm:p-8"><IconShieldCheck className="text-[#D9A619]" size={32} /><h2 className="mt-5 text-2xl font-bold">Why Choose Commercial Property in Tirunelveli?</h2><p className="mt-3 text-sm leading-7 text-slate-200">Choosing the right commercial property involves more than simply finding a building. Location, accessibility, surrounding development, property configuration and future business requirements all play an important role.</p><p className="mt-4 text-sm leading-7 text-slate-200">Tirunelveli has a growing range of commercial property options, including shops, showrooms, offices and commercial land. Current market listings also show properties across different sizes and price segments, giving buyers multiple options depending on their investment capacity and business needs.</p></div>
                    <div className="rounded-2xl border border-gray-200 bg-white p-7 shadow-sm sm:p-8"><IconRulerMeasure className="text-[#2C4964]" size={32} /><h2 className="mt-5 text-2xl font-bold text-gray-800">Why Choose Veedu 360?</h2><p className="mt-3 text-sm leading-7 text-gray-600">Veedu 360 makes your search for commercial properties in Tirunelveli simpler and more convenient. Our platform helps buyers discover property options and compare them based on their preferred location, property type and requirements.</p><p className="mt-4 text-sm leading-7 text-gray-600">Whether you are a first-time business owner, an established entrepreneur or a property investor, Veedu 360 can help you explore suitable commercial real estate opportunities in Tirunelveli.</p></div>
                </div>
            </section>

            <section className="bg-white py-14 md:py-20"><div className="mx-auto max-w-5xl px-4 sm:px-6"><div className="text-center"><span className="text-xs font-bold uppercase tracking-widest text-gray-500">Frequently Asked Questions</span><h2 className="mt-3 text-3xl font-bold text-[#2C4964]">Frequently Asked Questions</h2></div><div className="mt-8 divide-y divide-gray-200 rounded-xl border border-gray-200 bg-white px-5">{faqs.map(([question, answer], index) => <details key={question} className="group py-4"><summary className="cursor-pointer list-none pr-6 text-sm font-bold text-gray-800">{index + 1}. {question}<span className="float-right text-xl font-normal text-[#2C4964] transition-transform group-open:rotate-45">+</span></summary><p className="pt-3 pr-4 text-sm leading-6 text-gray-600">{answer}</p></details>)}</div></div></section>

            <section className="px-4 py-14 sm:px-6 md:py-20"><div className="mx-auto max-w-7xl rounded-2xl bg-[#2C4964] px-6 py-10 text-center shadow-lg sm:px-10"><h2 className="text-3xl font-bold text-white">Find Your Commercial Property in Tirunelveli</h2><p className="mx-auto mt-3 max-w-2xl text-sm leading-7 text-slate-200">Your next business opportunity could start with the right location. Explore commercial properties for sale in Tirunelveli with Veedu 360 and find a property that matches your business plans and investment goals.</p><p className="mx-auto mt-3 max-w-2xl text-sm leading-7 text-slate-200">Browse commercial properties today and take the next step towards owning commercial real estate in Tirunelveli.</p><Link to={catalogueUrl} className="mt-6 inline-flex items-center justify-center gap-2 rounded-lg bg-[#D9A619] px-6 py-2.5 text-sm font-bold text-[#2C4964] no-underline shadow-md transition-all hover:-translate-y-0.5 hover:bg-[#f0c13d]">Browse commercial properties today <IconArrowRight size={17} /></Link></div></section>
        </div>
    );
}

export default CommercialPropertiesForSaleTirunelveli;
