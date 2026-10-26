import { useEffect, useState, useCallback, Fragment, useMemo, lazy, Suspense, useRef } from 'react';

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
import { DEFAULT_CITY, distanceInKilometres, geocodeLocation } from '../lib/geoUtils';
import { getPropertyLabel } from '../lib/propertyAvailability';
import PropertyComingSoon from '../components/PropertyComingSoon';
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

const sanitizeFiltersByPropertyType = (filters: Omit<PropertiesFilterParams, 'p_offset' | 'p_limit'>) => {
    const propertyType = filters.p_property_types?.[0];
    const sanitized = { ...filters };
    if (propertyType !== 'HOUSE') {
        sanitized.p_house_types = undefined;
        sanitized.p_num_bedrooms_min = undefined;
        sanitized.p_num_bedrooms_max = undefined;
        sanitized.p_furnished_statuses = undefined;
        sanitized.p_facing_directions = undefined;
    }
    if (propertyType !== 'LAND') sanitized.p_land_types = undefined;
    if (propertyType !== 'BUILDING') sanitized.p_building_types = undefined;
    return sanitized;
};

const propertyTypeSpecificFilterKeys: Record<string, (keyof typeof defaultFilters)[]> = {
    HOUSE: ['p_land_types', 'p_building_types'],
    LAND: ['p_house_types', 'p_num_bedrooms_min', 'p_num_bedrooms_max', 'p_furnished_statuses', 'p_facing_directions', 'p_building_types'],
    BUILDING: ['p_house_types', 'p_num_bedrooms_min', 'p_num_bedrooms_max', 'p_furnished_statuses', 'p_facing_directions', 'p_land_types'],
};

const getInvalidFilterKeys = (propertyType: string | undefined) =>
    propertyTypeSpecificFilterKeys[propertyType || ''] || [
        'p_house_types', 'p_num_bedrooms_min', 'p_num_bedrooms_max', 'p_furnished_statuses',
        'p_facing_directions', 'p_land_types', 'p_building_types',
    ];

const parseFiltersFromParams = (params: URLSearchParams): Omit<PropertiesFilterParams, 'offset' | 'limit'> => {
    const newFilters = { ...defaultFilters };
    const arrayKeys: (keyof typeof newFilters)[] = ['p_listing_types', 'p_property_types', 'p_house_types', 'p_furnished_statuses', 'p_facing_directions', 'p_land_types', 'p_building_types'];
    const numberKeys: (keyof typeof newFilters)[] = ['p_price_min', 'p_price_max', 'p_area_min', 'p_area_max', 'p_num_bedrooms_min', 'p_num_bedrooms_max'];
    const stringKeys: (keyof typeof newFilters)[] = ['p_area_unit', 'p_location_search', 'p_city', 'p_sort_by', 'p_sort_direction'];

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

    const currentFilters = useMemo(() => sanitizeFiltersByPropertyType(parseFiltersFromParams(searchParams)), [searchParams]);
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
    const [nearbyFallback, setNearbyFallback] = useState(false);
    const { showErrorNotification } = useNotification();
    const requestVersion = useRef(0);

    const itemsPerPage = ITEMS_PER_PAGE;

    const fetchProperties = useCallback(async () => {
        const requestId = ++requestVersion.current;
        setError(null);
        setLoading(true);
        const currentOffset = (currentPage - 1) * itemsPerPage;
        const hasLocationSearch = Boolean(debouncedFiltersFromUrl.p_location_search);
        const hasBudgetFilter = debouncedFiltersFromUrl.p_price_min !== undefined
            || debouncedFiltersFromUrl.p_price_max !== undefined;
        const hasAreaSort = debouncedFiltersFromUrl.p_sort_by === 'area';
        const shouldPaginateLocally = hasLocationSearch || hasBudgetFilter || hasAreaSort;
        setProperties([]);

        try {
            const { data, error: fetchError } = await api.getProperties({
                ...debouncedFiltersFromUrl,
                // Fetch the complete ordered set before local deduplication for
                // location, budget, and area-sort views. This prevents a
                // property from appearing on two pages after deduplication.
                p_offset: shouldPaginateLocally ? 0 : currentOffset,
                p_limit: shouldPaginateLocally ? 1000 : itemsPerPage,
            });

            if (fetchError) throw fetchError;

            const fetchedProperties = data || [];

            if (hasLocationSearch) {
                const locationQuery = debouncedFiltersFromUrl.p_location_search as string;
                const location = await geocodeLocation(locationQuery);
                const nearbyCity = location?.city || debouncedFiltersFromUrl.p_city || DEFAULT_CITY;
                if (location || nearbyCity) {
                    const nearbyResponse = await api.getProperties({
                        ...debouncedFiltersFromUrl,
                        p_location_search: undefined,
                        p_city: nearbyCity,
                        p_offset: 0,
                        p_limit: 100,
                    });
                    if (!nearbyResponse.error && nearbyResponse.data?.length) {
                        const nearbyProperties = nearbyResponse.data
                            .map(property => ({
                                property,
                                distance: location && property.latitude != null && property.longitude != null
                                    ? distanceInKilometres(property.latitude, property.longitude, location.latitude, location.longitude)
                                    : Number.MAX_SAFE_INTEGER,
                            }))
                            .sort((a, b) => a.distance - b.distance)
                            .map(({ property }) => property);
                        const exactPropertyIds = new Set(fetchedProperties.map(property => property.property_id));
                        const additionalNearbyProperties = nearbyProperties.filter(property => !exactPropertyIds.has(property.property_id));
                        const combinedProperties = Array.from(new Map([...fetchedProperties, ...additionalNearbyProperties].map(property => [property.property_id, property])).values());
                        if (requestId !== requestVersion.current) return;
                        setProperties(combinedProperties.slice(currentOffset, currentOffset + itemsPerPage));
                        setTotalProperties(combinedProperties.length);
                        setNearbyFallback(true);
                        return;
                    }
                }
            }

            if (requestId !== requestVersion.current) return;
            setNearbyFallback(false);
            const uniqueProperties = Array.from(new Map(fetchedProperties.map(property => [property.property_id, property])).values());
            // The RPC already applies the selected sort. Do not re-sort here;
            // doing so overrides direction and featured/exclusive priority.
            setProperties(shouldPaginateLocally
                ? uniqueProperties.slice(currentOffset, currentOffset + itemsPerPage)
                : uniqueProperties);

            if (fetchedProperties.length > 0 && fetchedProperties[0].total_count !== undefined) {
                setTotalProperties(fetchedProperties[0].total_count);
            } else if (currentOffset === 0) {
                setTotalProperties(0);
            } else {
                const countResponse = await api.getProperties({ ...debouncedFiltersFromUrl, p_offset: 0, p_limit: 1 });
                if (requestId !== requestVersion.current) return;
                const totalCount = countResponse.data?.[0]?.total_count ?? 0;
                setTotalProperties(totalCount);
                if (totalCount > 0) {
                    setSearchParams(previous => {
                        const next = new URLSearchParams(previous);
                        next.delete('page');
                        return next;
                    }, { replace: true });
                }
            }

        } catch (err: any) {
            console.error("Error fetching properties:", err);
            showErrorNotification('Load Failed', err.message || 'Failed to load properties.');
            setError(err.message || 'Failed to load properties.');
            setProperties([]);
            setTotalProperties(0);
        } finally {
            if (requestId === requestVersion.current) {
                setLoading(false);
            }
        }
    }, [debouncedFiltersFromUrl, currentPage, itemsPerPage, showErrorNotification]);

    useEffect(() => {
        fetchProperties();
    }, [fetchProperties]);

    // --- Event Handlers ---
    const handleFilterChange = useCallback((newFilters: Partial<Omit<PropertiesFilterParams, 'p_offset' | 'p_limit'>>) => {
        const newSearchParams = new URLSearchParams(searchParams);

        // Any filter change starts from the first page. This is especially
        // important when changing area units because the previous page may no
        // longer exist in the newly filtered result set.
        newSearchParams.delete('page');

        if (Object.prototype.hasOwnProperty.call(newFilters, 'p_property_types')) {
            const nextType = newFilters.p_property_types?.[0];
            // Remove all incompatible filters from the URL as well as from
            // the rendered state, so they cannot affect a later request.
            getInvalidFilterKeys(nextType).forEach(key => newSearchParams.delete(key));
        }

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

        setSearchParams(newSearchParams);
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
            setSearchParams(newSearchParams);
            window.scrollTo({ top: 0, behavior: 'smooth' });
        }
    };

    // --- Other UI Logic ---
    const openMobileFilters = () => setMobileFiltersOpen(true);
    const closeMobileFilters = () => setMobileFiltersOpen(false);
    const totalPages = Math.ceil(totalProperties / itemsPerPage);
    const sortValue = `${currentFilters.p_sort_by || 'updated_at'}-${currentFilters.p_sort_direction || 'DESC'}`;
    const hasSpecificFilters = Boolean(
        currentFilters.p_price_min !== undefined || currentFilters.p_price_max !== undefined
        || currentFilters.p_area_min !== undefined || currentFilters.p_area_max !== undefined
        || currentFilters.p_num_bedrooms_min !== undefined || currentFilters.p_num_bedrooms_max !== undefined
        || currentFilters.p_furnished_statuses?.length || currentFilters.p_facing_directions?.length
        || currentFilters.p_land_types?.length || currentFilters.p_building_types?.length,
    );
    const emptyStateTitle = hasSpecificFilters
        ? 'Matching Properties Coming Soon'
        : `${getPropertyLabel(currentFilters.p_property_types?.[0], currentFilters.p_house_types?.[0])} for ${currentFilters.p_listing_types?.[0] === 'RENTAL' ? 'Rent' : 'Sale'}${currentFilters.p_location_search || currentFilters.p_city ? ` in ${currentFilters.p_location_search || currentFilters.p_city}` : ''} – Coming Soon`;
    const emptyStateDescription = hasSpecificFilters
        ? 'There are currently no active listings matching your selected preferences.'
        : `There are currently no active ${getPropertyLabel(currentFilters.p_property_types?.[0], currentFilters.p_house_types?.[0]).toLowerCase()} listings${currentFilters.p_listing_types?.[0] === 'RENTAL' ? ' for rent' : ' for sale'}${currentFilters.p_location_search || currentFilters.p_city ? ` in ${currentFilters.p_location_search || currentFilters.p_city}` : ''}.`;

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
                <PropertyComingSoon title={emptyStateTitle} description={emptyStateDescription} />
            );
        }

        // Show property list/grid
        return (
            <div className="relative">
                {nearbyFallback && (
                    <div className="mb-4 rounded-lg border border-blue-200 bg-blue-50 px-4 py-3 text-sm text-blue-800">
                        Showing properties in and around <span className="font-semibold">{currentFilters.p_location_search}</span>.
                    </div>
                )}
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
                                showFeaturedBadge={false}
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
            <meta name="description" content="Browse verified houses, land and buildings for sale or rent with Veedu 360." />
            <meta property="og:title" content={`Properties | ${companyName}`} />
            <meta property="og:description" content="Browse verified houses, land and buildings for sale or rent with Veedu 360." />
            <meta property="og:url" content="https://www.veedu360.com/catalogue" />

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
