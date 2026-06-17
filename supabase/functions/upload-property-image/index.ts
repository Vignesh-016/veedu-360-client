import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { v4 as uuidv4 } from 'npm:uuid';
import { corsHeaders } from '../_shared/cors.ts';
import supabaseAdmin from "../_shared/supabaseAdmin.ts";
import { Database } from '../../../src/database.types.ts';

// --- Configuration ---
const STORAGE_BUCKET_NAME = Deno.env.get('STORAGE_BUCKET');
const MAX_FILE_SIZE_MB = 10;
const MAX_FILE_SIZE_BYTES = MAX_FILE_SIZE_MB * 1024 * 1024;
const ALLOWED_MIME_TYPES = [
    'image/jpeg',
    'image/png',
    'image/webp'
];
// -------------------

// Explicitly type the insert payload based on the table definition
type PropertyImageInsert = Database['public']['Tables']['property_images']['Insert'];
type AdminRoleEnum = Database['public']['Enums']['admin_role_enum'];

Deno.serve(async (req) => {
    // Handle CORS preflight request
    if (req.method === 'OPTIONS') {
        console.log("Handling OPTIONS request");
        return new Response('ok', { headers: corsHeaders });
    }

    try {
        console.log("Processing POST request for property image upload...");

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
        const propertyId = formData.get('property_id') as string | null;
        const imageFile = formData.get('image_file') as File | null;
        const description = formData.get('description') as string | null;
        const isInternalImageString = formData.get('is_internal_image') as string | null; // Expect 'true' or 'false'
        const displayOrderString = formData.get('display_order') as string | null;

        const isInternalImage = isInternalImageString === 'true';
        const displayOrder = displayOrderString ? parseInt(displayOrderString, 10) : 0;
        if (displayOrderString && isNaN(displayOrder)) {
            console.warn(`Invalid display_order value: ${displayOrderString}. Defaulting to 0.`);
        }


        // --- Basic Input Validation ---
        if (!propertyId) {
            console.error("Missing property_id in FormData");
            return new Response(JSON.stringify({ error: 'Missing property_id' }), { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
        }
        if (!imageFile) {
            console.error("Missing image_file in FormData");
            return new Response(JSON.stringify({ error: 'Missing image_file' }), { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
        }
        console.log(`Received data - Property ID: ${propertyId}, File: ${imageFile.name} (${imageFile.type}, ${imageFile.size} bytes), Description: ${description ? 'Yes' : 'No'}, Internal: ${isInternalImage}, Order: ${displayOrder}`);

        // --- Authorization Check: Admin with specific roles OR User must own the property ---
        let userIsAuthorizedAdmin = false;
        const permittedAdminRoles: AdminRoleEnum[] = ['super-admin', 'telecalling-owner-team', 'marketing-team'];

        const { data: adminRecord, error: adminRecordError } = await supabaseAdmin
            .from('admins')
            .select('roles')
            .eq('user_id', userId)
            .eq('is_active', true)
            .maybeSingle();

        if (adminRecordError) {
            console.error(`Database error fetching admin record for user ${userId}:`, adminRecordError);
            // Fail safely, do not grant permission
        } else if (adminRecord && adminRecord.roles) {
            userIsAuthorizedAdmin = adminRecord.roles.some(role => permittedAdminRoles.includes(role));
        }
        console.log(`User Admin Role Check: IsAuthorizedAdmin=${userIsAuthorizedAdmin}`);

        let isOwner = false;
        if (!userIsAuthorizedAdmin) { // Only check ownership if not an authorized admin
            const { data: propertyData, error: propertyError } = await supabaseAdmin
                .from('properties')
                .select('submitter, admin_status') // Also fetch admin_status to check if editable by owner
                .eq('property_id', propertyId)
                .maybeSingle();

            if (propertyError) {
                console.error(`Database error fetching property ${propertyId}:`, propertyError);
                return new Response(JSON.stringify({ error: 'Database error checking property ownership' }), { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
            }
            if (!propertyData) {
                console.error(`Property not found: ${propertyId}`);
                return new Response(JSON.stringify({ error: 'Property not found' }), { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
            }
            // Owner can upload if property status is SUBMITTED or REJECTED
            if (propertyData.submitter === userId &&
                (propertyData.admin_status === 'SUBMITTED' || propertyData.admin_status === 'REJECTED')) {
                isOwner = true;
            }
            console.log(`Ownership Check: Submitter=${propertyData.submitter}, User=${userId}, Property Status=${propertyData.admin_status}, IsOwnerAllowed=${isOwner}`);
        }

        // Final Authorization Check
        if (!userIsAuthorizedAdmin && !isOwner) {
            console.error(`User ${userId} NOT authorized to upload image for property ${propertyId}`);
            return new Response(JSON.stringify({ error: 'Forbidden - You do not have permission to upload images for this property or the property is not in an editable state.' }), { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
        }
        console.log(`User ${userId} authorized for property ${propertyId}`);

        // --- File Validation ---
        if (imageFile.size > MAX_FILE_SIZE_BYTES) {
            console.error(`File too large: ${imageFile.name} (${imageFile.size} bytes)`);
            return new Response(JSON.stringify({ error: `File exceeds ${MAX_FILE_SIZE_MB}MB limit.` }), { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
        }
        if (!ALLOWED_MIME_TYPES.includes(imageFile.type)) {
            console.error(`Invalid file type: ${imageFile.name} (${imageFile.type})`);
            return new Response(JSON.stringify({ error: `Invalid file type. Allowed types: ${ALLOWED_MIME_TYPES.join(', ')}` }), { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
        }
        console.log(`File validation passed for ${imageFile.name}`);

        // --- Storage Upload ---
        if (!STORAGE_BUCKET_NAME) {
            throw new Error("Storage bucket name is not configured in environment variables.");
        }
        const fileExt = imageFile.name.split('.').pop()?.toLowerCase() || 'bin';
        const uniqueFileName = `${uuidv4()}.${fileExt}`;
        const filePath = `properties/${propertyId}/${uniqueFileName}`;

        console.log(`Uploading file to storage path: ${filePath}`);
        const { data: uploadData, error: uploadError } = await supabaseAdmin.storage
            .from(STORAGE_BUCKET_NAME)
            .upload(filePath, imageFile, {
                upsert: false,
                contentType: imageFile.type,
            });

        if (uploadError) {
            console.error(`Storage upload error for ${filePath}:`, uploadError);
            throw new Error(`Storage upload failed: ${uploadError.message}`);
        }
        console.log(`File uploaded successfully: ${uploadData?.path}`);

        // --- Get Public URL ---
        const { data: publicUrlData } = supabaseAdmin.storage
            .from(STORAGE_BUCKET_NAME)
            .getPublicUrl(filePath);

        const imageUrl = publicUrlData?.publicUrl;
        if (!imageUrl) {
            console.error(`Failed to get public URL for ${filePath}. Upload Data: ${JSON.stringify(publicUrlData)}`);
            try { await supabaseAdmin.storage.from(STORAGE_BUCKET_NAME).remove([filePath]); } catch (rmErr) { console.error("Storage cleanup failed after URL error:", rmErr); }
            throw new Error('Failed to construct public URL for uploaded file.');
        }
        console.log(`Public URL obtained: ${imageUrl}`);

        // --- Database Insert (Direct) ---
        const insertPayload: PropertyImageInsert = {
            property_id: propertyId,
            uploaded_by: userId, // This is auth.users.id, which is fine. Admins are also users.
            image_url: imageUrl,
            description: description,
            display_order: !isNaN(displayOrder) ? displayOrder : 0, // Use parsed or default
            is_internal_image: userIsAuthorizedAdmin ? isInternalImage : false // Only admins can set internal_image flag. Owners always upload public images.
        };

        console.log("Database insert payload:", insertPayload);

        const { data: dbData, error: dbError } = await supabaseAdmin
            .from('property_images')
            .insert(insertPayload)
            .select('image_id')
            .single();

        if (dbError) {
            console.error(`Database insert error for property ${propertyId}:`, dbError);
            // Attempt cleanup on DB failure
            try { await supabaseAdmin.storage.from(STORAGE_BUCKET_NAME).remove([filePath]); } catch (rmErr) { console.error("Storage cleanup failed after DB error:", rmErr); }
            throw new Error(`Database insert failed: ${dbError.message}`);
        }

        if (!dbData?.image_id) {
            console.error(`Database insert succeeded but did not return image_id for property ${propertyId}`);
            // Attempt cleanup on missing ID
            try { await supabaseAdmin.storage.from(STORAGE_BUCKET_NAME).remove([filePath]); } catch (rmErr) { console.error("Storage cleanup failed after missing ID error:", rmErr); }
            throw new Error(`Database insert failed: Could not retrieve generated image ID.`);
        }
        console.log(`Database record created, Image ID: ${dbData.image_id}`);


        // --- Success Response ---
        return new Response(
            JSON.stringify({
                image_id: dbData.image_id,
                image_url: imageUrl
            }),
            {
                headers: { ...corsHeaders, 'Content-Type': 'application/json' },
                status: 200,
            }
        );

    } catch (error: any) {
        console.error('Upload Property Image Error:', error);
        return new Response(
            JSON.stringify({ error: error.message || 'An unexpected error occurred' }),
            {
                status: error.status || 500, // Use status from error if available
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            }
        );
    }
});