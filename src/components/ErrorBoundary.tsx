import { Component, ErrorInfo, ReactNode } from 'react';
import { IconAlertTriangle, IconRefresh } from '@tabler/icons-react';
import { getPrimaryButtonClasses, getTertiaryButtonClasses } from '../lib/twUtils';

interface ErrorBoundaryProps {
    children: ReactNode;
    fallback?: ReactNode;
    onReset?: () => void;
}

interface ErrorBoundaryState {
    hasError: boolean;
    error: Error | null;
    errorInfo: ErrorInfo | null;
}

class ErrorBoundary extends Component<ErrorBoundaryProps, ErrorBoundaryState> {
    constructor(props: ErrorBoundaryProps) {
        super(props);
        this.state = {
            hasError: false,
            error: null,
            errorInfo: null
        };
    }

    static getDerivedStateFromError(error: Error): Partial<ErrorBoundaryState> {
        return { hasError: true, error };
    }

    componentDidCatch(error: Error, errorInfo: ErrorInfo): void {
        console.error('ErrorBoundary caught an error', error, errorInfo);
        this.setState({ errorInfo });
    }

    handleReset = (): void => {
        this.setState({
            hasError: false,
            error: null,
            errorInfo: null
        });

        // Call the onReset prop if provided
        if (this.props.onReset) {
            this.props.onReset();
        }
    }

    render(): ReactNode {
        if (this.state.hasError) {
            if (this.props.fallback) {
                return this.props.fallback;
            }

            return (
                <div className="container mx-auto p-4 md:p-8">
                    <div className="bg-white rounded-lg shadow-md p-6 md:p-8 border border-gray-200">
                        <div className="flex flex-col items-center space-y-6">
                            {/* Alert Box */}
                            <div className="bg-gray-100 border border-gray-300 text-gray-700 px-4 py-3 rounded-md flex items-center w-full max-w-2xl">
                                <IconAlertTriangle size={24} className="mr-3 text-gray-600" />
                                <div className='flex flex-col'>
                                    <span className="font-bold text-gray-800">Something went wrong</span>
                                    <span className='text-sm text-gray-600'>
                                        The application encountered an unexpected error. Please try reloading the page.
                                    </span>
                                </div>
                            </div>

                            {/* Error Details */}
                            <div className="space-y-4 w-full max-w-2xl">
                                <h3 className="text-2xl font-semibold text-gray-700 text-center">Error Details</h3>
                                <p className="text-sm text-gray-600 text-center">
                                    The following error occurred:
                                </p>
                                <div className="bg-gray-50 border border-gray-200 rounded-md p-4 overflow-auto">
                                    <pre className="text-sm text-gray-800 font-mono whitespace-pre-wrap">
                                        {this.state.error?.toString()}
                                    </pre>
                                    {this.state.errorInfo && (
                                        <pre className="text-sm text-gray-600 font-mono whitespace-pre-wrap mt-2">
                                            {this.state.errorInfo.componentStack}
                                        </pre>
                                    )}
                                </div>
                            </div>

                            {/* Action Buttons */}
                            <div className="flex flex-col items-center space-y-2">
                                <button
                                    onClick={this.handleReset}
                                    className={getPrimaryButtonClasses()}
                                >
                                    <IconRefresh size={16} className="mr-2" />
                                    Try Again
                                </button>
                                <button
                                    onClick={() => window.location.reload()}
                                    className={getTertiaryButtonClasses()}
                                >
                                    Reload Page
                                </button>
                            </div>
                        </div>
                    </div>
                </div>
            );
        }

        return this.props.children;
    }
}

export default ErrorBoundary;