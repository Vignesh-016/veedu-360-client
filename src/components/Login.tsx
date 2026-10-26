import { IconBrandGoogle } from '@tabler/icons-react';
import { useAuth } from '../lib/AuthContext';

import { Navigate, Link, useLocation } from 'react-router-dom';
import LoadingSpinner from './LoadingSpinner';

function Login() {
    const { user, loading, signInWithGoogle } = useAuth();
    const location = useLocation();

    if (!loading && user) {
        const destination = sessionStorage.getItem('postLoginDestination') || location.state?.from || '/';
        sessionStorage.removeItem('postLoginDestination');
        return <Navigate to={destination} replace />;
    }

    const companyName = import.meta.env.VITE_COMPANY_NAME?.trim() || 'Veedu 360';

    return (
        <>
            <title>Sign In | {companyName}</title>

            <div className="min-h-screen flex">
                {/* Left Side - Home image */}
                <div className="hidden lg:block lg:w-1/2 overflow-hidden bg-[#2C4964]">
                    <img
                        src="/images/Website_Home_Page.jpg.jpeg"
                        alt="Veedu 360 property management"
                        className="h-full w-full object-cover"
                    />
                </div>

                {/* Right Side - Login Form */}
                <div className="w-full lg:w-1/2 flex items-center justify-center bg-gray-50 px-6 py-12">
                    <div className="w-full max-w-md">
                        {/* Logo */}
                        <div className="text-center mb-10">
                            <Link to="/">
                                <img src="/veedu360-logo.png" alt={companyName} className="h-32 w-auto mx-auto mb-2" />
                            </Link>
                        </div>

                        {/* Sign In Card */}
                        <div className="bg-white rounded-2xl shadow-xl p-8 border border-gray-100">
                            <div className="text-center mb-8">
                                <h2 className="text-2xl font-bold text-gray-900 mb-2">
                                    Welcome Back!
                                </h2>
                                <p className="text-gray-500 text-sm">
                                    Sign in to continue to {companyName}
                                </p>
                            </div>

                            {/* Google Button */}
                            <button
                                onClick={signInWithGoogle}
                                disabled={loading}
                                className="w-full flex items-center justify-center gap-3 bg-[#2C4964] hover:bg-[#1E3347] text-white font-semibold py-4 px-6 rounded-xl shadow-lg shadow-[#2C4964]/20 hover:shadow-xl hover:shadow-[#2C4964]/30 transform hover:-translate-y-0.5 transition-all duration-200 disabled:opacity-50 disabled:cursor-not-allowed disabled:transform-none"
                            >
                                {loading ? (
                                    <LoadingSpinner size={22} />
                                ) : (
                                    <>
                                        <IconBrandGoogle size={22} />
                                        <span>Continue with Google</span>
                                    </>
                                )}
                            </button>

                            {/* Terms */}
                            <p className="text-center text-gray-400 text-xs mt-6">
                                By continuing, you agree to our{' '}
                                <a href="/terms" className="text-[#2C4964] hover:underline">Terms of Service</a>
                                {' '}and{' '}
                                <a href="/privacy" className="text-[#2C4964] hover:underline">Privacy Policy</a>
                            </p>
                        </div>

                        {/* Help Link */}
                        <div className="text-center mt-8">
                            <p className="text-gray-500 text-sm">
                                Need help?{' '}
                                <a
                                    href="https://wa.me/919566034213"
                                    target="_blank"
                                    rel="noopener noreferrer"
                                    className="text-[#2C4964] hover:underline font-medium"
                                >
                                    Contact Support
                                </a>
                            </p>
                        </div>

                        {/* Copyright */}
                        <p className="text-center text-gray-400 text-xs mt-6">
                            © {new Date().getFullYear()} {companyName}. All rights reserved.
                        </p>
                    </div>
                </div>
            </div>
        </>
    );
}

export default Login;
