import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": Deno.env.get("APP_ORIGIN") ?? "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  try {
    const url = Deno.env.get("SUPABASE_URL")!;
    const anon = Deno.env.get("SUPABASE_ANON_KEY")!;
    const service = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) throw new Error("Sign-in required");
    const userClient = createClient(url, anon, { global: { headers: { Authorization: authHeader } } });
    const { data: { user }, error: authError } = await userClient.auth.getUser();
    if (authError || !user) throw new Error("Invalid session");
    const { data: profile } = await userClient.from("profiles").select("church_id,role").eq("id", user.id).single();
    if (!profile || !["church_admin", "developer"].includes(profile.role) || !profile.church_id) throw new Error("Church administrator permission required");

    const { email, role, branch_id, full_name } = await req.json();
    const normalized = String(email ?? "").trim().toLowerCase();
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(normalized)) throw new Error("A valid email address is required");
    if (!["church_admin", "treasurer", "pastor", "department_leader", "member"].includes(role)) throw new Error("Invalid role");
    const admin = createClient(url, service);
    const { data: branch, error: branchError } = await admin.from("branches").select("id").eq("id", branch_id).eq("church_id", profile.church_id).single();
    if (branchError || !branch) throw new Error("Branch does not belong to this church");

    const tokenBytes = crypto.getRandomValues(new Uint8Array(32));
    const token = Array.from(tokenBytes, b => b.toString(16).padStart(2, "0")).join("");
    const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(token));
    const tokenHash = Array.from(new Uint8Array(digest), b => b.toString(16).padStart(2, "0")).join("");
    const { error: insertError } = await admin.from("church_invitations").insert({
      church_id: profile.church_id, branch_id, email: normalized, role, token_hash: tokenHash,
      expires_at: new Date(Date.now() + 7 * 86400000).toISOString(), invited_by: user.id
    });
    if (insertError) throw insertError;
    const redirect = Deno.env.get("APP_ORIGIN") ?? undefined;
    const { error: inviteError } = await admin.auth.admin.inviteUserByEmail(normalized, {
      data: { kt_invite_token: token, full_name: String(full_name ?? "").trim() },
      redirectTo: redirect
    });
    if (inviteError) {
      await admin.from("church_invitations").delete().eq("token_hash", tokenHash);
      throw inviteError;
    }
    return new Response(JSON.stringify({ ok: true, message: "Invitation email sent. The invited person will join this church after accepting." }), {
      headers: { ...cors, "Content-Type": "application/json" }
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: e.message ?? "Invitation failed" }), {
      status: 400, headers: { ...cors, "Content-Type": "application/json" }
    });
  }
});