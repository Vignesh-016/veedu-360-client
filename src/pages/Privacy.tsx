import { NavLink } from 'react-router-dom';

const companyName = import.meta.env.VITE_COMPANY_NAME;
const contactEmail = import.meta.env.VITE_CONTACT_EMAIL;
const effectiveDate = "15-06-2025";

function Privacy() {
    return (
        <>
            <title>Privacy Policy | {companyName}</title>

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
                        PRIVACY POLICY
                    </h1>
                    <nav className="flex justify-center items-center space-x-2 text-white/90 font-medium">
                        <NavLink to="/" className="hover:text-white transition-colors">Home</NavLink>
                        <span>•</span>
                        <span className="text-white">Privacy Policy</span>
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
                                Your privacy is important to us. This Privacy Policy explains how {companyName} collects, uses, and protects your personal information.
                            </p>

                            <h2 className="text-2xl font-bold text-gray-800 mt-8 mb-4">1. Information We Collect</h2>
                            <p className="text-gray-600">We collect the following types of information:</p>

                            <h3 className="text-xl font-semibold text-gray-700 mt-6 mb-3">a. Personal Information:</h3>
                            <ul className="list-disc pl-6 text-gray-600 space-y-2">
                                <li>Full name, phone number, email address</li>
                                <li>Profile photo (optional)</li>
                                <li>Billing address or payment details (via secure third-party gateway)</li>
                                <li>Identity verification documents (for landlords/tenants if required)</li>
                            </ul>

                            <h3 className="text-xl font-semibold text-gray-700 mt-6 mb-3">b. Property and Usage Information:</h3>
                            <ul className="list-disc pl-6 text-gray-600 space-y-2">
                                <li>Property listings, rent amounts, and tenant details</li>
                                <li>Maintenance requests, service history</li>
                                <li>App usage logs and preferences</li>
                            </ul>

                            <h3 className="text-xl font-semibold text-gray-700 mt-6 mb-3">c. Device & Technical Data:</h3>
                            <ul className="list-disc pl-6 text-gray-600 space-y-2">
                                <li>IP address</li>
                                <li>Device type</li>
                                <li>Operating system</li>
                                <li>Browser information</li>
                            </ul>

                            <h2 className="text-2xl font-bold text-gray-800 mt-8 mb-4">2. How We Use Your Information</h2>
                            <p className="text-gray-600">We use your information to:</p>
                            <ul className="list-disc pl-6 text-gray-600 space-y-2">
                                <li>Create and manage user accounts</li>
                                <li>Facilitate rent collection and service payments</li>
                                <li>Manage property records</li>
                                <li>Send updates and alerts</li>
                                <li>Improve the platform through analytics</li>
                            </ul>

                            <h2 className="text-2xl font-bold text-gray-800 mt-8 mb-4">3. Data Sharing and Disclosure</h2>
                            <p className="text-gray-600">We do not sell your personal data. We may share information:</p>
                            <ul className="list-disc pl-6 text-gray-600 space-y-2">
                                <li>With payment providers for transaction processing</li>
                                <li>With maintenance/service vendors for task assignment</li>
                                <li>With legal authorities if required by law</li>
                            </ul>

                            <h2 className="text-2xl font-bold text-gray-800 mt-8 mb-4">4. Data Security</h2>
                            <p className="text-gray-600">We implement strict data protection measures, including:</p>
                            <ul className="list-disc pl-6 text-gray-600 space-y-2">
                                <li>Encrypted transmission (HTTPS/SSL)</li>
                                <li>Secure servers with access control</li>
                                <li>Regular security audits</li>
                            </ul>
                            <p className="text-gray-600 mt-4">While we strive for 100% security, no online platform can guarantee absolute safety.</p>

                            <h2 className="text-2xl font-bold text-gray-800 mt-8 mb-4">5. Your Rights</h2>
                            <p className="text-gray-600">Subject to local laws, you have the right to:</p>
                            <ul className="list-disc pl-6 text-gray-600 space-y-2">
                                <li>Access and view the data we hold about you</li>
                                <li>Request corrections or deletions</li>
                                <li>Withdraw consent for specific uses</li>
                            </ul>
                            <p className="text-gray-600 mt-4">
                                To exercise these rights, email us at{' '}
                                <a href={`mailto:${contactEmail}`} className="text-[#2C4964] hover:underline font-medium">{contactEmail}</a>.
                            </p>

                            <h2 className="text-2xl font-bold text-gray-800 mt-8 mb-4">6. Cookies and Tracking</h2>
                            <p className="text-gray-600">Our platform may use cookies or other tracking technologies to:</p>
                            <ul className="list-disc pl-6 text-gray-600 space-y-2">
                                <li>Store user preferences</li>
                                <li>Measure site performance</li>
                                <li>Support analytics tools</li>
                            </ul>
                            <p className="text-gray-600 mt-4">You can manage cookie preferences through your browser settings.</p>

                            <h2 className="text-2xl font-bold text-gray-800 mt-8 mb-4">7. Third-party Integrations</h2>
                            <p className="text-gray-600">We use third-party tools (e.g., Razorpay, Google Analytics). Their data use is governed by their own privacy policies.</p>
                        </div>
                    </div>
                </div>
            </div>
        </>
    );
}

export default Privacy;