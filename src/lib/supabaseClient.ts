import { createClient, PostgrestError, SupabaseClient } from '@supabase/supabase-js';
import { Database } from '../database.types';
import {
    Property,
    VisitStatus,
    VerifyPaymentPayload,
    VerifyPaymentResponse,
    CreatePaymentOrderResponse,
    CreatePaymentOrderPayload,
    CreateTicketPayload,
    AddTicketCommentPayload,
    UploadPropertyImageResponse,
    ManagementPlan,
    PropertiesFilterParams,
    VisitPlan,
    MyTransactions,
    MyProperties,
    MyRentDues,
    MyPropertyTickets,
    PropertyPaymentHistory,
    MyOccupiedProperties,
    UpdatePropertyPayload,
    InsertPropertyPayload,
    MyTickets,
    TicketDetails,
    DeletePropertyImagePayload,
    EditPropertyImagePayload,
    PropertyRentDues,
    DetailedPropertyImage,
    WishlistItem,
    CustomerSubmitRentalApplicationPayload,
    MyRentalApplication,
    MyRentalApplicationDetails
} from './types';
import { format } from 'date-fns';


const supabaseUrl = import.meta.env.VITE_SUPABASE_URL;
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY;


// Generic response type remains the same
export interface ApiResponse<T> {
    data: T | null;
    error: PostgrestError | string | null;
}

let razorpayScriptLoaded = false;
const loadRazorpayScript = (): Promise<void> => {
    return new Promise((resolve, reject) => {
        if (razorpayScriptLoaded) {
            resolve();
            return;
        }
        const script = document.createElement('script');
        script.src = 'https://checkout.razorpay.com/v1/checkout.js';
        script.onload = () => {
            razorpayScriptLoaded = true;
            resolve();
        };
        script.onerror = (error) => {
            console.error('Failed to load Razorpay script:', error);
            reject(new Error('Failed to load Razorpay script'));
        };
        document.body.appendChild(script);
    });
};


/**
 * Real Estate API class for Supabase
 */
class RealEstateApi {
    public supabase: SupabaseClient<Database>;
    private razorpayInstance: any = null;

    constructor() {
        if (!supabaseUrl || !supabaseAnonKey) {
            throw new Error("Supabase URL or Anon Key is missing. Check your .env file.");
        }
        this.supabase = createClient<Database>(supabaseUrl, supabaseAnonKey);
    }


    // --- Generic RPC Handler ---
    protected async handleRpc<T>(
        functionName: keyof Database['public']['Functions'],
        params?: Database['public']['Functions'][typeof functionName]['Args']
    ): Promise<ApiResponse<T>> {
        try {
            const rpc = this.supabase.rpc(functionName, params);
            const { data, error } = await rpc;

            if (error) {
                console.error(`Error calling RPC ${String(functionName)} with params:`, params, 'Error:', error);
                return { data: null, error: error };
            }
            return { data: data as T, error: null };
        } catch (err) {
            const error = err as PostgrestError | Error;
            console.error(`Unexpected error calling RPC ${String(functionName)}:`, error);
            return { data: null, error: error.message };
        }
    }

    // --- Generic Edge Function Handler ---
    protected async handleFunction<T>(
        functionName: string,
        payload: object | FormData
    ): Promise<ApiResponse<T>> {
        try {
            const options: { body: BodyInit; headers?: Record<string, string> } = {
                body: payload instanceof FormData ? payload : JSON.stringify(payload),
            };

            if (!(payload instanceof FormData)) {
                options.headers = { 'Content-Type': 'application/json' };
            }

            const { data, error } = await this.supabase.functions.invoke(functionName, options);

            if (error) {
                console.error(`Error invoking function ${functionName} with payload:`, payload, 'Error:', error);
                const contextErrorMessage = (error as any).context?.errorMessage;
                return { data: null, error: contextErrorMessage || error.message || 'Unknown function invocation error' };
            }
            return { data: data as T, error: null };
        } catch (err: unknown) {
            const error = err as Error;
            console.error(`Unexpected error invoking function ${functionName}:`, error);
            return { data: null, error: error.message || 'Unknown error during function invocation' };
        }
    }


    // =========================================
    // == Public Property Browsing Functions ==
    // =========================================

    async getProperties(params: PropertiesFilterParams): Promise<ApiResponse<Property[]>> {
        return this.handleRpc<Property[]>('get_properties_customer', params);
    }

    getPropertyFromId(propertyId: string): Promise<ApiResponse<Property[]>> {
        return this.handleRpc<Property[]>('get_property_from_id_customer', { p_requested_property_id: propertyId });
    }


    // =========================================
    // == Wishlist & Interaction Functions ==
    // =========================================

    async getWishlistCount(): Promise<ApiResponse<number>> {
        const response = await this.handleRpc<{ wishlist_count: number }>('get_my_interaction_summary_customer');
        if (response.error || !response.data) {
            return { data: 0, error: response.error };
        }
        return { data: response.data.wishlist_count || 0, error: null };
    }

    async getWishlist(offset: number = 0, limit: number = 50): Promise<ApiResponse<WishlistItem[]>> {
        return this.handleRpc<WishlistItem[]>('get_my_interactions_customer', { p_offset: offset, p_limit: limit });
    }

    async removeFromWishlist(propertyId: string): Promise<ApiResponse<null>> {
        // Updated to call remove_interaction_customer. This function removes any interaction,
        // so ensure it's only called for wishlisted items from UI.
        const response = await this.handleRpc<void>('remove_interaction_customer', { p_property_id: propertyId });
        return { data: null, error: response.error };
    }

    async addToWishlist(propertyId: string): Promise<ApiResponse<string>> {
        return this.handleRpc<string>('add_to_wishlist_customer', { p_property_id: propertyId });
    }


    // =========================================
    // == Visit Request & Plan Functions ==
    // =========================================

    async getVisitStatus(): Promise<ApiResponse<VisitStatus>> {
        const response = await this.handleRpc<VisitStatus[]>('get_visit_status_customer');
        if (response.error || !response.data) {
            // Ensure default structure if data is null or empty array
            return { data: { visit_balance: 0, expiry_date: null }, error: response.error };
        }
        const statusData = response.data.length > 0 ? response.data[0] : { visit_balance: 0, expiry_date: null };
        return { data: statusData, error: null };
    }

    async requestVisit(propertyId: string, preferredDate: Date): Promise<ApiResponse<string>> {
        return this.handleRpc<string>('request_visit_customer', {
            p_property_id: propertyId,
            p_preferred_date: format(preferredDate, 'yyyy-MM-dd')
        });
    }

    async getVisitPlans(): Promise<ApiResponse<VisitPlan[]>> {
        return this.handleRpc<VisitPlan[]>('get_visit_plans_customer');
    }

    // =========================================
    // == Property Submission & Management Functions ==
    // =========================================

    async insertProperty(payload: InsertPropertyPayload): Promise<ApiResponse<string>> {
        return this.handleRpc<string>('insert_property_customer', payload);
    }

    async updateProperty(payload: UpdatePropertyPayload): Promise<ApiResponse<void>> {
        return this.handleRpc<void>('update_property_customer', payload);
    }

    async uploadPropertyImage(
        propertyId: string,
        file: File,
        description?: string,
        isInternalImage?: boolean,
        displayOrder?: number
    ): Promise<ApiResponse<UploadPropertyImageResponse>> {
        const formData = new FormData();
        formData.append('property_id', propertyId);
        formData.append('image_file', file);
        if (description) {
            formData.append('description', description);
        }
        if (isInternalImage !== undefined) {
            formData.append('is_internal_image', String(isInternalImage));
        }
        if (displayOrder !== undefined) {
            formData.append('display_order', String(displayOrder));
        }
        return this.handleFunction<UploadPropertyImageResponse>('upload-property-image', formData);
    }

    async deletePropertyImage(payload: DeletePropertyImagePayload): Promise<ApiResponse<void>> {
        return this.handleRpc<void>('delete_property_image_customer', payload);
    }

    async editPropertyImage(payload: EditPropertyImagePayload): Promise<ApiResponse<void>> {
        return this.handleRpc<void>('edit_property_image_customer', payload);
    }

    // =========================================
    // == Payment & Transaction Functions ==
    // =========================================

    async createPaymentOrder(payload: CreatePaymentOrderPayload): Promise<ApiResponse<CreatePaymentOrderResponse>> {
        try {
            const { data, error } = await this.supabase.functions.invoke('create-payment', {
                body: JSON.stringify(payload),
            });
            if (error) throw error;
            return { data: data as CreatePaymentOrderResponse, error: null };
        } catch (err: unknown) {
            const error = err as Error;
            console.error('Error creating payment order:', error);
            let message = error.message;
            if ((error as any).context?.errorMessage) {
                message = (error as any).context.errorMessage;
            }
            return { data: null, error: message };
        }
    }

    async verifyPayment(payload: VerifyPaymentPayload): Promise<ApiResponse<VerifyPaymentResponse>> {
        try {
            const { data, error } = await this.supabase.functions.invoke('verify-payment', {
                body: JSON.stringify(payload),
            });
            if (error) throw error;
            return { data: data as VerifyPaymentResponse, error: null };
        } catch (err: unknown) {
            const error = err as Error;
            console.error('Error verifying payment:', error);
            let message = error.message;
            if ((error as any).context?.errorMessage) {
                message = (error as any).context.errorMessage;
            }
            return { data: null, error: message };
        }
    }

    async openRazorpayCheckout(options: { key: string; amount: number; currency: string; name: string; description: string; order_id: string; handler: (response: any) => void; prefill?: { name?: string; email?: string; contact?: string; }; notes?: object; theme?: { color?: string; }; }): Promise<void> {
        try {
            await loadRazorpayScript();
            const razorpayOptions = { ...options };
            this.razorpayInstance = new (window as any).Razorpay(razorpayOptions);
            this.razorpayInstance.open();
        } catch (error) {
            console.error('Failed to open Razorpay checkout:', error);
            throw error;
        }
    }

    async getMyTransactions(offset: number = 0, limit: number = 10): Promise<ApiResponse<MyTransactions[]>> {
        return this.handleRpc<MyTransactions[]>('get_my_transactions_customer', { p_offset: offset, p_limit: limit });
    }

    // =========================================
    // == Landlord Specific Functions        ==
    // =========================================

    async getMyProperties(offset: number = 0, limit: number = 10): Promise<ApiResponse<MyProperties[]>> {
        return this.handleRpc<MyProperties[]>('get_my_properties_customer', { p_offset: offset, p_limit: limit });
    }

    async getMyPropertyWithId(propertyId: string): Promise<ApiResponse<MyProperties | null>> {
        const { data, error } = await this.handleRpc<MyProperties[]>('get_my_property_with_id_customer', { p_property_id_input: propertyId });
        if (error) {
            return { data: null, error };
        }
        return { data: data && data.length > 0 ? data[0] : null, error: null };
    }

    async getPropertyRentDues(propertyId?: string, offset: number = 0, limit: number = 10): Promise<ApiResponse<PropertyRentDues[]>> {
        return this.handleRpc<PropertyRentDues[]>('get_property_rent_dues_landlord', { p_property_id_filter: propertyId, p_offset: offset, p_limit: limit });
    }

    async getPropertyTickets(propertyId?: string, offset: number = 0, limit: number = 10): Promise<ApiResponse<MyPropertyTickets[]>> {
        return this.handleRpc<MyPropertyTickets[]>('get_property_tickets_landlord', { p_property_id_filter: propertyId, p_offset: offset, p_limit: limit });
    }

    async getPropertyPaymentHistory(propertyId: string, offset: number = 0, limit: number = 10): Promise<ApiResponse<PropertyPaymentHistory[]>> {
        return this.handleRpc<PropertyPaymentHistory[]>('get_property_payment_history_landlord', { p_property_id_input: propertyId, p_offset: offset, p_limit: limit });
    }

    // =========================================
    // == Tenant Specific Functions          ==
    // =========================================

    async getMyRentDues(offset: number = 0, limit: number = 10): Promise<ApiResponse<MyRentDues[]>> { // Removed propertyId filter as SQL doesn't have it
        return this.handleRpc<MyRentDues[]>('get_my_rent_dues_customer', { p_offset: offset, p_limit: limit });
    }

    async viewMyOccupiedProperties(p_offset: number = 0, p_limit: number = 10): Promise<ApiResponse<MyOccupiedProperties[]>> {
        return this.handleRpc<MyOccupiedProperties[]>('get_my_occupied_properties_customer', { p_offset: p_offset, p_limit: p_limit });
    }

    async createTicket(payload: CreateTicketPayload): Promise<ApiResponse<number>> {
        return this.handleRpc<number>('create_ticket_customer', payload);
    }

    async getMyTickets(offset: number = 0, limit: number = 10): Promise<ApiResponse<MyTickets[]>> {
        return this.handleRpc<MyTickets[]>('get_my_raised_tickets_customer', { p_offset: offset, p_limit: limit });
    }

    async addTicketComment(payload: AddTicketCommentPayload): Promise<ApiResponse<null>> {
        const response = await this.handleRpc<void>('add_ticket_comment_customer', payload);
        return { data: null, error: response.error };
    }

    async getTicketDetailsCustomer(ticketId: number): Promise<ApiResponse<TicketDetails | null>> {
        const { data, error } = await this.handleRpc<TicketDetails[]>('get_ticket_details_customer', { p_ticket_id_input: ticketId });
        if (error) return { data: null, error };
        return { data: data && data.length > 0 ? data[0] : null, error: null };
    }

    async uploadTicketImages(ticketId: number, images: File[], description?: string | null): Promise<ApiResponse<{ message: string; uploads: { fileName: string; url: string; image_id: string }[]; failures?: { fileName: string; error: string }[] } | null>> {
        const formData = new FormData();
        formData.append('ticket_id', ticketId.toString());
        if (description) formData.append('description', description);
        images.forEach((image, index) => {
            formData.append(`image_${index}`, image);
        });
        const result = await this.handleFunction<{ message: string; uploads: { fileName: string; url: string; image_id: string }[]; failures?: { fileName: string; error: string }[] }>('upload-ticket-images', formData);

        if (result.error) {
            return { data: null, error: result.error };
        }
        return { data: result.data, error: null };
    }

    // ==================================================
    // == Shared Owner/Tenant Functions            ==
    // ==================================================

    async viewPropertyInternalImages(propertyId: string): Promise<ApiResponse<DetailedPropertyImage[]>> {
        const { data: property, error: propError } = await this.getMyPropertyWithId(propertyId);
        if (propError) return { data: null, error: propError };
        if (!property) return { data: [], error: 'Property not found or not owned by user.' };
        const internalImages = property.property_images.filter(img => img.is_internal_image);
        return { data: internalImages, error: null };
    }


    async getManagementPlans(): Promise<ApiResponse<ManagementPlan[]>> {
        return this.handleRpc<ManagementPlan[]>('list_management_plans_customer');
    }

    // =========================================
    // == Customer Rental Application Functions ==
    // =========================================

    async submitRentalApplication(payload: CustomerSubmitRentalApplicationPayload): Promise<ApiResponse<string | null>> {
        return this.handleRpc<string | null>('customer_submit_rental_application', payload);
    }

    async getMyRentalApplications(offset: number = 0, limit: number = 10): Promise<ApiResponse<MyRentalApplication[]>> {
        return this.handleRpc<MyRentalApplication[]>('customer_get_my_rental_applications', { p_offset: offset, p_limit: limit });
    }

    async getMyRentalApplicationDetails(applicationId: string): Promise<ApiResponse<MyRentalApplicationDetails | null>> {
        const { data, error } = await this.handleRpc<MyRentalApplicationDetails[]>('customer_get_rental_application_details', { p_application_id: applicationId });
        if (error) {
            return { data: null, error };
        }
        return { data: data && data.length > 0 ? data[0] : null, error: null };
    }

    async withdrawRentalApplication(applicationId: string): Promise<ApiResponse<null>> {
        const response = await this.handleRpc<void>('customer_withdraw_rental_application', { p_application_id: applicationId });
        return { data: null, error: response.error };
    }
}

const api = new RealEstateApi();
export default api;