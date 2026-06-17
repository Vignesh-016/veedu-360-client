// src/pages/AboutUs.tsx

import { NavLink } from 'react-router-dom';
import { IconArrowRight, IconCheckbox, IconLayout, IconApps, IconHeadset } from '@tabler/icons-react';

const companyName = import.meta.env.VITE_COMPANY_NAME || 'Veedu360';

function AboutUs() {
    return (
        <>
            <title>About Us | {companyName}</title>

            {/* Hero Section */}
            <section className="relative h-[400px] flex items-center justify-center overflow-hidden">
                <div
                    className="absolute inset-0 bg-cover bg-center z-0"
                    style={{
                        backgroundImage: 'url("/images/about/hero-house.png")',
                        filter: 'brightness(0.6)'
                    }}
                />
                <div className="relative z-10 text-center container mx-auto px-4">
                    <h1 className="text-5xl md:text-6xl font-bold text-white mb-4 tracking-tight drop-shadow-lg">
                        ABOUT US
                    </h1>
                    <nav className="flex justify-center items-center space-x-2 text-white/90 font-medium">
                        <NavLink to="/" className="hover:text-white transition-colors">Home</NavLink>
                        <span>•</span>
                        <span className="text-white">About Us</span>
                    </nav>
                </div>
            </section>

            <div className="bg-white">
                {/* Section 1: Our Mission */}
                <section className="py-20 container mx-auto px-4">
                    <div className="flex flex-col lg:flex-row items-center gap-12 max-w-7xl mx-auto">
                        <div className="lg:w-1/2 space-y-6">
                            <div className="inline-flex items-center space-x-2 bg-[#2C4964]/10 px-4 py-2 rounded-full text-[#2C4964] font-medium text-sm">
                                <span className="flex space-x-1">
                                    {[1, 2, 3, 4, 5].map((s) => (
                                        <span key={s} className="text-yellow-400 text-xs">★</span>
                                    ))}
                                </span>
                                <span>4.97/5 reviews</span>
                            </div>
                            <h2 className="text-4xl md:text-5xl font-bold text-[#2C4964] leading-tight">
                                Our Mission
                            </h2>
                            <p className="text-gray-600 text-lg leading-relaxed">
                                At {companyName}, our mission is to revolutionize the property market by providing a seamless, transparent, and efficient platform for buyers, sellers, landlords, and tenants. We aim to simplify property transactions and management through innovative technology and exceptional customer service.
                            </p>
                            <p className="text-gray-600 text-lg leading-relaxed border-l-4 border-[#2C4964] pl-6 italic bg-gray-50 py-4 rounded-r-xl">
                                We believe that finding, managing, or transacting property should be a straightforward and empowering experience. Our platform is built to ensure trust, security, and convenience for all our users.
                            </p>
                            <div className="flex flex-wrap gap-4 pt-4">
                                <button className="bg-[#2C4964] hover:bg-[#1E3347] text-white px-8 py-3 rounded-lg font-semibold flex items-center space-x-2 transition-all transform hover:scale-105">
                                    <span>Explore Properties</span>
                                    <IconArrowRight size={20} />
                                </button>
                            </div>
                        </div>
                        <div className="lg:w-1/2">
                            <div className="relative rounded-3xl overflow-hidden shadow-2xl transform hover:scale-[1.02] transition-transform duration-500">
                                <img
                                    src="/images/about/man-working.png"
                                    alt="Our Mission in action"
                                    className="w-full h-full object-cover"
                                />
                                <div className="absolute bottom-0 left-0 right-0 bg-gradient-to-t from-black/60 to-transparent p-8">
                                    <h3 className="text-white text-2xl font-bold italic">"Empowering your property journey."</h3>
                                </div>
                            </div>
                        </div>
                    </div>
                </section>

                {/* Section 2: Our Story & Team */}
                <section className="py-20 bg-gray-50">
                    <div className="container mx-auto px-4">
                        <div className="flex flex-col lg:flex-row-reverse items-start gap-16 max-w-7xl mx-auto">
                            <div className="lg:w-1/2 space-y-10">
                                <div className="space-y-4">
                                    <h2 className="text-3xl md:text-4xl font-bold text-[#2C4964]">Our Story</h2>
                                    <p className="text-gray-600 text-lg leading-relaxed">
                                        Founded with a vision to address the complexities of the real estate sector, {companyName} started as a small idea to bridge the gap between property seekers and providers. We noticed the challenges faced by individuals in navigating the property landscape – from finding reliable listings to managing rental agreements and maintenance.
                                    </p>
                                    <p className="text-gray-600 text-lg leading-relaxed">
                                        Driven by a passion for technology and real estate, our team embarked on a journey to create a comprehensive solution. Over the years, we've grown into a trusted platform, continuously evolving to meet the dynamic needs of the market and our valued users.
                                    </p>
                                </div>
                                <div className="space-y-4">
                                    <h2 className="text-3xl md:text-4xl font-bold text-[#2C4964]">Our Team</h2>
                                    <p className="text-gray-600 text-lg leading-relaxed">
                                        The {companyName} team is composed of dedicated professionals from diverse backgrounds, including technology, real estate, customer service, and marketing. We share a common goal: to make property dealings easier and more accessible for everyone.
                                    </p>
                                    <p className="text-gray-600 text-lg leading-relaxed">
                                        Our experts work tirelessly to enhance the platform, introduce new features, and provide unparalleled support to ensure a positive experience for every user. We are committed to fostering a community built on integrity and mutual respect.
                                    </p>
                                </div>
                            </div>
                            <div className="lg:w-1/2 sticky top-24">
                                <div className="rounded-3xl overflow-hidden shadow-2xl relative">
                                    <img
                                        src="/images/about/woman-smiling.png"
                                        alt="Our Team & Vision"
                                        className="w-full h-full object-cover"
                                    />
                                    <div className="absolute top-6 left-6 bg-white/90 backdrop-blur-sm px-6 py-4 rounded-2xl shadow-lg border border-white/50">
                                        <div className="flex items-center space-x-4">
                                            <div className="bg-[#2C4964] text-white p-2 rounded-xl">
                                                <IconApps size={24} />
                                            </div>
                                            <div>
                                                <div className="text-sm text-gray-500 font-medium whitespace-nowrap">Unified Platform</div>
                                                <div className="text-xl font-bold text-gray-900">Comprehensive Solutions</div>
                                            </div>
                                        </div>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>
                </section>

                {/* Section 3: Why Choose Us? */}
                <section className="py-24 container mx-auto px-4">
                    <div className="text-center max-w-3xl mx-auto mb-16 space-y-4">
                        <h2 className="text-4xl md:text-5xl font-bold text-[#2C4964]">Why Choose Us?</h2>
                        <p className="text-gray-600 text-lg">We prioritize the security of your data and transactions through robust measures, offering a new standard in property management.</p>
                    </div>

                    <div className="flex flex-col lg:flex-row items-center justify-center gap-12 max-w-7xl mx-auto">
                        <div className="lg:w-1/3 space-y-8">
                            <div className="bg-gray-50 p-8 rounded-2xl space-y-4 hover:bg-white hover:shadow-xl transition-all border border-transparent hover:border-[#2C4964]/20 group relative">
                                <div className="bg-[#2C4964] w-14 h-14 rounded-2xl flex items-center justify-center text-white group-hover:scale-110 transition-transform shadow-lg shadow-[#2C4964]/20">
                                    <IconCheckbox size={28} />
                                </div>
                                <h4 className="text-2xl font-bold text-[#2C4964]">Verified Listings</h4>
                                <p className="text-gray-600 leading-relaxed italic">"We strive to ensure all properties listed on our platform are verified for authenticity."</p>
                            </div>
                            <div className="bg-gray-50 p-8 rounded-2xl space-y-4 hover:bg-white hover:shadow-xl transition-all border border-transparent hover:border-[#2C4964]/20 group relative">
                                <div className="bg-[#2C4964] w-14 h-14 rounded-2xl flex items-center justify-center text-white group-hover:scale-110 transition-transform shadow-lg shadow-[#2C4964]/20">
                                    <IconLayout size={28} />
                                </div>
                                <h4 className="text-2xl font-bold text-[#2C4964]">User-Friendly Interface</h4>
                                <p className="text-gray-600 leading-relaxed italic">"Our platform is designed for ease of use, making property search and management intuitive."</p>
                            </div>
                        </div>

                        <div className="lg:w-1/3 h-[550px]">
                            <div className="h-full rounded-3xl overflow-hidden shadow-2xl ring-8 ring-[#2C4964]/5">
                                <img
                                    src="/images/about/woman-laptop.png"
                                    alt="Technology & Support"
                                    className="w-full h-full object-cover"
                                />
                            </div>
                        </div>

                        <div className="lg:w-1/3 space-y-8">
                            <div className="bg-gray-50 p-8 rounded-2xl space-y-4 hover:bg-white hover:shadow-xl transition-all border border-transparent hover:border-[#2C4964]/20 group relative">
                                <div className="bg-[#2C4964] w-14 h-14 rounded-2xl flex items-center justify-center text-white group-hover:scale-110 transition-transform shadow-lg shadow-[#2C4964]/20">
                                    <IconApps size={28} />
                                </div>
                                <h4 className="text-2xl font-bold text-[#2C4964]">Comprehensive Services</h4>
                                <p className="text-gray-600 leading-relaxed italic">"From listings to rent management and maintenance requests, we offer a wide array of services."</p>
                            </div>
                            <div className="bg-gray-50 p-8 rounded-2xl space-y-4 hover:bg-white hover:shadow-xl transition-all border border-transparent hover:border-[#2C4964]/20 group relative">
                                <div className="bg-[#2C4964] w-14 h-14 rounded-2xl flex items-center justify-center text-white group-hover:scale-110 transition-transform shadow-lg shadow-[#2C4964]/20">
                                    <IconHeadset size={28} />
                                </div>
                                <h4 className="text-2xl font-bold text-[#2C4964]">Dedicated Support</h4>
                                <p className="text-gray-600 leading-relaxed italic">"Our customer support team is always ready to assist you with any queries or issues."</p>
                            </div>
                        </div>
                    </div>


                </section>
            </div>
        </>
    );
}

export default AboutUs;