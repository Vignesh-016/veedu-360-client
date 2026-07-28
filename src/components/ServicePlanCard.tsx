import { ManagementPlan } from '../lib/types';
import { IconUserCheck, IconFileCheck, IconTools, IconHelpCircle } from '@tabler/icons-react';

interface ServicePlanCardProps {
    plan: ManagementPlan;
    highlight?: 'gold' | 'silver';
}

const getPlanIcon = (name: string, index: number) => {
    const lowerName = name.toLowerCase();
    if (lowerName.includes('tenant') || lowerName.includes('placement')) {
        return <IconUserCheck className="w-6 h-6 text-[#2C4964] group-hover:text-white transition-colors duration-300" stroke={2} />;
    } else if (lowerName.includes('rent') || lowerName.includes('agreement')) {
        return <IconFileCheck className="w-6 h-6 text-[#2C4964] group-hover:text-white transition-colors duration-300" stroke={2} />;
    } else if (lowerName.includes('full') || lowerName.includes('stack') || lowerName.includes('complete')) {
        return <IconTools className="w-6 h-6 text-[#2C4964] group-hover:text-white transition-colors duration-300" stroke={2} />;
    } else if (lowerName.includes('why') || lowerName.includes('choose')) {
        return <IconHelpCircle className="w-6 h-6 text-[#2C4964] group-hover:text-white transition-colors duration-300" stroke={2} />;
    }
    const icons = [
        <IconUserCheck className="w-6 h-6 text-[#2C4964] group-hover:text-white transition-colors duration-300" stroke={2} />,
        <IconFileCheck className="w-6 h-6 text-[#2C4964] group-hover:text-white transition-colors duration-300" stroke={2} />,
        <IconTools className="w-6 h-6 text-[#2C4964] group-hover:text-white transition-colors duration-300" stroke={2} />,
        <IconHelpCircle className="w-6 h-6 text-[#2C4964] group-hover:text-white transition-colors duration-300" stroke={2} />
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
            className="relative flex flex-col h-full rounded-2xl border-2 border-gray-200 bg-white 
      hover:bg-gradient-to-b hover:from-blue-50/60 hover:via-white hover:to-blue-50/40 hover:border-[#2C4964]/40
      transition-all duration-300 hover:-translate-y-2 hover:shadow-2xl group overflow-hidden p-7"
        >
            {/* Header Title with Icon & Title */}
            <div className="flex items-center gap-3.5 mb-6 border-b border-gray-100 pb-4">
                <div className="w-13 h-13 p-3 rounded-2xl bg-gray-100 group-hover:bg-[#2C4964] flex items-center justify-center shadow-sm flex-shrink-0 transition-colors duration-300">
                    {getPlanIcon(plan.name, 0)}
                </div>
                <div>
                    <h3 className="text-xl md:text-2xl font-extrabold text-[#2C4964] group-hover:text-[#1E3347] transition-colors leading-snug">
                        {plan.name}
                    </h3>
                </div>
            </div>

            {/* Bullet Points with Subheadings & Descriptions */}
            <div className="flex-grow space-y-4 mb-7">
                {rawFeatures.map((feature, idx) => {
                    const colonIndex = feature.indexOf(':');
                    let titlePart = '';
                    let bodyPart = feature;

                    if (colonIndex !== -1) {
                        titlePart = feature.substring(0, colonIndex).trim();
                        bodyPart = feature.substring(colonIndex + 1).trim();
                    }

                    const isCostLine = titlePart.toLowerCase().includes('cost');

                    return (
                        <div key={idx} className={`${isCostLine ? 'bg-amber-50/80 p-3.5 rounded-xl border border-amber-200/70 font-semibold' : ''}`}>
                            {titlePart ? (
                                <p className="text-sm md:text-base leading-relaxed text-gray-800">
                                    <span className={`font-bold italic ${isCostLine ? 'text-amber-900 text-base' : 'text-[#2C4964]'} mr-1.5`}>
                                        {titlePart}:
                                    </span>
                                    <span className="text-gray-700 font-medium">{bodyPart}</span>
                                </p>
                            ) : (
                                <div className="flex items-start gap-2.5">
                                    <div className="mt-2 w-2 h-2 rounded-full bg-[#2C4964] flex-shrink-0 group-hover:bg-blue-600 transition-colors" />
                                    <p className="text-sm md:text-base text-gray-700 font-medium leading-relaxed">{bodyPart}</p>
                                </div>
                            )}
                        </div>
                    );
                })}
            </div>

            {/* CTA Button */}
            <div className="mt-auto pt-2">
                <button
                    className="w-full py-3.5 rounded-xl text-sm font-extrabold text-white bg-[#2C4964] hover:bg-[#1E3347]
          transition-all duration-300 transform hover:scale-[1.01] active:scale-[0.99] shadow-md uppercase tracking-wider"
                >
                    Learn More & Select
                </button>
            </div>
        </div>
    );
}

export default ServicePlanCard;



