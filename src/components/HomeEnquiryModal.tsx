import { FormEvent, useEffect, useState } from 'react';
import { IconBuildingEstate, IconHomeHeart, IconX } from '@tabler/icons-react';
import { User } from '@supabase/supabase-js';
import api from '../lib/supabaseClient';
import { HomepageEnquiryType } from '../lib/types';
import LoadingSpinner from './LoadingSpinner';

interface Props {
    user: User | null;
    onSuccess: () => void;
}

export default function HomeEnquiryModal({ user, onSuccess }: Props) {
    const [open, setOpen] = useState(false);
    const [type, setType] = useState<HomepageEnquiryType | null>(null);
    const [submitting, setSubmitting] = useState(false);
    const [error, setError] = useState<string | null>(null);
    const [form, setForm] = useState({
        customerName: '', phone: '', email: '', occupancyType: 'FAMILY', budget: '', bedroomRequirement: '1 BHK', preferredArea: '', message: '',
    });

    useEffect(() => {
        if (!user) return;
        setForm(current => ({
            ...current,
            customerName: String(user.user_metadata?.full_name || user.user_metadata?.name || ''),
            phone: user.phone || '',
            email: user.email || '',
        }));
        setOpen(true);
    }, [user]);

    const close = () => {
        setOpen(false);
    };

    const submit = async (event: FormEvent) => {
        event.preventDefault();
        if (!type) return;
        setSubmitting(true); setError(null);
        const { error: submitError } = await api.submitHomepageEnquiry({
            p_enquiry_type: type,
            p_customer_name: form.customerName,
            p_contact_phone: form.phone,
            p_email: type === 'OWNER' ? form.email : null,
            p_occupancy_type: type === 'TENANT' ? form.occupancyType as 'FAMILY' | 'BACHELOR' | 'COMMERCIAL' : null,
            p_budget: type === 'TENANT' ? Number(form.budget) : null,
            p_bedroom_requirement: type === 'TENANT' ? form.bedroomRequirement : null,
            p_preferred_area: type === 'TENANT' ? form.preferredArea : null,
            p_message: type === 'OWNER' ? form.message : null,
        });
        setSubmitting(false);
        if (submitError) {
            setError(typeof submitError === 'string' ? submitError : 'Could not submit your enquiry.');
            return;
        }
        setOpen(false);
        onSuccess();
    };

    if (!open || !user) return null;
    const inputClass = 'mt-1 block w-full rounded-lg border border-slate-300 bg-white px-3 py-2.5 text-sm text-slate-900 outline-none focus:border-[#2C4964] focus:ring-2 focus:ring-[#2C4964]/15';

    return (
        <div className="fixed inset-0 z-[100] flex items-center justify-center p-4" role="dialog" aria-modal="true" aria-labelledby="home-enquiry-title">
            <button className="absolute inset-0 bg-slate-950/55 backdrop-blur-md" onClick={close} aria-label="Close enquiry form" />
            <div className="relative w-full max-w-lg overflow-hidden rounded-2xl bg-white shadow-2xl">
                <div className="flex items-start justify-between border-b border-slate-100 px-6 py-5">
                    <div><h2 id="home-enquiry-title" className="text-xl font-bold text-slate-900">How can we help?</h2><p className="mt-1 text-sm text-slate-500">Tell us what you need and our team will contact you.</p></div>
                    <button onClick={close} className="rounded-lg p-2 text-slate-500 hover:bg-slate-100" aria-label="Close"><IconX size={20} /></button>
                </div>
                {!type ? (
                    <div className="grid gap-4 p-6 sm:grid-cols-2">
                        <button onClick={() => setType('TENANT')} className="rounded-xl border border-slate-200 p-5 text-left transition hover:border-[#2C4964] hover:bg-slate-50"><IconHomeHeart className="mb-3 text-[#2C4964]" size={30} /><h3 className="font-bold text-slate-900">I am a tenant</h3><p className="mt-1 text-sm text-slate-500">I am looking for a home.</p></button>
                        <button onClick={() => setType('OWNER')} className="rounded-xl border border-slate-200 p-5 text-left transition hover:border-[#2C4964] hover:bg-slate-50"><IconBuildingEstate className="mb-3 text-[#2C4964]" size={30} /><h3 className="font-bold text-slate-900">I am a house owner</h3><p className="mt-1 text-sm text-slate-500">I need help with my property.</p></button>
                    </div>
                ) : (
                    <form onSubmit={submit} className="p-6">
                        <button type="button" onClick={() => setType(null)} className="mb-4 text-sm font-semibold text-[#2C4964]">← Change enquiry type</button>
                        <div className="grid gap-4 sm:grid-cols-2">
                            <label className="text-sm font-medium text-slate-700">Customer name<input required value={form.customerName} onChange={e => setForm({ ...form, customerName: e.target.value })} className={inputClass} /></label>
                            <label className="text-sm font-medium text-slate-700">Contact number<input required type="tel" value={form.phone} onChange={e => setForm({ ...form, phone: e.target.value })} className={inputClass} /></label>
                            {type === 'TENANT' ? <>
                                <label className="text-sm font-medium text-slate-700">For<select value={form.occupancyType} onChange={e => setForm({ ...form, occupancyType: e.target.value })} className={inputClass}><option value="FAMILY">Family</option><option value="BACHELOR">Bachelor</option><option value="COMMERCIAL">Commercial</option></select></label>
                                <label className="text-sm font-medium text-slate-700">Budget (₹)<input required min="0" type="number" value={form.budget} onChange={e => setForm({ ...form, budget: e.target.value })} className={inputClass} /></label>
                                <label className="text-sm font-medium text-slate-700">Requirement<select value={form.bedroomRequirement} onChange={e => setForm({ ...form, bedroomRequirement: e.target.value })} className={inputClass}><option>1 RK</option><option>1 BHK</option><option>2 BHK</option><option>3 BHK</option><option>4+ BHK</option><option>Commercial space</option></select></label>
                                <label className="text-sm font-medium text-slate-700">Preferred Location<input required value={form.preferredArea} onChange={e => setForm({ ...form, preferredArea: e.target.value })} className={inputClass} /></label>
                            </> : <>
                                <label className="text-sm font-medium text-slate-700 sm:col-span-2">Email<input required type="email" value={form.email} onChange={e => setForm({ ...form, email: e.target.value })} className={inputClass} /></label>
                                <label className="text-sm font-medium text-slate-700 sm:col-span-2">Message<textarea required rows={4} value={form.message} onChange={e => setForm({ ...form, message: e.target.value })} className={inputClass} /></label>
                            </>}
                        </div>
                        {error && <p className="mt-4 text-sm text-red-600">{error}</p>}
                        <button disabled={submitting} className="mt-6 inline-flex w-full items-center justify-center rounded-lg bg-[#2C4964] px-4 py-3 text-sm font-bold text-white disabled:opacity-60">{submitting ? <LoadingSpinner size={18} /> : 'Send enquiry'}</button>
                    </form>
                )}
            </div>
        </div>
    );
}
