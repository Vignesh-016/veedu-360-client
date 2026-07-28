import { useState, useEffect } from 'react';
import api from '../lib/supabaseClient';
import { ContactPlan } from '../lib/types';
import LoadingSpinner from '../components/LoadingSpinner';
import { IconAlertCircle, IconPhoneCall, IconCrown, IconGift, IconCheckbox } from '@tabler/icons-react';
import { useNotification } from '../components/NotificationProvider';
import { useAuth } from '../lib/AuthContext';
import { useNavigate } from 'react-router-dom';

function BuyContactPlans() {
    const [plans, setPlans] = useState<ContactPlan[]>([]);
    const [loading, setLoading] = useState(false);
    const [paymentLoading, setPaymentLoading] = useState(false);
    const [error, setError] = useState<string | null>(null);
    const [selectedPlan, setSelectedPlan] = useState<ContactPlan | null>(null);
    const { showSuccessNotification, showErrorNotification, showInfoNotification } = useNotification();
    const { user, balance, refetchBalance } = useAuth();
    const navigate = useNavigate();

    useEffect(() => {
        const fetchPlans = async () => {
            setLoading(true);
            setError(null);
            try {
                const { data, error: fetchErr } = await api.getContactPlans();
                if (fetchErr) throw fetchErr;
                const activePlans = data || [];
                setPlans(activePlans);
                if (activePlans.length > 0) {
                    // Pre-select first paid plan or default plan
                    const defaultPlan = activePlans.find(p => p.price > 0) || activePlans[0];
                    setSelectedPlan(defaultPlan);
                }
            } catch (err: any) {
                showErrorNotification('Load Failed', err.message || 'Failed to fetch contact plans.');
                setError(err.message || 'Failed to fetch contact plans.');
            } finally {
                setLoading(false);
            }
        };
        fetchPlans();
    }, [showErrorNotification]);

    const companyName = import.meta.env.VITE_COMPANY_NAME || "Veedu 360";

    const handleClaimFree = async (plan: ContactPlan) => {
        setPaymentLoading(true);
        setError(null);
        try {
            showInfoNotification('Claiming Plan', 'Registering your free contact plan...');
            const { data, error: claimErr } = await api.claimFreeContactPlan(plan.plan_id);
            if (claimErr || !data?.success) {
                throw new Error((claimErr as any)?.message || claimErr as string || data?.error || 'Failed to claim free plan.');
            }
            showSuccessNotification('Claimed!', `Added ${plan.contacts} contact credits to your account.`);
            await refetchBalance();
            navigate('/catalogue');
        } catch (err: any) {
            showErrorNotification('Claim Failed', err.message || 'Could not claim free plan.');
            setError(err.message || 'Failed to claim free plan.');
        } finally {
            setPaymentLoading(false);
        }
    };

    const handlePurchase = async () => {
        if (!selectedPlan || paymentLoading || !user) {
            if (!user) showErrorNotification('Login Required', 'Please log in to purchase a plan.');
            return;
        }

        if (selectedPlan.price === 0) {
            handleClaimFree(selectedPlan);
            return;
        }

        setPaymentLoading(true);
        setError(null);

        try {
            showInfoNotification('Processing Payment', 'Creating payment order...');
            const { data: orderData, error: orderError } = await api.createPaymentOrder({
                plan_id: selectedPlan.plan_id,
                plan_type: 'contact',
            });

            if (orderError || !orderData) {
                throw new Error(orderError as string || 'Failed to create payment order.');
            }

            const { orderId, amount, keyId } = orderData;

            const options = {
                key: keyId,
                amount: amount,
                currency: "INR",
                name: companyName + " Contact Plans",
                description: `Purchase: ${selectedPlan.name} (${selectedPlan.contacts} contacts)`,
                order_id: orderId,
                handler: async (response: any) => {
                    setPaymentLoading(true);
                    showInfoNotification('Processing Payment', 'Verifying payment details...');
                    try {
                        const payload = {
                            razorpay_order_id: response.razorpay_order_id,
                            razorpay_payment_id: response.razorpay_payment_id,
                            razorpay_signature: response.razorpay_signature,
                        };
                        const { data: verifyData, error: verifyError } = await api.verifyPayment(payload);
                        if (verifyError || !verifyData?.success) {
                            throw new Error(verifyError as string || 'Payment verification failed.');
                        }

                        showSuccessNotification('Payment Successful!', `Added ${selectedPlan.contacts} contact credits to your account.`);
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
                    plan_type: 'contact',
                    user_id: user.id,
                },
                theme: {
                    color: "#D9A619"
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
            <title>Contact Unlock Plans | {companyName}</title>
            <div className="py-12 bg-gray-50 min-h-screen flex flex-col justify-center">
                <div className="max-w-6xl mx-auto w-full px-4">
                    <div className="mb-10 text-center">
                        <h1 className="text-4xl font-extrabold text-[#2C4964] mb-3 leading-tight tracking-tight">Unlock Owner Contacts</h1>
                        <p className="text-gray-600 font-medium">Select a plan to unlock owner contact details and interact with them directly.</p>
                        {balance && (
                            <div className="mt-4 inline-flex items-center gap-1.5 bg-[#D9A619]/10 text-[#8F6F1B] px-4 py-2 rounded-full text-sm font-bold border border-[#D9A619]/20 shadow-sm">
                                <IconCheckbox size={18} />
                                You have {balance.contact_balance ?? 0} contact unlocks left
                            </div>
                        )}
                    </div>

                    {loading && (<div className="flex justify-center items-center py-16"><LoadingSpinner /></div>)}

                    {error && !paymentLoading && (
                        <div className="bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded-lg mb-6 shadow-sm max-w-2xl mx-auto">
                            <div className="flex items-center">
                                <IconAlertCircle className="h-5 w-5 mr-2" />
                                <span><strong className="font-bold">Error: </strong>{error}</span>
                            </div>
                        </div>
                    )}

                    {!loading && plans.length === 0 && (
                        <div className="bg-white rounded-lg p-8 border border-gray-200 shadow-sm text-center max-w-md mx-auto">
                            <IconPhoneCall className="h-12 w-12 mx-auto text-gray-400 mb-4" />
                            <p className="text-gray-600">No contact plans available at the moment.</p>
                        </div>
                    )}

                    {!loading && plans.length > 0 && (
                        <div className="grid grid-cols-1 md:grid-cols-3 gap-8 items-stretch pt-8 pb-16 max-w-5xl mx-auto">
                            {plans.map((plan) => {
                                const isSelected = selectedPlan?.plan_id === plan.plan_id;
                                const isFree = plan.price === 0;

                                let CurrentIcon = IconPhoneCall;
                                let currentGradient = 'from-[#3A5D7C] to-[#2C4964]';
                                let currentHighlight = 'text-[#2C4964]';
                                let currentShadow = 'shadow-[#2C4964]/20';
                                let currentRing = 'ring-[#2C4964]/10';
                                let currentBorder = 'border-[#2C4964]';

                                if (isFree) {
                                    CurrentIcon = IconGift;
                                    currentGradient = 'from-emerald-600 to-teal-800';
                                    currentHighlight = 'text-teal-700';
                                    currentShadow = 'shadow-teal-600/20';
                                    currentRing = 'ring-teal-600/10';
                                    currentBorder = 'border-teal-600';
                                } else if (plan.price >= 1400) {
                                    CurrentIcon = IconCrown;
                                    currentGradient = 'from-[#E5B83B] to-[#D9A619]';
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
                                        <div className={`absolute -top-8 left-1/2 transform -translate-x-1/2 w-16 h-16 rounded-full bg-gradient-to-br ${currentGradient} flex items-center justify-center shadow-lg`}>
                                            <CurrentIcon className="text-white w-8 h-8" stroke={1.5} />
                                        </div>

                                        <h3 className={`mt-4 text-sm font-bold uppercase tracking-widest ${isSelected ? 'text-gray-800' : 'text-gray-500'}`}>
                                            {plan.name}
                                        </h3>

                                        <div className="mt-6 mb-8">
                                            <span className="text-4xl font-extrabold text-gray-900">
                                                {isFree ? 'Free' : `₹${plan.price.toLocaleString('en-IN')}`}
                                            </span>
                                            {!isFree && <span className="text-gray-400 font-medium">/pack</span>}
                                        </div>

                                        <p className="text-gray-500 text-sm leading-relaxed mb-8 flex-grow border-t border-gray-100 pt-6">
                                            {plan.description || `Get ${plan.contacts} owner contact unlock credits valid for lifetime.`}
                                            {!isFree && (
                                                <span className="text-xs text-gray-400 mt-2 block">
                                                    (≈ ₹{Math.round(plan.price / plan.contacts)} per contact)
                                                </span>
                                            )}
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
                                            {paymentLoading && isSelected ? (
                                                <div className="text-white flex justify-center"><LoadingSpinner size={16} /></div>
                                            ) : isFree ? (
                                                `Claim ${plan.contacts} Free Credits`
                                            ) : (
                                                `Buy ${plan.contacts} Contacts Plan`
                                            )}
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
                    )}
                </div>
            </div>
        </>
    );
}

export default BuyContactPlans;
