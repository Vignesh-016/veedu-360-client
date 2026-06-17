import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { v4 as uuidv4 } from 'npm:uuid';
import { corsHeaders } from '../_shared/cors.ts';
import { Database } from '../../../src/database.types.ts';
import supabaseAdmin from "../_shared/supabaseAdmin.ts";

// Ensure this bucket exists in your Supabase project
const STORAGE_BUCKET_NAME = Deno.env.get('STORAGE_BUCKET');
const MAX_FILE_SIZE_MB = 10;
const MAX_FILE_SIZE_BYTES = MAX_FILE_SIZE_MB * 1024 * 1024;
const ALLOWED_MIME_TYPES = [
    'image/jpeg',
    'image/png',
    'image/webp',
];
// -------------------

type TicketImageInsert = Database['public']['Tables']['ticket_images']['Insert'];

Deno.serve(async (req) => {
    // Handle CORS preflight request
    if (req.method === 'OPTIONS') {
        console.log("Handling OPTIONS request");
        return new Response('ok', { headers: corsHeaders });
    }

    if (req.method !== 'POST') {
        return new Response(JSON.stringify({ error: 'Method Not Allowed' }), {
            status: 405,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
    }

    try {
        console.log("Processing POST request for ticket image upload...");

        // --- Authentication ---
        const authHeader = req.headers.get('Authorization');
        if (!authHeader) {
            console.error("Missing Authorization header");
            return new Response(JSON.stringify({ error: 'Missing authorization header' }), { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
        }
        const token = authHeader.replace('Bearer ', '');
        const { data: { user }, error: userError } = await supabaseAdmin.auth.getUser(token);

        if (userError || !user) {
            console.error('Auth Error:', userError?.message || 'User not found');
            return new Response(JSON.stringify({ error: 'Unauthorized - Invalid token or user not found' }), { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
        }
        const userId = user.id;
        console.log(`Authenticated user: ${userId}`);

        // --- Form Data Parsing ---
        const formData = await req.formData();
        const ticketIdString = formData.get('ticket_id') as string | null;
        const description = formData.get('description') as string | null; // Shared description for all images in this batch
        const imageFiles: File[] = [];

        // --- Basic Input Validation ---
        if (!ticketIdString) {
            console.error("Missing ticket_id in FormData");
            return new Response(JSON.stringify({ error: 'Missing ticket_id' }), { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
        }
        const ticketId = parseInt(ticketIdString, 10);
        if (isNaN(ticketId)) {
            console.error("Invalid ticket_id format:", ticketIdString);
            return new Response(JSON.stringify({ error: 'Invalid ticket_id format' }), { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
        }

        // Collect image files
        for (const [key, value] of formData.entries()) {
            if (value instanceof File && key.startsWith('image_')) { // Assuming files are named like image_0, image_1
                imageFiles.push(value);
            }
        }

        if (imageFiles.length === 0) {
            console.error("No image files found in FormData (expected keys like 'image_0', 'image_1', etc.)");
            return new Response(JSON.stringify({ error: "No image files provided (expected keys like 'image_0', 'image_1', etc.)" }), { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
        }
        console.log(`Received ${imageFiles.length} file(s) for Ticket ID: ${ticketId}. Description provided: ${description ? 'Yes' : 'No'}`);


        // --- Authorization Check: Can user access this ticket? ---
        // This RPC `check_user_can_access_ticket` should be updated to use the new `admins` table and role logic on the SQL side.
        const { data: canAccess, error: rpcError } = await supabaseAdmin.rpc(
            'check_user_can_access_ticket',
            { p_ticket_id: ticketId, p_user_id: userId } // p_user_id defaults to auth.uid() in SQL function, but explicit is fine
        );

        if (rpcError) {
            console.error(`RPC check_user_can_access_ticket failed for user ${userId}, ticket ${ticketId}:`, rpcError);
            return new Response(JSON.stringify({ error: 'Failed to verify ticket access permission' }), { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
        }

        if (canAccess !== true) {
            console.warn(`User ${userId} denied access to ticket ${ticketId}`);
            return new Response(JSON.stringify({ error: 'Forbidden - You do not have permission to upload images for this ticket' }), { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
        }
        console.log(`User ${userId} authorized for ticket ${ticketId}`);


        // --- Process Each Image ---
        const uploadPromises = imageFiles.map(async (file) => {
            // File Validation
            if (file.size > MAX_FILE_SIZE_BYTES) {
                console.warn(`Skipping large file: ${file.name} (${file.size} bytes)`);
                return { success: false, fileName: file.name, error: `File exceeds ${MAX_FILE_SIZE_MB}MB limit.`, image_id: null, url: null };
            }
            if (!ALLOWED_MIME_TYPES.includes(file.type)) {
                console.warn(`Skipping invalid file type: ${file.name} (${file.type})`);
                return { success: false, fileName: file.name, error: `Invalid file type. Allowed: ${ALLOWED_MIME_TYPES.join(', ')}`, image_id: null, url: null };
            }

            // Storage Upload
            if (!STORAGE_BUCKET_NAME) {
                console.error("Storage bucket name is not configured.");
                return { success: false, fileName: file.name, error: 'Storage bucket not configured.', image_id: null, url: null };
            }
            const fileExt = file.name.split('.').pop()?.toLowerCase() || 'bin';
            const uniqueFileName = `${uuidv4()}.${fileExt}`;
            const filePath = `tickets/${ticketId}/${uniqueFileName}`; // Structured path

            console.log(`Uploading ${file.name} to ${filePath}...`);
            const { data: uploadData, error: uploadError } = await supabaseAdmin.storage
                .from(STORAGE_BUCKET_NAME)
                .upload(filePath, file, { upsert: false, contentType: file.type });

            if (uploadError) {
                console.error(`Storage upload error for ${filePath}:`, uploadError);
                return { success: false, fileName: file.name, error: `Storage upload failed: ${uploadError.message}`, image_id: null, url: null };
            }
            if (!uploadData?.path) {
                console.error(`Storage upload successful but no path returned for ${filePath}`);
                return { success: false, fileName: file.name, error: 'Storage upload data missing after successful upload.', image_id: null, url: null };
            }
            console.log(`Uploaded ${file.name} successfully.`);

            // Get Public URL
            const { data: publicUrlData } = supabaseAdmin.storage
                .from(STORAGE_BUCKET_NAME)
                .getPublicUrl(filePath);

            const imageUrl = publicUrlData?.publicUrl;
            if (!imageUrl) {
                console.error(`Failed to get public URL for ${filePath}`);
                try { await supabaseAdmin.storage.from(STORAGE_BUCKET_NAME).remove([filePath]); } catch (rmErr) { console.error(`Storage cleanup failed for ${filePath} after URL error:`, rmErr); }
                return { success: false, fileName: file.name, error: 'Failed to construct public URL.' };
            }
            console.log(`Public URL for ${file.name}: ${imageUrl}`);

            // Database Insert
            const imageRecord: TicketImageInsert = {
                ticket_id: ticketId,
                uploaded_by: userId,
                image_url: imageUrl,
                description: description, // Use the shared description for all images in the batch
            };

            const { error: dbError } = await supabaseAdmin
                .from('ticket_images')
                .insert(imageRecord);

            if (dbError) {
                console.error(`Database insert error for image ${file.name}:`, dbError);
                // Attempt cleanup
                try { await supabaseAdmin.storage.from(STORAGE_BUCKET_NAME).remove([filePath]); } catch (rmErr) { console.error(`Storage cleanup failed for ${filePath} after DB error:`, rmErr); }
                return { success: false, fileName: file.name, error: `Database insert failed: ${dbError.message}` };
            }
            console.log(`Database record created for ${file.name}`);
            return { success: true, fileName: file.name, url: imageUrl };
        });

        const results = await Promise.allSettled(uploadPromises);

        const successfulUploads = results
            .filter((r): r is PromiseFulfilledResult<{ success: true; fileName: string; url: string }> => r.status === 'fulfilled' && r.value.success === true)
            .map(r => ({ fileName: r.value.fileName, url: r.value.url }));

        const failedUploads = results
            .filter((r): r is PromiseFulfilledResult<{ success: false; fileName: string; error: string }> | PromiseRejectedResult => r.status === 'rejected' || (r.status === 'fulfilled' && r.value.success === false))
            .map(r => {
                if (r.status === 'rejected') {
                    return { fileName: 'Unknown', error: r.reason?.message || 'Unknown upload error' };
                } else {
                    return { fileName: r.value.fileName, error: r.value.error };
                }
            });

        console.log(`Upload Summary: ${successfulUploads.length} succeeded, ${failedUploads.length} failed.`);

        if (failedUploads.length > 0 && successfulUploads.length === 0) {
            return new Response(JSON.stringify({
                message: `All ${failedUploads.length} image uploads failed.`,
                failures: failedUploads
            }), {
                status: 400, // Or 500 if server-side errors dominated
                headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            });
        }
        if (failedUploads.length > 0) {
            return new Response(JSON.stringify({
                message: `Partial success: ${successfulUploads.length} uploaded, ${failedUploads.length} failed.`,
                successes: successfulUploads,
                failures: failedUploads
            }), {
                status: 207, // Multi-Status
                headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            });
        }

        // --- Success Response (All Uploads Succeeded) ---
        return new Response(
            JSON.stringify({
                message: `${successfulUploads.length} image(s) uploaded successfully`,
                uploads: successfulUploads
            }),
            {
                headers: { ...corsHeaders, 'Content-Type': 'application/json' },
                status: 200,
            }
        );

    } catch (error: any) {
        console.error('General Upload Ticket Image Error:', error.message);
        console.error('Stack Trace:', error.stack);
        return new Response(
            JSON.stringify({ error: error.message || 'An unexpected error occurred' }),
            {
                status: error.status || 500,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            }
        );
    }
});