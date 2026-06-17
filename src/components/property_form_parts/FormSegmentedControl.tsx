import React from 'react';

interface FormSegmentedControlProps {
    name: string;
    value: string | undefined | null;
    onChange: (value: string) => void;
    options: { label: React.ReactNode; value: string }[];
    disabled?: boolean;
    className?: string;
}

const FormSegmentedControl: React.FC<FormSegmentedControlProps> = ({
    name,
    value,
    onChange,
    options,
    disabled = false,
    className = "",
}) => {
    return (
        <div className={`flex w-full bg-slate-50 border border-gray-100 rounded-xl p-1 text-sm ${disabled ? 'opacity-70' : ''} ${className}`}>
            {options.map((option) => (
                <label
                    key={option.value}
                    className={`
                        flex-1 px-4 py-2 text-center transition-all duration-200 rounded-lg font-medium
                        ${disabled ? 'cursor-not-allowed' : 'cursor-pointer'}
                        ${value === option.value
                            ? (disabled ? 'bg-gray-400 text-white' : 'bg-gradient-to-r from-indigo-600 to-purple-600 text-white shadow-sm ring-1 ring-white/10')
                            : (disabled ? 'text-gray-400' : 'text-slate-600 hover:bg-slate-100 hover:text-slate-900')}
                    `}
                >
                    <input
                        type="radio"
                        name={name}
                        value={option.value}
                        checked={value === option.value}
                        onChange={() => !disabled && onChange(option.value)}
                        className="sr-only"
                        disabled={disabled}
                    />
                    {option.label}
                </label>
            ))}
        </div>
    );
};

export default FormSegmentedControl;