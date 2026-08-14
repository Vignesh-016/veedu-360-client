import { useState, useEffect } from 'react';
import { useLocation, useNavigate } from 'react-router-dom';

import api from '../lib/supabaseClient';
import { VisitPlan, ContactPlan } from '../lib/types';
import LoadingSpinner from '../components/LoadingSpinner';
import {
    IconAlertCircle,
    IconPackage,
    IconStarFilled,
    IconCrown,
    IconMapPin,
    IconBuildingCommunity,
    IconPhoneCall,
    IconGift,
    IconCheckbox,
    IconHomePlus
} from '@tabler/icons-react';
import { useNotification } from '../components/NotificationProvider';
import { useAuth } from '../lib/AuthContext';

declare global {
    interface Window {
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        Razorpay: any;
    }
}

function Plans() {
    // Visit Plans state (excluding listing plans)
    const [visitPlans, setVisitPlans] = useState<VisitPlan[]>([]);
    const [selectedVisitPlan, setSelectedVisitPlan] = useState<VisitPlan | null>(null);

    // Listing Plans state (only listing plans)
    const [listingPlans, setListingPlans] = useState<VisitPlan[]>([]);
    const [selectedListingPlan, setSelectedListingPlan] = useState<VisitPlan | null>(null);

    const [visitLoading, setVisitLoading] = useState(false);
    const [visitPaymentLoading, setVisitPaymentLoading] = useState(false);
    const [visitError, setVisitError] = useState<string | null>(null);

    // Contact Plans state
    const [contactPlans, setContactPlans] = useState<ContactPlan[]>([]);
    const [contactLoading, setContactLoading] = useState(false);
    const [contactPaymentLoading, setContactPaymentLoading] = useState(false);
    const [contactError, setContactError] = useState<string | null>(null);
    const [selectedContactPlan, setSelectedContactPlan] = useState<ContactPlan | null>(null);

    const { showSuccessNotification, showErrorNotification, showInfoNotification } = useNotification();
    const { user, balance, refetchBalance } = useAuth();
    const navigate = useNavigate();
    const location = useLocation();

    // Fetch Visit & Listing Plans
    useEffect(() => {
        const fetchVisitPlans = async () => {
            setVisitLoading(true);
            setVisitError(null);
            try {
                const { data, error: fetchErr } = await api.getVisitPlans();
                if (fetchErr) throw fetchErr;
                const activePlans = data || [];

                // Separate visit plans from listing plans
                const vPlans = activePlans.filter(p => !p.name.toLowerCase().includes('listing'));
                const lPlans = activePlans.filter(p => p.name.toLowerCase().includes('listing'));

                setVisitPlans(vPlans);
                setListingPlans(lPlans);

                if (vPlans.length > 0) {
                    const middleIndex = Math.floor(vPlans.length / 2);
                    setSelectedVisitPlan(vPlans[middleIndex]);
                }
                if (lPlans.length > 0) {
                    setSelectedListingPlan(lPlans[0]);
                }
            } catch (err: any) {
                showErrorNotification('Load Failed', err.message || 'Failed to fetch plans.');
                setVisitError(err.message || 'Failed to fetch plans.');
            } finally {
                setVisitLoading(false);
            }
        };
        fetchVisitPlans();
    }, [showErrorNotification]);

    // Fetch Contact Plans
    useEffect(() => {
        const fetchContactPlans = async () => {
            setContactLoading(true);
            setContactError(null);
            try {
                const { data, error: fetchErr } = await api.getContactPlans();
                if (fetchErr) throw fetchErr;
                const activePlans = data || [];
                setContactPlans(activePlans);
                if (activePlans.length > 0) {
                    const defaultPlan = activePlans.find(p => p.price > 0) || activePlans[0];
                    setSelectedContactPlan(defaultPlan);
                }
            } catch (err: any) {
                showErrorNotification('Load Failed', err.message || 'Failed to fetch contact plans.');
                setContactError(err.message || 'Failed to fetch contact plans.');
            } finally {
                setContactLoading(false);
            }
        };
        fetchContactPlans();
    }, [showErrorNotification]);

    // Smooth scroll to section if hash present
    useEffect(() => {
        if (location.hash === '#contact-credits' || location.pathname === '/buy-contact-plans') {
            const el = document.getElementById('contact-credits');
            if (el) {
                setTimeout(() => {
                    el.scrollIntoView({ behavior: 'smooth' });
                }, 150);
            }
        } else if (location.hash === '#visit-credits') {
            const el = document.getElementById('visit-credits');
            if (el) {
                setTimeout(() => {
                    el.scrollIntoView({ behavior: 'smooth' });
                }, 150);
            }
        } else if (location.hash === '#listing-credits') {
            const el = document.getElementById('listing-credits');
            if (el) {
                setTimeout(() => {
                    el.scrollIntoView({ behavior: 'smooth' });
                }, 150);
            }
        }
    }, [location]);

    const companyName = import.meta.env.VITE_COMPANY_NAME || "Veedu 360";

    // --- Handle Purchase for Visit / Listing Plans ---
    const handleVisitOrListingPurchase = async (targetPlan: VisitPlan | null) => {
        if (!targetPlan || visitPaymentLoading || !user) {
            if (!user) showErrorNotification('Login Required', 'Please log in to purchase a plan.');
            return;
        }

        setVisitPaymentLoading(true);
        setVisitError(null);

        try {
            showInfoNotification('Processing Payment', 'Creating payment order...');
            const { data: orderData, error: orderError } = await api.createPaymentOrder({
                plan_id: targetPlan.plan_id,
            });

            if (orderError || !orderData) {
                throw new Error(orderError as string || 'Failed to create payment order.');
            }

            const { orderId, amount, keyId } = orderData;

            const isListing = targetPlan.name.toLowerCase().includes('listing');

            const options = {
                key: keyId,
                amount: amount,
                currency: "INR",
                name: companyName + (isListing ? " Property Listing" : " Property Visits"),
                description: `Purchase: ${targetPlan.name}`,
                order_id: orderId,
                handler: async (response: any) => {
                    setVisitPaymentLoading(true);
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

                        showSuccessNotification(
                            'Payment Successful!',
                            isListing
                                ? 'Added property listing credit to your account.'
                                : `Added ${targetPlan.visits} visits to your account.`
                        );
                        await refetchBalance();
                        navigate(isListing ? '/submit-property' : '/catalogue');

                    } catch (verificationError: any) {
                        showErrorNotification('Verification Failed', verificationError.message || 'Could not verify payment. Please contact support.');
                        setVisitError(verificationError.message || 'Payment verification failed.');
                    } finally {
                        setVisitPaymentLoading(false);
                    }
                },
                prefill: {
                    name: user.user_metadata?.full_name || user.email,
                    email: user.email,
                    contact: user.phone || user.user_metadata?.phone,
                },
                notes: {
                    plan_id: targetPlan.plan_id,
                    user_id: user.id,
                },
                theme: {
                    color: isListing ? "#1E3347" : "#2C4964"
                }
            };

            await api.openRazorpayCheckout(options);

        } catch (err: any) {
            console.error("Payment initiation error:", err);
            showErrorNotification('Payment Error', err.message || 'Could not initiate payment.');
            setVisitError(err.message || 'Failed to start payment.');
            setVisitPaymentLoading(false);
        }
    };

    // --- Handle Claim Free Contact Plan ---
    const handleClaimFreeContact = async (plan: ContactPlan) => {
        setContactPaymentLoading(true);
        setContactError(null);
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
            setContactError(err.message || 'Failed to claim free plan.');
        } finally {
            setContactPaymentLoading(false);
        }
    };

    // --- Handle Contact Plan Purchase ---
    const handleContactPurchase = async (planToBuy?: ContactPlan) => {
        const targetPlan = planToBuy || selectedContactPlan;
        if (!targetPlan || contactPaymentLoading || !user) {
            if (!user) showErrorNotification('Login Required', 'Please log in to purchase a plan.');
            return;
        }

        if (targetPlan.price === 0) {
            handleClaimFreeContact(targetPlan);
            return;
        }

        setContactPaymentLoading(true);
        setContactError(null);

        try {
            showInfoNotification('Processing Payment', 'Creating payment order...');
            const { data: orderData, error: orderError } = await api.createPaymentOrder({
                plan_id: targetPlan.plan_id,
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
                description: `Purchase: ${targetPlan.name} (${targetPlan.contacts} contacts)`,
                order_id: orderId,
                handler: async (response: any) => {
                    setContactPaymentLoading(true);
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

                        showSuccessNotification('Payment Successful!', `Added ${targetPlan.contacts} contact credits to your account.`);
                        await refetchBalance();
                        navigate('/catalogue');

                    } catch (verificationError: any) {
                        showErrorNotification('Verification Failed', verificationError.message || 'Could not verify payment. Please contact support.');
                        setContactError(verificationError.message || 'Payment verification failed.');
                    } finally {
                        setContactPaymentLoading(false);
                    }
                },
                prefill: {
                    name: user.user_metadata?.full_name || user.email,
                    email: user.email,
                    contact: user.phone || user.user_metadata?.phone,
                },
                notes: {
                    plan_id: targetPlan.plan_id,
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
            setContactError(err.message || 'Failed to start payment.');
            setContactPaymentLoading(false);
        }
    };

    return (
        <>
            <title>Credits & Plans | {companyName}</title>
            <div className="py-8 bg-gray-50 min-h-screen">
                <div className="container mx-auto max-w-6xl px-4 space-y-16">
                    
                    {/* SECTION 1: VISIT CREDITS */}
                    <section id="visit-credits" className="scroll-mt-20">
                        <div className="text-center mb-10">
                            <h1 className="text-4xl font-extrabold text-[#2C4964] mb-3 leading-tight tracking-tight">Choose Your Visit Plan</h1>
                            <p className="text-gray-600 font-medium">Select a premium plan to buy property visit credits and unlock exclusive features.</p>
                        </div>

                        {visitLoading && (<div className="flex justify-center items-center py-12"><LoadingSpinner /></div>)}

                        {visitError && !visitPaymentLoading && (
                            <div className="bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded-lg mb-6 shadow-sm max-w-2xl mx-auto">
                                <div className="flex items-center">
                                    <IconAlertCircle className="h-5 w-5 mr-2" />
                                    <span><strong className="font-bold">Error: </strong>{visitError}</span>
                                </div>
                            </div>
                        )}

                        {!visitLoading && visitPlans.length === 0 && (
                            <div className="bg-white rounded-lg p-8 border border-gray-200 shadow-sm text-center max-w-md mx-auto">
                                <IconPackage className="h-12 w-12 mx-auto text-gray-400 mb-4" />
                                <p className="text-gray-600">No visit plans available at the moment.</p>
                            </div>
                        )}

                        {!visitLoading && visitPlans.length > 0 && (
                            <div className="grid grid-cols-1 md:grid-cols-3 gap-8 items-stretch pt-8 pb-4">
                                {visitPlans.map((plan) => {
                                    const isSelected = selectedVisitPlan?.plan_id === plan.plan_id;
                                    const lowerName = plan.name.toLowerCase();

                                    let CurrentIcon = IconStarFilled;
                                    let currentGradient = 'from-[#3A5D7C] to-[#2C4964]';
                                    let currentHighlight = 'text-[#2C4964]';
                                    let currentShadow = 'shadow-[#2C4964]/20';
                                    let currentRing = 'ring-[#2C4964]/10';
                                    let currentBorder = 'border-[#2C4964]';

                                    if (lowerName.includes('starter')) {
                                        CurrentIcon = IconMapPin;
                                        currentGradient = 'from-[#3A5D7C] to-[#2C4964]';
                                        currentHighlight = 'text-[#2C4964]';
                                        currentShadow = 'shadow-[#2C4964]/20';
                                        currentRing = 'ring-[#2C4964]/10';
                                        currentBorder = 'border-[#2C4964]';
                                    } else if (lowerName.includes('bronze') || lowerName.includes('silver') || lowerName.includes('standard')) {
                                        CurrentIcon = IconBuildingCommunity;
                                        currentGradient = 'from-[#C59B27] to-[#8F6F1B]';
                                        currentHighlight = 'text-[#8F6F1B]';
                                        currentShadow = 'shadow-[#C59B27]/20';
                                        currentRing = 'ring-[#C59B27]/10';
                                        currentBorder = 'border-[#C59B27]';
                                    } else if (lowerName.includes('gold') || lowerName.includes('premium') || lowerName.includes('elite')) {
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
                                            onClick={() => setSelectedVisitPlan(plan)}
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
                                                    setSelectedVisitPlan(plan);
                                                    if (isSelected) handleVisitOrListingPurchase(plan);
                                                }}
                                                disabled={visitPaymentLoading}
                                                className={`w-full py-4 rounded-full font-bold text-sm tracking-wide transition-all duration-300 transform active:scale-95 ${buttonGradient}`}
                                            >
                                                {visitPaymentLoading && isSelected ? <div className="text-white flex justify-center"><LoadingSpinner size={16} /></div> : `Get ${plan.visits} Visits Plan`}
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
                    </section>

                    {/* DIVIDER */}
                    {listingPlans.length > 0 && <hr className="border-t border-gray-200/80 my-8" />}

                    {/* SECTION 2: PROPERTY LISTING CREDITS */}
                    {listingPlans.length > 0 && (
                        <section id="listing-credits" className="scroll-mt-20">
                            <div className="text-center mb-10">
                                <h2 className="text-4xl font-extrabold text-[#2C4964] mb-3 leading-tight tracking-tight">Property Listing Fee</h2>
                                <p className="text-gray-600 font-medium">Listing fee required for posting additional properties on the platform.</p>
                            </div>

                            <div className="grid grid-cols-1 md:grid-cols-3 gap-8 items-stretch pt-8 pb-4 max-w-6xl mx-auto">
                                {listingPlans.map((plan) => {
                                    const isSelected = selectedListingPlan?.plan_id === plan.plan_id;
                                    const currentGradient = 'from-slate-700 to-[#1E3347]';
                                    const currentHighlight = 'text-[#2C4964]';
                                    const currentRing = 'ring-[#2C4964]/10';
                                    const currentBorder = 'border-[#2C4964]';

                                    const buttonGradient = isSelected
                                        ? `bg-gradient-to-r ${currentGradient} shadow-lg text-white`
                                        : 'bg-[#2C4964] text-white hover:bg-[#1E3347] shadow-md hover:shadow-lg hover:-translate-y-0.5';

                                    return (
                                        <div
                                            key={plan.plan_id}
                                            onClick={() => setSelectedListingPlan(plan)}
                                            className={`relative bg-white rounded-[2rem] p-8 pt-12 text-center transition-all duration-300 cursor-pointer flex flex-col md:col-start-1 md:col-span-1
                                                ${isSelected
                                                    ? `shadow-2xl scale-105 ring-4 ${currentRing} border-t-4 ${currentBorder} z-10`
                                                    : 'shadow-lg hover:shadow-xl hover:-translate-y-1 border border-gray-100 hover:border-gray-200'
                                                }
                                            `}
                                        >
                                            <div className={`absolute -top-8 left-1/2 transform -translate-x-1/2 w-16 h-16 rounded-full bg-gradient-to-br ${currentGradient} flex items-center justify-center shadow-lg`}>
                                                <IconHomePlus className="text-white w-8 h-8" stroke={1.5} />
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
                                                {plan.description || 'Listing fee for additional properties.'}
                                                <br />
                                                <span className="text-xs text-gray-400 mt-2 block">
                                                    (≈ ₹{plan.price} per listing)
                                                </span>
                                            </p>

                                            <button
                                                onClick={(e) => {
                                                    e.stopPropagation();
                                                    setSelectedListingPlan(plan);
                                                    if (isSelected) handleVisitOrListingPurchase(plan);
                                                }}
                                                disabled={visitPaymentLoading}
                                                className={`w-full py-4 rounded-full font-bold text-sm tracking-wide transition-all duration-300 transform active:scale-95 ${buttonGradient}`}
                                            >
                                                {visitPaymentLoading && isSelected ? <div className="text-white flex justify-center"><LoadingSpinner size={16} /></div> : `Get ${plan.visits || 1} Listing Plan`}
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
                        </section>
                    )}

                    {/* DIVIDER */}
                    <hr className="border-t border-gray-200/80 my-8" />

                    {/* SECTION 3: CONTACT CREDITS */}
                    <section id="contact-credits" className="scroll-mt-20">
                        <div className="text-center mb-10">
                            <h2 className="text-4xl font-extrabold text-[#2C4964] mb-3 leading-tight tracking-tight">Unlock Owner Contacts</h2>
                            <p className="text-gray-600 font-medium">Select a plan to unlock owner contact details and interact with them directly.</p>
                            {balance && (
                                <div className="mt-4 inline-flex items-center gap-1.5 bg-[#D9A619]/10 text-[#8F6F1B] px-4 py-2 rounded-full text-sm font-bold border border-[#D9A619]/20 shadow-sm">
                                    <IconCheckbox size={18} />
                                    You have {balance.contact_balance ?? 0} contact unlocks left
                                </div>
                            )}
                        </div>

                        {contactLoading && (<div className="flex justify-center items-center py-12"><LoadingSpinner /></div>)}

                        {contactError && !contactPaymentLoading && (
                            <div className="bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded-lg mb-6 shadow-sm max-w-2xl mx-auto">
                                <div className="flex items-center">
                                    <IconAlertCircle className="h-5 w-5 mr-2" />
                                    <span><strong className="font-bold">Error: </strong>{contactError}</span>
                                </div>
                            </div>
                        )}

                        {!contactLoading && contactPlans.length === 0 && (
                            <div className="bg-white rounded-lg p-8 border border-gray-200 shadow-sm text-center max-w-md mx-auto">
                                <IconPhoneCall className="h-12 w-12 mx-auto text-gray-400 mb-4" />
                                <p className="text-gray-600">No contact plans available at the moment.</p>
                            </div>
                        )}

                        {!contactLoading && contactPlans.length > 0 && (
                            <div className="grid grid-cols-1 md:grid-cols-3 gap-8 items-stretch pt-8 pb-12 max-w-5xl mx-auto">
                                {contactPlans.map((plan) => {
                                    const isSelected = selectedContactPlan?.plan_id === plan.plan_id;
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
                                            onClick={() => setSelectedContactPlan(plan)}
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
                                                    setSelectedContactPlan(plan);
                                                    if (isSelected) handleContactPurchase(plan);
                                                }}
                                                disabled={contactPaymentLoading}
                                                className={`w-full py-4 rounded-full font-bold text-sm tracking-wide transition-all duration-300 transform active:scale-95 ${buttonGradient}`}
                                            >
                                                {contactPaymentLoading && isSelected ? (
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
                    </section>

                </div>
            </div>
        </>
    );
}

export default Plans;