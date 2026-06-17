import React, { useEffect } from 'react';
import { useNavigate, useLocation } from 'react-router-dom';
import { useAuth } from '../lib/AuthContext';

function RequirePhone({ children }: { children: React.ReactNode }) {
    const skipOtp = import.meta.env.VITE_SKIP_OTP === 'true';
    const { user, loading: authLoading, hasPhoneNumber } = useAuth();
    const navigate = useNavigate();
    const location = useLocation();

    useEffect(() => {
        if (skipOtp) {
            return;
        }
        // Exit checks if:
        // - Auth is still loading
        // - There's no user logged in
        // - User is already on a page that doesn't require a phone (login, auth callback, verify phone)
        const isExcludedPath = ['/login', '/auth/callback', '/verifyphone'].includes(location.pathname);

        if (authLoading || !user || isExcludedPath) {
            return;
        }

        if (!hasPhoneNumber()) {
            navigate('/verifyphone', { replace: true, state: { from: location.pathname } });
        }

    }, [user, authLoading, hasPhoneNumber, navigate, location.pathname]);

    return <>{children}</>;
}

export default RequirePhone;