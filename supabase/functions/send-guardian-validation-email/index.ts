import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

type GuardianEmailPayload = {
  player_id?: string;
  guardian_email?: string;
  player_name?: string;
  approval_code?: string;
};

function jsonResponse(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
}

function normalizeEmail(value: unknown) {
  return String(value ?? "").trim().toLowerCase();
}

function normalizeCode(value: unknown) {
  return String(value ?? "").trim().toUpperCase();
}

function escapeHtml(value: string) {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}

function trimTrailingSlash(value: string) {
  return value.endsWith("/") ? value.slice(0, -1) : value;
}

async function fetchJson(url: string, headers: HeadersInit) {
  const response = await fetch(url, { headers });
  if (!response.ok) return null;
  return await response.json();
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return jsonResponse({ error: "method_not_allowed" }, 405);
  }

  const resendApiKey = Deno.env.get("RESEND_API_KEY")?.trim() ?? "";
  const supabaseUrl = Deno.env.get("SUPABASE_URL")?.trim() ?? "";
  const supabaseServiceRoleKey =
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")?.trim() ?? "";
  const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY")?.trim() ?? "";

  if (!resendApiKey) {
    return jsonResponse({ error: "missing_resend_api_key" }, 500);
  }
  if (!supabaseUrl || !supabaseServiceRoleKey || !supabaseAnonKey) {
    return jsonResponse({ error: "missing_supabase_server_env" }, 500);
  }

  const authorization = req.headers.get("Authorization") ?? "";
  if (!authorization.startsWith("Bearer ")) {
    return jsonResponse({ error: "auth_required" }, 401);
  }

  let payload: GuardianEmailPayload;
  try {
    payload = await req.json();
  } catch (_) {
    return jsonResponse({ error: "invalid_json" }, 400);
  }

  const playerId = String(payload.player_id ?? "").trim();
  const guardianEmail = normalizeEmail(payload.guardian_email);
  const approvalCode = normalizeCode(payload.approval_code);
  const playerName = String(payload.player_name ?? "Jugador").trim() ||
    "Jugador";

  if (!playerId || !guardianEmail.includes("@") || !approvalCode) {
    return jsonResponse({ error: "invalid_payload" }, 400);
  }

  const authUser = await fetchJson(`${supabaseUrl}/auth/v1/user`, {
    apikey: supabaseAnonKey,
    Authorization: authorization,
  });

  if (!authUser?.id || authUser.id !== playerId) {
    return jsonResponse({ error: "player_auth_mismatch" }, 403);
  }

  const guardianQuery = new URL(`${supabaseUrl}/rest/v1/guardians`);
  guardianQuery.searchParams.set(
    "select",
    "player_id,email,approval_code,status,approval_code_used_at",
  );
  guardianQuery.searchParams.set("player_id", `eq.${playerId}`);
  guardianQuery.searchParams.set("order", "created_at.desc");
  guardianQuery.searchParams.set("limit", "5");

  const guardianRows = await fetchJson(guardianQuery.toString(), {
    apikey: supabaseServiceRoleKey,
    Authorization: `Bearer ${supabaseServiceRoleKey}`,
  });

  const guardian = Array.isArray(guardianRows)
    ? guardianRows.find((row) => normalizeEmail(row.email) === guardianEmail)
    : null;
  if (!guardian) {
    return jsonResponse({ error: "guardian_not_found" }, 404);
  }

  const storedCode = normalizeCode(guardian.approval_code);
  const storedStatus = String(guardian.status ?? "pending")
    .trim()
    .toLowerCase();
  if (
    storedStatus !== "pending" ||
    guardian.approval_code_used_at ||
    storedCode !== approvalCode
  ) {
    return jsonResponse({ error: "guardian_code_not_sendable" }, 409);
  }

  const appUrl = trimTrailingSlash(
    Deno.env.get("APP_PUBLIC_URL")?.trim() ?? "https://futboltalent.pro",
  );
  const approveUrl = `${appUrl}/login?guardianApproval=1`;
  const fromEmail =
    Deno.env.get("RESEND_FROM_EMAIL")?.trim() ||
    Deno.env.get("GUARDIAN_APPROVAL_FROM_EMAIL")?.trim() ||
    "FutbolTalent <onboarding@futboltalent.pro>";
  const safePlayerName = escapeHtml(playerName);
  const safeApprovalCode = escapeHtml(approvalCode);
  const safeApproveUrl = escapeHtml(approveUrl);

  const resendResponse = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${resendApiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from: fromEmail,
      to: [guardianEmail],
      subject: "Código de autorización de FutbolTalent",
      html: `<!doctype html>
<html>
  <body style="font-family: Arial, sans-serif; color: #172033; line-height: 1.55; max-width: 600px; margin: 0 auto; padding: 24px;">
    <h1 style="color: #0D3B66; font-size: 24px;">Validación de responsable legal</h1>
    <p>Hola,</p>
    <p><strong>${safePlayerName}</strong> te registró como responsable legal en FutbolTalent.</p>
    <p>Para autorizar la cuenta, ingresa este código en la pantalla de aprobación:</p>
    <div style="background: #F2F7F4; border: 1px solid #D8E9DD; border-radius: 12px; padding: 20px; text-align: center; margin: 22px 0;">
      <div style="font-size: 13px; color: #536471;">Código de aprobación</div>
      <div style="font-size: 32px; color: #0F9D58; font-weight: 800; letter-spacing: 2px; margin-top: 8px;">${safeApprovalCode}</div>
    </div>
    <p>Abre FutbolTalent y elige <strong>Aprobar cuenta de menor</strong>, o entra aquí:</p>
    <p><a href="${safeApproveUrl}" style="color: #0D3B66;">${safeApproveUrl}</a></p>
    <p>Si no reconoces esta solicitud, puedes ignorar este correo.</p>
    <p style="font-size: 12px; color: #718096; border-top: 1px solid #E2E8F0; padding-top: 16px;">El código vence en 7 días.</p>
  </body>
</html>`,
      text:
        `Hola,\n\n${playerName} te registró como responsable legal en FutbolTalent.\n\n` +
        `Código de aprobación: ${approvalCode}\n\n` +
        `Abre FutbolTalent y elige "Aprobar cuenta de menor", o entra aquí: ${approveUrl}\n\n` +
        "Si no reconoces esta solicitud, puedes ignorar este correo.\n",
    }),
  });

  const resendBody = await resendResponse.text();
  if (!resendResponse.ok) {
    return jsonResponse(
      {
        error: "resend_delivery_failed",
        status: resendResponse.status,
        details: resendBody,
      },
      502,
    );
  }

  return jsonResponse({ success: true });
});
