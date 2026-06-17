import { useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '../lib/AuthContext';
import LoadingSpinner from './LoadingSpinner';

function AuthCallback() {
    const navigate = useNavigate();
    const { user, loading: authLoading } = useAuth();

    useEffect(() => {
        // Only navigate when auth is no longer loading
        if (!authLoading) {
            if (user) {
                navigate('/', { replace: true });
            } else {
                console.warn('Auth finished, but no user found. Redirecting to /login.');
                navigate('/login', { replace: true });
            }
        }

    }, [user, authLoading, navigate]);

    return (
        <div className="flex flex-col items-center justify-center min-h-screen bg-gray-100 text-center p-4">
            <LoadingSpinner size={40} />
            <h1 className="text-xl font-semibold text-gray-700 mt-4">
                Processing Authentication
            </h1>
            <p className="text-gray-500">
                Please wait, redirecting shortly...
            </p>
        </div>
    );
}

export default AuthCallback;