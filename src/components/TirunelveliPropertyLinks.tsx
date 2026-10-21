import { Link } from 'react-router-dom';
import {
  IconBuildingCommunity,
  IconHome2,
  IconTrees,
  IconBuildingStore,
  IconMapPin,
  IconArrowRight,
} from '@tabler/icons-react';

export interface PropertyCategoryInfo {
  id: string;
  title: string;
  url: string;
  path: string;
  prefix: string;
  anchorText: string;
  suffix: string;
  icon: typeof IconHome2;
  badge: string;
}

export const TIRUNELVELI_PROPERTY_CATEGORIES: PropertyCategoryInfo[] = [
  {
    id: 'apartments',
    title: 'Apartments for Sale',
    url: 'https://www.veedu360.com/apartments-for-sale-in-tirunelveli',
    path: '/apartments-for-sale-in-tirunelveli',
    prefix: 'Find ',
    anchorText: 'apartments for sale in Tirunelveli',
    suffix: ' on Veedu360. Explore residential apartments in prime locations, compare properties and find your ideal home.',
    icon: IconBuildingCommunity,
    badge: 'Flats & Apartments',
  },
  {
    id: 'houses',
    title: 'Houses for Sale',
    url: 'https://www.veedu360.com/houses-for-sale-in-tirunelveli',
    path: '/houses-for-sale-in-tirunelveli',
    prefix: 'Find ',
    anchorText: 'houses for sale in Tirunelveli',
    suffix: ' with VEEDU 360. Explore verified property listings, suitable locations, prices and details to find your ideal home.',
    icon: IconHome2,
    badge: 'Independent Houses',
  },
  {
    id: 'villas',
    title: 'Villas for Sale',
    url: 'https://www.veedu360.com/villas-for-sale-in-tirunelveli',
    path: '/villas-for-sale-in-tirunelveli',
    prefix: 'Explore ',
    anchorText: 'villas for sale in Tirunelveli',
    suffix: ' on VEEDU 360. Find verified villa properties in prime locations, compare options, and discover your dream home today.',
    icon: IconTrees,
    badge: 'Luxury & Gated Villas',
  },
  {
    id: 'commercial',
    title: 'Commercial Properties for Sale',
    url: 'https://www.veedu360.com/commercial-properties-for-sale-in-tirunelveli',
    path: '/commercial-properties-for-sale-in-tirunelveli',
    prefix: 'Find ',
    anchorText: 'commercial properties for sale in Tirunelveli',
    suffix: ' with VEEDU 360. Explore shops, offices, commercial buildings, land and investment properties in prime locations.',
    icon: IconBuildingStore,
    badge: 'Shops, Offices & Buildings',
  },
  {
    id: 'plots',
    title: 'Plots for Sale',
    url: 'https://www.veedu360.com/plots-for-sale-in-tirunelveli',
    path: '/plots-for-sale-in-tirunelveli',
    prefix: 'Find ',
    anchorText: 'plots for sale in Tirunelveli',
    suffix: ' with VEEDU 360. Explore residential land and property options in prime locations, with details to help you find the right plot.',
    icon: IconMapPin,
    badge: 'Residential Land',
  },
];

interface Props {
  currentPath?: string;
  title?: string;
  subtitle?: string;
  className?: string;
}

export default function TirunelveliPropertyLinks({
  currentPath,
  title = 'Explore Properties for Sale in Tirunelveli',
  subtitle = 'Discover verified residential and commercial properties across prime locations in Tirunelveli.',
  className = '',
}: Props) {
  return (
    <section className={`py-14 bg-slate-50 border-t border-slate-200/80 ${className}`}>
      <div className="max-w-7xl mx-auto px-4 sm:px-6">
        <div className="text-center max-w-3xl mx-auto mb-10">
          <span className="text-xs font-bold uppercase tracking-widest text-[#D9A619]">
            Tirunelveli Real Estate
          </span>
          <h2 className="mt-2 text-2xl sm:text-3xl font-bold text-[#2C4964]">
            {title}
          </h2>
          <p className="mt-3 text-sm sm:text-base text-gray-600">
            {subtitle}
          </p>
        </div>

        <div className="grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
          {TIRUNELVELI_PROPERTY_CATEGORIES.map((category) => {
            const isCurrent = currentPath === category.path;
            const Icon = category.icon;

            return (
              <div
                key={category.id}
                className={`relative flex flex-col justify-between rounded-2xl border p-6 transition-all duration-200 ${
                  isCurrent
                    ? 'border-[#D9A619] bg-white ring-2 ring-[#D9A619]/20 shadow-md'
                    : 'border-gray-200 bg-white hover:border-[#2C4964]/40 hover:shadow-lg hover:-translate-y-0.5'
                }`}
              >
                <div>
                  <div className="flex items-center justify-between mb-4">
                    <div className="flex h-11 w-11 items-center justify-center rounded-xl bg-[#2C4964] text-white">
                      <Icon size={22} />
                    </div>
                    {isCurrent ? (
                      <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-semibold bg-[#D9A619]/15 text-[#9E7200]">
                        Current Page
                      </span>
                    ) : (
                      <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-slate-100 text-slate-600">
                        {category.badge}
                      </span>
                    )}
                  </div>

                  <h3 className="text-lg font-bold text-gray-900 mb-2">
                    {category.title}
                  </h3>

                  <p className="text-sm leading-6 text-gray-600">
                    {category.prefix}
                    <Link
                      to={category.path}
                      title={category.anchorText}
                      className="font-semibold text-[#2C4964] underline decoration-[#D9A619] decoration-2 underline-offset-2 hover:text-[#D9A619] transition-colors"
                    >
                      {category.anchorText}
                    </Link>
                    {category.suffix}
                  </p>
                </div>

                <div className="mt-5 pt-4 border-t border-gray-100">
                  <Link
                    to={category.path}
                    className="inline-flex items-center gap-1.5 text-sm font-bold text-[#2C4964] hover:text-[#D9A619] transition-colors"
                  >
                    View Listings <IconArrowRight size={16} />
                  </Link>
                </div>
              </div>
            );
          })}
        </div>
      </div>
    </section>
  );
}
