import { Fragment, useEffect, useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { useAuth } from '../lib/AuthContext';
import {
    IconHeart,
    IconUser,
    IconX,
    IconMenu2,
    IconChevronDown,
    IconLogout,
    IconSettings,
    IconSquarePlus,
    IconWallet,
    IconBuildingSkyscraper,
    IconHome2,
    IconMapPin,
    IconBuildingCommunity,
    IconReceipt,
    IconHomeUp,
    IconHomeCheck,
    IconHomePlus,
    IconClipboardList,
} from '@tabler/icons-react';
import { getPrimaryButtonClasses, getSecondaryButtonClasses } from '../lib/twUtils';
import LoadingSpinner from './LoadingSpinner';
import { Menu, MenuButton, MenuItem, MenuItems, Popover, PopoverButton, PopoverPanel, Transition } from '@headlessui/react';
import api from '../lib/supabaseClient';



// Helper function to render navigation link
const renderNavLinks = (closeMobileMenu?: () => void) => {
    const navItems = [
        { name: 'Home', path: '/' },
        { name: 'Properties', path: '/catalogue' },
        {
            name: 'Buy',
            subItems: [
                { name: 'Houses', path: '/catalogue?p_listing_types=SALE&p_property_types=HOUSE', icon: IconHome2 },
                { name: 'Land', path: '/catalogue?p_listing_types=SALE&p_property_types=LAND', icon: IconMapPin },
                { name: 'Buildings', path: '/catalogue?p_listing_types=SALE&p_property_types=BUILDING', icon: IconBuildingSkyscraper },
                { name: 'Apartments', path: '/catalogue?p_listing_types=SALE&p_property_types=HOUSE&p_house_types=APARTMENT_FLAT', icon: IconBuildingCommunity },
            ],
        },
        {
            name: 'Rent',
            subItems: [
                { name: 'Houses', path: '/catalogue?p_listing_types=RENTAL&p_property_types=HOUSE', icon: IconHome2 },
                { name: 'Land', path: '/catalogue?p_listing_types=RENTAL&p_property_types=LAND', icon: IconMapPin },
                { name: 'Buildings', path: '/catalogue?p_listing_types=RENTAL&p_property_types=BUILDING', icon: IconBuildingSkyscraper },
                { name: 'Apartments', path: '/catalogue?p_listing_types=RENTAL&p_property_types=HOUSE&p_house_types=APARTMENT_FLAT', icon: IconBuildingCommunity },
            ],
        },
        { name: 'Buy Visit Credits', path: '/plans' },
    ];

    return navItems.map((item) => (
        item.subItems ? (
            <Popover key={item.name} className="relative">
                <PopoverButton className="hidden md:flex items-center gap-1 text-sm font-medium text-gray-700 hover:text-[#D9A619] focus:outline-none focus-visible:ring-2 focus-visible:ring-gray-500 rounded-md px-2 py-1">
                    {item.name} <IconChevronDown size={16} />
                </PopoverButton>
                <span className="block md:hidden px-3 py-2 rounded-md text-base font-medium text-gray-700">{item.name}</span>

                <Transition
                    as={Fragment}
                    enter="transition ease-out duration-200"
                    enterFrom="opacity-0 translate-y-1"
                    enterTo="opacity-100 translate-y-0"
                    leave="transition ease-in duration-150"
                    leaveFrom="opacity-100 translate-y-0"
                    leaveTo="opacity-0 translate-y-1"
                >
                    <PopoverPanel className="absolute left-0 z-20 mt-2 w-56 origin-top-left rounded-md bg-white shadow-lg ring-1 ring-black ring-opacity-5 focus:outline-none border border-gray-100 md:origin-top-left">
                        <div className="py-1">
                            {item.subItems.map((subItem) => (
                                <Link
                                    key={subItem.name}
                                    to={subItem.path}
                                    onClick={closeMobileMenu}
                                    className="group flex items-center gap-2 w-full px-4 py-2 text-sm text-gray-700 hover:bg-gray-100 hover:text-gray-900 no-underline data-[focus]:bg-gray-100 data-[focus]:text-gray-900"
                                >
                                    <subItem.icon size={16} className="text-gray-400 group-hover:text-[#D9A619]" stroke={1.5} />
                                    {subItem.name}
                                </Link>
                            ))}
                        </div>
                    </PopoverPanel>
                </Transition>
                <div className="ml-4 mt-1 space-y-1 md:hidden">
                    {item.subItems.map((subItem) => (
                        <Link
                            key={subItem.name}
                            to={subItem.path}
                            onClick={closeMobileMenu}
                            className="group flex items-center gap-2 w-full px-3 py-2 text-sm text-gray-600 hover:bg-gray-50 hover:text-gray-800 no-underline rounded-md"
                        >
                            <subItem.icon size={16} className="text-gray-400 group-hover:text-[#D9A619]" stroke={1.5} />
                            {subItem.name}
                        </Link>
                    ))}
                </div>
            </Popover>
        ) : (
            <Link
                key={item.name}
                to={item.path || '#'}
                onClick={closeMobileMenu}
                className="text-sm font-medium text-gray-700 hover:text-[#D9A619] no-underline px-3 py-2 rounded-md block md:inline-block"
            >
                {item.name}
            </Link>
        )
    ));
};

// Helper for User Menu items
const UserMenuItem = ({ to, icon: Icon, text, action, closeMenu, isLogout = false }: {
    to?: string;
    icon: React.ElementType;
    text: string;
    action?: () => void;
    closeMenu?: () => void;
    isLogout?: boolean;
}) => (
    <MenuItem>
        {({ focus }) => {
            const classes = `group flex w-full items-center gap-2 rounded-md px-3 py-2 text-sm no-underline ${isLogout
                ? 'text-gray-700 data-[focus]:bg-gray-100 data-[focus]:text-gray-900'
                : 'text-gray-700 data-[focus]:bg-gray-100 data-[focus]:text-gray-900'
                } ${focus ? 'bg-gray-100 text-gray-900' : ''}`;

            const content = (
                <>
                    <Icon size={18} className="text-gray-400 group-hover:text-gray-600" stroke={1.5} />
                    {text}
                </>
            );

            const handleClick = () => {
                if (action) {
                    action();
                }
                closeMenu?.();
            };

            return to ? (
                <Link to={to} className={classes} onClick={handleClick}>
                    {content}
                </Link>
            ) : (
                <button onClick={handleClick} className={classes}>
                    {content}
                </button>
            );
        }}
    </MenuItem>
);


function Navbar() {
    const { user, signOut, loading: authLoading, balance, balanceLoading, currentCity, setCurrentCity } = useAuth();
    const navigate = useNavigate();
    const [wishlistCount, setWishlistCount] = useState<number | null>(null);
    const [wishlistLoading, setWishlistLoading] = useState(false);
    const [availableCities, setAvailableCities] = useState<string[]>([]);
    const [citiesLoading, setCitiesLoading] = useState(true);

    useEffect(() => {
        const fetchCities = async () => {
            try {
                const { data, error } = await api.supabase
                    .from('properties')
                    .select('city')
                    .eq('is_listed', true);

                if (error) throw error;

                if (data) {
                    const uniqueCities = Array.from(
                        new Set(
                            data
                                .map(item => item.city?.trim())
                                .filter((city): city is string => !!city)
                        )
                    ).sort((a, b) => a.localeCompare(b));
                    setAvailableCities(uniqueCities);
                }
            } catch (err) {
                console.error("Navbar: Failed to fetch available cities:", err);
            } finally {
                setCitiesLoading(false);
            }
        };
        fetchCities();
    }, []);

    const iconSize = 20;
    const iconStroke = 1.5;

    useEffect(() => {
        const fetchCount = async () => {
            if (!user) {
                setWishlistCount(null);
                return;
            }
            setWishlistLoading(true);
            try {
                const { data, error } = await api.getWishlistCount();
                if (error) throw error;
                setWishlistCount(data ?? 0);
            } catch (err) {
                console.error("Navbar: Failed to fetch wishlist count:", err);
                setWishlistCount(0);
            } finally {
                setWishlistLoading(false);
            }
        };
        fetchCount();
    }, [user]);

    // User Menu Dropdown Content for Desktop
    const UserMenuContentDesktop = () => (
        <>
            <UserMenuItem to="/my-properties" icon={IconHomeUp} text="My Properties" />
            <MenuItem>
                {({ focus }) => (
                    <Link
                        to="/wishlist"
                        className={`group flex w-full items-center gap-2 rounded-md px-3 py-2 text-sm no-underline text-gray-700 data-[focus]:bg-gray-100 data-[focus]:text-gray-900 ${focus ? 'bg-gray-100 text-gray-900' : ''}`}
                    >
                        <IconHeart size={18} className="text-gray-400 group-hover:text-gray-600" stroke={1.5} />
                        Wishlist
                        {!wishlistLoading && wishlistCount !== null && wishlistCount > 0 && (
                            <span className="ml-auto text-xs bg-gray-200 text-gray-700 px-1.5 py-0.5 rounded-full">{wishlistCount}</span>
                        )}
                    </Link>
                )}
            </MenuItem>
            <UserMenuItem to="/my-rentals" icon={IconHomeCheck} text="My Rentals" />
            <UserMenuItem to="/my-applications" icon={IconClipboardList} text="My Applications" />
            <UserMenuItem to="/transactions" icon={IconReceipt} text="My Transactions" />
            <UserMenuItem to="/profile" icon={IconSettings} text="Profile Settings" />
            <div className="my-1 h-px bg-gray-100" />
            <UserMenuItem icon={IconLogout} text="Sign out" action={async () => { await signOut(); navigate('/'); }} isLogout />
        </>
    );

    // User Menu Content for Mobile
    const UserMenuContentMobile = ({ closePopover }: { closePopover: () => void }) => (
        <>
            <UserMenuItem to="/submit-property" icon={IconHomePlus} text="Post Property" closeMenu={closePopover} />
            <UserMenuItem to="/my-properties" icon={IconHomeUp} text="My Properties" closeMenu={closePopover} />
            <MenuItem>
                {({ focus }) => (
                    <Link
                        to="/wishlist"
                        className={`group flex w-full items-center gap-2 rounded-md px-3 py-2 text-sm no-underline text-gray-700 data-[focus]:bg-gray-100 data-[focus]:text-gray-900 ${focus ? 'bg-gray-100 text-gray-900' : ''}`}
                        onClick={closePopover}
                    >
                        <IconHeart size={18} className="text-gray-400 group-hover:text-gray-600" stroke={1.5} />
                        Wishlist
                        {!wishlistLoading && wishlistCount !== null && wishlistCount > 0 && (
                            <span className="ml-auto text-xs bg-gray-200 text-gray-700 px-1.5 py-0.5 rounded-full">{wishlistCount}</span>
                        )}
                    </Link>
                )}
            </MenuItem>
            <UserMenuItem to="/my-rentals" icon={IconHomeCheck} text="My Rentals" closeMenu={closePopover} />
            <UserMenuItem to="/my-applications" icon={IconClipboardList} text="My Applications" closeMenu={closePopover} />
            <UserMenuItem to="/transactions" icon={IconReceipt} text="My Transactions" closeMenu={closePopover} />
            <UserMenuItem to="/profile" icon={IconSettings} text="Profile Settings" closeMenu={closePopover} />
            <div className="my-1 h-px bg-gray-100" />
            <UserMenuItem icon={IconLogout} text="Sign out" action={async () => { await signOut(); navigate('/'); }} closeMenu={closePopover} isLogout />
        </>
    );


    const renderBalance = () => {
        if (balanceLoading) {
            return (
                <div className="flex items-center text-xs text-gray-500 bg-gray-100 px-2 py-1 rounded-full border border-gray-200">
                    <LoadingSpinner size={12} className="mr-1" /> Loading...
                </div>
            );
        }
        if (!user) return null;

        const visits = balance?.visit_balance ?? 0;
        const expiry = balance?.expiry_date;
        const hasBalance = visits > 0;

        return (
            <div className={`flex flex-col text-xs px-2.5 py-1 items-start rounded-full border ${hasBalance ? 'bg-gray-100 text-gray-700 border-gray-200' : 'bg-gray-100 text-gray-600 border-gray-200'}`}>
                <div className="flex items-center">
                    <IconWallet size={14} className="mr-1 text-gray-400" stroke={1.5} />
                    <span className="font-medium">{visits}</span>
                    <span className="ml-1">{visits === 1 ? "visit" : "visits"} left</span>
                </div>
                {expiry && (
                    <div className="text-gray-400 text-[11px] mt-0.5">
                        {hasBalance ? `• Valid till ${new Date(expiry).toLocaleDateString("en-IN", { day: 'numeric', month: 'short' })}` :
                            `• Expired on ${new Date(expiry).toLocaleDateString("en-IN", { day: 'numeric', month: 'short' })}`}
                    </div>
                )}
            </div>
        );
    };

    return (
        <Popover as="header" className="bg-white shadow-sm border-b border-gray-200 sticky top-0 z-50">
            {({ open, close: closePopover }) => (
                <>
                    <div className="container mx-auto px-4">
                        <div className="flex h-16 items-center justify-between gap-4">
                            <div className="flex items-center gap-2 md:gap-4 flex-shrink-0">
                                <Link to="/" className="flex items-center gap-2 group" onClick={closePopover}>
                                    <img src="/veedu360-logo.png" alt="Company Logo" className="h-20 w-auto" />
                                </Link>

                                <Popover className="relative">
                                    {({ open, close }) => (
                                        <>
                                            <PopoverButton className={`flex items-center gap-1 px-2.5 py-1.5 rounded-t-md text-xs md:text-sm font-semibold border-t border-x transition-colors focus:outline-none ${open ? 'bg-white border-gray-200 text-[#D9A619] shadow-[0_-2px_10px_rgba(0,0,0,0.03)] z-50' : 'bg-transparent border-transparent text-gray-700 hover:text-[#D9A619]'}`}>
                                                <IconMapPin size={16} className="text-[#D9A619]" stroke={1.5} />
                                                <span>{currentCity}</span>
                                                <IconChevronDown size={14} className={`text-gray-400 transition-transform ${open ? 'rotate-180 text-[#D9A619]' : ''}`} />
                                            </PopoverButton>

                                            <Transition
                                                as={Fragment}
                                                enter="transition ease-out duration-200"
                                                enterFrom="opacity-0 translate-y-1"
                                                enterTo="opacity-100 translate-y-0"
                                                leave="transition ease-in duration-150"
                                                leaveFrom="opacity-100 translate-y-0"
                                                leaveTo="opacity-0 translate-y-1"
                                            >
                                                <PopoverPanel className="absolute left-0 md:left-auto md:right-auto z-50 mt-[-1px] w-[92vw] sm:w-[500px] md:w-[720px] origin-top-left rounded-b-lg rounded-r-lg bg-white shadow-2xl ring-1 ring-black ring-opacity-5 focus:outline-none border border-gray-200 p-4 md:p-6 max-h-[80vh] overflow-y-auto">
                                                    <div className="flex flex-col gap-4">
                                                        <div className="flex items-center gap-2 text-[#E11D48] font-bold text-sm tracking-wider pb-2 border-b border-gray-100">
                                                            <IconMapPin size={16} className="text-[#E11D48]" stroke={2} />
                                                            <span>INDIA</span>
                                                        </div>

                                                        {citiesLoading ? (
                                                            <div className="flex items-center justify-center py-8">
                                                                <LoadingSpinner size={24} />
                                                                <span className="ml-2 text-sm text-gray-500">Loading cities...</span>
                                                            </div>
                                                        ) : availableCities.length === 0 ? (
                                                            <div className="text-center py-8 text-sm text-gray-500">
                                                                No active cities found.
                                                            </div>
                                                        ) : (
                                                            <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-4 gap-x-6 gap-y-3">
                                                                {availableCities.map((city) => (
                                                                    <button
                                                                        key={city}
                                                                        onClick={() => {
                                                                            setCurrentCity(city);
                                                                            navigate(`/catalogue?p_location_search=${encodeURIComponent(city)}`);
                                                                            close();
                                                                        }}
                                                                        className={`text-xs text-left w-full transition-colors hover:text-[#D9A619] ${currentCity === city ? 'text-[#D9A619] font-bold' : 'text-gray-600'}`}
                                                                    >
                                                                        {city}
                                                                    </button>
                                                                ))}
                                                            </div>
                                                        )}
                                                    </div>
                                                </PopoverPanel>
                                            </Transition>
                                        </>
                                    )}
                                </Popover>
                            </div>

                            <nav className="hidden md:flex items-center gap-3 flex-grow justify-center">
                                {renderNavLinks(closePopover)}
                            </nav>

                            <div className="hidden md:flex items-center gap-3 flex-shrink-0">
                                <Link
                                    to={user ? "/submit-property" : "/login"}
                                    state={user ? undefined : { from: '/submit-property' }}
                                    className={`${getSecondaryButtonClasses()} !text-xs !px-3 !py-1.5 flex items-center gap-1.5 hover:text-[#D9A619]`}
                                >
                                    <IconSquarePlus size={16} stroke={1.5} />
                                    <span>Post Property</span>
                                    <span className="bg-[#16A34A] text-white text-[9px] font-extrabold px-1.5 py-0.5 rounded shadow-sm tracking-wider">
                                        FREE
                                    </span>
                                </Link>
                                {user && (
                                    <Link
                                        to="/wishlist"
                                        className="relative text-gray-500 hover:text-gray-800 transition-colors p-1.5 rounded-full hover:bg-gray-100"
                                        title="Wishlist"
                                    >
                                        <IconHeart size={iconSize} stroke={iconStroke} />
                                        {!wishlistLoading && wishlistCount !== null && wishlistCount > 0 && (
                                            <span className="absolute -top-1 -right-1 flex h-4 w-4 items-center justify-center rounded-full bg-[#D9A619] text-xs font-bold text-white">
                                                {wishlistCount}
                                            </span>
                                        )}
                                        <span className="sr-only">Wishlist</span>
                                    </Link>
                                )}
                                {renderBalance()}
                                {authLoading ? (
                                    <div className="w-8 h-8 flex items-center justify-center">
                                        <LoadingSpinner size={iconSize} />
                                    </div>
                                ) : user ? (
                                    <Menu as="div" className="relative">
                                        <MenuButton className="flex items-center rounded-full focus:outline-none focus-visible:ring-2 focus-visible:ring-offset-2 focus-visible:ring-gray-500">
                                            <span className="sr-only">Open user menu</span>
                                            <div className="w-8 h-8 rounded-full bg-gray-200 text-gray-600 flex items-center justify-center text-sm font-semibold border border-gray-300">
                                                {user.email ? user.email.charAt(0).toUpperCase() : <IconUser size={16} />}
                                            </div>
                                        </MenuButton>
                                        <Transition
                                            as={Fragment}
                                            enter="transition ease-out duration-100"
                                            enterFrom="transform opacity-0 scale-95"
                                            enterTo="transform opacity-100 scale-100"
                                            leave="transition ease-in duration-75"
                                            leaveFrom="transform opacity-100 scale-100"
                                            leaveTo="transform opacity-0 scale-95"
                                        >
                                            <MenuItems className="absolute right-0 mt-2 w-56 origin-top-right rounded-md bg-white shadow-lg ring-1 ring-black ring-opacity-5 focus:outline-none border border-gray-100">
                                                <div className="px-3 py-3 border-b border-gray-100">
                                                    <p className="text-sm font-medium text-gray-900 truncate" title={user.email ?? ''}>{user.email}</p>
                                                </div>
                                                <div className="py-1">
                                                    <UserMenuContentDesktop />
                                                </div>
                                            </MenuItems>
                                        </Transition>
                                    </Menu>
                                ) : (
                                    <Link to="/login" className={`${getPrimaryButtonClasses()} !text-xs !px-4 !py-1.5`}>
                                        Login
                                    </Link>
                                )}
                            </div>

                            <div className="md:hidden flex items-center">
                                <Link
                                    to={user ? "/submit-property" : "/login"}
                                    state={user ? undefined : { from: '/submit-property' }}
                                    className="text-gray-500 hover:text-gray-800 transition-colors p-1.5 rounded-full hover:bg-gray-100 mr-1"
                                    title="Post Property"
                                    onClick={closePopover}
                                >
                                    <IconSquarePlus size={iconSize} stroke={iconStroke} />
                                    <span className="sr-only">Post Property</span>
                                </Link>
                                {user && (
                                    <Link
                                        to="/wishlist"
                                        className="relative text-gray-500 hover:text-gray-800 transition-colors p-1.5 rounded-full hover:bg-gray-100 mr-1"
                                        title="Wishlist"
                                        onClick={closePopover}
                                    >
                                        <IconHeart size={iconSize} stroke={iconStroke} />
                                        {!wishlistLoading && wishlistCount !== null && wishlistCount > 0 && (
                                            <span className="absolute -top-1 -right-1 flex h-4 w-4 items-center justify-center rounded-full bg-[#D9A619] text-xs font-bold text-white">
                                                {wishlistCount}
                                            </span>
                                        )}
                                        <span className="sr-only">Wishlist</span>
                                    </Link>
                                )}
                                <PopoverButton className="inline-flex items-center justify-center p-2 rounded-md text-gray-400 hover:text-gray-500 hover:bg-gray-100 focus:outline-none focus:ring-2 focus:ring-inset focus:ring-gray-500">
                                    <span className="sr-only">Open main menu</span>
                                    {open ? (
                                        <IconX className="block h-6 w-6" aria-hidden="true" />
                                    ) : (
                                        <IconMenu2 className="block h-6 w-6" aria-hidden="true" />
                                    )}
                                </PopoverButton>
                            </div>
                        </div>
                    </div>

                    <Transition
                        as={Fragment}
                        enter="duration-150 ease-out"
                        enterFrom="opacity-0 scale-95"
                        enterTo="opacity-100 scale-100"
                        leave="duration-100 ease-in"
                        leaveFrom="opacity-100 scale-100"
                        leaveTo="opacity-0 scale-95"
                    >
                        <PopoverPanel focus className="absolute inset-x-0 top-0 origin-top-right transform p-2 transition md:hidden z-50">
                            <div className="rounded-lg bg-white shadow-md ring-1 ring-black ring-opacity-5 border border-gray-100">
                                <div className="px-5 pt-4 pb-3 flex items-center justify-between">
                                    <Link to="/" className="flex items-center gap-2 group" onClick={closePopover}>
                                        <img src="/veedu360-logo.png" alt="Company Logo" className="h-20 w-auto" />
                                    </Link>
                                    <div className="-mr-2">
                                        <PopoverButton className="inline-flex items-center justify-center rounded-md bg-white p-2 text-gray-400 hover:bg-gray-100 hover:text-gray-500 focus:outline-none focus:ring-2 focus:ring-inset focus:ring-gray-500">
                                            <span className="sr-only">Close menu</span>
                                            <IconX className="h-6 w-6" aria-hidden="true" />
                                        </PopoverButton>
                                    </div>
                                </div>

                                <nav className="space-y-1 px-2 py-3">
                                    {renderNavLinks(closePopover)}
                                </nav>

                                {user ? (
                                    <div className="border-t border-gray-100 pt-4 pb-3">
                                        <div className="flex items-center px-5 mb-3">
                                            <div className="flex-shrink-0">
                                                <div className="w-10 h-10 rounded-full bg-gray-200 text-gray-600 flex items-center justify-center text-base font-semibold border border-gray-300">
                                                    {user.email ? user.email.charAt(0).toUpperCase() : <IconUser size={20} />}
                                                </div>
                                            </div>
                                            <div className="ml-3 min-w-0">
                                                <p className="text-sm font-medium text-gray-800 truncate">{user.email}</p>
                                                {renderBalance()}
                                            </div>
                                        </div>
                                        <div className="mt-3 space-y-1 px-2">
                                            <Menu>
                                                <UserMenuContentMobile closePopover={closePopover} />
                                            </Menu>
                                        </div>
                                    </div>
                                ) : (
                                    <div className="border-t border-gray-100 py-3 px-5">
                                        <Link
                                            to="/login"
                                            onClick={closePopover}
                                            className={`${getPrimaryButtonClasses()} w-full text-center`}
                                        >
                                            Log in
                                        </Link>
                                    </div>
                                )}
                            </div>
                        </PopoverPanel>
                    </Transition>
                </>
            )}
        </Popover>
    );
}

export default Navbar;