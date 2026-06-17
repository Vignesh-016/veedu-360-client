import { ManagementPlan } from '../lib/types';
import { IconCheck, IconCrown, IconStarFilled } from '@tabler/icons-react';

interface ServicePlanCardProps {
    plan: ManagementPlan;
    highlight?: 'gold' | 'silver';
}

const parseFeatures = (description: string): string[] =>
    description
        ?.replace(/\s*\+\s*/g, ',')
        .split(',')
        .map(f => f.trim())
        .filter(Boolean) || [];

function ServicePlanCard({ plan, highlight }: ServicePlanCardProps) {
    const features = parseFeatures(plan.description || '');

    const isGold = highlight === 'gold';
    const isSilver = highlight === 'silver';

    // Dynamic styles based on highlight
    const cardStyles = isGold
        ? 'bg-gradient-to-br from-amber-50 via-orange-50 to-yellow-50 border-amber-300 shadow-amber-100'
        : isSilver
            ? 'bg-gradient-to-br from-slate-50 via-[#2C4964]/5 to-slate-50 border-slate-200 shadow-slate-100'
            : 'bg-white border-gray-200';

    const accentColor = isGold
        ? 'text-amber-600'
        : 'text-[#2C4964]';

    const buttonStyles = isGold
        ? 'bg-gradient-to-r from-amber-500 via-orange-500 to-amber-500 hover:from-amber-600 hover:via-orange-600 hover:to-amber-600 shadow-lg shadow-amber-200'
        : 'bg-[#2C4964] hover:bg-[#1E3347] shadow-lg shadow-slate-200';

    const checkBg = isGold
        ? 'bg-amber-500'
        : 'bg-[#2C4964]';

    return (
        <div
            className={`relative flex flex-col h-full rounded-xl border-2 ${cardStyles} 
      transition-all duration-500 hover:-translate-y-2 hover:shadow-xl group overflow-hidden`}
        >
            {/* Background Decoration */}
            <div className="absolute top-0 right-0 w-24 h-24 opacity-10">
                <div className={`w-full h-full rounded-full blur-2xl ${isGold ? 'bg-amber-400' : 'bg-slate-400'}`} />
            </div>

            {/* Popular Badge */}
            {isGold && (
                <div className="absolute top-0 right-0">
                    <div className="bg-orange-500 text-white text-[10px] font-bold px-3 py-1 rounded-bl-xl shadow-sm flex items-center gap-1">
                        <IconCrown size={12} className="fill-current" />
                        MOST POPULAR
                    </div>
                </div>
            )}

            {/* Recommended Badge */}
            {isSilver && (
                <div className="absolute top-0 right-0">
                    <div className="bg-[#2C4964] text-white text-[10px] font-bold px-3 py-1 rounded-bl-xl shadow-sm flex items-center gap-1">
                        <IconStarFilled size={10} />
                        RECOMMENDED
                    </div>
                </div>
            )}

            {/* Header */}
            <div className="p-4 pb-2">
                <h3 className="text-lg font-bold text-gray-900 mb-0.5">
                    {plan.name}
                </h3>
                <p className="text-xs text-gray-500">Property Management Service</p>
            </div>

            {/* Pricing Section */}
            <div className="px-4 py-2">
                <div className="flex items-end gap-1">
                    <span className={`text-4xl font-extrabold ${accentColor}`}>
                        {plan.percentage}%
                    </span>
                    <span className="text-gray-500 text-xs font-medium mb-1.5">
                        fee
                    </span>
                </div>
                <p className="text-gray-400 text-[10px] mt-0.5">of monthly rent collected</p>
            </div>

            {/* Divider */}
            <div className="px-4 my-1">
                <div className={`h-px ${isGold ? 'bg-amber-200' : 'bg-gray-200'}`} />
            </div>

            {/* Features */}
            <div className="p-4 flex-grow">
                <p className="text-[10px] font-bold uppercase tracking-wider text-gray-400 mb-2">
                    What's Included
                </p>
                <ul className="space-y-1.5">
                    {features.map((feature, index) => (
                        <li key={index} className="flex items-start gap-2 group/item">
                            <div
                                className={`mt-0.5 h-4 w-4 rounded-full ${checkBg} flex items-center justify-center flex-shrink-0 
                transition-transform group-hover/item:scale-110`}
                            >
                                <IconCheck size={10} className="text-white" strokeWidth={3} />
                            </div>
                            <span className="text-xs text-gray-600 leading-tight">
                                {feature}
                            </span>
                        </li>
                    ))}
                </ul>
            </div>

            {/* CTA Button */}
            <div className="p-4 pt-0 pb-4">
                <button
                    className={`w-full py-2.5 rounded-lg text-xs font-bold text-white ${buttonStyles}
          transition-all duration-300 transform hover:scale-[1.02] active:scale-[0.98]`}
                >
                    Get Started
                </button>
                <p className="text-center text-[10px] text-gray-400 mt-2">
                    No hidden charges • Cancel anytime
                </p>
            </div>
        </div>
    );
}

export default ServicePlanCard;
