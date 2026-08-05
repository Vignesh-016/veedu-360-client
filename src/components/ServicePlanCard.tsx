import { ManagementPlan } from '../lib/types';
import { IconUserCheck, IconFileCheck, IconTools, IconHelpCircle } from '@tabler/icons-react';

interface ServicePlanCardProps {
    plan: ManagementPlan;
    highlight?: 'gold' | 'silver';
}

const getPlanIcon = (name: string, index: number) => {
    const lowerName = name.toLowerCase();
    const iconClass = "w-6 h-6 text-[#2C4964] group-hover:text-white transition-colors duration-300";

    if (lowerName.includes('tenant') || lowerName.includes('placement')) {
        return <IconUserCheck className={iconClass} stroke={2} />;
    } else if (lowerName.includes('rent') || lowerName.includes('agreement')) {
        return <IconFileCheck className={iconClass} stroke={2} />;
    } else if (lowerName.includes('full') || lowerName.includes('stack') || lowerName.includes('complete')) {
        return <IconTools className={iconClass} stroke={2} />;
    } else if (lowerName.includes('why') || lowerName.includes('choose')) {
        return <IconHelpCircle className={iconClass} stroke={2} />;
    }
    const icons = [
        <IconUserCheck className={iconClass} stroke={2} />,
        <IconFileCheck className={iconClass} stroke={2} />,
        <IconTools className={iconClass} stroke={2} />,
        <IconHelpCircle className={iconClass} stroke={2} />
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
            className="relative flex flex-col h-full rounded-2xl border border-gray-100 bg-white 
              hover:border-transparent hover:bg-gradient-to-b hover:from-[#2C4964] hover:to-[#1e3347] hover:text-white
              transition-all duration-300 hover:-translate-y-2 hover:shadow-2xl group overflow-hidden"
            style={{ fontFamily: "'Outfit', 'Inter', sans-serif" }}
        >
            {/* Header Section with subtle gradient */}
            <div className="p-6 pb-4 border-b bg-gradient-to-br from-slate-50/50 to-white border-gray-50 group-hover:from-transparent group-hover:to-transparent group-hover:border-white/10 transition-all duration-300">
                <div className="flex items-center gap-4 mb-4">
                    <div className="w-12 h-12 rounded-xl flex items-center justify-center shadow-sm flex-shrink-0 bg-slate-50 group-hover:bg-white/10 transition-colors duration-300">
                        {getPlanIcon(plan.name, 0)}
                    </div>
                    <div className="flex-1">
                        <h3 className="text-xl md:text-2xl font-bold leading-snug text-gray-900 group-hover:text-white transition-colors">
                            {plan.name}
                        </h3>
                    </div>
                </div>
            </div>

            {/* Content Section */}
            <div className="flex-grow p-6 space-y-5">
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
                                className="p-4 rounded-xl border mt-auto bg-[#2C4964]/5 border-[#2C4964]/10 group-hover:bg-white/10 group-hover:border-white/20 transition-all duration-300"
                            >
                                <p className="text-[15px] md:text-[16px] leading-relaxed flex flex-wrap items-center gap-1.5">
                                    <span className="font-bold text-sm tracking-wide uppercase text-[#2C4964] group-hover:text-amber-300 transition-colors">
                                        {titlePart}:
                                    </span>
                                    <span className="text-[#2C4964] font-semibold group-hover:text-white transition-colors">
                                        {bodyPart}
                                    </span>
                                </p>
                            </div>
                        );
                    }

                    return (
                        <div key={idx} className="flex items-start gap-3">
                            <div className="mt-2 w-2 h-2 rounded-full flex-shrink-0 bg-[#2C4964] opacity-75 group-hover:bg-amber-400 group-hover:scale-125 transition-all duration-300" />
                            <div className="flex-1">
                                {titlePart ? (
                                    <p className="text-[15px] md:text-[16px] leading-relaxed">
                                        <span className="font-bold block mb-0.5 text-gray-900 group-hover:text-white transition-colors">
                                            {titlePart}
                                        </span>
                                        <span className="font-normal text-gray-700 group-hover:text-slate-200 transition-colors">
                                            {bodyPart}
                                        </span>
                                    </p>
                                ) : (
                                    <p className="text-[15px] md:text-[16px] font-normal leading-relaxed text-gray-700 group-hover:text-slate-200 transition-colors">{bodyPart}</p>
                                )}
                            </div>
                        </div>
                    );
                })}
            </div>

            {/* CTA Button Section */}
            <div className="p-6 pt-0 mt-auto">
                <button
                    className="w-full py-3.5 rounded-xl text-[15px] font-bold transition-all duration-300 shadow-md hover:shadow-lg uppercase tracking-wider bg-[#2C4964] group-hover:bg-amber-400 text-white group-hover:text-gray-900"
                >
                    Learn More & Select
                </button>
            </div>
        </div>
    );
}

export default ServicePlanCard;



