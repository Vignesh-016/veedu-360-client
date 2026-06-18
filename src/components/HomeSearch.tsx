import { useState, useEffect } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { IconSearch, IconMapPin, IconHome, IconBuildingCommunity, IconBed, IconBuildingWarehouse, IconSquarePlus, IconCurrentLocation } from '@tabler/icons-react';
import { ListingType, PropertyType, HouseType } from '../lib/types';
import { useAuth } from '../lib/AuthContext';
import { DEFAULT_CITY } from '../lib/geoUtils';

type TabType = 'SALE' | 'RENTAL' | 'PLOT' | 'PG' | 'SERVICE_APARTMENT';

// structure for property type options
interface PropertyTypeOptionValue {
    mainType: PropertyType;
    subType?: HouseType;
}

interface PropertyTypeOption {
    label: string;
    value: PropertyTypeOptionValue;
    icon: React.ElementType;
}


function HomeSearch() {
    const [activeTab, setActiveTab] = useState<TabType>('SALE');
    const { currentCity, geolocationLoading, user, refetchGeolocation } = useAuth();
    const [propertyType, setPropertyType] = useState<PropertyType | null>(null);
    const [houseType, setHouseType] = useState<HouseType | null>(null);
    const [locationInput, setLocationInput] = useState(DEFAULT_CITY);
    const [bhk, setBhk] = useState<string | null>(null);
    const [userHasTypedLocation, setUserHasTypedLocation] = useState(false);
    const navigate = useNavigate();

    useEffect(() => {
        if (!geolocationLoading && currentCity && !userHasTypedLocation) {
            setLocationInput(currentCity);
        }
    }, [currentCity, geolocationLoading, userHasTypedLocation]);

    const handleLocationChange = (e: React.ChangeEvent<HTMLInputElement>) => {
        setLocationInput(e.target.value);
        setUserHasTypedLocation(true);
    };

    const handleTabChange = (tab: TabType) => {
        setActiveTab(tab);
        setPropertyType(null);
        setHouseType(null);
        setBhk(null);
    };

    const handleSearch = () => {
        const queryParams = new URLSearchParams();

        if (activeTab === 'SALE' || activeTab === 'RENTAL') {
            queryParams.append('p_listing_types', activeTab);

            if (propertyType) {
                queryParams.append('p_property_types', propertyType);
            }

            if (propertyType === 'HOUSE' && houseType) {
                queryParams.append('p_house_types', houseType);
            }

            // Append BHK (only if propertyType is HOUSE and not HOSTEL_PG)
            if (bhk && propertyType === 'HOUSE' && houseType !== 'HOSTEL_PG') {
                if (bhk === '1') {
                    queryParams.append('p_num_bedrooms_min', '1');
                    queryParams.append('p_num_bedrooms_max', '1');
                } else if (bhk === '2') {
                    queryParams.append('p_num_bedrooms_min', '2');
                    queryParams.append('p_num_bedrooms_max', '2');
                } else if (bhk === '3+') {
                    queryParams.append('p_num_bedrooms_min', '3');
                }
            }
        } else if (activeTab === 'PLOT') {
            queryParams.append('p_property_types', 'LAND');
        } else if (activeTab === 'PG') {
            queryParams.append('p_listing_types', 'RENTAL');
            queryParams.append('p_property_types', 'HOUSE');
            queryParams.append('p_house_types', 'HOSTEL_PG');
        } else if (activeTab === 'SERVICE_APARTMENT') {
            queryParams.append('p_listing_types', 'RENTAL');
            queryParams.append('p_property_types', 'HOUSE');
            queryParams.append('p_house_types', 'APARTMENT_FLAT');

            if (bhk) {
                if (bhk === '1') {
                    queryParams.append('p_num_bedrooms_min', '1');
                    queryParams.append('p_num_bedrooms_max', '1');
                } else if (bhk === '2') {
                    queryParams.append('p_num_bedrooms_min', '2');
                    queryParams.append('p_num_bedrooms_max', '2');
                } else if (bhk === '3+') {
                    queryParams.append('p_num_bedrooms_min', '3');
                }
            }
        }

        if (locationInput && locationInput.trim() !== '') {
            queryParams.append('p_location_search', locationInput.trim());
        }

        navigate(`/catalogue?${queryParams.toString()}`);
    };

    // Define property types mapping with mainType and subType for Buy/Rent subcategories
    const propertyTypeOptions: PropertyTypeOption[] = [
        { label: 'House / Villa', value: { mainType: 'HOUSE', subType: 'INDEPENDENT_VILLA' }, icon: IconHome },
        { label: 'Apartment', value: { mainType: 'HOUSE', subType: 'APARTMENT_FLAT' }, icon: IconBuildingCommunity },
        { label: 'Land', value: { mainType: 'LAND' }, icon: IconMapPin },
        { label: 'Building / Commercial', value: { mainType: 'BUILDING' }, icon: IconBuildingWarehouse },
    ];

    // Click handler for property type buttons
    const handlePropertyTypeClick = (optionValue: PropertyTypeOptionValue) => {
        if (propertyType === optionValue.mainType && houseType === (optionValue.subType ?? null)) {
            setPropertyType(null);
            setHouseType(null);
            setBhk(null);
        } else {
            setPropertyType(optionValue.mainType);
            setHouseType(optionValue.subType ?? null);
            if (optionValue.mainType !== 'HOUSE' || optionValue.subType === 'HOSTEL_PG') {
                setBhk(null);
            }
        }
    };


    const renderPropertyTypeButtons = () => {
        return propertyTypeOptions.map((typeOption) => {
            const isActive = propertyType === typeOption.value.mainType && houseType === (typeOption.value.subType ?? null);
            return (
                <button
                    key={typeOption.label}
                    type="button"
                    className={`px-3 py-1.5 text-sm rounded-xl flex items-center gap-1.5 transition-colors border ${isActive
                        ? 'bg-[#2C4964] text-white font-medium border-[#2C4964] ring-2 ring-[#2C4964]/30'
                        : 'text-gray-600 hover:bg-gray-100 border-gray-300'
                        }`}
                    onClick={() => handlePropertyTypeClick(typeOption.value)}
                >
                    <typeOption.icon size={16} stroke={1.5} />
                    {typeOption.label}
                </button>
            );
        });
    };

    const renderBhkButtons = () => {
        const bhkOptions = ['1', '2', '3+'];
        return bhkOptions.map((option) => (
            <button
                key={option}
                type="button"
                className={`px-3 py-1.5 text-xs rounded-full border transition-colors ${bhk === option
                    ? 'bg-[#2C4964] text-white border-[#2C4964]'
                    : 'text-gray-700 border-gray-300 hover:bg-gray-100'
                    }`}
                onClick={() => setBhk(bhk === option ? null : option)}
            >
                {option} BHK
            </button>
        ));
    };

    return (
        <div className="">
            {/* Tabs & Post Property */}
            <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between mb-6 gap-4 pb-2 sm:pb-0">
                <div className="flex flex-wrap border-b border-gray-200 flex-grow">
                    {[
                        { id: 'SALE', label: 'Buy' },
                        { id: 'RENTAL', label: 'Rent' },
                        { id: 'PLOT', label: 'Plot' },
                        { id: 'PG', label: 'PG' },
                        { id: 'SERVICE_APARTMENT', label: 'Service Apartment' },
                    ].map((tab) => (
                        <button
                            key={tab.id}
                            type="button"
                            className={`py-3 px-4 md:px-6 font-semibold text-sm md:text-base relative -mb-[1px] transition-all duration-300 ${activeTab === tab.id
                                ? 'border-b-2 border-[#2C4964] text-[#2C4964]'
                                : 'text-gray-500 hover:text-[#D9A619]'
                                }`}
                            onClick={() => handleTabChange(tab.id as TabType)}
                        >
                            {tab.label}
                        </button>
                    ))}
                </div>

                <Link
                    to={user ? "/submit-property" : "/login"}
                    state={user ? undefined : { from: '/submit-property' }}
                    className="flex items-center gap-1.5 px-5 py-2.5 bg-[#2C4964] hover:bg-[#1E3347] text-white rounded-full font-bold text-xs md:text-sm transition-all duration-300 shadow-md hover:shadow-lg self-start sm:self-auto group mb-2 sm:mb-0"
                >
                    <IconSquarePlus size={18} stroke={2} className="text-white" />
                    <span>Post Property</span>
                    <span className="bg-[#16A34A] text-white text-[9px] md:text-[10px] font-extrabold px-1.5 py-0.5 rounded shadow-sm tracking-wider flex items-center justify-center">
                        FREE
                    </span>
                </Link>
            </div>

            {/* Property Type Buttons (only show for Buy or Rent tabs) */}
            {(activeTab === 'SALE' || activeTab === 'RENTAL') && (
                <div className="flex flex-wrap gap-4 mb-6">
                    {renderPropertyTypeButtons()}
                </div>
            )}

            {/* Location Input and BHK Selector */}
            <div className="flex flex-col md:flex-row items-center gap-6 mb-6">
                {/* Location Input */}
                <div className="relative flex-grow w-full md:w-1/2">
                    <IconMapPin size={20} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
                    <input
                        type="text"
                        placeholder={geolocationLoading && !userHasTypedLocation ? "Detecting city..." : `Enter location (e.g., ${DEFAULT_CITY})`}
                        value={locationInput}
                        onChange={handleLocationChange}
                        className="w-full pl-12 pr-12 py-3 border-2 border-gray-300 rounded-xl focus:outline-none focus:ring-2 focus:ring-[#2C4964] focus:border-transparent"
                    />
                    <button
                        type="button"
                        onClick={async () => {
                            setUserHasTypedLocation(false);
                            await refetchGeolocation();
                        }}
                        className={`absolute right-3 top-1/2 -translate-y-1/2 p-1.5 rounded-lg text-gray-400 hover:text-[#2C4964] hover:bg-gray-100 transition-all ${geolocationLoading ? 'animate-spin text-[#2C4964]' : ''}`}
                        title="Detect my current location"
                    >
                        <IconCurrentLocation size={20} />
                    </button>
                </div>

                {/* BHK Selector (appears if main propertyType is HOUSE under Buy/Rent, or if Service Apartment tab is active) */}
                {(((activeTab === 'SALE' || activeTab === 'RENTAL') && propertyType === 'HOUSE' && houseType !== 'HOSTEL_PG') ||
                  activeTab === 'SERVICE_APARTMENT') && (
                    <div className="flex items-center gap-3 p-3 border-2 border-gray-300 rounded-lg bg-gray-50 flex-shrink-0">
                        <IconBed size={20} className="text-gray-500" />
                        <div className="flex gap-2">
                            {renderBhkButtons()}
                        </div>
                    </div>
                )}

                {/* Search Button */}
                <button
                    type="button"
                    onClick={handleSearch}
                    className="w-full md:w-auto px-8 py-3 text-lg font-bold text-white bg-[#2C4964] hover:bg-[#1E3347] shadow-md rounded-full flex items-center justify-center gap-2 transition-all duration-300"
                >
                    <IconSearch size={22} stroke={2.5} />
                    Search
                </button>
            </div>
        </div>
    );
}

export default HomeSearch;