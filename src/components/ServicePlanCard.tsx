import { ManagementPlan } from '../lib/types';
import { IconUserCheck, IconFileCheck, IconTools, IconHelpCircle, IconTag } from '@tabler/icons-react';

const REGULAR_MANAGEMENT_PLAN_PRICE = 1000;
const formatRupees = (amount: number) => `₹${amount.toLocaleString('en-IN', { maximumFractionDigits: 2 })}`;

interface ServicePlanCardProps {
    plan: ManagementPlan;
    highlight?: 'gold' | 'silver';
    showIcon?: boolean;
    selected?: boolean;
    disabled?: boolean;
    className?: string;
    onSelect?: () => void;
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

const getPlanContent = (description: string | null) => {
    const lines = (description || '').split('\n');
    const buttonLine = lines.find(line => /^button\s*:/i.test(line.trim()));
    const subtitleLine = lines.find(line => /^subtitle\s*:/i.test(line.trim()));
    return {
        subtitle: subtitleLine?.replace(/^subtitle\s*:/i, '').trim() || '',
        features: parseFeatures(lines.filter(line => !/^button\s*:/i.test(line.trim()) && !/^subtitle\s*:/i.test(line.trim())).join('\n')),
        buttonText: buttonLine?.replace(/^button\s*:/i, '').trim() || 'Learn More & Select'
    };
};

function ServicePlanCard({ plan, showIcon = true, selected = false, disabled = false, className = '', onSelect }: ServicePlanCardProps) {
    const { subtitle, features: rawFeatures, buttonText } = getPlanContent(plan.description);
    const postPrice = Number(plan.post_price) || 0;
    const hasSpecialOffer = plan.document_processing_fee_enabled
        && postPrice > 0
        && postPrice < REGULAR_MANAGEMENT_PLAN_PRICE;

    return (
        <div
            onClick={!disabled ? onSelect : undefined}
            className={`relative flex flex-col h-full min-h-[500px] rounded-2xl border transition-all duration-500 hover:-translate-y-1.5 group overflow-hidden
                            ${selected
                                ? 'border-[#2C4964] bg-[#2C4964] text-white ring-2 ring-[#2C4964]/30 ring-offset-2 shadow-[0_16px_35px_rgba(44,73,100,0.25)]'
                                : 'border-slate-200 bg-white backdrop-blur-xl hover:bg-white/30 hover:backdrop-blur-2xl hover:border-white hover:shadow-[0_20px_45px_rgba(44,73,100,0.14)] shadow-[0_10px_30px_rgba(0,0,0,0.04)]'
                            } ${disabled ? 'opacity-70' : 'cursor-pointer'} ${className}`}
            style={{ fontFamily: "'Outfit', 'Inter', sans-serif" }}
        >
            {/* Header Section with glass styling */}
            <div className={`relative p-6 pb-4 border-b transition-all duration-300 ${selected ? 'border-white/20 bg-white/10' : 'border-slate-100 bg-slate-50/70'}`}>
                <div className={`flex items-center ${showIcon ? 'gap-3.5' : ''}`}>
                    {showIcon && <div className={`w-11 h-11 rounded-xl flex items-center justify-center flex-shrink-0 transition-all duration-300 shadow-sm group-hover:shadow-md ${selected ? 'bg-white/20' : 'bg-slate-100/80 group-hover:bg-[#2C4964]'}`}>
                        {getPlanIcon(plan.name, 0)}
                    </div>}
                    <div className="flex-1">
                        <h3 className={`text-lg md:text-xl font-semibold leading-snug tracking-tight transition-colors ${selected ? 'text-white' : 'text-gray-800 group-hover:text-[#2C4964]'}`}>
                            {plan.name}
                        </h3>
                        {subtitle && <p className={`mt-1 text-sm leading-relaxed ${selected ? 'text-white/80' : 'text-gray-600'}`}>{subtitle}</p>}
                        {plan.document_processing_fee_enabled && postPrice > 0 && (
                            <span className="hidden" aria-hidden="true">
                                <IconFileCheck size={13} /> Document charges apply · ₹{Number(plan.post_price).toFixed(2)}
                            </span>
                        )}
                        {plan.document_processing_fee_enabled && postPrice > 0 && (
                            <div className="mt-3 flex flex-wrap items-center gap-2">
                                <span className={`inline-flex items-center gap-1.5 rounded-full border px-2.5 py-1 text-[11px] font-bold ${selected ? 'border-white/30 bg-white/15 text-white' : 'border-[#2C4964]/20 bg-white text-[#2C4964]'}`}>
                                    <IconFileCheck size={13} /> Platform fees · {formatRupees(postPrice)}
                                </span>
                                {hasSpecialOffer && (
                                    <span className={`inline-flex items-center gap-1.5 text-[11px] font-bold ${selected ? 'text-white' : 'text-[#2C4964]'}`}>
                                        <IconTag size={13} /> Offer price <span>{formatRupees(postPrice)}</span><span className={`font-medium line-through ${selected ? 'text-white/50' : 'text-slate-400'}`}>{formatRupees(REGULAR_MANAGEMENT_PLAN_PRICE)}</span>
                                    </span>
                                )}
                            </div>
                        )}
                    </div>
                </div>
            </div>

            {/* Content Section */}
            <div className="flex flex-1 flex-col p-6 space-y-4 overflow-hidden">
                {rawFeatures.map((feature, idx) => {
                    const colonIndex = feature.indexOf(':');
                    let titlePart = '';
                    let bodyPart = feature;

                    if (colonIndex !== -1) {
                        titlePart = feature.substring(0, colonIndex).trim();
                        bodyPart = feature.substring(colonIndex + 1).trim();
                    }

                    const isCostLine = titlePart.toLowerCase().includes('cost');

                    if (titlePart && !bodyPart) {
                        return (
                            <div key={idx} className="pt-1">
                                <p className={`text-[14px] md:text-[15px] font-semibold leading-relaxed tracking-tight transition-colors ${selected ? 'text-white' : 'text-gray-800 group-hover:text-[#2C4964]'}`}>
                                    {titlePart}
                                </p>
                            </div>
                        );
                    }

                    if (isCostLine) {
                        return (
                            <div 
                                key={idx} 
                                className={`p-3.5 rounded-xl border backdrop-blur-sm transition-all duration-300 mt-auto ${selected ? 'border-white/20 bg-white/10' : 'border-[#2C4964]/10 bg-[#2C4964]/5 group-hover:bg-white/60 group-hover:border-[#2C4964]/20'}`}
                            >
                                <p className="text-[14px] md:text-[15px] leading-relaxed flex flex-wrap items-center gap-1.5">
                                    <span className={`font-semibold text-xs tracking-wider uppercase ${selected ? 'text-white' : 'text-[#2C4964]'}`}>
                                        {titlePart}:
                                    </span>
                                    <span className={`font-medium transition-colors ${selected ? 'text-white/90' : 'text-[#2C4964] group-hover:text-gray-900'}`}>
                                        {bodyPart}
                                    </span>
                                </p>
                            </div>
                        );
                    }

                    return (
                        <div key={idx} className="flex items-start gap-3">
                            <div className={`mt-2 w-1.5 h-1.5 rounded-full flex-shrink-0 transition-all duration-300 ${selected ? 'bg-white/60' : 'bg-[#2C4964]/40 group-hover:bg-[#2C4964]'}`} />
                            <div className="flex-1">
                                {titlePart ? (
                                    <p className="text-[14px] md:text-[15px] leading-relaxed">
                                        <span className={`font-semibold tracking-tight block mb-0.5 transition-colors ${selected ? 'text-white' : 'text-gray-800 group-hover:text-[#2C4964]'}`}>
                                            {titlePart}
                                        </span>
                                        <span className={`font-normal transition-colors ${selected ? 'text-white/80' : 'text-gray-600 group-hover:text-gray-700'}`}>
                                            {bodyPart}
                                        </span>
                                    </p>
                                ) : (
                                    <p className={`text-[14px] md:text-[15px] font-normal leading-relaxed transition-colors ${selected ? 'text-white/80' : 'text-gray-600 group-hover:text-gray-700'}`}>{bodyPart}</p>
                                )}
                            </div>
                        </div>
                    );
                })}
            </div>

            {/* CTA Button Section */}
            <div className="p-6 pt-0 mt-auto">
                <button
                    type="button"
                    onClick={(e) => {
                        e.stopPropagation();
                        onSelect?.();
                    }}
                    disabled={disabled}
                    className={`w-full rounded-xl py-3 text-xs font-semibold tracking-wider uppercase shadow-sm transition-all duration-300 active:scale-[0.99] ${selected ? 'bg-white text-[#2C4964] ring-2 ring-white/20 hover:bg-white/90' : 'bg-[#2C4964] text-white hover:bg-[#1e3347] hover:shadow-md'}`}
                >
                    {buttonText}
                </button>
            </div>
        </div>
    );
}

export default ServicePlanCard;
