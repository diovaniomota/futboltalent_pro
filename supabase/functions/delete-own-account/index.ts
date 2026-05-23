import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
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

async function fetchJson(url: string, headers: HeadersInit, init?: RequestInit) {
  const response = await fetch(url, { ...init, headers });
  const text = await response.text();
  let body: unknown = null;
  try {
    body = text ? JSON.parse(text) : null;
  } catch (_) {
    body = text;
  }
  return { response, body };
}

function legacyIdFromUserId(userId: string) {
  return userId.replace(/[^a-zA-Z0-9]/g, "").slice(0, 10);
}

function shouldDeleteStorageObject(name: string, tokens: string[]) {
  return tokens.some((token) => token.length > 0 && name.includes(token));
}

function isAuthUserNotFound(status: number, body: unknown) {
  if (status === 404) return true;

  const text = typeof body === "string" ? body : JSON.stringify(body ?? {});
  return status === 400 && /not found|no user|user.*missing/i.test(text);
}

function authUserHasDeletedAt(body: unknown) {
  if (!body || typeof body !== "object") return false;

  const record = body as Record<string, unknown>;
  const user = record.user && typeof record.user === "object"
    ? record.user as Record<string, unknown>
    : record;

  return typeof user.deleted_at === "string" && user.deleted_at.length > 0;
}

function storageError(message: string, details: unknown) {
  return { error: "storage_cleanup_failed", message, details };
}

async function listStorageObjects(
  supabaseUrl: string,
  serviceRoleKey: string,
  bucketId: string,
  prefix = "",
): Promise<string[]> {
  const limit = 1000;
  let offset = 0;
  const names: string[] = [];

  while (true) {
    const { response, body } = await fetchJson(
      `${supabaseUrl}/storage/v1/object/list/${encodeURIComponent(bucketId)}`,
      {
        apikey: serviceRoleKey,
        Authorization: `Bearer ${serviceRoleKey}`,
        "Content-Type": "application/json",
      },
      {
        method: "POST",
        body: JSON.stringify({
          prefix,
          limit,
          offset,
          sortBy: { column: "name", order: "asc" },
        }),
      },
    );

    if (!response.ok || !Array.isArray(body)) {
      throw storageError("object_list_failed", {
        bucket_id: bucketId,
        prefix,
        status: response.status,
        body,
      });
    }

    for (const item of body) {
      if (!item || typeof item !== "object") continue;
      const rawName = String((item as Record<string, unknown>).name ?? "");
      if (!rawName) continue;

      const fullName = prefix ? `${prefix}/${rawName}` : rawName;
      const metadata = (item as Record<string, unknown>).metadata;
      const id = (item as Record<string, unknown>).id;

      if (id || metadata) {
        names.push(fullName);
        continue;
      }

      const childNames = await listStorageObjects(
        supabaseUrl,
        serviceRoleKey,
        bucketId,
        fullName,
      );
      names.push(...childNames);
    }

    if (body.length < limit) break;
    offset += limit;
  }

  return names;
}

async function removeStorageObjects(
  supabaseUrl: string,
  serviceRoleKey: string,
  bucketId: string,
  objectNames: string[],
) {
  let deleted = 0;
  const chunkSize = 100;

  for (let index = 0; index < objectNames.length; index += chunkSize) {
    const chunk = objectNames.slice(index, index + chunkSize);
    if (chunk.length === 0) continue;

    const { response } = await fetchJson(
      `${supabaseUrl}/storage/v1/object/${encodeURIComponent(bucketId)}`,
      {
        apikey: serviceRoleKey,
        Authorization: `Bearer ${serviceRoleKey}`,
        "Content-Type": "application/json",
      },
      {
        method: "DELETE",
        body: JSON.stringify({ prefixes: chunk }),
      },
    );

    if (response.ok) {
      deleted += chunk.length;
      continue;
    }

    throw storageError("object_delete_failed", {
      bucket_id: bucketId,
      object_names: chunk,
      status: response.status,
    });
  }

  return deleted;
}

async function cleanupStorageForUser(
  supabaseUrl: string,
  serviceRoleKey: string,
  userId: string,
) {
  const { response, body } = await fetchJson(
    `${supabaseUrl}/storage/v1/bucket`,
    {
      apikey: serviceRoleKey,
      Authorization: `Bearer ${serviceRoleKey}`,
    },
  );

  if (!response.ok || !Array.isArray(body)) {
    throw storageError("bucket_list_failed", {
      status: response.status,
      body,
    });
  }

  const tokens = [userId, legacyIdFromUserId(userId)].filter(Boolean);
  let deleted = 0;
  let bucketsChecked = 0;

  for (const bucket of body) {
    if (!bucket || typeof bucket !== "object") continue;
    const bucketId = String((bucket as Record<string, unknown>).id ?? "");
    if (!bucketId) continue;

    bucketsChecked++;
    const objects = await listStorageObjects(
      supabaseUrl,
      serviceRoleKey,
      bucketId,
    );
    const matches = objects.filter((name) =>
      shouldDeleteStorageObject(name, tokens)
    );
    deleted += await removeStorageObjects(
      supabaseUrl,
      serviceRoleKey,
      bucketId,
      matches,
    );
  }

  return { deleted, buckets_checked: bucketsChecked };
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return jsonResponse({ error: "method_not_allowed" }, 405);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL")?.trim() ?? "";
  const supabaseServiceRoleKey =
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")?.trim() ?? "";
  const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY")?.trim() ?? "";

  if (!supabaseUrl || !supabaseServiceRoleKey || !supabaseAnonKey) {
    return jsonResponse({ error: "missing_supabase_server_env" }, 500);
  }

  const authorization = req.headers.get("Authorization") ?? "";
  if (!authorization.startsWith("Bearer ")) {
    return jsonResponse({ error: "auth_required" }, 401);
  }

  const { response: userResponse, body: authUser } = await fetchJson(
    `${supabaseUrl}/auth/v1/user`,
    {
      apikey: supabaseAnonKey,
      Authorization: authorization,
    },
  );

  if (!userResponse.ok || !authUser || typeof authUser !== "object") {
    return jsonResponse({ error: "invalid_user_session", details: authUser }, 401);
  }

  const userId = String((authUser as Record<string, unknown>).id ?? "").trim();
  if (!userId) {
    return jsonResponse({ error: "invalid_user_session" }, 401);
  }

  let storageCleanup;
  try {
    storageCleanup = await cleanupStorageForUser(
      supabaseUrl,
      supabaseServiceRoleKey,
      userId,
    );
  } catch (error) {
    return jsonResponse(
      {
        error: "storage_cleanup_failed",
        details: error,
      },
      500,
    );
  }

  const { response: cleanupResponse, body: cleanupBody } = await fetchJson(
    `${supabaseUrl}/rest/v1/rpc/delete_own_account`,
    {
      apikey: supabaseAnonKey,
      Authorization: authorization,
      "Content-Type": "application/json",
    },
    {
      method: "POST",
      body: "{}",
    },
  );

  if (!cleanupResponse.ok) {
    return jsonResponse(
      {
        error: "profile_cleanup_failed",
        status: cleanupResponse.status,
        details: cleanupBody,
      },
      500,
    );
  }

  const { response: deleteResponse, body: deleteBody } = await fetchJson(
    `${supabaseUrl}/auth/v1/admin/users/${encodeURIComponent(userId)}`,
    {
      apikey: supabaseServiceRoleKey,
      Authorization: `Bearer ${supabaseServiceRoleKey}`,
      "Content-Type": "application/json",
    },
    {
      method: "DELETE",
      body: JSON.stringify({ should_soft_delete: false }),
    },
  );

  if (!deleteResponse.ok && deleteResponse.status !== 404) {
    return jsonResponse(
      {
        error: "auth_account_delete_failed",
        status: deleteResponse.status,
        details: deleteBody,
      },
      500,
    );
  }

  const { response: verifyDeleteResponse, body: verifyDeleteBody } =
    await fetchJson(
      `${supabaseUrl}/auth/v1/admin/users/${encodeURIComponent(userId)}`,
      {
        apikey: supabaseServiceRoleKey,
        Authorization: `Bearer ${supabaseServiceRoleKey}`,
      },
    );

  const authAccountSoftDeleted =
    verifyDeleteResponse.ok && authUserHasDeletedAt(verifyDeleteBody);

  if (verifyDeleteResponse.ok && !authAccountSoftDeleted) {
    return jsonResponse(
      {
        error: "auth_account_still_exists",
        details: verifyDeleteBody,
      },
      500,
    );
  }

  if (
    !verifyDeleteResponse.ok &&
    !isAuthUserNotFound(verifyDeleteResponse.status, verifyDeleteBody)
  ) {
    return jsonResponse(
      {
        error: "auth_account_delete_verification_failed",
        status: verifyDeleteResponse.status,
        details: verifyDeleteBody,
      },
      500,
    );
  }

  return jsonResponse({
    success: true,
    user_id: userId,
    cleanup: cleanupBody,
    storage_cleanup: storageCleanup,
    deleted_auth_account: deleteResponse.ok,
    auth_account_soft_deleted: authAccountSoftDeleted,
  });
});
