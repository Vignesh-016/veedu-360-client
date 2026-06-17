import React, { useState, Fragment } from 'react';
import { IconChevronDown, IconChevronUp, IconHome2, IconMapPin, IconFilterOff, IconBuildingCommunity, IconSearch } from '@tabler/icons-react';
import { Transition } from '@headlessui/react';
import { PropertiesFilterParams, HouseType, FurnishedStatus, LandType, PropertyType, ListingType, BuildingType, Direction, AreaUnit } from '../lib/types';
import { getTertiaryButtonClasses, getBaseInputClasses } from '../lib/twUtils';
import { Constants } from '../database.types';
import { areaUnitMap, getDisplayValue } from '../lib/displayUtils';

// --- Options ---
const houseTypeOptions: { label: string, value: HouseType }[] = [
    { label: 'Flat / Apartment', value: 'APARTMENT_FLAT' },
    { label: 'Independent House / Villa', value: 'INDEPENDENT_VILLA' },
];
const landTypeOptions: { label: string, value: LandType }[] = [
    { label: 'Residential', value: 'RESIDENTIAL' },
    { label: 'Commercial', value: 'COMMERCIAL' },
    { label: 'Agricultural', value: 'AGRICULTURAL' },
];
const buildingTypeOptions: { label: string, value: BuildingType }[] = [
    { label: 'Office Space', value: 'OFFICE' },
    { label: 'Retail Shop', value: 'RETAIL' },
    { label: 'Warehouse / Godown', value: 'WAREHOUSE' },
    { label: 'Industrial', value: 'INDUSTRIAL' },
    { label: 'Hospitality (Hotel, etc)', value: 'HOSPITALITY' },
];
const bedroomOptions = ['1', '2', '3', '4', '5+'];
const furnishingOptions: { label: string, value: FurnishedStatus }[] = [
    { label: 'Unfurnished', value: 'UNFURNISHED' },
    { label: 'Semi Furnished', value: 'SEMI_FURNISHED' },
    { label: 'Fully Furnished', value: 'FULLY_FURNISHED' },
];

const directionOptions: { label: string, value: Direction }[] = [
    { label: 'North', value: 'NORTH' },
    { label: 'South', value: 'SOUTH' },
    { label: 'East', value: 'EAST' },
    { label: 'West', value: 'WEST' },
];

const areaUnitFilterOptions = Constants.public.Enums.area_unit_enum.map(unit => ({
    label: getDisplayValue(areaUnitMap, unit),
    value: unit,
}));


const defaultFilters: PropertiesFilterParams = {
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

// --- Helper Components ---
interface SegmentedRadioProps {
    name: string;
    value: string | undefined | null;
    onChange: (value: string | undefined) => void;
    options: { label: React.ReactNode; value: string }[];
}

function SegmentedRadio({ name, value, onChange, options }: SegmentedRadioProps) {
    return (
        <div className="flex flex-wrap gap-2 w-full">
            {options.map((option) => (
                <label
                    key={option.value}
                    className={`
                        flex-1 min-w-fit px-4 py-2.5 text-center cursor-pointer rounded-xl text-sm font-medium
                        transition-all duration-200 ease-out border-2
                        ${value === option.value
                            ? 'bg-gradient-to-r from-[#2C4964] to-[#1E3347] text-white border-transparent shadow-md shadow-slate-200 scale-[1.02]'
                            : 'bg-white text-gray-600 border-gray-200 hover:border-[#2C4964]/30 hover:bg-[#2C4964]/5 hover:text-[#2C4964]'
                        }
                    `}
                >
                    <input
                        type="radio"
                        name={name}
                        value={option.value}
                        checked={value === option.value}
                        onChange={() => onChange(option.value)}
                        className="sr-only"
                    />
                    {option.label}
                </label>
            ))}
        </div>
    );
}

function FilterSection({ title, children, defaultOpen = false }: { title: string, children: React.ReactNode, defaultOpen?: boolean }) {
    const [opened, setOpened] = useState(defaultOpen);
    const ChevronIcon = opened ? IconChevronUp : IconChevronDown;

    return (
        <div className="py-4 border-b border-gray-100 last:border-b-0">
            <button
                className="w-full flex justify-between items-center text-left group"
                onClick={() => setOpened((o) => !o)}
                aria-expanded={opened}
            >
                <h3 className="text-sm font-semibold text-gray-800 group-hover:text-[#2C4964] transition-colors">{title}</h3>
                <div className={`p-1 rounded-md transition-all duration-200 ${opened ? 'bg-[#2C4964]/10 text-[#2C4964]' : 'text-gray-400 group-hover:bg-gray-100'}`}>
                    <ChevronIcon size={14} />
                </div>
            </button>
            <Transition
                show={opened}
                as={Fragment}
                enter="transition ease-out duration-200"
                enterFrom="transform opacity-0 -translate-y-1"
                enterTo="transform opacity-100 translate-y-0"
                leave="transition ease-in duration-150"
                leaveFrom="transform opacity-100 translate-y-0"
                leaveTo="transform opacity-0 -translate-y-1"
            >
                <div className="mt-3 space-y-3 pr-1 max-h-60 overflow-y-auto custom-scrollbar">
                    {children}
                </div>
            </Transition>
        </div>
    );
}

interface CheckboxGroupProps {
    values: string[] | undefined | null;
    onChange: (value: string, checked: boolean) => void;
    options: { label: string; value: string }[];
    columns?: number;
}

function CheckboxGroup({ values, onChange, options, columns = 1 }: CheckboxGroupProps) {
    const currentValues = values || [];
    const gridClasses = columns === 2 ? 'grid grid-cols-2 gap-x-3 gap-y-2' : 'space-y-2';

    return (
        <div className={gridClasses}>
            {options.map((opt) => (
                <label
                    key={opt.value}
                    className={`
                        flex items-center text-sm cursor-pointer p-2 rounded-lg transition-all duration-150
                        ${currentValues.includes(opt.value)
                            ? 'bg-[#2C4964]/10 text-[#2C4964]'
                            : 'text-gray-600 hover:bg-gray-50'
                        }
                    `}
                >
                    <input
                        type="checkbox"
                        value={opt.value}
                        checked={currentValues.includes(opt.value)}
                        onChange={(e) => onChange(opt.value, e.target.checked)}
                        className="h-4 w-4 text-[#2C4964] border-gray-300 rounded focus:ring-[#2C4964] focus:ring-offset-0 mr-2.5 flex-shrink-0"
                    />
                    <span className="truncate font-medium">{opt.label}</span>
                </label>
            ))}
        </div>
    );
}

// --- Main Component ---
interface PropertyFilterSidebarProps {
    filters: PropertiesFilterParams;
    onFilterChange: (newFilters: Partial<PropertiesFilterParams>) => void;
    isMobile?: boolean;
}

function PropertyFilterSidebar({ filters, onFilterChange, isMobile = false }: PropertyFilterSidebarProps) {

    const handleMultiCheckboxChange = (filterKey: keyof PropertiesFilterParams, value: string, checked: boolean) => {
        const currentValues = (filters[filterKey] as string[] | undefined) || [];
        let newValues: string[];
        if (checked) {
            newValues = [...currentValues, value];
        } else {
            newValues = currentValues.filter(item => item !== value);
        }
        onFilterChange({ [filterKey]: newValues.length > 0 ? newValues : undefined });
    };

    const handleSingleSelectChange = (filterKey: keyof PropertiesFilterParams, value: string | undefined) => {
        onFilterChange({ [filterKey]: value });
    };

    const handleSegmentedChange = (filterKey: keyof PropertiesFilterParams, value: string | undefined) => {
        onFilterChange({ [filterKey]: value ? [value] : undefined });
    };

    const handleBedroomChange = (value: string | undefined) => {
        let min: number | undefined = undefined;
        let max: number | undefined = undefined;
        if (value) {
            const num = parseInt(value.replace('+', ''), 10);
            min = num;
            if (!value.includes('+')) {
                max = num;
            }
        }
        onFilterChange({ p_num_bedrooms_min: min, p_num_bedrooms_max: max });
    };

    const selectedBedrooms = filters.p_num_bedrooms_min
        ? filters.p_num_bedrooms_max === filters.p_num_bedrooms_min
            ? String(filters.p_num_bedrooms_min)
            : `${filters.p_num_bedrooms_min}+`
        : undefined;

    const handleRangeChange = (
        keyMin: keyof PropertiesFilterParams,
        keyMax: keyof PropertiesFilterParams,
        type: 'min' | 'max',
        valueStr: string
    ) => {
        const value = valueStr === '' ? undefined : parseInt(valueStr.replace(/,/g, ''), 10);
        if (isNaN(value as number) && value !== undefined) return;

        if (type === 'min') {
            onFilterChange({ [keyMin]: value });
        } else {
            onFilterChange({ [keyMax]: value });
        }
    };

    const isPropertyTypeSelected = (type: PropertyType) => {
        return filters.p_property_types?.includes(type);
    }

    const selectedAreaUnitLabel = filters.p_area_unit ? getDisplayValue(areaUnitMap, filters.p_area_unit, 'unit') : 'unit';

    return (
        <div className={`bg-white ${isMobile ? '' : 'rounded-lg shadow-sm border border-gray-200 p-4'}`}>
            {/* Desktop Header */}
            {!isMobile && (
                <div className="flex justify-between items-center mb-4 pb-3 border-b border-gray-200">
                    <h2 className="text-lg font-bold text-gray-800">Filters</h2>
                    <button
                        className={`${getTertiaryButtonClasses()} text-xs px-2 py-1 hover:bg-[#D9A619]`}
                        onClick={() => onFilterChange(defaultFilters)}
                    >
                        <IconFilterOff size={14} className="mr-1" /> Reset All
                    </button>
                </div>
            )}

            {/* Mobile Header*/}
            {isMobile && (
                <div className="flex justify-end py-3 border-b border-gray-200">
                    <button
                        className={`${getTertiaryButtonClasses()} text-xs px-2 py-1 hover:bg-[#D9A619]`}
                        onClick={() => onFilterChange(defaultFilters)}
                    >
                        <IconFilterOff size={14} className="mr-1" /> Reset All
                    </button>
                </div>
            )}

            {/* Filter Sections */}
            <FilterSection title="Property Type" defaultOpen={true}>
                <SegmentedRadio
                    name="property_type"
                    value={filters.p_property_types?.[0]}
                    onChange={(value) => handleSegmentedChange('p_property_types', value as PropertyType | undefined)}
                    options={[
                        { label: <div className='flex items-center justify-center gap-1'><IconHome2 size={14} /> House</div>, value: 'HOUSE' },
                        { label: <div className='flex items-center justify-center gap-1'><IconMapPin size={14} /> Land</div>, value: 'LAND' },
                        { label: <div className='flex items-center justify-center gap-1'><IconBuildingCommunity size={14} /> Building</div>, value: 'BUILDING' },
                    ]}
                />
            </FilterSection>

            <FilterSection title="Looking For" defaultOpen={true}>
                <SegmentedRadio
                    name="listing_type"
                    value={filters.p_listing_types?.[0]}
                    onChange={(value) => handleSegmentedChange('p_listing_types', value as ListingType | undefined)}
                    options={[
                        { label: 'Buy', value: 'SALE' },
                        { label: 'Rent', value: 'RENTAL' },
                    ]}
                />
            </FilterSection>

            <FilterSection title="Location" defaultOpen={true}>
                <div className="relative">
                    <IconSearch size={16} className="absolute left-2.5 top-1/2 -translate-y-1/2 text-gray-400" />
                    <input
                        id="locality"
                        type="text"
                        placeholder="Search by Locality..."
                        value={filters.p_location_search || ''}
                        onChange={(e) => onFilterChange({ p_location_search: e.target.value || undefined })}
                        className={`${getBaseInputClasses()} pl-8`}
                    />
                </div>
                <div className="mt-3">
                    <div className="relative">
                        <IconMapPin size={16} className="absolute left-2.5 top-1/2 -translate-y-1/2 text-gray-400" />
                        <input
                            id="city"
                            type="text"
                            placeholder="City"
                            value={filters.p_city || ''}
                            onChange={(e) => onFilterChange({ p_city: e.target.value || undefined })}
                            className={`${getBaseInputClasses()} pl-8`}
                        />
                    </div>
                </div>
            </FilterSection >

            <FilterSection title="Budget">
                <div className="grid grid-cols-2 gap-2 items-end">
                    <div>
                        <label htmlFor="price_min" className="block text-xs font-medium text-gray-500 mb-1">Min Price (₹)</label>
                        <input
                            id="price_min"
                            type="number"
                            placeholder="e.g., 10 L"
                            value={filters.p_price_min ?? ''}
                            onChange={(e) => handleRangeChange('p_price_min', 'p_price_max', 'min', e.target.value)}
                            className={getBaseInputClasses()}
                            min="0"
                            step="100000"
                        />
                    </div>
                    <div>
                        <label htmlFor="price_max" className="block text-xs font-medium text-gray-500 mb-1">Max Price (₹)</label>
                        <input
                            id="price_max"
                            type="number"
                            placeholder="e.g., 50 L"
                            value={filters.p_price_max ?? ''}
                            onChange={(e) => handleRangeChange('p_price_min', 'p_price_max', 'max', e.target.value)}
                            className={getBaseInputClasses()}
                            min="0"
                            step="100000"
                        />
                    </div>
                </div>
            </FilterSection>

            {/* Conditional Filters */}
            {
                isPropertyTypeSelected('HOUSE') && (
                    <>
                        <FilterSection title="Type of House">
                            <CheckboxGroup
                                values={filters.p_house_types}
                                onChange={(value, checked) => handleMultiCheckboxChange('p_house_types', value, checked)}
                                options={houseTypeOptions}
                            />
                        </FilterSection>
                        <FilterSection title="No. of Bedrooms">
                            <SegmentedRadio
                                name="bedrooms"
                                value={selectedBedrooms}
                                onChange={(value) => handleBedroomChange(value as string | undefined)}
                                options={bedroomOptions.map(b => ({ label: b.includes('+') ? b : `${b} BHK`, value: b }))}
                            />
                            {selectedBedrooms && (
                                <button
                                    onClick={() => handleBedroomChange(undefined)}
                                    className="mt-2 text-xs text-gray-600 hover:underline"
                                >
                                    Clear Bedrooms
                                </button>
                            )}
                        </FilterSection>
                        <FilterSection title="Furnishing Status">
                            <CheckboxGroup
                                values={filters.p_furnished_statuses}
                                onChange={(value, checked) => handleMultiCheckboxChange('p_furnished_statuses', value, checked)}
                                options={furnishingOptions}
                            />
                        </FilterSection>
                        <FilterSection title="Facing Direction">
                            <CheckboxGroup
                                values={filters.p_facing_directions}
                                onChange={(value, checked) => handleMultiCheckboxChange('p_facing_directions', value as Direction, checked)}
                                options={directionOptions}
                                columns={2}
                            />
                        </FilterSection>
                    </>
                )
            }

            {
                isPropertyTypeSelected('LAND') && (
                    <FilterSection title="Type of Land">
                        <CheckboxGroup
                            values={filters.p_land_types}
                            onChange={(value, checked) => handleMultiCheckboxChange('p_land_types', value, checked)}
                            options={landTypeOptions}
                        />
                    </FilterSection>
                )
            }

            {
                isPropertyTypeSelected('BUILDING') && (
                    <FilterSection title="Type of Building">
                        <CheckboxGroup
                            values={filters.p_building_types}
                            onChange={(value, checked) => handleMultiCheckboxChange('p_building_types', value, checked)}
                            options={buildingTypeOptions}
                        />
                    </FilterSection>
                )
            }

            <FilterSection title="Area">
                <div>
                    <label htmlFor="area_unit" className="block text-xs font-medium text-gray-500 mb-1">Area Unit</label>
                    <select
                        id="area_unit"
                        name="p_area_unit"
                        value={filters.p_area_unit || ''}
                        onChange={(e) => handleSingleSelectChange('p_area_unit', e.target.value || undefined as AreaUnit | undefined)}
                        className={`${getBaseInputClasses()} mb-3`}
                    >
                        <option value="">Any Unit</option>
                        {areaUnitFilterOptions.map(opt => (
                            <option key={opt.value} value={opt.value}>{opt.label}</option>
                        ))}
                    </select>
                </div>
                <div className="grid grid-cols-2 gap-2 items-end">
                    <div>
                        <label htmlFor="area_min" className="block text-xs font-medium text-gray-500 mb-1">Min Area ({selectedAreaUnitLabel})</label>
                        <input
                            id="area_min"
                            type="number"
                            placeholder="e.g., 500"
                            value={filters.p_area_min ?? ''}
                            onChange={(e) => handleRangeChange('p_area_min', 'p_area_max', 'min', e.target.value)}
                            className={getBaseInputClasses()}
                            min="0"
                            step="100"
                        />
                    </div>
                    <div>
                        <label htmlFor="area_max" className="block text-xs font-medium text-gray-500 mb-1">Max Area ({selectedAreaUnitLabel})</label>
                        <input
                            id="area_max"
                            type="number"
                            placeholder="e.g., 2000"
                            value={filters.p_area_max ?? ''}
                            onChange={(e) => handleRangeChange('p_area_min', 'p_area_max', 'max', e.target.value)}
                            className={getBaseInputClasses()}
                            min="0"
                            step="100"
                        />
                    </div>
                </div>
            </FilterSection>
        </div >
    );
}

export default PropertyFilterSidebar;