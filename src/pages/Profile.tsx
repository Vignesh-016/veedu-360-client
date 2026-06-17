
import { Link, useNavigate } from 'react-router-dom';
import { useAuth } from '../lib/AuthContext';
import { IconUserCircle, IconWallet, IconHeart, IconLogout, IconChevronRight, IconCalendarPlus, IconSettings, IconShieldLock, IconHomeUp, IconReceipt, IconHomeCheck, IconTicket } from '@tabler/icons-react';
import { getBaseCardClasses, getSecondaryButtonClasses } from '../lib/twUtils';
import LoadingSpinner from '../components/LoadingSpinner';
import { format } from 'date-fns';

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
                            <div className="w-16 h-16 rounded-full bg-gray-200 text-gray-600 flex items-center justify-center text-2xl font-semibold border border-gray-300 flex-shrink-0">
                                {user.email ? user.email.charAt(0).toUpperCase() : <IconUserCircle size={32} />}
                            </div>
                            <div className="min-w-0">
                                <p className="text-lg font-semibold text-gray-800 truncate" title={user.email ?? ''}>
                                    {user.email}
                                </p>
                                <p className="text-sm text-gray-500">
                                    {user.phone || 'Phone number not verified'}
                                </p>
                                {/* Add Edit Profile Button (Future) */}
                                {/* <button className={getTertiaryButtonClasses() + " mt-1 !px-2 !py-1 !text-xs"}>Edit Profile</button> */}
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

                        {/* Account Links Section */}
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