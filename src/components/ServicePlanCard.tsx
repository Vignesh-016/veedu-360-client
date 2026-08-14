import { ManagementPlan } from '../lib/types';
import { IconUserCheck, IconFileCheck, IconTools, IconHelpCircle } from '@tabler/icons-react';

interface ServicePlanCardProps {
    plan: ManagementPlan;
    highlight?: 'gold' | 'silver';
}

const getPlanIcon = (name: string, index: number) => {
    const lowerName = name.toLowerCase();
    const iconClass = "w-5 h-5 text-[#2C4964] group-hover:text-white transition-colors duration-300";

    if (lowerName.includes('tenant') || lowerName.includes('placement')) {
        return <IconUserCheck className={iconClass} stroke={1.8} />;
    } else if (lowerName.includes('rent') || lowerName.includes('agreement')) {
        return <IconFileCheck className={iconClass} stroke={1.8} />;
    } else if (lowerName.includes('full') || lowerName.includes('stack') || lowerName.includes('complete')) {
        return <IconTools className={iconClass} stroke={1.8} />;
    } else if (lowerName.includes('why') || lowerName.includes('choose')) {
        return <IconHelpCircle className={iconClass} stroke={1.8} />;
    }
    const icons = [
        <IconUserCheck className={iconClass} stroke={1.8} />,
        <IconFileCheck className={iconClass} stroke={1.8} />,
        <IconTools className={iconClass} stroke={1.8} />,
        <IconHelpCircle className={iconClass} stroke={1.8} />
    ];
    return icons[index % icons.length];
};

const parseFeatures = (description: string): string[] => {
    if (!description) return [];
    return description
        .split('\n')
        .flatMap(line => line.split(/\s*\+\s*/))
        .map(f => f.trim())
        .filter(Boolean);
};

function ServicePlanCard({ plan }: ServicePlanCardProps) {
    const rawFeatures = parseFeatures(plan.description || '');

    return (
        <div
            className="relative flex flex-col h-full rounded-2xl border border-white/80 bg-white/50 
              backdrop-blur-xl hover:bg-white/30 hover:backdrop-blur-2xl hover:border-white 
              hover:shadow-[0_20px_45px_rgba(44,73,100,0.14)]
              transition-all duration-500 hover:-translate-y-1.5 group overflow-hidden shadow-[0_10px_30px_rgba(0,0,0,0.04)]"
            style={{ fontFamily: "'Outfit', 'Inter', sans-serif" }}
        >
            {/* Header Section with glass styling */}
            <div className="p-6 pb-4 border-b border-gray-100/60 bg-white/40 backdrop-blur-md group-hover:bg-white/20 transition-all duration-300">
                <div className="flex items-center gap-3.5">
                    <div className="w-11 h-11 rounded-xl flex items-center justify-center flex-shrink-0 bg-slate-100/80 group-hover:bg-[#2C4964] transition-all duration-300 shadow-sm group-hover:shadow-md">
                        {getPlanIcon(plan.name, 0)}
                    </div>
                    <div className="flex-1">
                        <h3 className="text-lg md:text-xl font-semibold leading-snug tracking-tight text-gray-800 group-hover:text-[#2C4964] transition-colors">
                            {plan.name}
                        </h3>
                    </div>
                </div>
            </div>

            {/* Content Section */}
            <div className="flex-grow p-6 space-y-4.5">
                {rawFeatures.map((feature, idx) => {
                    const colonIndex = feature.indexOf(':');
                    let titlePart = '';
                    let bodyPart = feature;

                    if (colonIndex !== -1) {
                        titlePart = feature.substring(0, colonIndex).trim();
                        bodyPart = feature.substring(colonIndex + 1).trim();
                    }

                    const isCostLine = titlePart.toLowerCase().includes('cost');

                    if (isCostLine) {
                        return (
                            <div 
                                key={idx} 
                                className="p-3.5 rounded-xl border border-[#2C4964]/10 bg-[#2C4964]/5 backdrop-blur-sm group-hover:bg-white/60 group-hover:border-[#2C4964]/20 transition-all duration-300 mt-auto"
                            >
                                <p className="text-[14px] md:text-[15px] leading-relaxed flex flex-wrap items-center gap-1.5">
                                    <span className="font-semibold text-xs tracking-wider uppercase text-[#2C4964]">
                                        {titlePart}:
                                    </span>
                                    <span className="text-[#2C4964] font-medium group-hover:text-gray-900 transition-colors">
                                        {bodyPart}
                                    </span>
                                </p>
                            </div>
                        );
                    }

                    return (
                        <div key={idx} className="flex items-start gap-3">
                            <div className="mt-2 w-1.5 h-1.5 rounded-full flex-shrink-0 bg-[#2C4964]/40 group-hover:bg-[#2C4964] transition-all duration-300" />
                            <div className="flex-1">
                                {titlePart ? (
                                    <p className="text-[14px] md:text-[15px] leading-relaxed">
                                        <span className="font-semibold text-gray-800 tracking-tight block mb-0.5 group-hover:text-[#2C4964] transition-colors">
                                            {titlePart}
                                        </span>
                                        <span className="font-normal text-gray-600 group-hover:text-gray-700 transition-colors">
                                            {bodyPart}
                                        </span>
                                    </p>
                                ) : (
                                    <p className="text-[14px] md:text-[15px] font-normal leading-relaxed text-gray-600 group-hover:text-gray-700 transition-colors">{bodyPart}</p>
                                )}
                            </div>
                        </div>
                    );
                })}
            </div>

            {/* CTA Button Section */}
            <div className="p-6 pt-0 mt-auto">
                <button
                    className="w-full py-3 rounded-xl text-xs font-semibold tracking-wider uppercase bg-[#2C4964] text-white hover:bg-[#1e3347] shadow-sm hover:shadow-md transition-all duration-300 active:scale-[0.99]"
                >
                    Learn More & Select
                </button>
            </div>
        </div>
    );
}

export default ServicePlanCard;



