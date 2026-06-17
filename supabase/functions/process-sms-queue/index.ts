import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import supabaseAdmin from "../_shared/supabaseAdmin.ts";
import { corsHeaders } from "../_shared/cors.ts";

// --- Fast2SMS Configuration ---
const FASTSMS_API_KEY = Deno.env.get("FASTSMS_API_KEY");
const FASTSMS_SENDER_ID = "VDU360";
const CRON_SECRET = Deno.env.get("CRON_SECRET");

// --- DLT Template ID Mapping ---
const TEMPLATE_ID_MAP: { [key: string]: string } = {
  POST_SUBMITTED:                    '194504',
  MARKETING_ASSIGNED_TO_MARKETER:    '194503',
  MARKETING_ASSIGNED_TO_CUSTOMER:    '194502',
  MARKETING_REASSIGNED_TO_CUSTOMER:  '194501',
  RENT_APPROVAL_TO_CUSTOMER:         '194500',
  RENTED_APPROVAL_TO_OWNER:          '194499',
  TICKET_CREATED:                    '194498',
  TICKET_CLOSED:                     '194497',
  CREDITS_PURCHASED:                 '194496',
  RENT_DUE:                          '194495',
  VISIT_BOOKING_TO_OWNER:            '194494',
  VISIT_BOOKING_TO_TENANT:           '194493',
  TICKET_ASSIGNED_TO_VENDOR:         '194492',
  TICKET_VENDOR_DETAILS_TO_RAISER:   '194491',
};

const VARIABLE_MAX_LENGTH = 30;

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  // --- Security Check ---
  const authHeader = req.headers.get('Authorization');
  if (!CRON_SECRET || authHeader !== `Bearer ${CRON_SECRET}`) {
    return new Response(JSON.stringify({ error: 'Unauthorized' }), {
      status: 401,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  // --- Main Logic ---
  try {
    // 1. Fetch SMS jobs that are NOT_SENT
    const { data: smsJobs, error: fetchError } = await supabaseAdmin
      .from('service_sms_log')
      .select('*')
      .eq('status', 'NOT_SENT')
      .limit(50);

    if (fetchError) {
      console.error("Error fetching SMS jobs:", fetchError.message);
      return new Response(JSON.stringify({ error: "Failed to fetch SMS jobs" }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    if (!smsJobs || smsJobs.length === 0) {
      return new Response(JSON.stringify({ message: "No pending SMS jobs to process." }), {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const processingPromises = smsJobs.map(async (job) => {
      const templateId = TEMPLATE_ID_MAP[job.sms_type];

      if (!templateId) {
        console.error(`No template ID found for sms_type: ${job.sms_type} (Job ID: ${job.id})`);
        await supabaseAdmin.from('service_sms_log').update({ status: 'FAILED' }).eq('id', job.id);
        return { id: job.id, status: 'failed', reason: 'Invalid sms_type' };
      }

      let variables_values = '';
      if (job.variables && job.variables.length > 0) {
        const processedVars = job.variables.map(v => {
          if (v && v.length > VARIABLE_MAX_LENGTH) {
            console.warn(`Variable for job ${job.id} truncated: "${v}" -> "${v.substring(0, VARIABLE_MAX_LENGTH)}"`);
            return v.substring(0, VARIABLE_MAX_LENGTH);
          }
          return v || '';
        });
        variables_values = processedVars.join('|');
      }

      // Build API request
      const params = new URLSearchParams({
        authorization: FASTSMS_API_KEY!,
        route: 'dlt',
        sender_id: FASTSMS_SENDER_ID,
        message: templateId,
        flash: '0',
        numbers: job.to_phone_number,
      });

      if (variables_values) {
        params.append('variables_values', variables_values);
      }
      
      const fastSmsUrl = `https://www.fast2sms.com/dev/bulkV2?${params.toString()}`;

      try {
        const smsApiResponse = await fetch(fastSmsUrl, { method: 'GET' });
        const responseBody = await smsApiResponse.json();

        if (responseBody.return === true) {
          console.log(`Successfully sent SMS for job ${job.id} to ${job.to_phone_number}`);
          await supabaseAdmin.from('service_sms_log').update({ status: 'SENT' }).eq('id', job.id);
          return { id: job.id, status: 'sent' };
        } else {
          console.error(`Failed to send SMS for job ${job.id}. API Response:`, responseBody);
          await supabaseAdmin.from('service_sms_log').update({ status: 'FAILED' }).eq('id', job.id);
          return { id: job.id, status: 'failed', reason: responseBody.message || 'Unknown API error' };
        }
      } catch (apiError: any) {
        console.error(`API call failed for job ${job.id}:`, apiError.message);
        await supabaseAdmin.from('service_sms_log').update({ status: 'FAILED' }).eq('id', job.id);
        return { id: job.id, status: 'failed', reason: apiError.message };
      }
    });

    const results = await Promise.all(processingPromises);

    const sentCount = results.filter(r => r.status === 'sent').length;
    const failedCount = results.filter(r => r.status === 'failed').length;

    return new Response(JSON.stringify({
      message: "SMS processing complete.",
      total_processed: results.length,
      sent: sentCount,
      failed: failedCount,
    }), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });

  } catch (error: any) {
    console.error("Main function error:", error.message);
    return new Response(JSON.stringify({ error: "An unexpected error occurred." }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});