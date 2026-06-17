import { useEffect, useState, useCallback, Fragment, useMemo, lazy, Suspense } from 'react';

import { useSearchParams } from 'react-router-dom';
import { IconFilter, IconX, IconLayoutGrid, IconLayoutList, IconAlertCircle, IconMap, IconMapOff } from '@tabler/icons-react';
import useDebounce from '../lib/hooks/useDebounce';

import PropertyCard from '../components/PropertyCard';
import PropertyFilterSidebar from '../components/PropertyFilterSidebar';
import { Property, PropertiesFilterParams } from '../lib/types';
import api from '../lib/supabaseClient';
import LoadingSpinner from '../components/LoadingSpinner';
import PaginationControls from '../components/PaginationControls';
import { Dialog, Transition, TransitionChild, DialogPanel } from '@headlessui/react';
import { useNotification } from '../components/NotificationProvider';
import { getTertiaryButtonClasses } from '../lib/twUtils';
const PropertiesMapView = lazy(() => import('../components/PropertiesMapView'));

const ITEMS_PER_PAGE = 12;

// --- Helper Functions ---
const safeParseInt = (value: string | null | undefined): number | undefined => {
    if (value === null || value === undefined) return undefined;
    const num = parseInt(value, 10);
    return isNaN(num) || num < 0 ? undefined : num;
};

const defaultFilters: Omit<PropertiesFilterParams, 'p_offset' | 'p_limit'> = {
    p_property_types: undefined,
    p_listing_types: undefined,
    p_price_min: undefined,
    p_price_max: undefined,
    p_area_min: undefined,
    p_area_max: undefined,
    p_area_unit: undefined,
    p_location_search: undefined,
    p_city: undefined,
    p_house_types: undefined,
    p_num_bedrooms_min: undefined,
    p_num_bedrooms_max: undefined,
    p_furnished_statuses: undefined,
    p_facing_directions: undefined,
    p_land_types: undefined,
    p_building_types: undefined,
    p_sort_by: 'updated_at',
    p_sort_direction: 'DESC',
};

const parseFiltersFromParams = (params: URLSearchParams): Omit<PropertiesFilterParams, 'offset' | 'limit'> => {
    const newFilters = { ...defaultFilters };
    const arrayKeys: (keyof typeof newFilters)[] = ['p_listing_types', 'p_property_types', 'p_house_types', 'p_furnished_statuses', 'p_facing_directions', 'p_land_types', 'p_building_types'];
    const numberKeys: (keyof typeof newFilters)[] = ['p_price_min', 'p_price_max', 'p_area_min', 'p_area_max', 'p_num_bedrooms_min', 'p_num_bedrooms_max'];
    const stringKeys: (keyof typeof newFilters)[] = ['p_location_search', 'p_city', 'p_sort_by', 'p_sort_direction'];

    // Initialize arrays
    arrayKeys.forEach(key => { (newFilters as any)[key] = []; });

    params.forEach((value, key) => {
        const filterKey = key as keyof typeof newFilters;
        if (key === 'page' || !Object.prototype.hasOwnProperty.call(newFilters, filterKey)) {
            return;
        }

        if (arrayKeys.includes(filterKey)) {
            if (value) {
                (newFilters as any)[filterKey].push(value);
            }
        } else if (numberKeys.includes(filterKey)) {
            (newFilters as any)[filterKey] = safeParseInt(value);
        } else if (stringKeys.includes(filterKey)) {
            (newFilters as any)[filterKey] = value;
        }
    });

    // Set array to undefined if empty after parsing
    arrayKeys.forEach(key => {
        if ((newFilters[key] as string[]).length === 0) {
            (newFilters as any)[key] = undefined;
        } else {
            // Ensure uniqueness
            (newFilters as any)[key] = [...new Set((newFilters as any)[key])];
        }
    });

    return newFilters;
};
// --- Component Start ---
function Catalogue() {

    const companyName = import.meta.env.VITE_COMPANY_NAME;
    const [searchParams, setSearchParams] = useSearchParams();

    const currentFilters = useMemo(() => parseFiltersFromParams(searchParams), [searchParams]);
    const currentPage = useMemo(() => safeParseInt(searchParams.get('page')) || 1, [searchParams]);
    const debouncedFiltersFromUrl = useDebounce(currentFilters, 1000);

    // --- Other State ---
    const [properties, setProperties] = useState<Property[]>([]);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState<string | null>(null);
    const [totalProperties, setTotalProperties] = useState<number>(0);
    const [mobileFiltersOpen, setMobileFiltersOpen] = useState(false);
    const [viewMode, setViewMode] = useState<'list' | 'grid'>('grid');
    const [showMap, setShowMap] = useState(false);
    const { showErrorNotification } = useNotification();

    const itemsPerPage = ITEMS_PER_PAGE;

    const fetchProperties = useCallback(async () => {
        setError(null);
        setLoading(true);
        const currentOffset = (currentPage - 1) * itemsPerPage;

        try {
            const { data, error: fetchError } = await api.getProperties({
                ...debouncedFiltersFromUrl,
                p_offset: currentOffset,
                p_limit: itemsPerPage,
            });

            if (fetchError) throw fetchError;

            const fetchedProperties = data || [];
            setProperties(fetchedProperties);

            if (fetchedProperties.length > 0 && fetchedProperties[0].total_count !== undefined) {
                setTotalProperties(fetchedProperties[0].total_count);
            } else if (currentOffset === 0) {
                setTotalProperties(0);
            }

        } catch (err: any) {
            console.error("Error fetching properties:", err);
            showErrorNotification('Load Failed', err.message || 'Failed to load properties.');
            setError(err.message || 'Failed to load properties.');
            setProperties([]);
            setTotalProperties(0);
        } finally {
            setLoading(false);
        }
    }, [debouncedFiltersFromUrl, currentPage, itemsPerPage, showErrorNotification]);

    useEffect(() => {
        fetchProperties();
    }, [fetchProperties]);

    // --- Event Handlers ---
    const handleFilterChange = useCallback((newFilters: Partial<Omit<PropertiesFilterParams, 'p_offset' | 'p_limit'>>) => {
        const newSearchParams = new URLSearchParams(searchParams);

        Object.entries(newFilters).forEach(([key, value]) => {
            const filterKey = key as keyof typeof defaultFilters;
            const defaultValue = defaultFilters[filterKey];

            newSearchParams.delete(key);

            if (value !== undefined && value !== null && JSON.stringify(value) !== JSON.stringify(defaultValue)) {
                if (Array.isArray(value)) {
                    if (value.length > 0) {
                        value.forEach(item => newSearchParams.append(key, String(item)));
                    }
                } else {
                    newSearchParams.set(key, String(value));
                }
            }
        });

        newSearchParams.delete('page');

        setSearchParams(newSearchParams, { replace: true });
    }, [searchParams, setSearchParams]);

    const handleSortChange = (event: React.ChangeEvent<HTMLSelectElement>) => {
        const value = event.target.value;
        const [sortBy, sortDirection] = value?.split('-') || ['updated_at', 'DESC'];
        handleFilterChange({
            p_sort_by: sortBy as PropertiesFilterParams['p_sort_by'],
            p_sort_direction: sortDirection as PropertiesFilterParams['p_sort_direction']
        });
    };

    const handlePageChange = (newPage: number) => {
        const totalPages = Math.ceil(totalProperties / itemsPerPage);
        if (newPage >= 1 && newPage <= totalPages && newPage !== currentPage) {
            const newSearchParams = new URLSearchParams(searchParams);
            if (newPage === 1) {
                newSearchParams.delete('page');
            } else {
                newSearchParams.set('page', String(newPage));
            }
            setSearchParams(newSearchParams, { replace: true });
            window.scrollTo({ top: 0, behavior: 'smooth' });
        }
    };

    // --- Other UI Logic ---
    const openMobileFilters = () => setMobileFiltersOpen(true);
    const closeMobileFilters = () => setMobileFiltersOpen(false);
    const totalPages = Math.ceil(totalProperties / itemsPerPage);
    const sortValue = `${currentFilters.p_sort_by || 'updated_at'}-${currentFilters.p_sort_direction || 'DESC'}`;

    // --- Rendering ---
    const renderContent = () => {
        if (loading && properties.length === 0) {
            return (
                <div className="flex justify-center items-center py-16">
                    <LoadingSpinner />
                </div>
            );
        }

        // Error display
        if (error) {
            return (
                <div className="bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded-lg text-center flex flex-col items-center gap-2 shadow-sm">
                    <IconAlertCircle size={20} /> Error loading properties: {error}
                    <button onClick={fetchProperties} className={getTertiaryButtonClasses() + " text-xs !text-red-700 hover:!bg-red-100"}>
                        Try Again
                    </button>
                </div>
            );
        }

        // No results found
        if (!loading && totalProperties === 0) {
            return (
                <div className="bg-white p-8 rounded-lg shadow-sm text-center border border-gray-200">
                    <h3 className="text-lg font-medium text-gray-700 mb-2">No properties found</h3>
                    <p className="text-gray-500">Try adjusting your filters or search criteria.</p>
                    <button
                        onClick={() => {
                            setSearchParams({}, { replace: true });
                        }}
                        className="mt-4 px-4 py-2 bg-[#D9A619] text-white rounded-md hover:bg-white hover:text-[#D9A619] outline-[#D9A619] transition-colors text-sm"
                    >
                        Clear All Filters
                    </button>
                </div>
            );
        }

        // Show property list/grid
        return (
            <div className="relative">
                {/* Map View */}
                {showMap && properties.length > 0 && (
                    <div className="mb-6">
                        <Suspense fallback={<div className="h-[500px] flex items-center justify-center bg-gray-100 rounded-lg"><LoadingSpinner /></div>}>
                            <PropertiesMapView properties={properties} />
                        </Suspense>
                    </div>
                )}

                {/* List/Grid View */}
                <>
                    {loading && properties.length > 0 && (
                        <div className="absolute inset-0 bg-white/70 flex items-center justify-center z-10 rounded-lg">
                            <LoadingSpinner />
                        </div>
                    )}
                    <div className={`grid gap-6 ${viewMode === 'grid' ? 'grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4' : 'grid-cols-1'} ${loading ? 'opacity-50 pointer-events-none' : ''}`}>
                        {properties.map((property) => (
                            <PropertyCard
                                key={property.property_id}
                                property={property}
                                variant={viewMode === 'grid' ? 'simple' : 'detailed'}
                            />
                        ))}
                    </div>
                </>

                {/* Pagination Controls */}
                {totalPages > 1 && (
                    <PaginationControls
                        currentPage={currentPage}
                        totalPages={totalPages}
                        onPageChange={handlePageChange}
                        itemsPerPage={itemsPerPage}
                        totalItems={totalProperties}
                    />
                )}
            </div>
        );
    };

    return (
        <div className="bg-gray-50 min-h-screen">
            {/* Use derived currentFilters for title */}
            <title>Properties {currentFilters.p_location_search ? `in ${currentFilters.p_location_search}` : currentFilters.p_city ? `in ${currentFilters.p_city}` : ''} | {companyName}</title>

            {/* Mobile Filter Button */}
            <div className="md:hidden sticky top-[61px] bg-gray-50/90 backdrop-blur-sm z-30 p-2 border-b border-gray-200">
                <div className="container mx-auto flex justify-end">
                    <button
                        onClick={openMobileFilters}
                        className="inline-flex items-center gap-2 px-4 py-2 border border-gray-300 rounded-md text-sm font-medium text-gray-700 bg-white hover:bg-gray-50 shadow-sm"
                    >
                        <IconFilter size={18} /> Filters
                    </button>
                </div>
            </div>

            <div className="container mx-auto py-6 px-4">
                <div className="flex flex-col md:flex-row gap-6 lg:gap-8">
                    {/* Filters Sidebar */}
                    <aside className="hidden md:block md:w-72 lg:w-80 flex-shrink-0 md:sticky md:top-[85px] h-screen-minus-navbar overflow-y-auto custom-scrollbar ">
                        <PropertyFilterSidebar
                            filters={currentFilters}
                            onFilterChange={handleFilterChange}
                        />
                    </aside>

                    {/* Main Content Area */}
                    <main className="flex-grow min-w-0">
                        <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center mb-4 gap-2">
                            <h1 className="text-xl font-bold text-gray-800">
                                Properties {loading ? '' : `(${totalProperties})`}
                                {currentFilters.p_location_search && ` in ${currentFilters.p_location_search}`}
                                {currentFilters.p_city && !currentFilters.p_location_search && ` in ${currentFilters.p_city}`}
                            </h1>
                            <div className="flex items-center gap-3 w-full sm:w-auto flex-wrap">
                                {/* Sort Dropdown */}
                                <select
                                    value={sortValue}
                                    onChange={handleSortChange}
                                    className="block w-full sm:w-auto text-xs border-gray-300 rounded-md shadow-sm focus:border-gray-500 focus:ring-gray-500 px-3 py-1.5"
                                    aria-label="Sort properties"
                                >
                                    <option value="updated_at-DESC">Sort: Newest</option>
                                    <option value="price-ASC">Sort: Price (Low-High)</option>
                                    <option value="price-DESC">Sort: Price (High-Low)</option>
                                    <option value="area-DESC">Sort: Area (Largest)</option>
                                </select>

                                {/* Map Toggle */}
                                <button
                                    onClick={() => setShowMap(!showMap)}
                                    className={`p-1.5 border rounded-md text-xs flex items-center gap-1 transition-colors ${showMap
                                        ? 'bg-[#D9A619] text-white border-[#D9A619]'
                                        : 'bg-white text-gray-500 border-gray-300 hover:bg-gray-50'
                                        }`}
                                    aria-label={showMap ? "Hide map" : "Show map"}
                                >
                                    {showMap ? <IconMapOff size={18} /> : <IconMap size={18} />}
                                    <span className='hidden sm:inline'>{showMap ? 'Hide Map' : 'Show Map'}</span>
                                </button>

                                {/* View Mode Toggle */}
                                <div className="flex items-center border border-gray-300 rounded-md overflow-hidden">
                                    <button
                                        onClick={() => setViewMode('list')}
                                        className={`p-1.5 transition-colors ${viewMode === 'list' ? 'bg-[#2C4964] text-white' : 'text-gray-500 hover:bg-gray-100'}`}
                                        aria-label="List view"
                                        title="List View"
                                    >
                                        <IconLayoutList size={18} />
                                    </button>
                                    <button
                                        onClick={() => setViewMode('grid')}
                                        className={`p-1.5 transition-colors ${viewMode === 'grid' ? 'bg-[#2C4964] text-white' : 'text-gray-500 hover:bg-gray-100'}`}
                                        aria-label="Grid view"
                                        title="Grid View"
                                    >
                                        <IconLayoutGrid size={18} />
                                    </button>
                                </div>
                            </div>
                        </div>

                        {/* Property List/Grid/Map Area */}
                        {renderContent()}

                    </main>
                </div>
            </div>

            {/* Mobile Filters Drawer/Modal */}
            <Transition show={mobileFiltersOpen} as={Fragment}>
                <Dialog as="div" className="relative z-40 md:hidden" onClose={closeMobileFilters}>
                    <TransitionChild as={Fragment} enter="transition-opacity ease-linear duration-300" enterFrom="opacity-0" enterTo="opacity-100" leave="transition-opacity ease-linear duration-300" leaveFrom="opacity-100" leaveTo="opacity-0">
                        <div className="fixed inset-0 backdrop-blur-sm bg-black/25" />
                    </TransitionChild>
                    <div className="fixed inset-0 z-40 flex">
                        <TransitionChild as={Fragment} enter="transition ease-in-out duration-300 transform" enterFrom="-translate-x-full" enterTo="translate-x-0" leave="transition ease-in-out duration-300 transform" leaveFrom="translate-x-0" leaveTo="-translate-x-full">
                            <DialogPanel className="relative flex w-full max-w-xs flex-col overflow-y-auto bg-white pb-12 shadow-xl">
                                <div className="flex items-center justify-between px-4 pt-5 pb-2 border-b border-gray-200">
                                    <h2 className="text-lg font-medium text-gray-900">Filters</h2>
                                    <button type="button" className="-mr-2 flex h-10 w-10 items-center justify-center rounded-md bg-white p-2 text-gray-400 hover:bg-gray-50" onClick={closeMobileFilters}>
                                        <IconX className="h-6 w-6" aria-hidden="true" />
                                    </button>
                                </div>
                                <div className="mt-4 border-t border-gray-200 px-4 py-6 flex-grow overflow-y-auto custom-scrollbar">
                                    <PropertyFilterSidebar filters={currentFilters} onFilterChange={handleFilterChange} isMobile />
                                </div>
                                <div className="px-4 py-3 border-t border-gray-200 absolute bottom-0 left-0 right-0 bg-white">
                                    <button onClick={closeMobileFilters} className="w-full bg-gray-600 hover:bg-gray-700 text-white font-medium py-2 px-4 rounded-md">
                                        View Results
                                    </button>
                                </div>
                            </DialogPanel>
                        </TransitionChild>
                    </div>
                </Dialog>
            </Transition>
        </div>
    );
}

export default Catalogue;