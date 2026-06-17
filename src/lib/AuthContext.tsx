import { createContext, useContext, useEffect, useState, ReactNode, useCallback } from 'react';
import { User, Session } from '@supabase/supabase-js';
import api from './supabaseClient';
import { VisitStatus, NominatimResponse } from './types';
import { getCityFromNominatimData, DEFAULT_CITY } from './geoUtils';

interface AuthContextValue {
    user: User | null;
    loading: boolean;
    authLoading: boolean;
    signInWithGoogle: () => Promise<void>;
    signOut: () => Promise<void>;
    hasPhoneNumber: () => boolean;
    balance: VisitStatus | undefined;
    balanceLoading: boolean;
    balanceError: string | null;
    refetchBalance: () => Promise<void>;
    geolocationData: NominatimResponse | null;
    currentCity: string;
    setCurrentCity: (city: string) => void;
    geolocationLoading: boolean;
    geolocationError: string | null;
    refetchGeolocation: () => Promise<void>;
}

const AuthContext = createContext<AuthContextValue | undefined>(undefined);

interface AuthProviderProps {
    children: ReactNode;
}

export function AuthProvider({ children }: AuthProviderProps) {
    const [user, setUser] = useState<User | null>(null);
    const [authCheckLoading, setAuthCheckLoading] = useState(true);

    const [balanceLoading, setBalanceLoading] = useState(false);
    const [balance, setBalance] = useState<VisitStatus | undefined>(undefined);
    const [balanceError, setBalanceError] = useState<string | null>(null);

    const [geolocationData, setGeolocationData] = useState<NominatimResponse | null>(null);
    const [currentCity, setCurrentCity] = useState<string>(() => {
        return localStorage.getItem('winoli_selected_city') || DEFAULT_CITY;
    });
    const [geolocationLoading, setGeolocationLoading] = useState(true);
    const [geolocationError, setGeolocationError] = useState<string | null>(null);


    const fetchBalanceStable = useCallback(async (isMounted: { current: boolean }) => {
        if (isMounted.current) {
            setBalanceLoading(true);
            setBalanceError(null);
        }

        try {
            const { data, error } = await api.getVisitStatus();
            if (error) throw error;
            if (isMounted.current) {
                setBalance(data ? data : undefined);
            }
        } catch (err: any) {
            console.error('AuthProvider: Error fetching visit status:', err);
            if (isMounted.current) {
                setBalanceError(err.message || 'Failed to fetch balance');
                setBalance(undefined);
            }
        } finally {
            if (isMounted.current) {
                setBalanceLoading(false);
            }
        }
    }, []);

    const fetchGeolocationStable = useCallback(async (isMountedGeo: { current: boolean }) => {
        if (isMountedGeo.current) {
            setGeolocationLoading(true);
            setGeolocationError(null);
        }

        if (!navigator.geolocation) {
            if (isMountedGeo.current) {
                setGeolocationError('Geolocation is not supported by this browser.');
                setCurrentCity(DEFAULT_CITY);
                setGeolocationLoading(false);
            }
            return;
        }

        navigator.geolocation.getCurrentPosition(
            async (position) => {
                try {
                    const { latitude, longitude } = position.coords;
                    const response = await fetch(`https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=${latitude}&lon=${longitude}`);
                    if (!response.ok) {
                        throw new Error(`Nominatim API request failed: ${response.statusText}`);
                    }
                    const data: NominatimResponse = await response.json();
                    if (isMountedGeo.current) {
                        setGeolocationData(data);
                        const storedCity = localStorage.getItem('winoli_selected_city');
                        if (!storedCity) {
                            setCurrentCity(getCityFromNominatimData(data));
                        }
                        setGeolocationError(null);
                    }
                } catch (geoErr: any) {
                    console.error('AuthProvider: Error fetching geolocation data:', geoErr);
                    if (isMountedGeo.current) {
                        setGeolocationError(geoErr.message || 'Failed to fetch location details.');
                        const storedCity = localStorage.getItem('winoli_selected_city');
                        if (!storedCity) {
                            setCurrentCity(DEFAULT_CITY);
                        }
                        setGeolocationData(null);
                    }
                } finally {
                    if (isMountedGeo.current) {
                        setGeolocationLoading(false);
                    }
                }
            },
            (error) => {
                console.warn('AuthProvider: Geolocation access denied or error:', error.message);
                if (isMountedGeo.current) {
                    setGeolocationError(error.message === "User denied Geolocation" ? "Location access denied. Defaulting city." : "Could not retrieve location.");
                    const storedCity = localStorage.getItem('winoli_selected_city');
                    if (!storedCity) {
                        setCurrentCity(DEFAULT_CITY);
                    }
                    setGeolocationData(null);
                    setGeolocationLoading(false);
                }
            },
            { timeout: 10000 }
        );
    }, []);


    useEffect(() => {
        const isMountedAuth = { current: true };
        const isMountedGeo = { current: true };

        let effectUser: User | null = null;
        setAuthCheckLoading(true);

        api.supabase.auth.getUser().then(({ data: { user: initialUser } }) => {
            if (!isMountedAuth.current) return;
            effectUser = initialUser || null;
            setUser(effectUser);
            if (effectUser) {
                fetchBalanceStable(isMountedAuth);
            } else {
                setBalanceLoading(false);
            }
            setAuthCheckLoading(false);
        }).catch((err) => {
            console.error("Error during initial getUser:", err);
            if (isMountedAuth.current) {
                effectUser = null;
                setUser(null);
                setBalance(undefined);
                setBalanceError(null);
                setBalanceLoading(false);
                setAuthCheckLoading(false);
            }
        });

        // Fetch once on mount
        fetchGeolocationStable(isMountedGeo);


        const { data: { subscription } } = api.supabase.auth.onAuthStateChange(
            (_, session: Session | null) => {
                if (!isMountedAuth.current) return;

                const currentUser = session?.user ?? null;
                const previousUserId = effectUser?.id;
                effectUser = currentUser;
                setUser(effectUser);

                const userIdChanged = (!previousUserId && currentUser) || (previousUserId && !currentUser) || (previousUserId !== currentUser?.id);

                if (userIdChanged) {
                    if (currentUser) {
                        fetchBalanceStable(isMountedAuth);
                    } else {
                        setBalance(undefined);
                        setBalanceError(null);
                        setBalanceLoading(false);
                    }
                }
            }
        );

        return () => {
            isMountedAuth.current = false;
            isMountedGeo.current = false;
            subscription.unsubscribe();
        };
    }, [fetchBalanceStable, fetchGeolocationStable]);


    const signInWithGoogle = async () => {
        setAuthCheckLoading(true);
        const { error } = await api.supabase.auth.signInWithOAuth({
            provider: 'google',
            options: {
                redirectTo: `${window.location.origin}/auth/callback`
            }
        });
        if (error) {
            console.error('Error signing in with Google:', error);
            setAuthCheckLoading(false);
        }
    };

    const signOut = async () => {
        setAuthCheckLoading(true);
        const { error } = await api.supabase.auth.signOut();
        if (error) {
            console.error('Error signing out:', error);
        }
        setAuthCheckLoading(false);
        setBalanceLoading(false);
    };

    const hasPhoneNumber = () => {
        return !!user?.phone || !!user?.user_metadata?.phone;
    };

    const refetchBalanceCallback = useCallback(async () => {
        if (!user) {
            console.warn("Refetch balance called but no user is logged in.");
            return;
        }
        const isMounted = { current: true };
        await fetchBalanceStable(isMounted);
    }, [user, fetchBalanceStable]);

    const handleSetCurrentCity = (city: string) => {
        localStorage.setItem('winoli_selected_city', city);
        setCurrentCity(city);
    };

    const refetchGeolocationCallback = useCallback(async () => {
        const isMountedGeo = { current: true };
        localStorage.removeItem('winoli_selected_city');
        await fetchGeolocationStable(isMountedGeo);
    }, [fetchGeolocationStable]);

    const overallLoading = authCheckLoading || balanceLoading;

    const value: AuthContextValue = {
        user,
        loading: overallLoading,
        authLoading: authCheckLoading,
        signInWithGoogle,
        signOut,
        hasPhoneNumber,
        balance,
        balanceLoading,
        balanceError,
        refetchBalance: refetchBalanceCallback,
        geolocationData,
        currentCity,
        setCurrentCity: handleSetCurrentCity,
        geolocationLoading,
        geolocationError,
        refetchGeolocation: refetchGeolocationCallback,
    };

    return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth() {
    const context = useContext(AuthContext);
    if (!context) {
        throw new Error('useAuth must be used within an AuthProvider');
    }
    return context;
}