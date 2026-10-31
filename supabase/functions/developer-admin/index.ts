// Privacy-first developer administration for Kingdom Treasure.
// Cross-church data is never returned by default. Individual church diagnostics
// require an explicit, active, time-limited grant approved by that church.
import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), {
  status, headers: { ...corsHeaders, "Content-Type": "application/json" },
});

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  const url = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const reservedEmail = (Deno.env.get("RESERVED_DEVELOPER_EMAIL") ?? "tongaigodfreymapiye@gmail.com").toLowerCase();
  if (!url || !anonKey || !serviceKey) return json({ error: "Developer administration is not configured on the server." }, 500);

  const authorization = req.headers.get("Authorization");
  if (!authorization?.startsWith("Bearer ")) return json({ error: "A signed-in developer session is required." }, 401);
  const callerClient = createClient(url, anonKey, { global: { headers: { Authorization: authorization } }, auth: { persistSession: false, autoRefreshToken: false } });
  const admin = createClient(url, serviceKey, { auth: { persistSession: false, autoRefreshToken: false } });
  const { data: authData, error: authError } = await callerClient.auth.getUser();
  const caller = authData?.user;
  if (authError || !caller || caller.email?.toLowerCase() !== reservedEmail) return json({ error: "Reserved developer identity verification failed." }, 403);
  const { data: profile, error: profileError } = await admin.from("profiles").select("id,role,church_id").eq("id", caller.id).maybeSingle();
  if (profileError || profile?.role !== "developer") return json({ error: "Developer role verification failed." }, 403);

  let body: any;
  try { body = await req.json(); } catch { return json({ error: "Invalid JSON request." }, 400); }
  const action = String(body?.action ?? "");

  if (action === "business_summary") {
    const { data, error } = await admin.from("platform_business_ledger").select("direction,currency,amount");
    if (error) return json({ error: error.message }, 500);
    const totals = new Map<string, number>();
    for (const row of data ?? []) { const k = `${row.direction}|${row.currency}`; totals.set(k, (totals.get(k) ?? 0) + Number(row.amount)); }
    const income: any[] = [], expense: any[] = [];
    for (const [key, total] of totals) { const [direction, currency] = key.split("|"); (direction === "income" ? income : expense).push({ currency, total }); }
    const { data: monthlyRows, error: monthlyError } = await admin.from("platform_business_ledger").select("direction,currency,amount,entry_date");
    if (monthlyError) return json({ error: monthlyError.message }, 500);
    const monthlyMap = new Map<string, any>();
    for (const row of monthlyRows ?? []) { const month = String(row.entry_date).slice(0, 7); const key = `${month}|${row.currency}|${row.direction}`; const item = monthlyMap.get(key) ?? { month, currency: row.currency, direction: row.direction, total: 0 }; item.total += Number(row.amount); monthlyMap.set(key, item); }
    return json({ summary: { income, expense, monthly: [...monthlyMap.values()] } });
  }

  if (action === "list_business_ledger") {
    const { data, error } = await admin.from("platform_business_ledger").select("id,direction,entry_date,category,description,amount,currency,reference,created_at").order("entry_date", { ascending: false }).limit(250);
    if (error) return json({ error: error.message }, 500);
    return json({ entries: data ?? [] });
  }

  if (action === "create_business_entry") {
    const e = body.entry ?? {};
    const direction = e.direction;
    const amount = Number(e.amount);
    if (!['income', 'expense'].includes(direction) || !Number.isFinite(amount) || amount <= 0 || !String(e.category ?? '').trim() || !String(e.description ?? '').trim() || !/^([A-Z]{3})$/.test(String(e.currency ?? 'USD'))) {
      return json({ error: "Provide a valid direction, positive amount, category, description and 3-letter currency." }, 400);
    }
    const { data, error } = await admin.from("platform_business_ledger").insert({
      direction, amount, category: String(e.category).slice(0,100), description: String(e.description).slice(0,500),
      entry_date: e.entry_date || new Date().toISOString().slice(0,10), currency: e.currency, created_by: caller.id,
    }).select("id").single();
    if (error) return json({ error: error.message }, 500);
    return json({ success: true, id: data.id });
  }

  if (action === "list_support_requests") {
    const { data: requests, error } = await admin.from("platform_support_requests")
      .select("id,church_id,reason,scope,status,requested_at,approved_at,expires_at,revoked_at")
      .order("requested_at", { ascending: false }).limit(100);
    if (error) return json({ error: error.message }, 500);
    const ids = [...new Set((requests ?? []).map((r: any) => r.church_id))];
    const { data: churches, error: churchError } = ids.length
      ? await admin.from("churches").select("id,name").in("id", ids)
      : { data: [], error: null } as any;
    if (churchError) return json({ error: churchError.message }, 500);
    const names = new Map((churches ?? []).map((c: any) => [c.id, c.name]));
    return json({ requests: (requests ?? []).map((r: any) => ({ ...r, church_name: names.get(r.church_id) ?? "Church" })) });
  }

  if (action === "support_snapshot") {
    const requestId = String(body.request_id ?? "");
    const { data: grant, error: grantError } = await admin.from("platform_support_requests").select("id,church_id,scope,status,expires_at")
      .eq("id", requestId).eq("status", "approved").gt("expires_at", new Date().toISOString()).maybeSingle();
    if (grantError || !grant) return json({ error: "No active church-approved support grant exists. It may have expired or been revoked." }, 403);
    const { data: church, error: churchError } = await admin.from("churches").select("id,name,currency").eq("id", grant.church_id).single();
    if (churchError) return json({ error: churchError.message }, 500);
    const [branchesRes, membersRes, txRes] = await Promise.all([
      admin.from("branches").select("id,name").eq("church_id", grant.church_id),
      admin.from("members").select("id,branch_id").eq("church_id", grant.church_id),
      admin.from("financial_transactions").select("branch_id,direction,amount,currency,status").eq("church_id", grant.church_id),
    ]);
    for (const r of [branchesRes, membersRes, txRes]) if (r.error) return json({ error: r.error.message }, 500);
    const branches = branchesRes.data ?? [], members = membersRes.data ?? [], tx = txRes.data ?? [];
    const branch_summary = branches.map((b: any) => ({ branch_name: b.name, members: members.filter((m: any) => m.branch_id === b.id).length, transactions: tx.filter((t: any) => t.branch_id === b.id).length }));
    const currencyMap = new Map<string, any>();
    for (const t of tx.filter((x: any) => x.status === "posted")) {
      const cur = t.currency || church.currency || "USD";
      const x = currencyMap.get(cur) ?? { currency: cur, income: 0, expense: 0 };
      x[t.direction] += Number(t.amount); currencyMap.set(cur, x);
    }
    await admin.from("platform_support_requests").update({ last_accessed_at: new Date().toISOString() }).eq("id", grant.id);
    const snapshot: any = {
      church: { name: church.name }, expires_at: grant.expires_at, scope: grant.scope,
      counts: { members: members.length, branches: branches.length, transactions: tx.length, drafts: tx.filter((t: any) => t.status === "draft").length },
      branch_summary,
    };
    if (grant.scope === "financial_review") snapshot.financial_summary = [...currencyMap.values()];
    if (grant.scope === "user_access_review") {
      const { data: roleRows, error: roleError } = await admin.from("profiles").select("id,full_name,role").eq("church_id", grant.church_id);
      if (roleError) return json({ error: roleError.message }, 500);
      const roleCounts: Record<string, number> = {};
      for (const row of roleRows ?? []) roleCounts[String((row as any).role)] = (roleCounts[String((row as any).role)] ?? 0) + 1;
      const authUsers: any[] = [];
      for (let page = 1; page <= 20; page++) {
        const { data: pageData, error: authUsersError } = await admin.auth.admin.listUsers({ page, perPage: 1000 });
        if (authUsersError) return json({ error: authUsersError.message }, 500);
        authUsers.push(...(pageData.users ?? []));
        if ((pageData.users ?? []).length < 1000) break;
      }
      const userById = new Map(authUsers.map((u: any) => [u.id, u]));
      snapshot.user_role_counts = roleCounts;
      snapshot.users = (roleRows ?? []).map((p: any) => { const au: any = userById.get(p.id); return { id: p.id, full_name: p.full_name, role: p.role, email: au?.email ?? null, banned_until: au?.banned_until ?? null }; });
    }
    return json({ snapshot });
  }

  if (action === "revoke_support_access") {
    const requestId = String(body.request_id ?? "");
    const { data, error } = await admin.from("platform_support_requests").update({ status: "revoked", revoked_by: caller.id, revoked_at: new Date().toISOString() })
      .eq("id", requestId).eq("status", "approved").select("id").maybeSingle();
    if (error) return json({ error: error.message }, 500);
    if (!data) return json({ error: "No active support grant found." }, 404);
    await admin.from("audit_log").insert({ church_id: null, actor: caller.id, action: "developer_support_revoked_by_developer", entity: "platform_support_request", entity_id: requestId, details: { performed_by: caller.email } });
    return json({ success: true });
  }

  // User suspension is confined to the developer's CFMI home church. External
  // church user access is never changed by this endpoint in this release.
  if (["suspend_user", "restore_user"].includes(action) && body.user_id) {
    if (body.user_id === caller.id) return json({ error: "The reserved developer cannot suspend itself." }, 400);
    const { data: target, error: targetError } = await admin.from("profiles").select("id,role,church_id").eq("id", body.user_id).maybeSingle();
    if (targetError || !target) return json({ error: targetError?.message ?? "User profile not found." }, 404);
    if (target.role === "developer") return json({ error: "Developer identities are protected." }, 403);
    if (!profile.church_id || !target.church_id) return json({ error: "The target account is not assigned to a church." }, 403);
    if (target.church_id !== profile.church_id) {
      const requestId = String(body.request_id ?? "");
      const { data: grant, error: grantError } = await admin.from("platform_support_requests").select("id,church_id,scope,status,expires_at")
        .eq("id", requestId).eq("church_id", target.church_id).eq("scope", "user_access_review").eq("status", "approved")
        .gt("expires_at", new Date().toISOString()).maybeSingle();
      if (grantError || !grant) return json({ error: "External user access changes require an active church-approved user_access_review grant." }, 403);
    }
    const { data: targetUser, error: userError } = await admin.auth.admin.getUserById(body.user_id);
    if (userError || !targetUser.user) return json({ error: userError?.message ?? "User not found." }, 404);
    const banDuration = action === "suspend_user" ? "876000h" : "none";
    const { error: updateError } = await admin.auth.admin.updateUserById(body.user_id, { ban_duration: banDuration });
    if (updateError) return json({ error: updateError.message }, 500);
    const { error: auditError } = await admin.from("audit_log").insert({ church_id: target.church_id, actor: caller.id, action, entity: "auth_user", entity_id: body.user_id, details: { target_email: targetUser.user.email, performed_by: caller.email, support_request_id: body.request_id ?? null } });
    if (auditError) return json({ success: true, warning: "Access changed but audit event failed: " + auditError.message }, 207);
    return json({ success: true, action });
  }

  return json({ error: "Unsupported action." }, 400);
});
