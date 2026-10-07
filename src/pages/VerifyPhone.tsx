import { useState, useEffect } from 'react';
import { useAuth } from '../lib/AuthContext';
import { useNavigate, useLocation } from 'react-router-dom';
import { IconAlertCircle, IconDeviceMobileMessage } from '@tabler/icons-react';

import api from '../lib/supabaseClient';
import { getPrimaryButtonClasses, getBaseInputClasses } from '../lib/twUtils';
import LoadingSpinner from '../components/LoadingSpinner';
import { useNotification } from '../components/NotificationProvider';

function VerifyPhone() {
    const [phoneNumber, setPhoneNumber] = useState('+91');
    const [otp, setOtp] = useState('');
    const [otpSent, setOtpSent] = useState(false);
    const [loading, setLoading] = useState(false);
    const [error, setError] = useState<string | null>(null);
    const [resendTimer, setResendTimer] = useState(0);
    const { showSuccessNotification } = useNotification();

    const { user } = useAuth();
    const navigate = useNavigate();
    const location = useLocation();
    const from = location.state?.from || '/';

    useEffect(() => {
        if (user?.user_metadata?.phone) {
            setPhoneNumber(user.user_metadata.phone);
        }
    }, [user]);

    // Resend timer logic
    useEffect(() => {
        let interval: NodeJS.Timeout | null = null;
        if (resendTimer > 0) {
            interval = setInterval(() => {
                setResendTimer(prev => prev - 1);
            }, 1000);
        } else if (interval) {
            clearInterval(interval);
        }
        return () => {
            if (interval) clearInterval(interval);
        };
    }, [resendTimer]);

    const validatePhoneNumber = (phone: string): boolean => {
        const phoneRegex = /^\+91[6-9]\d{9}$/;
        return phoneRegex.test(phone);
    };

    const handleSendOtp = async (isResend = false) => {
        if (loading || (isResend && resendTimer > 0)) return;
        setLoading(true);
        setError(null);

        if (!validatePhoneNumber(phoneNumber)) {
            setError('Please enter a valid 10-digit Indian mobile number (e.g., +919876543210).');
            setLoading(false);
            return;
        }

        try {
            const { error: updateError } = await api.supabase.auth.updateUser({
                phone: phoneNumber,
            });
            if (updateError) throw updateError;

            setOtpSent(true);
            setResendTimer(60);
            setError(null);
            if (isResend) {
                showSuccessNotification('OTP Resent', `New OTP sent to ${phoneNumber}`);
            }

        } catch (err: any) {
            console.error("OTP Send Error:", err);
            setError(err.message || 'Failed to send OTP. Please try again.');
        } finally {
            setLoading(false);
        }
    };

    const handleVerifyOtp = async () => {
        if (loading || !otp.trim()) {
            if (!otp.trim()) setError('Please enter the OTP.');
            return;
        }
        setLoading(true);
        setError(null);

        try {
            const { error: verifyError } = await api.supabase.auth.verifyOtp({
                phone: phoneNumber,
                token: otp,
                type: 'phone_change'
            });

            if (verifyError) {
                throw verifyError;
            }

            navigate(from, { replace: true });

        } catch (err: any) {
            console.error("OTP Verify Error:", err);
            if (err.message && err.message.toLowerCase().includes('token has expired')) {
                setError('OTP has expired. Please request a new one.');
            } else if (err.message && err.message.toLowerCase().includes('token not found')) {
                setError('Invalid OTP. Please check and try again.');
            } else {
                setError(err.message || 'Failed to verify OTP. Please try again.');
            }
        } finally {
            setLoading(false);
        }
    };
    const companyName = import.meta.env.VITE_COMPANY_NAME;

    return (
        <>
            <title>Verify Phone Number | {companyName}</title>
            <div className="flex min-h-screen bg-white">
                {/* Left Column - Form */}
                <div className="flex flex-col items-center justify-center w-full lg:w-1/2 p-6 md:p-12 relative bg-gradient-to-br from-slate-50 via-white to-blue-50">
                    {loading && (
                        <div className="absolute inset-0 bg-white/70 flex items-center justify-center z-10">
                            <LoadingSpinner />
                        </div>
                    )}
                    <div className="w-full max-w-md mx-auto rounded-3xl border border-slate-200 bg-white p-7 shadow-xl shadow-slate-200/60 md:p-9">
                        <div className="mb-7 flex items-center gap-2" aria-label="Verification progress"><div className="flex flex-1 items-center gap-2"><span className="flex h-7 w-7 items-center justify-center rounded-full bg-[#2C4964] text-xs font-bold text-white">1</span><span className="text-xs font-semibold text-[#2C4964]">Phone</span></div><div className="h-px flex-1 bg-slate-200"><div className={`h-px bg-[#2C4964] transition-all ${otpSent ? 'w-full' : 'w-0'}`}></div></div><div className="flex flex-1 items-center justify-end gap-2"><span className={`flex h-7 w-7 items-center justify-center rounded-full text-xs font-bold ${otpSent ? 'bg-[#2C4964] text-white' : 'bg-slate-100 text-slate-400'}`}>2</span><span className={`text-xs font-semibold ${otpSent ? 'text-[#2C4964]' : 'text-slate-400'}`}>Verify</span></div></div>
                        <div className="mb-7 flex items-center gap-3"><div className="flex h-11 w-11 items-center justify-center rounded-2xl bg-[#2C4964] text-white"><IconDeviceMobileMessage size={23} /></div><div><p className="text-xs font-semibold uppercase tracking-[0.18em] text-[#2C4964]">Secure your account</p><p className="text-sm text-slate-500">Takes less than a minute</p></div></div>
                        <h2 className="text-3xl font-bold text-[#102a43] mb-3">
                            Verify Your Phone Number
                        </h2>
                        <p className="mb-7 text-sm leading-6 text-slate-600">Use your mobile number to receive login alerts, visit updates, and important property notifications from Veedu360.</p>

                        {error && (
                            <div className="bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded-lg mb-4 text-sm flex items-center gap-2" role="alert">
                                <IconAlertCircle className="h-5 w-5 flex-shrink-0" />
                                <span>{error}</span>
                            </div>
                        )}

                        {!otpSent ? (
                            // Phone Number Input Stage
                            <div className="space-y-4">
                                <div>
                                    <label htmlFor="phone" className="block text-sm font-medium text-gray-700 mb-1">
                                        Mobile Number
                                    </label>
                                    <input
                                        type="tel"
                                        id="phone"
                                        name="phone"
                                        className={getBaseInputClasses(!!error)}
                                        placeholder="+91XXXXXXXXXX"
                                        value={phoneNumber}
                                        onChange={(e) => {
                                            const value = e.target.value.replace(/[^+\d]/g, ''); // Allow only digits and +
                                            // Basic formatting/restriction
                                            if (value.startsWith('+91') && value.length <= 13) {
                                                setPhoneNumber(value);
                                                if (error) setError(null); // Clear error on input change
                                            } else if (value.length <= 10 && /^\d+$/.test(value)) {
                                                setPhoneNumber('+91' + value); // Auto-prefix if just numbers
                                                if (error) setError(null);
                                            } else if (value === '+' || value === '+9' || value === '+91') {
                                                setPhoneNumber(value); // Allow typing prefix
                                                if (error) setError(null);
                                            }
                                        }}
                                        autoComplete="tel"
                                    />
                                </div>
                                <button
                                    onClick={() => handleSendOtp(false)}
                                    disabled={loading || !validatePhoneNumber(phoneNumber)}
                                    className={`${getPrimaryButtonClasses()} w-full py-3.5 disabled:opacity-50`}
                                >
                                    Send OTP
                                </button>
                            </div>
                        ) : (
                            // OTP Verification Stage
                            <div className="space-y-4">
                                <p className="text-sm text-gray-600 text-center">
                                    Enter the 6-digit OTP sent to <span className="font-medium">{phoneNumber}</span>.
                                </p>
                                <div>
                                    <label htmlFor="otp" className="block text-sm font-medium text-gray-700 mb-1">
                                        One-Time Password (OTP)
                                    </label>
                                    <input
                                        type="text" // Use text to allow easier input on mobile? Or number? Let's try text.
                                        id="otp"
                                        name="otp"
                                        inputMode="numeric" // Hint for numeric keyboard
                                        pattern="\d{6}" // Basic pattern hint
                                        maxLength={6}
                                        className={`${getBaseInputClasses(!!error)} text-center tracking-[0.3em]`} // Center and space out digits
                                        placeholder="------"
                                        value={otp}
                                        onChange={(e) => {
                                            const value = e.target.value.replace(/\D/g, ''); // Allow only digits
                                            if (value.length <= 6) {
                                                setOtp(value);
                                                if (error) setError(null); // Clear error on input change
                                            }
                                        }}
                                        autoComplete="one-time-code"
                                    />
                                </div>
                                <button
                                    onClick={handleVerifyOtp}
                                    disabled={loading || otp.length !== 6}
                                    className={`${getPrimaryButtonClasses()} w-full py-3.5 disabled:opacity-50`}
                                >
                                    Verify OTP
                                </button>
                                <div className="text-center text-sm">
                                    <button
                                        onClick={() => handleSendOtp(true)}
                                        disabled={loading || resendTimer > 0}
                                        className={`text-gray-600 hover:underline disabled:text-gray-400 disabled:cursor-not-allowed`}
                                    >
                                        Resend OTP {resendTimer > 0 ? `(${resendTimer}s)` : ''}
                                    </button>
                                </div>
                                <div className="text-center text-sm">
                                    <button
                                        onClick={() => { setOtpSent(false); setError(null); setOtp(''); }} // Go back to phone entry
                                        disabled={loading}
                                        className="text-gray-500 hover:underline"
                                    >
                                        Change phone number?
                                    </button>
                                </div>
                            </div>
                        )}
                    </div>
                </div>

                {/* Right Column - Illustration */}
                <div className="hidden lg:block w-1/2 overflow-hidden bg-slate-100">
                    <img src="/images/Website_Home_Page.jpg.jpeg" alt="Veedu360 properties" className="h-full w-full object-cover" />
                </div>
            </div>
        </>
    );
}

export default VerifyPhone;
