
import { Link, useNavigate } from 'react-router-dom';
import { useAuth } from '../lib/AuthContext';
import { IconUserCircle, IconWallet, IconHeart, IconLogout, IconChevronRight, IconCalendarPlus, IconSettings, IconShieldLock, IconHomeUp, IconReceipt, IconHomeCheck, IconTicket, IconPhoneCall } from '@tabler/icons-react';
import { getBaseCardClasses, getSecondaryButtonClasses } from '../lib/twUtils';
import LoadingSpinner from '../components/LoadingSpinner';
import { format } from 'date-fns';
import api from '../lib/supabaseClient';
import { useEffect, useState } from 'react';
import OwnerBankAccountSection from '../components/property_form_parts/OwnerBankAccountSection';

// Helper to format expiry date
const formatExpiry = (dateString: string | null | undefined): string => {
    if (!dateString) return 'No Expiry';
    try {
        return `Valid until ${format(new Date(dateString), 'PPP')}`; // e.g., "Valid until Jan 1, 2025"
    } catch {
        return 'Invalid Date';
    }
};

// Reusable list item component for profile links
interface ProfileLinkItemProps {
    to: string;
    icon: React.ElementType;
    text: string;
    className?: string;
}
function ProfileLinkItem({ to, icon: Icon, text, className = "" }: ProfileLinkItemProps) {
    return (
        <Link
            to={to}
            className={`flex items-center justify-between px-4 py-3 bg-white hover:bg-gray-50 rounded-lg border border-gray-200 transition-colors group no-underline ${className}`}
        >
            <div className="flex items-center gap-3">
                <Icon size={20} className="text-gray-500 group-hover:text-gray-700" stroke={1.5} />
                <span className="text-sm font-medium text-gray-700 group-hover:text-gray-900">{text}</span>
            </div>
            <IconChevronRight size={16} className="text-gray-400 group-hover:text-gray-600" />
        </Link>
    );
}


function Profile() {
    const { user, balance, balanceLoading, signOut, loading: authLoading } = useAuth();
    const navigate = useNavigate();
    const [payout, setPayout] = useState<any>(null);
    const [editingPayout, setEditingPayout] = useState(false);
    useEffect(() => { if (!user) return; (async () => { await api.supabase.functions.invoke('setup-owner-route-account', { body: { refresh_only: true } }); const { data } = await (api.supabase as any).rpc('get_my_owner_payout_account'); setPayout(Array.isArray(data) ? data[0] : data); })(); }, [user]);

    const handleSignOut = async () => {
        await signOut();
        navigate('/'); // Navigate to home after sign out
    };

    // Combine auth and balance loading state
    const isLoading = authLoading || balanceLoading;

    if (isLoading) {
        return (
            <div className="min-h-screen flex items-center justify-center bg-gray-50">
                <LoadingSpinner />
            </div>
        );
    }

    if (!user) {
        // This should ideally be caught by RequirePhone, but as a safeguard:
        navigate('/login', { replace: true });
        return null; // Return null while navigating
    }

    const visits = balance?.visit_balance ?? 0;
    const expiryDateFormatted = formatExpiry(balance?.expiry_date);
    const companyName = import.meta.env.VITE_COMPANY_NAME;

    return (
        <>
            <title>My Profile | {companyName}</title>
            <div className="bg-gray-50 min-h-screen py-8 md:py-12">
                <div className="container mx-auto px-4 max-w-2xl">
                    <h1 className="text-2xl md:text-3xl font-bold text-gray-800 mb-6 text-center">
                        My Profile
                    </h1>

                    <div className={`${getBaseCardClasses()} p-6 md:p-8`}>
                        {/* User Info Section */}
                        <div className="flex items-center gap-4 pb-6 mb-6 border-b border-gray-200">
                            <div className="w-16 h-16 rounded-full bg-gray-200 text-gray-600 flex items-center justify-center text-2xl font-semibold border border-gray-300 flex-shrink-0 overflow-hidden">
                                {user.user_metadata?.avatar_url ? (
                                    <img src={user.user_metadata.avatar_url} alt="Profile" className="w-16 h-16 object-cover" />
                                ) : (user.user_metadata?.full_name || user.user_metadata?.name || user.email) ? (
                                    (user.user_metadata?.full_name || user.user_metadata?.name || user.email).charAt(0).toUpperCase()
                                ) : (
                                    <IconUserCircle size={32} />
                                )}
                            </div>
                            <div className="min-w-0">
                                <h2 className="text-lg font-bold text-gray-900 truncate">
                                    {user.user_metadata?.full_name || user.user_metadata?.name || user.email || 'User'}
                                </h2>
                                {user.email && (
                                    <p className="text-sm text-gray-600 truncate" title={user.email}>
                                        {user.email}
                                    </p>
                                )}
                                <p className="text-xs text-gray-500 mt-0.5">
                                    {user.phone || 'Phone number not verified'}
                                </p>
                            </div>
                        </div>

                        {/* Visit Balance Section */}
                        <div className="pb-6 mb-6 border-b border-gray-200">
                            <h2 className="text-lg font-semibold text-gray-700 mb-3 flex items-center gap-2">
                                <IconWallet size={20} stroke={1.5} /> Visit Credits
                            </h2>
                            <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-3 bg-gray-50 p-4 rounded-lg border border-gray-200">
                                <div>
                                    <p className="text-2xl font-bold text-gray-800">
                                        {visits} <span className="text-base font-medium text-gray-600">{visits === 1 ? 'visit' : 'visits'} left</span>
                                    </p>
                                    <p className="text-xs text-gray-500 mt-1">
                                        {expiryDateFormatted}
                                    </p>
                                </div>
                                <Link to="/plans" className={`${getSecondaryButtonClasses()} !text-xs !px-3 !py-1.5 hover:!bg-gray-100 flex items-center gap-1 whitespace-nowrap`}>
                                    <IconCalendarPlus size={14} stroke={1.5} /> Buy More Credits
                                </Link>
                            </div>
                        </div>

                        {/* Contact Unlock Credits Section */}
                        <div className="pb-6 mb-6 border-b border-gray-200">
                            <h2 className="text-lg font-semibold text-gray-700 mb-3 flex items-center gap-2">
                                <IconPhoneCall size={20} stroke={1.5} className="text-[#D9A619]" /> Contact Unlock Credits
                            </h2>
                            <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-3 bg-gray-50 p-4 rounded-lg border border-gray-200">
                                <div>
                                    <p className="text-2xl font-bold text-gray-800">
                                        {balance?.contact_balance ?? 0} <span className="text-base font-medium text-gray-600">{(balance?.contact_balance ?? 0) === 1 ? 'credit' : 'credits'} left</span>
                                    </p>
                                    <p className="text-xs text-gray-500 mt-1">
                                        Valid for lifetime
                                    </p>
                                </div>
                                <Link to="/buy-contact-plans" className={`${getSecondaryButtonClasses()} !text-xs !px-3 !py-1.5 hover:!bg-gray-100 flex items-center gap-1 whitespace-nowrap`}>
                                    <IconPhoneCall size={14} stroke={1.5} /> Buy Contact Plans
                                </Link>
                            </div>
                        </div>

                        {/* Account Links Section */}
                        <div className="pb-6 mb-6 border-b border-gray-200">
                            <h2 className="text-lg font-semibold text-gray-700 mb-3 flex items-center gap-2"><IconWallet size={20} stroke={1.5} /> Payout Account</h2>
                            <div className="bg-gray-50 p-4 rounded-lg border border-gray-200 text-sm space-y-1">
                                <p className="font-medium">{payout?.account_holder_name || 'Not configured'}</p>
                                {(payout?.masked_account_number || payout?.account_number) && <p>Bank Account: {payout.masked_account_number || `XXXX${String(payout.account_number).slice(-4)}`}</p>}
                                {payout?.ifsc_code && <p>IFSC: {payout.ifsc_code}</p>}
                                <p>Status: {payout?.payment_eligible ? 'Payout Account Verified' : payout?.status === 'FAILED' ? 'Payout Verification Failed' : 'Payout Verification In Progress'}</p>
                                <button type="button" onClick={() => setEditingPayout(value => !value)} className="mt-2 text-left text-[#2C4964] font-medium hover:underline">{editingPayout ? 'Close Payout Details' : 'Update / Manage Payout Details'}</button>
                                {editingPayout && <div className="mt-4 border-t border-gray-200 pt-4"><OwnerBankAccountSection /></div>}
                            </div>
                        </div>

                        <div className="pb-6 mb-6 border-b border-gray-200">
                            <h2 className="text-lg font-semibold text-gray-700 mb-4 flex items-center gap-2">
                                <IconSettings size={20} stroke={1.5} /> Account
                            </h2>
                            <div className="space-y-3">
                                {/* Group links visually */}
                                <ProfileLinkItem to="/my-properties" icon={IconHomeUp} text="My Listed Properties" />
                                <ProfileLinkItem to="/wishlist" icon={IconHeart} text="My Wishlist" />
                                <ProfileLinkItem to="/transactions" icon={IconReceipt} text="My Transactions" />
                                <ProfileLinkItem to="/my-rentals" icon={IconHomeCheck} text="My Rentals & Dues" className="bg-[#2C4964]/10 border-[#2C4964]/20 hover:bg-[#2C4964]/20" />
                                <ProfileLinkItem to="/my-tickets" icon={IconTicket} text="My Support Tickets" className="bg-green-50 border-green-100 hover:bg-green-100" />
                            </div>
                        </div>

                        {/* Sign Out Section */}
                        <div>
                            <button
                                onClick={handleSignOut}
                                className={`${getSecondaryButtonClasses()} w-full !border-gray-500 !text-gray-600 hover:!bg-gray-100 flex items-center justify-center gap-2`}
                            >
                                <IconLogout size={18} stroke={1.5} />
                                Sign Out
                            </button>
                        </div>
                    </div>

                    {/* Legal Links */}
                    <div className="mt-8 text-center text-xs text-gray-500 flex flex-wrap justify-center items-center gap-x-2 gap-y-1">
                        <IconShieldLock size={14} className="inline-block mr-1" />
                        <Link to="/terms" className="hover:underline">Terms & Conditions</Link>
                        <span>•</span>
                        <Link to="/privacy" className="hover:underline">Privacy Policy</Link>
                        <span>•</span>
                        <Link to="/refund-policy" className="hover:underline">Refund Policy</Link>
                        <span>•</span>
                        <Link to="/delivery-policy" className="hover:underline">Delivery Policy</Link>
                    </div>
                </div>
            </div>
        </>
    );
}

export default Profile;
