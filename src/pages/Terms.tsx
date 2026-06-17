import { NavLink } from 'react-router-dom';

const companyName = import.meta.env.VITE_COMPANY_NAME;
const effectiveDate = "15-06-2025";

function Terms() {
    return (
        <>
            <title>Terms and Conditions | {companyName}</title>

            {/* Hero Banner Section with Background Image */}
            <section className="relative h-[300px] md:h-[400px] flex items-center justify-center overflow-hidden">
                <div
                    className="absolute inset-0 bg-cover bg-center z-0"
                    style={{
                        backgroundImage: 'url("/images/about/hero-house.png")',
                        filter: 'brightness(0.6)'
                    }}
                />
                <div className="relative z-10 text-center container mx-auto px-4">
                    <h1 className="text-4xl md:text-5xl lg:text-6xl font-bold text-white mb-4 tracking-tight drop-shadow-lg">
                        TERMS & CONDITIONS
                    </h1>
                    <nav className="flex justify-center items-center space-x-2 text-white/90 font-medium">
                        <NavLink to="/" className="hover:text-white transition-colors">Home</NavLink>
                        <span>•</span>
                        <span className="text-white">Terms & Conditions</span>
                    </nav>
                </div>
            </section>

            {/* Content Section */}
            <div className="bg-gray-50 py-12 md:py-16">
                <div className="container mx-auto px-4 max-w-4xl">
                    <div className="bg-white rounded-2xl shadow-lg p-8 md:p-12 border border-gray-100">
                        {/* Effective Date Badge */}
                        <div className="flex flex-wrap gap-4 mb-8">
                            <span className="inline-flex items-center px-4 py-2 bg-[#2C4964]/10 text-[#2C4964] text-sm font-medium rounded-full">
                                Effective Date: {effectiveDate}
                            </span>
                            <span className="inline-flex items-center px-4 py-2 bg-gray-100 text-gray-600 text-sm font-medium rounded-full">
                                Last Updated: {effectiveDate}
                            </span>
                        </div>

                        <div className="prose prose-lg prose-slate max-w-none">
                            <p className="text-gray-600 text-lg leading-relaxed">
                                Welcome to {companyName}. These Terms and Conditions ("Terms") govern your use of our web and mobile platform, including all related services offered through our application (the "Platform" or "Service").
                            </p>

                            <h2 className="text-2xl font-bold text-gray-800 mt-8 mb-4">1. Acceptance of Terms</h2>
                            <p className="text-gray-600">By accessing or using our platform, you agree to be bound by these Terms. If you do not agree with any part, you may not access the service.</p>

                            <h2 className="text-2xl font-bold text-gray-800 mt-8 mb-4">2. Description of Service</h2>
                            <p className="text-gray-600">{companyName} is a property management application designed to simplify interactions between landlords, tenants, property managers, and service providers. Our platform may include features such as:</p>
                            <ul className="list-disc pl-6 text-gray-600 space-y-2">
                                <li>Property listing and management</li>
                                <li>Tenant onboarding</li>
                                <li>Rental payment collection</li>
                                <li>Maintenance requests</li>
                                <li>Communication tools</li>
                                <li>Document storage</li>
                            </ul>

                            <h2 className="text-2xl font-bold text-gray-800 mt-8 mb-4">3. User Eligibility</h2>
                            <p className="text-gray-600">You must be:</p>
                            <ul className="list-disc pl-6 text-gray-600 space-y-2">
                                <li>At least 18 years of age</li>
                                <li>Capable of forming a legally binding agreement</li>
                                <li>Using the platform for lawful purposes</li>
                            </ul>

                            <h2 className="text-2xl font-bold text-gray-800 mt-8 mb-4">4. Account Registration and Security</h2>
                            <p className="text-gray-600">Users are required to:</p>
                            <ul className="list-disc pl-6 text-gray-600 space-y-2">
                                <li>Provide accurate and complete information during registration</li>
                                <li>Maintain the confidentiality of their account credentials</li>
                                <li>Notify us immediately of any unauthorized use of the account</li>
                            </ul>
                            <p className="text-gray-600 mt-4">We reserve the right to suspend or delete accounts that violate our Terms or display suspicious activity.</p>

                            <h2 className="text-2xl font-bold text-gray-800 mt-8 mb-4">5. User Responsibilities</h2>
                            <p className="text-gray-600">You agree not to:</p>
                            <ul className="list-disc pl-6 text-gray-600 space-y-2">
                                <li>Upload false or misleading property information</li>
                                <li>Use the platform to harass, abuse, or harm others</li>
                                <li>Infringe on intellectual property rights</li>
                                <li>Transmit malicious software or attempt to hack the system</li>
                                <li>Use the platform for unlawful purposes</li>
                            </ul>
                            <p className="text-gray-600 mt-4">You are solely responsible for the accuracy of the content and listings you upload.</p>

                            <h2 className="text-2xl font-bold text-gray-800 mt-8 mb-4">6. Payments and Fees</h2>
                            <ul className="list-disc pl-6 text-gray-600 space-y-2">
                                <li>Subscription fees (if applicable) are billed monthly or annually as per your plan.</li>
                                <li>Payments made through the app (rent, deposits, maintenance charges) are processed via third-party payment gateways.</li>
                                <li>We do not hold or store credit card information on our servers.</li>
                                <li>Transaction fees may be applicable and are non-refundable unless explicitly stated.</li>
                            </ul>

                            <h2 className="text-2xl font-bold text-gray-800 mt-8 mb-4">7. Property Listings and Transactions</h2>
                            <p className="text-gray-600">We do not guarantee the accuracy, suitability, or legality of any listing or transaction between users. Users are solely responsible for their interactions and must comply with applicable rental/property laws.</p>

                            <h2 className="text-2xl font-bold text-gray-800 mt-8 mb-4">8. License and Intellectual Property</h2>
                            <p className="text-gray-600">All content on the Platform including code, design, logos, and software is our intellectual property or licensed to us. You may not:</p>
                            <ul className="list-disc pl-6 text-gray-600 space-y-2">
                                <li>Copy, reproduce, or modify any part of the platform</li>
                                <li>Use our branding without written permission</li>
                            </ul>

                            <h2 className="text-2xl font-bold text-gray-800 mt-8 mb-4">9. Limitation of Liability</h2>
                            <p className="text-gray-600">We are not liable for:</p>
                            <ul className="list-disc pl-6 text-gray-600 space-y-2">
                                <li>Losses or damages caused by user content or third-party services</li>
                                <li>Any indirect or consequential damages arising from your use of the Service</li>
                                <li>Disputes between property owners and tenants</li>
                            </ul>

                            <h2 className="text-2xl font-bold text-gray-800 mt-8 mb-4">10. Termination</h2>
                            <p className="text-gray-600">We reserve the right to suspend or terminate accounts:</p>
                            <ul className="list-disc pl-6 text-gray-600 space-y-2">
                                <li>For violation of these Terms</li>
                                <li>Due to inactivity</li>
                                <li>For suspected fraud or abuse</li>
                            </ul>
                            <p className="text-gray-600 mt-4">You may terminate your account by contacting support.</p>

                            <h2 className="text-2xl font-bold text-gray-800 mt-8 mb-4">11. Governing Law and Dispute Resolution</h2>
                            <p className="text-gray-600">These Terms are governed by the laws of India, Tamil Nadu. Any disputes shall be subject to the exclusive jurisdiction of the courts of Tirunelveli.</p>

                            <h2 className="text-2xl font-bold text-gray-800 mt-8 mb-4">12. Amendments</h2>
                            <p className="text-gray-600">We may update these Terms from time to time. Continued use of the platform after changes means you accept the revised terms.</p>
                        </div>
                    </div>
                </div>
            </div>
        </>
    );
}

export default Terms;