import { useState, useEffect } from 'react';

import api from '../lib/supabaseClient';
import { VisitPlan } from '../lib/types';
import LoadingSpinner from '../components/LoadingSpinner';
import { IconAlertCircle, IconPackage, IconStarFilled, IconCrown, IconMapPin, IconBuildingCommunity } from '@tabler/icons-react';
import { useNotification } from '../components/NotificationProvider';
import { useAuth } from '../lib/AuthContext';
import { useNavigate } from 'react-router-dom';



declare global {
    interface Window {
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        Razorpay: any; // Define Razorpay type on window
    }
}

function Plans() {
    const [plans, setPlans] = useState<VisitPlan[]>([]);
    const [loading, setLoading] = useState(false);
    const [paymentLoading, setPaymentLoading] = useState(false);
    const [error, setError] = useState<string | null>(null);
    const [selectedPlan, setSelectedPlan] = useState<VisitPlan | null>(null);
    const { showSuccessNotification, showErrorNotification, showInfoNotification } = useNotification();
    const { user, refetchBalance } = useAuth();
    const navigate = useNavigate();

    useEffect(() => {
        const fetchPlans = async () => {
            setLoading(true);
            setError(null);
            try {
                const { data, error: fetchErr } = await api.getVisitPlans();
                if (fetchErr) throw fetchErr;
                const activePlans = data || [];
                setPlans(activePlans);
                // Select the middle (center) plan by default if available
                if (activePlans.length > 0) {
                    const middleIndex = Math.floor(activePlans.length / 2);
                    setSelectedPlan(activePlans[middleIndex]);
                }
            } catch (err: any) {
                showErrorNotification('Load Failed', err.message || 'Failed to fetch plans.');
                setError(err.message || 'Failed to fetch plans.');
            } finally {
                setLoading(false);
            }
        };
        fetchPlans();
    }, [showErrorNotification]);

    const companyName = import.meta.env.VITE_COMPANY_NAME;

    // --- Handle Purchase ---
    const handlePurchase = async () => {
        if (!selectedPlan || paymentLoading || !user) {
            if (!user) showErrorNotification('Login Required', 'Please log in to purchase a plan.');
            return;
        }

        setPaymentLoading(true);
        setError(null); // Clear previous errors

        try {
            // 1. Create Order via Edge Function
            showInfoNotification('Processing Payment', 'Creating payment order...');
            const { data: orderData, error: orderError } = await api.createPaymentOrder({
                plan_id: selectedPlan.plan_id,
            });

            if (orderError || !orderData) {
                throw new Error(orderError as string || 'Failed to create payment order.');
            }

            const { orderId, amount, keyId } = orderData;

            // 2. Prepare Razorpay Options
            const options = {
                key: keyId,
                amount: amount,
                currency: "INR",
                name: companyName + " Property Visits",
                description: `Purchase: ${selectedPlan.name} (${selectedPlan.visits} visits)`,
                order_id: orderId,
                // eslint-disable-next-line @typescript-eslint/no-explicit-any
                handler: async (response: any) => {
                    // 3. Verify Payment via Edge Function
                    setPaymentLoading(true);
                    showInfoNotification('Processing Payment', 'Verifying payment details...');
                    try {
                        const payload = {
                            razorpay_order_id: response.razorpay_order_id,
                            razorpay_payment_id: response.razorpay_payment_id,
                            razorpay_signature: response.razorpay_signature,
                        }
                        const { data: verifyData, error: verifyError } = await api.verifyPayment(payload);
                        if (verifyError || !verifyData?.success) {
                            throw new Error(verifyError as string || 'Payment verification failed.');
                        }

                        showSuccessNotification('Payment Successful!', `Added ${selectedPlan.visits} visits to your account.`);
                        await refetchBalance();
                        navigate('/catalogue');

                    } catch (verificationError: any) {
                        showErrorNotification('Verification Failed', verificationError.message || 'Could not verify payment. Please contact support.');
                        setError(verificationError.message || 'Payment verification failed.');
                    } finally {
                        setPaymentLoading(false);
                    }
                },
                prefill: {
                    name: user.user_metadata?.full_name || user.email,
                    email: user.email,
                    contact: user.phone || user.user_metadata?.phone,
                },
                notes: {
                    plan_id: selectedPlan.plan_id,
                    user_id: user.id,
                },
                theme: {
                    color: "#2C4964"
                }
            };

            await api.openRazorpayCheckout(options);

        } catch (err: any) {
            console.error("Payment initiation error:", err);
            showErrorNotification('Payment Error', err.message || 'Could not initiate payment.');
            setError(err.message || 'Failed to start payment.');
            setPaymentLoading(false);
        }
    };


    return (
        <>
            <title>Visit Plans | {companyName}</title>
            <div className="py-8 container mx-auto h-full flex flex-col">
                <div className="max-w-4xl mx-auto w-full px-4">
                    <div className="mb-10 text-center">
                        <h1 className="text-4xl font-extrabold text-[#2C4964] mb-3 leading-tight tracking-tight">Choose Your Plan</h1>
                        <p className="text-gray-600 font-medium">Select a premium plan to buy property visit credits and unlock exclusive features.</p>
                    </div>

                    {/* Loading State */}
                    {loading && (<div className="flex justify-center items-center py-16"><LoadingSpinner /></div>)}

                    {/* Error State */}
                    {error && !paymentLoading && ( // Show general error only if not in payment process
                        <div className="bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded-lg mb-6 shadow-sm">
                            <div className="flex items-center">
                                <IconAlertCircle className="h-5 w-5 mr-2" />
                                <span><strong className="font-bold">Error: </strong>{error}</span>
                            </div>
                        </div>
                    )}

                    {/* Empty State */}
                    {!loading && plans.length === 0 && (
                        <div className="bg-white rounded-lg p-8 border border-gray-200 shadow-sm text-center">
                            <IconPackage className="h-12 w-12 mx-auto text-gray-400 mb-4" />
                            <p className="text-gray-600">No plans available at the moment.</p>
                            <p className="text-gray-500 text-sm mt-2">Please check back later or contact support.</p>
                        </div>
                    )}

                    {/* Plans Display */}
                    {!loading && plans.length > 0 && (
                        <>
                            <div className="grid grid-cols-1 md:grid-cols-3 gap-8 max-w-6xl mx-auto items-stretch pt-12 pb-16">
                                {plans.map((plan) => {
                                    const isSelected = selectedPlan?.plan_id === plan.plan_id;
                                    const lowerName = plan.name.toLowerCase();

                                    let CurrentIcon = IconStarFilled;
                                    let currentGradient = 'from-[#3A5D7C] to-[#2C4964]';
                                    let currentHighlight = 'text-[#2C4964]';
                                    let currentShadow = 'shadow-[#2C4964]/20';
                                    let currentRing = 'ring-[#2C4964]/10';
                                    let currentBorder = 'border-[#2C4964]';

                                    if (lowerName.includes('starter')) {
                                        CurrentIcon = IconMapPin; // Location pin symbolizing property visits
                                        currentGradient = 'from-[#3A5D7C] to-[#2C4964]'; // Navy Premium
                                        currentHighlight = 'text-[#2C4964]';
                                        currentShadow = 'shadow-[#2C4964]/20';
                                        currentRing = 'ring-[#2C4964]/10';
                                        currentBorder = 'border-[#2C4964]';
                                    } else if (lowerName.includes('bronze') || lowerName.includes('silver') || lowerName.includes('standard')) {
                                        CurrentIcon = IconBuildingCommunity; // Community complex symbolizing multi-property visits
                                        currentGradient = 'from-[#C59B27] to-[#8F6F1B]'; // Muted Gold/Bronze
                                        currentHighlight = 'text-[#8F6F1B]';
                                        currentShadow = 'shadow-[#C59B27]/20';
                                        currentRing = 'ring-[#C59B27]/10';
                                        currentBorder = 'border-[#C59B27]';
                                    } else if (lowerName.includes('gold') || lowerName.includes('premium') || lowerName.includes('elite')) {
                                        CurrentIcon = IconCrown; // Crown symbolizing ultimate royal package
                                        currentGradient = 'from-[#E5B83B] to-[#D9A619]'; // Ultra-Premium Gold
                                        currentHighlight = 'text-[#D9A619]';
                                        currentShadow = 'shadow-[#D9A619]/25';
                                        currentRing = 'ring-[#D9A619]/10';
                                        currentBorder = 'border-[#D9A619]';
                                    }

                                    const buttonGradient = isSelected
                                        ? `bg-gradient-to-r ${currentGradient} shadow-lg ${currentShadow} text-white`
                                        : 'bg-[#2C4964] text-white hover:bg-[#1E3347] shadow-md hover:shadow-lg hover:-translate-y-0.5';

                                    return (
                                        <div
                                            key={plan.plan_id}
                                            onClick={() => setSelectedPlan(plan)}
                                            className={`relative bg-white rounded-[2rem] p-8 pt-12 text-center transition-all duration-300 cursor-pointer flex flex-col
                                                ${isSelected
                                                    ? `shadow-2xl scale-105 ring-4 ${currentRing} border-t-4 ${currentBorder} z-10`
                                                    : 'shadow-lg hover:shadow-xl hover:-translate-y-1 border border-gray-100 hover:border-gray-200'
                                                }
                                            `}
                                        >
                                            {/* Floating Icon Header */}
                                            <div className={`absolute -top-8 left-1/2 transform -translate-x-1/2 w-16 h-16 rounded-full bg-gradient-to-br ${currentGradient} flex items-center justify-center shadow-lg`}>
                                                <CurrentIcon className="text-white w-8 h-8" stroke={1.5} />
                                            </div>

                                            <h3 className={`mt-4 text-sm font-bold uppercase tracking-widest ${isSelected ? 'text-gray-800' : 'text-gray-500'}`}>
                                                {plan.name}
                                            </h3>

                                            <div className="mt-6 mb-8">
                                                <span className="text-4xl font-extrabold text-gray-900">
                                                    ₹{plan.price.toLocaleString('en-IN')}
                                                </span>
                                                <span className="text-gray-400 font-medium">/pack</span>
                                            </div>

                                            <p className="text-gray-500 text-sm leading-relaxed mb-8 flex-grow border-t border-gray-100 pt-6">
                                                {plan.description || `Get ${plan.visits} property visit credits valid for a lifetime.`}
                                                <br />
                                                <span className="text-xs text-gray-400 mt-2 block">
                                                    (≈ ₹{Math.round(plan.price / plan.visits)} per visit)
                                                </span>
                                            </p>

                                            <button
                                                onClick={(e) => {
                                                    e.stopPropagation();
                                                    setSelectedPlan(plan);
                                                    if (isSelected) handlePurchase();
                                                }}
                                                disabled={paymentLoading}
                                                className={`w-full py-4 rounded-full font-bold text-sm tracking-wide transition-all duration-300 transform active:scale-95 ${buttonGradient}`}
                                            >
                                                {paymentLoading && isSelected ? <div className="text-white flex justify-center"><LoadingSpinner size={16} /></div> : `Get ${plan.visits} Visits Plan`}
                                            </button>

                                            {isSelected && (
                                                <div className={`mt-4 text-xs font-bold ${currentHighlight} animate-pulse`}>
                                                    Currently Selected
                                                </div>
                                            )}
                                        </div>
                                    );
                                })}
                            </div>

                            {/* Mobile Buy Button (Fixed Bottom) */}
                            <div className="md:hidden fixed bottom-0 left-0 right-0 p-4 bg-white border-t border-gray-200 shadow-[0_-4px_6px_-1px_rgba(0,0,0,0.1)] z-50">
                                <button
                                    onClick={handlePurchase}
                                    disabled={!selectedPlan || paymentLoading}
                                    className="w-full bg-[#2C4964] text-white font-bold py-3.5 rounded-full shadow-lg hover:bg-[#1E3347] transition-all duration-300"
                                >
                                    {selectedPlan ? `Pay ₹${selectedPlan.price.toLocaleString('en-IN')} Now` : 'Select a Plan'}
                                </button>
                            </div>
                        </>
                    )}
                </div>
            </div>
        </>
    );
}

export default Plans;