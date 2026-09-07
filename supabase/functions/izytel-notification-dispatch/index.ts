import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

type ServiceAccount = {
  project_id: string;
  client_email: string;
  private_key: string;
  token_uri?: string;
};

type OutboxRow = {
  id: string;
  recipient_uid: string;
  event_type: string;
  title: string;
  body: string;
  data: Record<string, unknown> | null;
  status: string;
  attempt_count: number;
  dispatch_nonce: string;
};

type DeviceRow = {
  id: string;
  fcm_token: string;
};

const jsonHeaders = { "Content-Type": "application/json" };

function response(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: jsonHeaders });
}

function base64Url(input: Uint8Array | string): string {
  const bytes = typeof input === "string" ? new TextEncoder().encode(input) : input;
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replaceAll("+", "-").replaceAll("/", "_").replace(/=+$/g, "");
}

function decodePemPrivateKey(pem: string): Uint8Array {
  const base64 = pem
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\s+/g, "");
  const binary = atob(base64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i += 1) bytes[i] = binary.charCodeAt(i);
  return bytes;
}

async function firebaseAccessToken(account: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const tokenUri = account.token_uri || "https://oauth2.googleapis.com/token";
  const header = base64Url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claims = base64Url(JSON.stringify({
    iss: account.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: tokenUri,
    iat: now,
    exp: now + 3600,
  }));
  const unsigned = `${header}.${claims}`;
  const key = await crypto.subtle.importKey(
    "pkcs8",
    decodePemPrivateKey(account.private_key),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = new Uint8Array(
    await crypto.subtle.sign(
      "RSASSA-PKCS1-v1_5",
      key,
      new TextEncoder().encode(unsigned),
    ),
  );
  const assertion = `${unsigned}.${base64Url(signature)}`;

  const tokenResponse = await fetch(tokenUri, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });
  const payload = await tokenResponse.json();
  if (!tokenResponse.ok || typeof payload.access_token !== "string") {
    throw new Error(`FCM_OAUTH_${tokenResponse.status}`);
  }
  return payload.access_token;
}

function fcmData(data: Record<string, unknown> | null): Record<string, string> {
  const normalized: Record<string, string> = {};
  for (const [key, value] of Object.entries(data ?? {})) {
    if (value === null || value === undefined) continue;
    normalized[key] = typeof value === "string" ? value : JSON.stringify(value);
  }
  return normalized;
}

async function sendFcm(
  account: ServiceAccount,
  accessToken: string,
  token: string,
  row: OutboxRow,
): Promise<{ ok: boolean; invalidToken: boolean; error?: string }> {
  const url = `https://fcm.googleapis.com/v1/projects/${encodeURIComponent(account.project_id)}/messages:send`;
  const fcmResponse = await fetch(url, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${accessToken}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      message: {
        token,
        notification: { title: row.title, body: row.body },
        data: {
          ...fcmData(row.data),
          title: row.title,
          body: row.body,
        },
        android: {
          priority: "high",
          notification: { sound: "default" },
        },
      },
    }),
  });

  if (fcmResponse.ok) return { ok: true, invalidToken: false };

  let errorPayload: any = null;
  try {
    errorPayload = await fcmResponse.json();
  } catch (_) {
    // Ignore an unreadable Google error body.
  }
  const serialized = JSON.stringify(errorPayload ?? {});
  const invalidToken =
    fcmResponse.status === 404 ||
    serialized.includes("UNREGISTERED") ||
    serialized.includes("registration-token-not-registered");
  const status = errorPayload?.error?.status ?? `HTTP_${fcmResponse.status}`;
  return { ok: false, invalidToken, error: String(status).slice(0, 240) };
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return response({ error: "METHOD_NOT_ALLOWED" }, 405);

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRole = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceRole) {
    return response({ error: "SUPABASE_SERVER_CONFIG_MISSING" }, 500);
  }

  let body: { outboxId?: string; nonce?: string };
  try {
    body = await req.json();
  } catch (_) {
    return response({ error: "INVALID_JSON" }, 400);
  }

  const outboxId = String(body.outboxId ?? "").trim();
  const nonce = String(body.nonce ?? "").trim();
  if (!outboxId || !nonce) return response({ error: "DISPATCH_TICKET_REQUIRED" }, 401);

  const admin = createClient(supabaseUrl, serviceRole, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  // Custom authentication: the nonce is random, lives only in the protected
  // outbox and is sent by pg_net after insertion. Client roles cannot read it.
  const { data: ticket, error: ticketError } = await admin
    .from("izytel_notification_outbox")
    .select("id, dispatch_nonce, status")
    .eq("id", outboxId)
    .eq("dispatch_nonce", nonce)
    .maybeSingle();
  if (ticketError || !ticket) return response({ error: "INVALID_DISPATCH_TICKET" }, 403);

  const rawServiceAccount = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON");
  if (!rawServiceAccount) {
    // Nothing is claimed: events remain pending until the secret is configured.
    return response({ ok: false, configured: false, pending: true });
  }

  let account: ServiceAccount;
  try {
    account = JSON.parse(rawServiceAccount) as ServiceAccount;
    if (!account.project_id || !account.client_email || !account.private_key) {
      throw new Error("missing fields");
    }
  } catch (_) {
    return response({ error: "INVALID_FIREBASE_SERVICE_ACCOUNT" }, 500);
  }

  let accessToken: string;
  try {
    accessToken = await firebaseAccessToken(account);
  } catch (error) {
    return response({ error: String(error) }, 502);
  }

  const { data: claimed, error: claimError } = await admin.rpc(
    "izytel_claim_notification_batch",
    { p_limit: 40 },
  );
  if (claimError) return response({ error: "OUTBOX_CLAIM_FAILED" }, 500);

  const rows = (claimed ?? []) as OutboxRow[];
  let sent = 0;
  let skipped = 0;
  let failed = 0;

  for (const row of rows) {
    const { data: devices, error: deviceError } = await admin
      .from("izytel_notification_devices")
      .select("id, fcm_token")
      .eq("firebase_uid", row.recipient_uid)
      .eq("is_active", true);

    if (deviceError) {
      failed += 1;
      await admin.from("izytel_notification_outbox").update({
        status: "failed",
        last_error: "DEVICE_LOOKUP_FAILED",
        updated_at: new Date().toISOString(),
      }).eq("id", row.id);
      continue;
    }

    const activeDevices = (devices ?? []) as DeviceRow[];
    if (activeDevices.length === 0) {
      skipped += 1;
      await admin.from("izytel_notification_outbox").update({
        status: "skipped",
        last_error: "NO_ACTIVE_DEVICE",
        updated_at: new Date().toISOString(),
      }).eq("id", row.id);
      continue;
    }

    let successes = 0;
    const errors: string[] = [];
    for (const device of activeDevices) {
      try {
        const result = await sendFcm(account, accessToken, device.fcm_token, row);
        if (result.ok) {
          successes += 1;
        } else {
          if (result.invalidToken) {
            await admin.from("izytel_notification_devices").update({
              is_active: false,
              updated_at: new Date().toISOString(),
            }).eq("id", device.id);
          }
          if (result.error) errors.push(result.error);
        }
      } catch (error) {
        errors.push(String(error).slice(0, 240));
      }
    }

    if (successes > 0) {
      sent += 1;
      await admin.from("izytel_notification_outbox").update({
        status: "sent",
        sent_at: new Date().toISOString(),
        last_error: errors.length > 0 ? errors.join(" | ").slice(0, 500) : null,
        updated_at: new Date().toISOString(),
      }).eq("id", row.id);
    } else {
      failed += 1;
      await admin.from("izytel_notification_outbox").update({
        status: "failed",
        last_error: (errors.join(" | ") || "FCM_SEND_FAILED").slice(0, 500),
        updated_at: new Date().toISOString(),
      }).eq("id", row.id);
    }
  }

  console.log(JSON.stringify({ event: "izytel_notification_dispatch", rows: rows.length, sent, skipped, failed }));
  return response({ ok: true, configured: true, processed: rows.length, sent, skipped, failed });
});
