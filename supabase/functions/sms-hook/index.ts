import "jsr:@supabase/functions-js/edge-runtime.d.ts"
import { Webhook } from "https://esm.sh/standardwebhooks@1.0.0";
import supabaseAdmin from "../_shared/supabaseAdmin.ts";
import { corsHeaders } from "../_shared/cors.ts";

// Rate limiting constants
const OTP_RATE_LIMIT_WINDOW_MS = 60 * 1000; // 1 minute
const OTP_DAILY_LIMIT_WINDOW_MS = 24 * 60 * 60 * 1000; // 24 hours
const MAX_OTP_PER_WINDOW = 3;
const MAX_OTP_PER_DAY = 10;

// Fast2SMS Configuration
const FASTSMS_API_KEY = Deno.env.get("FASTSMS_API_KEY");
const FASTSMS_SENDER_ID = Deno.env.get("FASTSMS_SENDER_ID") || "VDU360";
const FASTSMS_DLT_MESSAGE_ID = Deno.env.get("FASTSMS_DLT_MESSAGE_ID") || "194505";

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  if (!FASTSMS_API_KEY) {
    console.error("FASTSMS_API_KEY is not set in environment variables.");
    return new Response(
      JSON.stringify({ error: "SMS gateway not configured properly on the server." }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }

  const payload = await req.text();
  const base64_secret = Deno.env.get("SEND_SMS_HOOK_SECRET")?.replace('v1,whsec_', '');

  if (!base64_secret) {
    console.error("SEND_SMS_HOOK_SECRET is not set in environment variables or is invalid.");
    return new Response(
      JSON.stringify({ error: "Webhook secret not configured." }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }

  const wh = new Webhook(base64_secret);

  try {
    const verifiedPayload = wh.verify(payload, Object.fromEntries(req.headers));
    const { user, sms } = verifiedPayload;

    if (!user || !user.new_phone || !sms || !sms.otp) {
      console.error("Verified payload is missing required fields (user.new_phone or sms.otp). Payload:", verifiedPayload);
      return new Response(
        JSON.stringify({ error: "Invalid payload structure after verification." }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    var phoneNumber = user.new_phone;
    const otpValue = sms.otp;

    if (phoneNumber && phoneNumber.length > 10) {
      phoneNumber = phoneNumber.slice(-10);
    }

    // --- Rate Limiting Check ---
    const currentTime = new Date();
    const oneMinuteAgoISO = new Date(currentTime.getTime() - OTP_RATE_LIMIT_WINDOW_MS).toISOString();
    const oneDayAgoISO = new Date(currentTime.getTime() - OTP_DAILY_LIMIT_WINDOW_MS).toISOString();

    const { count: countLastMinute, error: minuteError } = await supabaseAdmin
      .from('otp_sent_log')
      .select('*', { count: 'exact', head: true })
      .eq('phone_number', phoneNumber)
      .gte('sent_at', oneMinuteAgoISO);

    if (minuteError) {
      console.error(`Error checking minute rate limit for ${phoneNumber}:`, minuteError.message);
    } else if (countLastMinute !== null && countLastMinute >= MAX_OTP_PER_WINDOW) {
      console.warn(`Minute rate limit exceeded for ${phoneNumber}: ${countLastMinute} attempts.`);
      return new Response(
        JSON.stringify({ error: "Too many OTP requests. Please try again in a minute." }),
        { status: 429, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const { count: countLastDay, error: dayError } = await supabaseAdmin
      .from('otp_sent_log')
      .select('*', { count: 'exact', head: true })
      .eq('phone_number', phoneNumber)
      .gte('sent_at', oneDayAgoISO);

    if (dayError) {
      console.error(`Error checking daily rate limit for ${phoneNumber}:`, dayError.message);
    } else if (countLastDay !== null && countLastDay >= MAX_OTP_PER_DAY) {
      console.warn(`Daily rate limit exceeded for ${phoneNumber}: ${countLastDay} attempts.`);
      return new Response(
        JSON.stringify({ error: "Daily OTP limit reached. Please try again later." }),
        { status: 429, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }
    // --- End Rate Limiting Check ---

    // --- Send SMS via Fast2SMS ---
    const params = new URLSearchParams({
      authorization: FASTSMS_API_KEY,
      route: 'dlt',
      sender_id: FASTSMS_SENDER_ID,
      message: FASTSMS_DLT_MESSAGE_ID,
      variables_values: `${otpValue}|`,
      flash: '1',
      numbers: phoneNumber,
    });
    const fastSmsUrl = `https://www.fast2sms.com/dev/bulkV2?${params.toString()}`;

    let smsApiResponse;
    try {
      console.log(`Attempting to send OTP to ${phoneNumber} using template ${FASTSMS_DLT_MESSAGE_ID}.`);
      smsApiResponse = await fetch(fastSmsUrl, { method: 'GET' });
    } catch (fetchError: any) {
      console.error(`Network error calling Fast2SMS API for ${phoneNumber}:`, fetchError.message);
      const { error: logErr } = await supabaseAdmin.from('otp_sent_log').insert({ phone_number: phoneNumber });
      if (logErr) console.error(`Failed to log OTP attempt after network error for ${phoneNumber}:`, logErr.message);

      return new Response(
        JSON.stringify({ error: "Failed to connect to SMS gateway." }),
        { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }
    // --- End Send SMS ---

    // --- Log OTP Attempt ---
    const { error: logError } = await supabaseAdmin.from('otp_sent_log').insert({ phone_number: phoneNumber });
    if (logError) {
      console.error(`Error logging OTP attempt for ${phoneNumber} after API call:`, logError.message);
    }
    // --- End Log OTP Attempt ---

    // --- Process Fast2SMS Response ---
    const responseBodyText = await smsApiResponse.text();
    if (!smsApiResponse.ok) {
      console.error(`Fast2SMS API Error for ${phoneNumber}: ${smsApiResponse.status} ${smsApiResponse.statusText}. Body: ${responseBodyText}`);
      return new Response(
        JSON.stringify({ error: `SMS gateway returned an error: ${smsApiResponse.statusText}` }),
        { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    try {
      const smsApiResult = JSON.parse(responseBodyText);
      const isSuccessStatusCode = smsApiResult.status_code === undefined ||
        smsApiResult.status_code === 200 ||
        smsApiResult.status_code === "200";

      if (smsApiResult.return === true && isSuccessStatusCode) {
        console.log(`SMS sent successfully to ${phoneNumber}. Fast2SMS API Response:`, smsApiResult);
        return new Response(
          JSON.stringify({ message: "OTP SMS sent successfully." }),
          { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      } else {
        console.error(`Failed to send SMS via Fast2SMS for ${phoneNumber}. API Response:`, smsApiResult);
        const errorMessage = smsApiResult.message?.join ? smsApiResult.message.join(', ') : (smsApiResult.message || 'Unknown SMS gateway error');
        return new Response(
          JSON.stringify({ error: `SMS gateway indicated failure: ${errorMessage}` }),
          { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }
    } catch (jsonParseError: any) {
      console.error(`Error parsing Fast2SMS JSON response for ${phoneNumber}: ${jsonParseError.message}. Body: ${responseBodyText}`);
      return new Response(
        JSON.stringify({ error: "Received an invalid response from SMS gateway." }),
        { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }
    // --- End Process Fast2SMS Response ---

  } catch (error: any) {
    console.error("Main webhook processing error:", error.message, error.stack);
    if (error.name === 'WebhookVerificationError' || error.name === 'SignatureVerificationError') {
      return new Response(
        JSON.stringify({ error: `Webhook verification failed: ${error.message}` }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }
    return new Response(
      JSON.stringify({ error: `Failed to process webhook: ${error.message || JSON.stringify(error)}` }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});