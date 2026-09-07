import { KeyboardEvent, useCallback, useEffect, useState } from 'react';
import { IconCheck, IconEdit, IconLoader2 } from '@tabler/icons-react';
import api from '../../lib/supabaseClient';

interface OwnerPayoutAccountSummary {
    account_holder_name: string;
    masked_account_number: string;
    ifsc_code: string;
    status: 'PENDING_VERIFICATION';
    updated_at: string;
}
interface OwnerProfile { address_line1: string; address_line2: string | null; city: string; state: string; pincode: string; pan_masked: string | null; updated_at: string; }

const IFSC_PATTERN = /^[A-Z]{4}0[A-Z0-9]{6}$/;
const ACCOUNT_NUMBER_PATTERN = /^[0-9]{6,35}$/;

function OwnerBankAccountSection() {
    const [savedAccount, setSavedAccount] = useState<OwnerPayoutAccountSummary | null>(null);
    const [editing, setEditing] = useState(false);
    const [loading, setLoading] = useState(true);
    const [saving, setSaving] = useState(false);
    const [accountHolderName, setAccountHolderName] = useState('');
    const [accountNumber, setAccountNumber] = useState('');
    const [ifscCode, setIfscCode] = useState('');
    const [error, setError] = useState<string | null>(null);
    const [message, setMessage] = useState<string | null>(null);
    const [routeConsent, setRouteConsent] = useState(false);
    const [payoutStatus, setPayoutStatus] = useState<string | null>(null);
    const [refreshing, setRefreshing] = useState(false);
    const [profile, setProfile] = useState<OwnerProfile | null>(null);
    const [addressEditing, setAddressEditing] = useState(false);
    const [address, setAddress] = useState({ address_line1: '', address_line2: '', city: '', state: '', pincode: '', pan_number: '' });

    const loadAccount = useCallback(async () => {
        setLoading(true);
        setError(null);
        const { data, error: readError } = await (api.supabase as any)
            .rpc('get_my_owner_payout_account');

        if (readError) {
            setError(readError.message || 'Could not load saved bank details.');
        } else {
            const account = Array.isArray(data) ? data[0] : null;
            setSavedAccount(account || null);
            setRouteConsent(Boolean(account?.route_consent_accepted));
            setEditing(!account);
        }
        setLoading(false);
    }, []);
    const loadProfile = useCallback(async () => {
        const { data, error: profileError } = await (api.supabase as any).rpc('get_my_owner_profile');
        if (!profileError) { const value = Array.isArray(data) ? data[0] : null; setProfile(value || null); setAddressEditing(!value); if (value) setAddress({ address_line1: value.address_line1, address_line2: value.address_line2 || '', city: value.city, state: value.state, pincode: value.pincode, pan_number: '' }); }
    }, []);

    useEffect(() => {
        void loadAccount();
        void loadProfile();
    }, [loadAccount, loadProfile]);

    const saveProfile = async () => {
        const value = { ...address, address_line1: address.address_line1.trim(), address_line2: address.address_line2.trim(), city: address.city.trim(), state: address.state.trim(), pincode: address.pincode.trim(), pan_number: address.pan_number.trim().toUpperCase() };
        if (!value.address_line1 || !value.city || !value.state) { setError('Address line 1, city, and state are required.'); return; }
        if (!/^\d{6}$/.test(value.pincode)) { setError('PIN code must contain exactly 6 digits.'); return; }
        if (!/^[A-Z]{5}[0-9]{4}[A-Z]$/.test(value.pan_number)) { setError('Enter a valid PAN number.'); return; }
        setSaving(true); setError(null);
        const { error: saveError } = await (api.supabase as any).rpc('save_my_owner_profile', { p_address_line1: value.address_line1, p_address_line2: value.address_line2 || null, p_city: value.city, p_state: value.state, p_pincode: value.pincode, p_pan_number: value.pan_number, p_route_consent: routeConsent });
        setSaving(false); if (saveError) { setError(saveError.message || 'Could not save address.'); return; }
        await loadProfile(); setAddressEditing(false); setMessage('Residential address saved.');
    };

    const startEditing = () => {
        setAccountHolderName(savedAccount?.account_holder_name || '');
        setAccountNumber('');
        setIfscCode(savedAccount?.ifsc_code || '');
        setError(null);
        setMessage(null);
        setEditing(true);
    };

    const saveAccount = async () => {
        setError(null);
        setMessage(null);

        const holderName = accountHolderName.trim();
        const normalizedAccountNumber = accountNumber.trim();
        const normalizedIfsc = ifscCode.trim().toUpperCase();

        if (holderName.length < 2 || holderName.length > 200) {
            setError('Enter a valid account holder name.');
            return;
        }
        if (!ACCOUNT_NUMBER_PATTERN.test(normalizedAccountNumber)) {
            setError('Account number must contain 6 to 35 digits.');
            return;
        }
        if (!IFSC_PATTERN.test(normalizedIfsc)) {
            setError('Enter a valid 11-character IFSC code.');
            return;
        }
        if (!routeConsent) {
            setError('Please accept the Razorpay payout terms before verifying your bank account.');
            return;
        }

        setSaving(true);
        const { error: saveError } = await (api.supabase as any).rpc('save_my_owner_payout_account', {
            p_account_holder_name: holderName,
            p_account_number: normalizedAccountNumber,
            p_ifsc_code: normalizedIfsc,
            p_route_consent: routeConsent,
        });

        if (saveError) {
            setError(saveError.message || 'Could not save bank details.');
            setSaving(false);
            return;
        }

        const { error: onboardingError } = await api.supabase.functions.invoke('setup-owner-route-account', { body: {} });
        if (!onboardingError) setPayoutStatus('Verification in Progress');

        setAccountNumber('');
        setMessage(onboardingError ? (onboardingError.message || 'Payout onboarding failed.') : 'Bank details saved. Verification is pending.');
        setSaving(false);
        await loadAccount();
    };

    const refreshPayoutStatus = async () => {
        setRefreshing(true);
        const { data, error: refreshError } = await api.supabase.functions.invoke('setup-owner-route-account', { body: {} });
        if (!refreshError && data?.status) setPayoutStatus(data.status);
        setRefreshing(false);
    };

    if (loading) {
        return (
            <div className="flex items-center gap-2 text-sm text-slate-600">
                <IconLoader2 size={18} className="animate-spin" /> Loading saved bank details…
            </div>
        );
    }

    const consentBlock = routeConsent ? <p className="text-sm text-emerald-700">✓ Razorpay payout terms accepted</p> : <label className="flex items-start gap-2 text-sm text-slate-700"><input type="checkbox" checked={routeConsent} onChange={e => setRouteConsent(e.target.checked)} disabled={saving} className="mt-1" /><span>I agree to share my KYC, bank and payout details with Razorpay and accept the Razorpay Route terms required to receive rent payments.</span></label>;
    const addressBlock = profile && !addressEditing ? <div className="space-y-3"><div className="rounded-lg bg-slate-50 p-3 text-sm text-slate-700">{profile.address_line1}{profile.address_line2 && <>, {profile.address_line2}</>}<br />{profile.city}, {profile.state} - {profile.pincode}<br />PAN: {profile.pan_masked || 'Not saved'}</div><button type="button" onClick={() => setAddressEditing(true)} className="text-sm font-medium text-slate-700 underline">Change Address / PAN</button></div> : <div className="grid grid-cols-1 gap-3 md:grid-cols-2"><label className="text-sm font-medium text-slate-700">Address Line 1<input value={address.address_line1} onChange={e => setAddress({ ...address, address_line1: e.target.value })} disabled={saving} className="mt-1 block w-full rounded-lg border border-slate-300 px-3 py-2" /></label><label className="text-sm font-medium text-slate-700">Address Line 2 (optional)<input value={address.address_line2} onChange={e => setAddress({ ...address, address_line2: e.target.value })} disabled={saving} className="mt-1 block w-full rounded-lg border border-slate-300 px-3 py-2" /></label><label className="text-sm font-medium text-slate-700">City<input value={address.city} onChange={e => setAddress({ ...address, city: e.target.value })} disabled={saving} className="mt-1 block w-full rounded-lg border border-slate-300 px-3 py-2" /></label><label className="text-sm font-medium text-slate-700">State<input value={address.state} onChange={e => setAddress({ ...address, state: e.target.value })} disabled={saving} className="mt-1 block w-full rounded-lg border border-slate-300 px-3 py-2" /></label><label className="text-sm font-medium text-slate-700">PIN Code<input value={address.pincode} onChange={e => setAddress({ ...address, pincode: e.target.value.replace(/\D/g, '').slice(0, 6) })} inputMode="numeric" disabled={saving} className="mt-1 block w-full rounded-lg border border-slate-300 px-3 py-2" /></label><label className="text-sm font-medium text-slate-700">PAN Number<input value={address.pan_number} onChange={e => setAddress({ ...address, pan_number: e.target.value.toUpperCase().slice(0, 10) })} disabled={saving} maxLength={10} className="mt-1 block w-full rounded-lg border border-slate-300 px-3 py-2 uppercase" /></label><div className="flex items-end"><button type="button" onClick={() => void saveProfile()} disabled={saving} className="rounded-lg bg-slate-900 px-4 py-2 text-sm font-semibold text-white">Save Address & PAN</button></div></div>;

    if (savedAccount && !editing) {
        return (
            <div className="space-y-4">
                <h3 className="text-base font-semibold text-slate-800">Residential / KYC Address</h3>{addressBlock}
                {payoutStatus && <div className="rounded-lg bg-amber-50 p-3 text-sm text-amber-800">{payoutStatus === 'Payout Account Active' ? 'Bank Account Verified ✓' : payoutStatus === 'Action Required' ? 'Payout Verification Needs Attention' : payoutStatus === 'Payout Account Suspended' ? 'Bank Verification Failed' : 'Bank Verification In Progress'}<br /><button type="button" onClick={() => void refreshPayoutStatus()} disabled={refreshing} className="mt-1 underline">{refreshing ? 'Checking…' : 'Check Verification Status'}</button></div>}
                <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
                    <div><p className="text-xs font-medium uppercase tracking-wide text-slate-500">Account Holder</p><p className="mt-1 font-medium text-slate-900">{savedAccount.account_holder_name}</p></div>
                    <div><p className="text-xs font-medium uppercase tracking-wide text-slate-500">Account</p><p className="mt-1 font-mono font-medium text-slate-900">{savedAccount.masked_account_number}</p></div>
                    <div><p className="text-xs font-medium uppercase tracking-wide text-slate-500">IFSC Code</p><p className="mt-1 font-mono font-medium text-slate-900">{savedAccount.ifsc_code}</p></div>
                    <div><p className="text-xs font-medium uppercase tracking-wide text-slate-500">Current Status</p><p className="mt-1 inline-flex items-center gap-1.5 rounded-full bg-amber-50 px-3 py-1 text-sm font-medium text-amber-700"><IconCheck size={15} /> Verification Pending</p></div>
                </div>
                <div className="mt-4">{consentBlock}</div>
                {message && <p className="text-sm text-emerald-700">{message}</p>}
                <button type="button" onClick={startEditing} className="inline-flex items-center gap-2 rounded-lg border border-slate-300 px-4 py-2 text-sm font-medium text-slate-700 hover:bg-slate-50">
                    <IconEdit size={16} /> Change Bank Details
                </button>
            </div>
        );
    }

    return (
        <div className="space-y-4" onKeyDown={(event: KeyboardEvent<HTMLDivElement>) => {
            if (event.key === 'Enter') {
                event.preventDefault();
                void saveAccount();
            }
        }}>
            <div><h3 className="text-base font-semibold text-slate-800">Residential / KYC Address</h3>{addressBlock}</div>
            <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
                <label className="text-sm font-medium text-slate-700">Account Holder Name
                    <input value={accountHolderName} onChange={(event) => setAccountHolderName(event.target.value)} autoComplete="name" maxLength={200} disabled={saving} className="mt-1 block w-full rounded-lg border border-slate-300 px-3 py-2.5 font-normal outline-none focus:border-slate-500 focus:ring-2 focus:ring-slate-200" />
                </label>
                <label className="text-sm font-medium text-slate-700">Account Number
                    <input value={accountNumber} onChange={(event) => setAccountNumber(event.target.value.replace(/\s/g, ''))} inputMode="numeric" autoComplete="off" minLength={6} maxLength={35} disabled={saving} className="mt-1 block w-full rounded-lg border border-slate-300 px-3 py-2.5 font-normal outline-none focus:border-slate-500 focus:ring-2 focus:ring-slate-200" />
                </label>
                <label className="text-sm font-medium text-slate-700">IFSC Code
                    <input value={ifscCode} onChange={(event) => setIfscCode(event.target.value.toUpperCase().replace(/\s/g, ''))} autoComplete="off" minLength={11} maxLength={11} disabled={saving} className="mt-1 block w-full rounded-lg border border-slate-300 px-3 py-2.5 font-mono font-normal uppercase outline-none focus:border-slate-500 focus:ring-2 focus:ring-slate-200" placeholder="HDFC0001234" />
                </label>
                <div className="flex items-end"><p className="w-full rounded-lg bg-amber-50 px-3 py-2.5 text-sm font-medium text-amber-700">Current Status: Verification Pending</p></div>
            </div>
            <div className="mt-4">{consentBlock}</div>
            {error && <p role="alert" className="text-sm text-red-600">{error}</p>}
            <div className="flex flex-wrap gap-3">
                <button type="button" onClick={() => void saveAccount()} disabled={saving} className="inline-flex items-center gap-2 rounded-lg bg-slate-900 px-4 py-2.5 text-sm font-semibold text-white hover:bg-slate-800 disabled:cursor-not-allowed disabled:opacity-60">
                    {saving && <IconLoader2 size={16} className="animate-spin" />} Save Bank Details
                </button>
                {savedAccount && <button type="button" disabled={saving} onClick={() => setEditing(false)} className="rounded-lg border border-slate-300 px-4 py-2.5 text-sm font-medium text-slate-700 hover:bg-slate-50">Cancel</button>}
            </div>
        </div>
    );
}

export default OwnerBankAccountSection;
