import supabaseAdmin from "../_shared/supabaseAdmin.ts";
const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization,apikey,content-type,x-client-info",
  "Access-Control-Allow-Methods": "POST,OPTIONS",
};
const out = (body: Record<string, unknown>, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
Deno.serve(async (req) => {
  if (req.method === "OPTIONS")
    return new Response(null, { status: 204, headers: cors });
  if (req.method !== "POST")
    return out({ message: "Method not allowed." }, 405);
  const auth = req.headers.get("Authorization");
  if (!auth?.startsWith("Bearer "))
    return out({ message: "Authentication required." }, 401);
  const {
    data: { user },
  } = await supabaseAdmin.auth.getUser(auth.slice(7));
  if (!user) return out({ message: "Authentication required." }, 401);
  const { data: admin } = await (supabaseAdmin as any)
    .from("admins")
    .select("is_active,roles")
    .eq("user_id", user.id)
    .maybeSingle();
  if (!admin?.is_active || !admin.roles?.length)
    return out(
      { message: "You are not authorised to manage payout details." },
      403,
    );
  try {
    const b = await req.json();
    const owner = String(b.target_owner_user_id || "");
    const propertyId = String(b.property_id || "");
    const holder = String(b.account_holder_name || "").trim();
    const account = String(b.account_number || "").trim();
    const confirm = String(b.confirm_account_number || "").trim();
    const ifsc = String(b.ifsc_code || "")
      .trim()
      .toUpperCase();
    const pan = String(b.pan_number || "")
      .trim()
      .toUpperCase();
    if (
      !owner ||
      !holder ||
      account.length < 6 ||
      account !== confirm ||
      !/^[A-Z]{4}0[A-Z0-9]{6}$/.test(ifsc) ||
      !/^[A-Z]{5}[0-9]{4}[A-Z]$/.test(pan) ||
      !b.route_consent_accepted
    )
      return out(
        {
          message:
            "Please complete all required owner KYC details and consent.",
        },
        400,
      );
    const { data: target } = await supabaseAdmin.auth.admin.getUserById(owner);
    if (!target?.user)
      return out({ message: "Selected owner was not found." }, 404);
    if (propertyId) {
      const { data: property } = await (supabaseAdmin as any)
        .from("properties")
        .select("submitter")
        .eq("property_id", propertyId)
        .maybeSingle();
      if (!property) return out({ message: "Property was not found." }, 404);
      if (property.submitter !== owner)
        return out({ message: "Payout owner does not match this property." }, 409);
    }
    const payoutId = String(b.payout_account_id || "");
    const lookupColumn = payoutId ? "payout_account_id" : "owner_user_id";
    const { data: old } = await (supabaseAdmin as any)
      .from("owner_payout_accounts")
      .select(
        "payout_account_id,owner_user_id,account_number,ifsc_code,account_holder_name",
      )
      .eq(lookupColumn, payoutId || owner)
      .maybeSingle();
    if (old && old.owner_user_id !== owner)
      return out(
        { message: "Payout account does not belong to the selected owner." },
        403,
      );
    const changed =
      !old ||
      old.account_number !== account ||
      String(old.ifsc_code || "").toUpperCase() !== ifsc ||
      String(old.account_holder_name || "").trim() !== holder;
    const { data: duplicate } = await (supabaseAdmin as any)
      .from("owner_payout_accounts")
      .select("owner_user_id")
      .neq("owner_user_id", owner)
      .eq("account_number", account)
      .eq("ifsc_code", ifsc)
      .limit(1)
      .maybeSingle();
    if (duplicate)
      return out(
        {
          code: "BANK_ACCOUNT_ALREADY_IN_USE",
          message: "This bank account is already linked to another owner.",
        },
        409,
      );
    const { error: profileError } = await (supabaseAdmin as any)
      .from("owner_profiles")
      .upsert(
        {
          owner_user_id: owner,
          address_line1: String(b.address_line1 || "").trim(),
          address_line2: String(b.address_line2 || "").trim() || null,
          city: String(b.city || "").trim(),
          state: String(b.state || "").trim(),
          pincode: String(b.pincode || "").trim(),
          pan_number: pan,
          updated_at: new Date().toISOString(),
        },
        { onConflict: "owner_user_id" },
      );
    if (profileError) throw profileError;
    const payload: any = {
      ...(old?.payout_account_id
        ? { payout_account_id: old.payout_account_id }
        : {}),
      owner_user_id: owner,
      account_holder_name: holder,
      account_number: account,
      ifsc_code: ifsc,
      status: "PENDING_VERIFICATION",
      route_consent_accepted: true,
      route_consent_at: new Date().toISOString(),
      route_consent_version: "v1",
      updated_at: new Date().toISOString(),
    };
    if (changed) payload.payment_eligible = false;
    const { data: saved, error: payoutError } = await (supabaseAdmin as any)
      .from("owner_payout_accounts")
      .upsert(payload, { onConflict: "payout_account_id" })
      .select("payout_account_id")
      .single();
    if (payoutError) throw payoutError;
    return out({
      success: true,
      owner_user_id: owner,
      payout_account_id: saved.payout_account_id,
      status: "PENDING_VERIFICATION",
      changed,
    });
  } catch (error) {
    console.error(
      "admin-save-owner-payout failed",
      error instanceof Error ? error.message : "unknown",
    );
    return out({ message: "Unable to save owner payout details." }, 500);
  }
});
