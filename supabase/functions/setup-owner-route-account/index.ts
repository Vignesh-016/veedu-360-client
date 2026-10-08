/// <reference path="../global.d.ts" />
import supabaseAdmin from "../_shared/supabaseAdmin.ts";
import { getRazorpayCredentials } from "../_shared/razorpayCredentials.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization,apikey,content-type,x-client-info",
  "Access-Control-Allow-Methods": "OPTIONS,POST",
};
const out = (body: Record<string, unknown>, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
const normalizeIndianMobile = (raw: string) => {
  const digits = raw.replace(/\D/g, "");
  if (digits.length === 12 && digits.startsWith("91")) return digits.slice(2);
  if (digits.length === 11 && digits.startsWith("0")) return digits.slice(1);
  if (digits.length === 10) return digits;
  throw new Error(
    "Owner phone number is invalid for Razorpay stakeholder verification.",
  );
};
const canonicalIndianState = (raw: string) => {
  const value = raw
    .trim()
    .toLowerCase()
    .replace(/[._-]+/g, " ")
    .replace(/\s+/g, " ");
  const states: Record<string, string> = {
    "tamil nadu": "Tamil Nadu",
    tamilnadu: "Tamil Nadu",
    tn: "Tamil Nadu",
    kerala: "Kerala",
    karnataka: "Karnataka",
    "andhra pradesh": "Andhra Pradesh",
    telangana: "Telangana",
    maharashtra: "Maharashtra",
    delhi: "Delhi",
  };
  return states[value] || raw.trim();
};
Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    console.log("OPTIONS request handled");
    return new Response(null, { status: 204, headers: corsHeaders });
  }
  if (req.method !== "POST") return out({ error: "Method not allowed" }, 405);
  const auth = req.headers.get("Authorization");
  if (!auth?.startsWith("Bearer ")) return out({ error: "Unauthorized" }, 401);
  const {
    data: { user },
    error,
  } = await supabaseAdmin.auth.getUser(auth.slice(7));
  if (error || !user) return out({ error: "Unauthorized" }, 401);
  const body = await req.json().catch(() => ({}));
  const target = body.owner_user_id || user.id;
  const refreshOnly = body.refresh_only === true;
  const { data: admin } = await (supabaseAdmin as any)
    .from("admins")
    .select("roles")
    .eq("user_id", user.id)
    .maybeSingle();
  const isAdmin = admin?.roles?.length > 0;
  if (target !== user.id && !isAdmin) return out({ error: "Forbidden" }, 403);
  const { data: profile } = await (supabaseAdmin as any)
    .from("owner_profiles")
    .select("address_line1,address_line2,city,state,pincode,pan_number")
    .eq("owner_user_id", target)
    .maybeSingle();
  const { data: payout } = await (supabaseAdmin as any)
    .from("owner_payout_accounts")
    .select("*")
    .eq("owner_user_id", target)
    .maybeSingle();
  console.log("POST onboarding started");
  if (!profile || !payout)
    return out(
      { error: "Owner profile or payout account is incomplete." },
      400,
    );
  console.log("Owner profile loaded");
  console.log("Payout account loaded");
  if (!payout.route_consent_accepted)
    return out({ error: "Route consent is required." }, 400);
  if (
    !profile.address_line1 ||
    !profile.city ||
    !profile.state ||
    !profile.pincode
  )
    return out({ error: "Owner address is incomplete." }, 400);
  if (!profile.pan_number) return out({ error: "Owner PAN is missing." }, 400);
  if (!payout.account_number || !payout.ifsc_code)
    return out({ error: "Owner bank details are incomplete." }, 400);
  const { keyId, keySecret } = getRazorpayCredentials();
  if (!keyId || !keySecret)
    return out({ error: "Razorpay is not configured." }, 500);
  const headers = {
    Authorization: `Basic ${btoa(`${keyId}:${keySecret}`)}`,
    "Content-Type": "application/json",
  };
  const call = async (
    url: string,
    method = "GET",
    payload?: unknown,
    step = "razorpay_request",
  ) => {
    const r = await fetch(`https://api.razorpay.com${url}`, {
      method,
      headers,
      body: payload ? JSON.stringify(payload) : undefined,
    });
    const d = await r.json().catch(() => ({}));
    if (!r.ok) {
      const e = d?.error || {};
      const description =
        e.description || e.reason || e.code || "Request rejected";
      const err = new Error(
        `Razorpay request failed (${r.status}): ${description}`,
      );
      (err as any).step = step;
      (err as any).upstreamStatus = r.status;
      (err as any).safeCode = e.code;
      (err as any).requestId =
        r.headers.get("x-razorpay-request-id") ||
        r.headers.get("x-request-id") ||
        null;
      throw err;
    }
    return d;
  };
  const redactConfiguration = (configuration: any) => {
    if (!configuration || typeof configuration !== "object")
      return configuration;
    const copy = JSON.parse(JSON.stringify(configuration));
    const redact = (value: any) => {
      if (!value || typeof value !== "object") return;
      for (const key of Object.keys(value)) {
        if (
          ["account_number", "pan", "api_key", "api_secret"].includes(
            key.toLowerCase(),
          )
        )
          value[key] = "[REDACTED]";
        else redact(value[key]);
      }
    };
    redact(copy);
    return copy;
  };
  const safeProductLog = (product: any) => ({
    activation_status: product?.activation_status || null,
    requirements: Array.isArray(product?.requirements)
      ? product.requirements.map((r: any) => ({
          field_reference: r?.field_reference || null,
          reason_code: r?.reason_code || null,
          status: r?.status || null,
        }))
      : [],
    requested_configuration: redactConfiguration(
      product?.requested_configuration,
    ),
    active_configuration: redactConfiguration(product?.active_configuration),
  });
  try {
    const targetUser = (await supabaseAdmin.auth.admin.getUserById(target)).data
      .user;
    if (!targetUser) return out({ error: "Owner user not found." }, 400);
    let accountId = payout.razorpay_account_id;
    let stakeholderId = payout.razorpay_stakeholder_id;
    let productId = payout.razorpay_product_id;
    let account: any;
    const fullName =
      targetUser.user_metadata?.full_name ||
      targetUser.user_metadata?.name ||
      payout.account_holder_name;
    const phone = normalizeIndianMobile(String(targetUser.phone || ""));
    const category = Deno.env.get("RAZORPAY_ROUTE_CATEGORY");
    const subcategory = Deno.env.get("RAZORPAY_ROUTE_SUBCATEGORY");
    if (!accountId) {
      if (!category || !subcategory)
        return out(
          { error: "Route business category configuration is pending." },
          400,
        );
      console.log("Creating Razorpay linked account");
      account = await call(
        "/v2/accounts",
        "POST",
        {
          email: targetUser.email,
          phone,
          legal_business_name: fullName,
          customer_facing_business_name: fullName,
          business_type: "individual",
          reference_id: target,
          profile: {
            category,
            subcategory,
            addresses: {
              registered: {
                street1: profile.address_line1,
                street2: profile.address_line2 || undefined,
                city: profile.city,
                state: canonicalIndianState(profile.state),
                postal_code: profile.pincode,
                country: "IN",
              },
            },
          },
        },
        "linked_account",
      );
      accountId = account?.id;
      if (!accountId)
        throw new Error(
          "Razorpay linked account response did not include an account ID.",
        );
      const { error } = await (supabaseAdmin as any)
        .from("owner_payout_accounts")
        .update({
          razorpay_account_id: accountId,
          razorpay_account_status: account.status || "created",
          linked_account_created_at: new Date().toISOString(),
          payment_eligible: false,
          updated_at: new Date().toISOString(),
        })
        .eq("owner_user_id", target);
      if (error)
        throw new Error(
          "Linked account was created but could not be saved locally.",
        );
    } else account = await call(`/v2/accounts/${accountId}`);
    if (!stakeholderId) {
      console.log("Creating stakeholder");
      const stakeholder = await call(
        `/v2/accounts/${accountId}/stakeholders`,
        "POST",
        {
          name: fullName,
          email: targetUser.email,
          phone: { primary: phone },
          percentage_ownership: 100,
          relationship: { director: false, executive: false },
          addresses: {
            residential: {
              street: [profile.address_line1, profile.address_line2]
                .filter(Boolean)
                .join(", "),
              city: profile.city,
              state: canonicalIndianState(profile.state),
              postal_code: profile.pincode,
              country: "IN",
            },
          },
          kyc: { pan: profile.pan_number },
        },
        "stakeholder",
      );
      stakeholderId = stakeholder?.id;
      if (!stakeholderId)
        throw new Error("Razorpay stakeholder response did not include an ID.");
      await (supabaseAdmin as any)
        .from("owner_payout_accounts")
        .update({
          razorpay_stakeholder_id: stakeholderId,
          updated_at: new Date().toISOString(),
        })
        .eq("owner_user_id", target);
    }
    let product: any;
    if (!productId) {
      console.log("Requesting Route product");
      product = await call(
        `/v2/accounts/${accountId}/products`,
        "POST",
        { product_name: "route", tnc_accepted: true },
        "route_product",
      );
      productId = product?.id;
      if (!productId)
        throw new Error("Razorpay product response did not include an ID.");
      await (supabaseAdmin as any)
        .from("owner_payout_accounts")
        .update({
          razorpay_product_id: productId,
          updated_at: new Date().toISOString(),
        })
        .eq("owner_user_id", target);
    } else
      product = await call(`/v2/accounts/${accountId}/products/${productId}`);
    const before = String(
      product.activation_status || product.status || "requested",
    ).toLowerCase();
    console.log(
      "Razorpay product inspection:",
      JSON.stringify(safeProductLog(product)),
    );
    const requirements = Array.isArray(product.requirements)
      ? product.requirements
      : [];
    const settlementNeedsUpdate = requirements.some(
      (r: any) =>
        String(r?.field_reference || "")
          .toLowerCase()
          .includes("settlement") &&
        ["missing", "invalid", "required", "needs_clarification"].includes(
          String(r?.status || r?.reason_code || "").toLowerCase(),
        ),
    );
    const currentSettlement =
      product.active_configuration?.settlements ||
      product.requested_configuration?.settlements;
    const bankChanged =
      JSON.stringify(currentSettlement || {}) !==
      JSON.stringify({
        account_number: payout.account_number,
        ifsc_code: payout.ifsc_code,
        beneficiary_name: payout.account_holder_name,
      });
    // A bank edit resets the local payout row to pending. Re-submit the
    // settlement configuration to the existing Route product in that state;
    // never create a second linked account for a bank change.
    const bankConfigUpdated = bankChanged && (settlementNeedsUpdate || payout.status === 'PENDING_VERIFICATION' || payout.payment_eligible !== true);
    if (bankConfigUpdated)
      product = await call(
        `/v2/accounts/${accountId}/products/${productId}`,
        "PATCH",
        {
          settlements: {
            account_number: payout.account_number,
            ifsc_code: payout.ifsc_code,
            beneficiary_name: payout.account_holder_name,
          },
          tnc_accepted: true,
        },
        "bank_configuration",
      );
    if (bankConfigUpdated)
      product = await call(`/v2/accounts/${accountId}/products/${productId}`);
    const status = String(
      product.activation_status || product.status || "requested",
    ).toLowerCase();
    const eligible = status === "activated";
    const mapped =
      status === "activated"
        ? "Verified"
        : status === "needs_clarification"
          ? "Action Required"
          : status === "verification_failed"
            ? "Verification Failed"
            : status === "suspended"
              ? "Suspended"
              : "Verification In Progress";
    const reason = eligible
      ? null
      : status === "needs_clarification"
        ? "Bank account verification requires attention."
        : status === "under_review"
          ? "Verification Under Review"
          : status === "verification_failed"
            ? "Razorpay could not verify the submitted bank details."
            : "Razorpay is verifying the payout details.";
    await (supabaseAdmin as any)
      .from("owner_payout_accounts")
      .update({
        razorpay_product_status: status,
        payment_eligible: eligible,
        status: eligible
          ? "VERIFIED"
          : status === "needs_clarification"
            ? "ACTION_REQUIRED"
            : status === "verification_failed"
              ? "VERIFICATION_FAILED"
              : status === "suspended"
                ? "SUSPENDED"
                : "PENDING_VERIFICATION",
        route_onboarding_error: reason,
        last_status_checked_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      })
      .eq("owner_user_id", target);
    console.log(
      "Razorpay product inspection:",
      JSON.stringify(safeProductLog(product)),
    );
    const safeProduct = safeProductLog(product);
    return out({
      success: true,
      account_id: accountId,
      product_id: productId,
      status_before: before,
      requirements: safeProduct.requirements,
      requested_configuration: safeProduct.requested_configuration,
      active_configuration: safeProduct.active_configuration,
      bank_config_updated: bankConfigUpdated,
      status_after: status,
      payment_eligible: eligible,
      message: eligible
        ? "Owner payout is verified and ready."
        : status === "needs_clarification"
          ? "Additional payout verification is required."
          : status === "under_review"
            ? "Payout verification is under review."
            : "Payout verification has been submitted.",
      action_required: reason,
    });
  } catch (e) {
    const safe = e instanceof Error ? e.message : "Onboarding failed";
    const step = (e as any)?.step || "onboarding";
    const status = (e as any)?.upstreamStatus || 502;
    const denied =
      status === 400 &&
      /access denied/i.test(safe) &&
      step === "linked_account";
    const message = denied
      ? "Razorpay Route is not allowing a new payout account to be created. Please check the Route account configuration or contact Razorpay support."
      : safe;
    console.error("Route onboarding failed:", safe);
    await (supabaseAdmin as any)
      .from("owner_payout_accounts")
      .update({
        route_onboarding_error: denied
          ? "Razorpay Route linked-account creation was denied."
          : safe,
        payment_eligible: false,
        updated_at: new Date().toISOString(),
      })
      .eq("owner_user_id", target);
    return out(
      {
        success: false,
        code: denied ? "RAZORPAY_ROUTE_ACCESS_DENIED" : undefined,
        step,
        error: message,
        upstream_status: status,
        razorpay_request_id: (e as any)?.requestId || undefined,
      },
      status >= 400 && status < 600 ? status : 502,
    );
  }
});
