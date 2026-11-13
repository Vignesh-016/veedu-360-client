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
    return out({ message: "Admin access required." }, 403);
  const body = await req.json().catch(() => ({}));
  let ownerId = String(body.owner_user_id || "");
  let selectedId = String(body.payout_account_id || "");
  if (body.property_id) {
    const { data: property } = await (supabaseAdmin as any)
      .from("properties")
      .select("submitter,payout_account_id")
      .eq("property_id", String(body.property_id))
      .maybeSingle();
    if (!property) return out({ message: "Property was not found." }, 404);
    selectedId ||= property.payout_account_id || "";
    if (!ownerId) ownerId = property.submitter || "";
  }
  if (!ownerId)
    return out({ success: true, exists: false, payout: null, accounts: [] });
  const { data: accounts, error } = await (supabaseAdmin as any)
    .from("owner_payout_accounts")
    .select(
      "payout_account_id,owner_user_id,account_holder_name,account_number,ifsc_code,status,payment_eligible,razorpay_account_id,razorpay_product_id,razorpay_product_status,route_onboarding_error",
    )
    .eq("owner_user_id", ownerId)
    .order("created_at", { ascending: true });
  const { data: profile } = await (supabaseAdmin as any)
    .from("owner_profiles")
    .select("address_line1,address_line2,city,state,pincode,pan_number")
    .eq("owner_user_id", ownerId)
    .maybeSingle();
  if (error) return out({ message: "Unable to load payout status." }, 500);
  const mapped = (accounts || []).map((p: any) => ({
    ...p,
    masked_account_number: p.account_number
      ? `****${String(p.account_number).slice(-4)}`
      : null,
    status:
      p.payment_eligible && p.razorpay_product_status === "activated"
        ? "VERIFIED"
        : p.razorpay_product_status === "needs_clarification"
          ? "ACTION_REQUIRED"
          : p.status || "PENDING_VERIFICATION",
    payment_eligible: !!p.payment_eligible,
    profile: profile || null,
  }));
  return out({
    success: true,
    exists: mapped.length > 0,
    payout:
      mapped.find((p: any) => p.payout_account_id === selectedId) ||
      mapped[0] ||
      null,
    accounts: mapped,
  });
});
