
import { Link } from 'react-router-dom';
import { Property, ManagementPlan } from '../lib/types';
import api from '../lib/supabaseClient';
import { useEffect, useState } from 'react';
import PropertyCard from '../components/PropertyCard';
import LoadingSpinner from '../components/LoadingSpinner';
import HomeSearch from '../components/HomeSearch';
import { IconBrandWhatsapp, IconPhone, IconMail, IconStar, IconClipboardCheck, IconArmchair, IconBuildingCommunity, IconHome2 } from '@tabler/icons-react';
import { useAuth } from '../lib/AuthContext';
import { useNotification } from '../components/NotificationProvider';
import { DEFAULT_CITY } from '../lib/geoUtils';
import ServicePlanCard from '../components/ServicePlanCard';

function Home() {
    const [recommendations, setRecommendations] = useState<Property[]>([]);
    const [loadingRecs, setLoadingRecs] = useState(true);
    const [managementPlans, setManagementPlans] = useState<ManagementPlan[]>([]);
    const [loadingPlans, setLoadingPlans] = useState(true);

    const { currentCity, geolocationLoading } = useAuth();
    const { showErrorNotification } = useNotification();

    useEffect(() => {
        const fetchRecommendations = async () => {
            setLoadingRecs(true);
            try {
                let searchLocationForApi: string | undefined = undefined;
                if (!geolocationLoading) {
                    searchLocationForApi = (currentCity && currentCity !== DEFAULT_CITY) ? currentCity : DEFAULT_CITY;
                } else {
                    searchLocationForApi = DEFAULT_CITY;
                }


                const { data, error } = await api.getProperties({
                    p_limit: 4,
                    p_sort_by: 'updated_at',
                    p_sort_direction: 'DESC',
                    p_city: undefined,
                    p_location_search: searchLocationForApi,
                });
                if (error) throw error;
                setRecommendations(data || []);
            } catch (err: any) {
                console.error("Failed to fetch recommendations:", err);
                showErrorNotification('Load Failed', 'Could not load recommended properties.');
                setRecommendations([]);
            } finally {
                setLoadingRecs(false);
            }
        };
        fetchRecommendations();

    }, [currentCity, geolocationLoading, showErrorNotification]);

    useEffect(() => {
        const fetchManagementPlans = async () => {
            setLoadingPlans(true);
            try {
                const { data, error } = await api.getManagementPlans();
                if (error) throw error;
                if (data) {
                    const sortedAndFilteredPlans = data
                        .filter(plan => plan.percentage > 0)
                        .sort((a, b) => a.percentage - b.percentage);
                    setManagementPlans(sortedAndFilteredPlans);
                }
            } catch (err: any) {
                console.error("Failed to fetch management plans:", err);
                showErrorNotification('Load Failed', 'Could not load our services.');
            } finally {
                setLoadingPlans(false);
            }
        };

        fetchManagementPlans();
    }, [showErrorNotification]);

    const displayCityName = geolocationLoading && currentCity === DEFAULT_CITY ? "your area" : currentCity;


    const companyName = import.meta.env.VITE_COMPANY_NAME;

    return (
        <>
            <title>
                Find Your Perfect Property {geolocationLoading && currentCity === DEFAULT_CITY ? '' : `in ${currentCity}`} | {companyName}
            </title>
            <div className="home-page bg-gray-50 min-h-screen">

                {/* HERO SECTION */}
                <div className="relative">

                    {/* Background Image (Half Height) */}
                    <div
                        className="relative h-[55vh] md:h-[65vh] bg-cover bg-center"
                        style={{
                            backgroundImage:
                                "url('https://images.unsplash.com/photo-1564013799919-ab600027ffc6?q=80&w=1920&auto=format&fit=crop')",
                        }}
                    >
                        {/* Dark Overlay */}
                        <div className="absolute inset-0 bg-black/50" />

                        {/* Hero Text */}
                        <div className="relative z-10 h-full flex items-center justify-center text-center px-4">
                            <h1 className="text-4xl md:text-5xl lg:text-6xl font-extrabold text-white leading-tight tracking-tight">
                                Discover Your Next Property
                                <span className="block text-[#FFFFFF] mt-3 font-bold">
                                    {geolocationLoading ? DEFAULT_CITY : currentCity}
                                </span>
                            </h1>
                        </div>
                    </div>

                    {/* SEARCH CARD OVERLAY */}
                    <div className="relative z-20 -mt-24 md:-mt-32">
                        <div className="container mx-auto px-4">
                            <div className="max-w-5xl mx-auto bg-white rounded-2xl shadow-2xl p-4 md:p-6">
                                {/* SEARCH BAR */}
                                <HomeSearch />
                            </div>
                        </div>
                    </div>
                </div>


                <div className="container mx-auto px-6 md:px-16 py-12 max-w-7xl">
                    <h2 className="text-2xl font-bold text-gray-800 mb-6">
                        Featured Properties {geolocationLoading && currentCity === DEFAULT_CITY ? `in ${DEFAULT_CITY}` : `in ${currentCity}`}
                    </h2>
                    {loadingRecs ? (
                        <div className="flex justify-center py-8">
                            <LoadingSpinner />
                        </div>
                    ) : recommendations.length > 0 ? (
                        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-6">
                            {recommendations.map((prop) => (
                                <PropertyCard
                                    key={prop.property_id}
                                    property={prop}
                                    variant="simple"
                                />
                            ))}
                        </div>
                    ) : (
                        <p className="text-gray-500 text-center py-8">No featured properties available in {displayCityName} right now.</p>
                    )}
                </div>

                {/* Land/Plots Promo Section */}
                <div className="container mx-auto px-4 mb-16">
                    <div className="grid md:grid-cols-2 gap-8 md:gap-12 items-center max-w-6xl mx-auto">
                        {/* Image Side - Increased Size to 50% */}
                        <div className="relative h-64 md:h-[400px] rounded-2xl overflow-hidden shadow-lg group">
                            <img
                                src="https://images.unsplash.com/photo-1500382017468-9049fed747ef?ixlib=rb-4.0.3&auto=format&fit=crop&w=1470&q=80"
                                alt="Plots and Land"
                                className="w-full h-full object-cover transition-transform duration-700 group-hover:scale-110"
                            />
                            <div className="absolute inset-0 bg-black/10 transition-opacity group-hover:opacity-0" />
                        </div>

                        {/* Content Side - Equal Width */}
                        <div className="flex flex-col justify-center text-left py-4">
                            <span className="text-xs font-bold text-gray-500 uppercase tracking-widest mb-2">
                                Buy Plots/Land
                            </span>
                            <h2 className="text-2xl md:text-3xl font-bold text-[#2C4964] mb-3 leading-tight">
                                Residential & <br />
                                <span className="text-[#2C4964]">Commercial Plots/Land</span>
                            </h2>
                            <p className="text-gray-600 mb-6 text-sm md:text-base leading-relaxed max-w-2xl">
                                Explore the best Residential, Agricultural, Industrial, and Commercial Plots/Land investments available in <span className="font-semibold text-gray-800">{geolocationLoading ? 'your area' : currentCity}</span>.
                            </p>
                            <div>
                                <Link
                                    to={`/catalogue?p_property_types=LAND&p_listing_types=SALE&p_location_search=${currentCity || DEFAULT_CITY}`}
                                    className="inline-flex items-center justify-center px-6 py-2.5 text-sm font-bold text-white bg-[#2C4964] rounded-lg shadow-md hover:bg-[#1E3347] hover:shadow-lg hover:-translate-y-0.5 transition-all duration-300"
                                >
                                    Explore Plots/Land
                                </Link>
                            </div>
                        </div>
                    </div>
                </div>


                {/* House/Villa Promo Section - Content Left, Image Right */}
                <div className="container mx-auto px-4 mb-24 mt-12">
                    <div className="grid md:grid-cols-2 gap-8 md:gap-12 items-center max-w-6xl mx-auto">
                        {/* Content Side */}
                        <div className="flex flex-col justify-center text-left py-4 order-2 md:order-1">
                            <span className="text-xs font-bold text-gray-500 uppercase tracking-widest mb-2">
                                Buy House/Villa
                            </span>
                            <h2 className="text-2xl md:text-3xl font-bold text-[#2C4964] mb-3 leading-tight">
                                Individual Houses & <br />
                                <span className="text-[#2C4964]">Luxury Villas</span>
                            </h2>
                            <p className="text-gray-600 mb-6 text-sm md:text-base leading-relaxed max-w-2xl">
                                Discover your dream home with our wide range of Independent Houses, Villas, and Bungalows available in <span className="font-semibold text-gray-800">{geolocationLoading ? 'your area' : currentCity}</span>.
                            </p>
                            <div>
                                <Link
                                    to={`/catalogue?p_property_types=HOUSE&p_listing_types=SALE&p_location_search=${currentCity || DEFAULT_CITY}`}
                                    className="inline-flex items-center justify-center px-6 py-2.5 text-sm font-bold text-white bg-[#2C4964] rounded-lg shadow-md hover:bg-[#1E3347] hover:shadow-lg hover:-translate-y-0.5 transition-all duration-300"
                                >
                                    Explore Houses
                                </Link>
                            </div>
                        </div>

                        {/* Image Side */}
                        <div className="relative h-64 md:h-[400px] rounded-2xl overflow-hidden shadow-lg group order-1 md:order-2">
                            <img
                                src="https://images.unsplash.com/photo-1564013799919-ab600027ffc6?ixlib=rb-4.0.3&auto=format&fit=crop&w=1000&q=80"
                                alt="Luxury Villa"
                                className="w-full h-full object-cover transition-transform duration-700 group-hover:scale-110"
                            />
                            <div className="absolute inset-0 bg-black/10 transition-opacity group-hover:opacity-0" />
                        </div>
                    </div>
                </div>

                {/* WHY CHOOSE US SECTION */}
                <div className="bg-gray-50 py-16">
                    <div className="container mx-auto px-4 max-w-6xl">
                        <div className="text-center mb-10">
                            <h2 className="text-3xl font-bold text-[#2C4964] mb-3">Why Choose Us?</h2>
                            <p className="text-gray-500 max-w-2xl mx-auto text-sm">
                                We prioritize the security of your data and transactions through robust measures, offering a new standard in property management.
                            </p>
                        </div>

                        <div className="grid md:grid-cols-[1fr_1.3fr_1fr] gap-8 items-center">
                            {/* Left Column */}
                            <div className="space-y-6">
                                <div className="bg-white p-5 rounded-2xl shadow-sm border border-gray-100 hover:shadow-md transition-shadow">
                                    <div className="w-10 h-10 bg-[#2C4964] rounded-lg flex items-center justify-center mb-3">
                                        <IconClipboardCheck className="text-white w-6 h-6" stroke={2} />
                                    </div>
                                    <h3 className="font-bold text-gray-800 text-lg mb-2">Verified Listings</h3>
                                    <p className="text-xs text-gray-500 leading-relaxed">
                                        "We strive to ensure all properties listed on our platform are verified for authenticity."
                                    </p>
                                </div>
                                <div className="bg-white p-5 rounded-2xl shadow-sm border border-gray-100 hover:shadow-md transition-shadow">
                                    <div className="w-10 h-10 bg-[#2C4964] rounded-lg flex items-center justify-center mb-3">
                                        <IconArmchair className="text-white w-6 h-6" stroke={2} />
                                    </div>
                                    <h3 className="font-bold text-gray-800 text-lg mb-2">User-Friendly Interface</h3>
                                    <p className="text-xs text-gray-500 leading-relaxed">
                                        "Our platform is designed for ease of use, making your property journey smooth."
                                    </p>
                                </div>
                            </div>

                            {/* Center Column - Image */}
                            <div className="h-[450px] rounded-[2rem] overflow-hidden shadow-xl w-full relative group">
                                <img
                                    src="https://images.unsplash.com/photo-1590650046871-92c887180603?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80"
                                    alt="Why Choose Us - Support"
                                    className="w-full h-full object-cover transition-transform duration-700 group-hover:scale-105"
                                
                                />
                                <div className="absolute inset-0 bg-gradient-to-t from-black/20 to-transparent" />
                            </div>

                            {/* Right Column */}
                            <div className="space-y-6">
                                <div className="bg-white p-5 rounded-2xl shadow-sm border border-gray-100 hover:shadow-md transition-shadow">
                                    <div className="w-10 h-10 bg-[#2C4964] rounded-lg flex items-center justify-center mb-3">
                                        <IconBuildingCommunity className="text-white w-6 h-6" stroke={2} />
                                    </div>
                                    <h3 className="font-bold text-gray-800 text-lg mb-2">Comprehensive Services</h3>
                                    <p className="text-xs text-gray-500 leading-relaxed">
                                        "From listings to rent management and maintenance requests, we offer a wide array of services."
                                    </p>
                                </div>
                                <div className="bg-white p-5 rounded-2xl shadow-sm border border-gray-100 hover:shadow-md transition-shadow">
                                    <div className="w-10 h-10 bg-[#2C4964] rounded-lg flex items-center justify-center mb-3">
                                        <IconHome2 className="text-white w-6 h-6" stroke={2} />
                                    </div>
                                    <h3 className="font-bold text-gray-800 text-lg mb-2">Dedicated Support</h3>
                                    <p className="text-xs text-gray-500 leading-relaxed">
                                        "Our support team is always ready to assist you with any inquiries or issues you may have."
                                    </p>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>


                <div className="bg-gradient-to-b from-gray-50 to-white py-16 md:py-24">
                    <div className="container mx-auto px-4">
                        <div className="text-center mb-12">
                            <h2 className="text-3xl font-bold text-gray-800">Our Management Services</h2>
                            <p className="mt-4 text-lg text-gray-600 max-w-2xl mx-auto">
                                Tailored plans to fit your property management needs, from basic marketing to all-inclusive care.
                            </p>
                        </div>
                        {loadingPlans ? (
                            <div className="flex justify-center py-8">
                                <LoadingSpinner />
                            </div>
                        ) : managementPlans.length > 0 ? (
                            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-8 max-w-6xl mx-auto">
                                {managementPlans.map((plan, index) => {
                                    const totalPlans = managementPlans.length;
                                    let highlight: 'gold' | 'silver' | undefined = undefined;

                                    if (index === totalPlans - 1) {
                                        highlight = 'gold';
                                    }
                                    else if (totalPlans > 1 && index === totalPlans - 2) {
                                        highlight = 'silver';
                                    }
                                    return (
                                        <ServicePlanCard
                                            key={plan.plan_id}
                                            plan={plan}
                                            highlight={highlight}
                                        />
                                    );
                                })}
                            </div>
                        ) : (
                            <p className="text-gray-500 text-center py-8">Management service plans are not available at the moment.</p>
                        )}
                    </div>
                </div>


                {/* TESTIMONIALS SECTION */}
                <div className="bg-white py-16 md:py-24 overflow-hidden relative">
                    <div className="container mx-auto px-4 max-w-6xl">
                        <div className="grid md:grid-cols-2 gap-12 items-center">
                            {/* Left Content */}
                            <div className="text-left relative z-10">
                                <h2 className="text-4xl md:text-5xl font-extrabold text-[#2C4964] mb-6 leading-tight">
                                    What Our <br />
                                    <span className="text-[#2C4964]">Customers Say</span>
                                </h2>
                                <p className="text-gray-600 text-lg leading-relaxed mb-8 max-w-md">
                                    Hear from homeowners who rely on our management services and tenants who found their perfect homes through Veedu360.
                                </p>
                                {/* Decorative circle */}
                                <div className="absolute -left-20 -top-20 w-64 h-64 bg-blue-50 rounded-full blur-3xl opacity-50 -z-10" />
                            </div>

                            {/* Right Content - Cards Stack */}
                            <div className="relative">
                                {/* Vertical connecting line */}
                                <div className="absolute left-8 top-10 bottom-10 w-0.5 bg-gradient-to-b from-transparent via-blue-200 to-transparent hidden md:block" />

                                <div className="space-y-6 md:pl-8">
                                    {/* Evaluation Card 1 */}
                                    <div className="bg-white p-6 rounded-2xl shadow-lg border border-gray-100 flex items-start gap-4 transform transition hover:-translate-y-1 hover:shadow-xl relative z-10 ml-0 md:ml-12">
                                        <div className="w-12 h-12 rounded-full overflow-hidden flex-shrink-0 border-2 border-white shadow-sm">
                                            <img src="https://images.unsplash.com/photo-1494790108377-be9c29b29330?ixlib=rb-1.2.1&auto=format&fit=crop&w=128&q=80" alt="Mehwish" className="w-full h-full object-cover" />
                                        </div>
                                        <div>
                                            <div className="flex justify-between items-center mb-1">
                                                <h4 className="font-bold text-gray-900">Mehwish</h4>
                                                <IconStar className="w-4 h-4 text-amber-400 fill-current" />
                                            </div>
                                            <p className="text-gray-600 text-sm leading-relaxed">
                                                "Found the perfect rental apartment within days! The verification process was so smooth and gave me total peace of mind."
                                            </p>
                                        </div>
                                    </div>

                                    {/* Evaluation Card 2 (Active/Highlighted) */}
                                    <div className="bg-white p-6 rounded-2xl shadow-xl border-l-4 border-[#2C4964] flex items-start gap-4 transform scale-105 relative z-20">
                                        <div className="absolute -left-[3.25rem] top-1/2 -translate-y-1/2 w-4 h-4 rounded-full bg-[#2C4964] hidden md:block ring-4 ring-white" />
                                        <div className="w-12 h-12 rounded-full overflow-hidden flex-shrink-0 border-2 border-[#2C4964] shadow-sm">
                                            <img src="https://images.unsplash.com/photo-1531123897727-8f129e1688ce?ixlib=rb-1.2.1&auto=format&fit=crop&w=128&q=80" alt="Elizabeth" className="w-full h-full object-cover" />
                                        </div>
                                        <div>
                                            <div className="flex justify-between items-center mb-1">
                                                <h4 className="font-bold text-gray-900">Elizabeth Jeff</h4>
                                                <div className="flex gap-0.5">
                                                    <IconStar className="w-3 h-3 text-amber-400 fill-current" />
                                                    <IconStar className="w-3 h-3 text-amber-400 fill-current" />
                                                </div>
                                            </div>
                                            <p className="text-gray-600 text-sm leading-relaxed font-medium">
                                                "Veedu360's property management is top-notch. They handle everything from maintenance to tenant search, letting me relax as a landlord."
                                            </p>
                                        </div>
                                    </div>

                                    {/* Evaluation Card 3 */}
                                    <div className="bg-white p-6 rounded-2xl shadow-lg border border-gray-100 flex items-start gap-4 transform transition hover:-translate-y-1 hover:shadow-xl relative z-10 ml-0 md:ml-12">
                                        <div className="w-12 h-12 rounded-full overflow-hidden flex-shrink-0 border-2 border-white shadow-sm">
                                            <img src="https://images.unsplash.com/photo-1517841905240-472988babdf9?ixlib=rb-1.2.1&auto=format&fit=crop&w=128&q=80" alt="Emily" className="w-full h-full object-cover" />
                                        </div>
                                        <div>
                                            <div className="flex justify-between items-center mb-1">
                                                <h4 className="font-bold text-gray-900">Emily Thomas</h4>
                                                <IconStar className="w-4 h-4 text-amber-400 fill-current" />
                                            </div>
                                            <p className="text-gray-600 text-sm leading-relaxed">
                                                "As a tenant, I love the transparency. Any issues I have are resolved quickly through their dedicated ticket system. Highly recommend!"
                                            </p>
                                        </div>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>

                {/* Need Help Section */}
                <div className="bg-gray-50 py-12">
                    <div className="container mx-auto px-4">
                        <div className="max-w-5xl mx-auto">
                            <h2 className="text-2xl font-bold text-gray-800 mb-8">Need help?</h2>
                            <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                                {/* WhatsApp */}
                                <a
                                    href="https://wa.me/919566034213"
                                    target="_blank"
                                    rel="noopener noreferrer"
                                    className="bg-white rounded-xl p-6 flex items-center justify-between hover:shadow-lg transition-shadow duration-300 group cursor-pointer border border-gray-200"
                                >
                                    <div className="flex items-center gap-4">
                                        <div className="bg-green-100 p-3 rounded-full">
                                            <IconBrandWhatsapp className="h-6 w-6 text-green-600" />
                                        </div>
                                        <div>
                                            <h3 className="font-semibold text-gray-800">Ask us on WhatsApp!</h3>
                                            <p className="text-sm text-gray-500">Get instant support via WhatsApp</p>
                                        </div>
                                    </div>
                                    <svg className="h-5 w-5 text-gray-400 group-hover:text-gray-600 transition-colors" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5l7 7-7 7" />
                                    </svg>
                                </a>

                                {/* Call Support */}
                                <a
                                    href="tel:+919566034213"
                                    className="bg-white rounded-xl p-6 flex items-center justify-between hover:shadow-lg transition-shadow duration-300 group cursor-pointer border border-gray-200"
                                >
                                    <div className="flex items-center gap-4">
                                        <div className="bg-slate-100 p-3 rounded-full">
                                            <IconPhone className="h-6 w-6 text-[#2C4964]" />
                                        </div>
                                        <div className="text-left">
                                            <h3 className="font-semibold text-gray-800">Call for Support</h3>
                                            <p className="text-sm text-gray-500">Talk to our experts directly</p>
                                        </div>
                                    </div>
                                    <svg className="h-5 w-5 text-gray-400 group-hover:text-gray-600 transition-colors" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5l7 7-7 7" />
                                    </svg>
                                </a>

                                {/* Email Support */}
                                <a
                                    href="mailto:winolicreators@gmail.com"
                                    className="bg-white rounded-xl p-6 flex items-center justify-between hover:shadow-lg transition-shadow duration-300 group cursor-pointer border border-gray-200"
                                >
                                    <div className="flex items-center gap-4">
                                        <div className="bg-purple-100 p-3 rounded-full">
                                            <IconMail className="h-6 w-6 text-purple-600" />
                                        </div>
                                        <div className="text-left">
                                            <h3 className="font-semibold text-gray-800">Email Support</h3>
                                            <p className="text-sm text-gray-500">winolicreators@gmail.com</p>
                                        </div>
                                    </div>
                                    <svg className="h-5 w-5 text-gray-400 group-hover:text-gray-600 transition-colors" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5l7 7-7 7" />
                                    </svg>
                                </a>
                            </div>
                        </div>
                    </div>
                </div>


            </div >
        </>
    );
}

export default Home;