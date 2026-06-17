import { Link } from 'react-router-dom';

import { IconHome } from '@tabler/icons-react';
import { getPrimaryButtonClasses } from '../lib/twUtils';

const companyName = import.meta.env.VITE_COMPANY_NAME;
function NotFound() {
    return (
        <>
            <title>404 Not Found | {companyName}</title>
            <div className="min-h-screen flex items-center justify-center bg-gray-100">
                <div className="bg-white shadow-lg rounded-lg px-8 py-12 md:px-16 md:py-20 text-center">
                    <h1 className="text-6xl font-bold text-gray-600 mb-4">404</h1>
                    <p className="text-gray-700 text-lg mb-6">
                        Oops! The page you are looking for could not be found.
                    </p>
                    <Link to="/" className={getPrimaryButtonClasses()}>
                        <IconHome className="h-5 w-5 mr-2" aria-hidden="true" />
                        <span>Go Back Home</span>
                    </Link>
                </div>
            </div>
        </>
    );
}

export default NotFound;