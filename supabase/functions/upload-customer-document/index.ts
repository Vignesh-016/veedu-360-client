import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { v4 as uuidv4 } from 'npm:uuid';
import { corsHeaders } from '../_shared/cors.ts';
import supabaseAdmin from "../_shared/supabaseAdmin.ts";
import { Database } from '../../../src/database.types.ts';

// --- Configuration ---
const STORAGE_BUCKET_NAME = Deno.env.get('STORAGE_BUCKET');
const MAX_DOC_SIZE_MB = 15;
const MAX_DOC_SIZE_BYTES = MAX_DOC_SIZE_MB * 1024 * 1024;

type AdminRoleEnum = Database['public']['Enums']['admin_role_enum'];

Deno.serve(async (req) => {
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders });
    }

    try {
        console.log("Processing POST request for customer document upload...");

        const authHeader = req.headers.get('Authorization');
        if (!authHeader) {
            return new Response(JSON.stringify({ error: 'Missing authorization header' }), { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
        }
        const token = authHeader.replace('Bearer ', '');
        const { data: { user }, error: userError } = await supabaseAdmin.auth.getUser(token);

        if (userError || !user) {
            console.warn('Unauthorized access attempt - userError or no user:', userError);
            return new Response(JSON.stringify({ error: 'Unauthorized' }), { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
        }
        const adminUserId = user.id;

        // Authorization Check: User must be an admin with specific roles
        let userIsAuthorizedAdmin = false;
        const permittedAdminRoles: AdminRoleEnum[] = ['super-admin', 'telecalling-owner-team', 'telecalling-tenant-team'];

        const { data: adminRecord, error: adminRecordError } = await supabaseAdmin
            .from('admins')
            .select('roles')
            .eq('user_id', adminUserId)
            .eq('is_active', true)
            .maybeSingle();

        if (adminRecordError) {
            console.error(`DB error fetching admin record for user ${adminUserId}:`, adminRecordError);
            return new Response(JSON.stringify({ error: 'Failed to verify admin status' }), { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
        }
        if (adminRecord && adminRecord.roles) {
            userIsAuthorizedAdmin = adminRecord.roles.some(role => permittedAdminRoles.includes(role));
        }

        if (!userIsAuthorizedAdmin) {
            console.warn(`User ${adminUserId} is not an authorized admin for customer document upload. Roles: ${adminRecord?.roles}`);
            return new Response(JSON.stringify({ error: 'Forbidden - Insufficient privileges' }), { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
        }
        console.log(`Admin ${adminUserId} authorized for customer document upload.`);


        const formData = await req.formData();
        const customerUserId = formData.get('customer_user_id') as string | null;
        const documentFile = formData.get('document_file') as File | null;
        const documentType = formData.get('document_type') as string | null;
        const description = formData.get('description') as string | null;

        if (!customerUserId || !documentFile || !documentType) {
            return new Response(JSON.stringify({ error: 'Missing customer_user_id, document_file, or document_type' }), { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
        }

        // File Validation
        if (documentFile.size > MAX_DOC_SIZE_BYTES) {
            return new Response(JSON.stringify({ error: `File exceeds ${MAX_DOC_SIZE_MB}MB limit.` }), { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
        }
        console.log(`File validation passed for ${documentFile.name}`);


        if (!STORAGE_BUCKET_NAME) {
            console.error("STORAGE_BUCKET_NAME is not configured in environment variables.");
            throw new Error("Storage bucket name is not configured.");
        }
        const fileExt = documentFile.name.split('.').pop()?.toLowerCase() || 'bin';
        const uniqueFileName = `${documentType.replace(/[^a-zA-Z0-9]/g, '_')}_${uuidv4()}.${fileExt}`;
        const filePath = `customer_documents/${customerUserId}/${uniqueFileName}`;

        console.log(`Attempting to upload to bucket: ${STORAGE_BUCKET_NAME}, path: ${filePath}`);
        const { data: uploadData, error: uploadError } = await supabaseAdmin.storage
            .from(STORAGE_BUCKET_NAME)
            .upload(filePath, documentFile, { upsert: false, contentType: documentFile.type });

        if (uploadError) {
            console.error(`Storage upload error for path ${filePath}:`, uploadError);
            throw new Error(`Storage upload failed: ${uploadError.message}`);
        }
        if (!uploadData?.path) {
            console.error(`Storage upload data missing path after successful upload for ${filePath}`);
            throw new Error('Storage upload data missing after successful upload.');
        }
        console.log(`File uploaded successfully to path: ${uploadData.path}`);


        const { data: publicUrlData } = supabaseAdmin.storage
            .from(STORAGE_BUCKET_NAME)
            .getPublicUrl(filePath);

        const documentUrl = publicUrlData?.publicUrl;
        if (!documentUrl) {
            console.error(`Failed to get public URL for path: ${filePath}. Attempting cleanup.`);
            try { await supabaseAdmin.storage.from(STORAGE_BUCKET_NAME).remove([filePath]); } catch (rmErr) { console.error("Storage cleanup failed after URL generation failure:", rmErr); }
            throw new Error('Failed to construct public URL for uploaded document.');
        }
        console.log(`Public URL generated: ${documentUrl}`);

        const { data: dbRecord, error: dbInsertError } = await supabaseAdmin
            .from('customer_documents')
            .insert({
                user_id: customerUserId,
                document_type: documentType,
                document_url: documentUrl,
                file_name: documentFile.name,
                description: description,
                uploaded_by: adminUserId,
            })
            .select('document_id')
            .single();

        if (dbInsertError) {
            console.error(`Database insert error for customer_documents:`, dbInsertError);
            try {
                await supabaseAdmin.storage.from(STORAGE_BUCKET_NAME).remove([filePath]);
                console.log(`Cleaned up storage file ${filePath} after DB insert error.`);
            } catch (rmErr) {
                console.error("Storage cleanup failed after DB insert error:", rmErr);
            }
            throw new Error(`Database record creation failed: ${dbInsertError.message}`);
        }

        if (!dbRecord || !dbRecord.document_id) {
            console.error(`Database insert for customer_documents did not return document_id or record.`);
            try {
                await supabaseAdmin.storage.from(STORAGE_BUCKET_NAME).remove([filePath]);
                console.log(`Cleaned up storage file ${filePath} after missing document_id.`);
            } catch (rmErr) {
                console.error("Storage cleanup failed after missing document_id:", rmErr);
            }
            throw new Error(`Database record creation failed: Did not retrieve document ID.`);
        }

        const documentId = dbRecord.document_id;

        console.log(`Customer document ${documentId} recorded for user ${customerUserId}`);

        return new Response(
            JSON.stringify({
                document_id: documentId,
                document_url: documentUrl,
                file_name: documentFile.name,
                document_type: documentType
            }),
            { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
        );

    } catch (error: any) {
        console.error('Overall Upload Customer Document Error:', error, error.stack);
        const status = error.status || (error.message?.includes("Storage upload failed") || error.message?.includes("Database record creation failed") ? 500 : 400);
        return new Response(
            JSON.stringify({ error: error.message || 'An unexpected error occurred' }),
            { status: status, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
    }
});