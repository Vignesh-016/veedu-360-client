import React from 'react';

interface FormFieldWrapperProps {
    label: string;
    htmlFor?: string;
    required?: boolean;
    errorMessage?: string;
    children: React.ReactNode;
    className?: string;
    labelClassName?: string;
    disabled?: boolean;
}

const FormFieldWrapper: React.FC<FormFieldWrapperProps> = ({
    label,
    htmlFor,
    required,
    errorMessage,
    children,
    className = "mb-4",
    labelClassName = "",
    disabled = false,
}) => {
    return (
        <div className={className}>
            <label
                htmlFor={htmlFor || label.toLowerCase().replace(/\s+/g, '-')}
                className={`block text-sm font-medium mb-1 ${disabled ? 'text-gray-400' : 'text-gray-700'} ${labelClassName}`}
            >
                {label} {required && <span className="text-red-500">*</span>}
            </label>
            {children}
            {errorMessage && <p className="mt-1 text-xs text-red-600">{errorMessage}</p>}
        </div>
    );
};

export default FormFieldWrapper;