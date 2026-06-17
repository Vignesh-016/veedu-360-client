import { IconBrandGoogle, IconHome2, IconKey } from '@tabler/icons-react';
import { useAuth } from '../lib/AuthContext';

import { Navigate, Link } from 'react-router-dom';
import LoadingSpinner from './LoadingSpinner';

function Login() {
    const { user, loading, signInWithGoogle } = useAuth();

    if (!loading && user) {
        return <Navigate to="/" replace />;
    }

    const companyName = import.meta.env.VITE_COMPANY_NAME;

    return (
        <>
            <title>Sign In | {companyName}</title>

            <div className="min-h-screen flex">
                {/* Left Side - Gradient Illustration */}
                <div className="hidden lg:flex lg:w-1/2 bg-gradient-to-br from-[#2C4964] via-[#1E3347] to-[#111F2D] relative overflow-hidden">
                    {/* Background Pattern */}
                    <div className="absolute inset-0 opacity-10">
                        <div className="absolute top-20 left-20 w-32 h-32 border-4 border-white rounded-2xl rotate-12"></div>
                        <div className="absolute bottom-32 right-20 w-24 h-24 border-4 border-white rounded-full"></div>
                        <div className="absolute top-1/2 left-1/3 w-16 h-16 bg-white rounded-lg rotate-45"></div>
                    </div>

                    {/* Content */}
                    <div className="relative z-10 flex flex-col justify-center items-center w-full px-12 text-center">
                        <div className="mb-8">

                            <h1 className="text-4xl font-bold text-white mb-4">
                                Find Your Dream Home
                            </h1>
                            <p className="text-white/80 text-lg max-w-md">
                                Discover thousands of properties for rent and sale. Your perfect home is just a click away.
                            </p>
                        </div>

                        {/* Feature List */}
                        <div className="space-y-4 text-left max-w-sm">
                            <div className="flex items-center gap-3 text-white/90">
                                <div className="w-8 h-8 bg-white/20 rounded-lg flex items-center justify-center">
                                    <IconHome2 size={18} />
                                </div>
                                <span>Browse verified property listings</span>
                            </div>
                            <div className="flex items-center gap-3 text-white/90">
                                <div className="w-8 h-8 bg-white/20 rounded-lg flex items-center justify-center">
                                    <IconKey size={18} />
                                </div>
                                <span>Schedule visits with one tap</span>
                            </div>
                        </div>
                    </div>
                </div>

                {/* Right Side - Login Form */}
                <div className="w-full lg:w-1/2 flex items-center justify-center bg-gray-50 px-6 py-12">
                    <div className="w-full max-w-md">
                        {/* Logo */}
                        <div className="text-center mb-10">
                            <Link to="/">
                                <img src="/logo.png" alt={companyName} className="h-12 w-auto mx-auto mb-2" />
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