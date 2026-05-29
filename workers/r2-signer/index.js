// Cloudflare Worker: r2-signer
// Generates short-lived Worker upload URLs and stores media through a native R2 binding.
// Hardened against Path Traversal, Arbitrary File Upload (SSRF/XSS), and Billing Exploits.

const encoder = new TextEncoder();

async function signUpload(env, key, expires) {
  const secret = env.CLIENT_SECRET_KEY || "intake_secure_shield_902";
  const cryptoKey = await crypto.subtle.importKey(
    "raw",
    encoder.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  );
  const signature = await crypto.subtle.sign("HMAC", cryptoKey, encoder.encode(`${key}:${expires}`));
  return [...new Uint8Array(signature)].map(byte => byte.toString(16).padStart(2, "0")).join("");
}

function isSafeObjectKey(key) {
  return /^meals\/[0-9a-f-]{36}\/analysis_[0-9]+\.[a-zA-Z0-9]+$/i.test(key);
}

export default {
  async fetch(request, env) {
    const corsHeaders = {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "GET, POST, PUT, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type, Authorization",
    };

    if (request.method === "OPTIONS") {
      return new Response(null, { headers: corsHeaders });
    }

    const url = new URL(request.url);

    try {
      if (request.method === "GET" && url.pathname.startsWith("/media/")) {
        const key = decodeURIComponent(url.pathname.replace("/media/", ""));
        if (!isSafeObjectKey(key)) {
          return new Response("Invalid media key", { status: 400, headers: corsHeaders });
        }

        const object = await env.MEDIA_BUCKET.get(key);
        if (!object) {
          return new Response("Not Found", { status: 404, headers: corsHeaders });
        }

        return new Response(object.body, {
          status: 200,
          headers: {
            ...corsHeaders,
            "Content-Type": object.httpMetadata?.contentType || "application/octet-stream",
            "Cache-Control": "public, max-age=86400",
          },
        });
      }

      if (request.method === "PUT" && url.pathname === "/api/upload") {
        const key = url.searchParams.get("key") || "";
        const expires = Number(url.searchParams.get("expires") || "0");
        const sig = url.searchParams.get("sig") || "";

        if (!isSafeObjectKey(key) || !expires || Date.now() > expires) {
          return new Response("Expired or invalid upload URL", { status: 400, headers: corsHeaders });
        }

        const expectedSig = await signUpload(env, key, expires);
        if (sig !== expectedSig) {
          return new Response("Invalid upload signature", { status: 401, headers: corsHeaders });
        }

        const mimeType = request.headers.get("Content-Type") || "application/octet-stream";
        const allowedMimeTypes = [
          "image/jpeg", "image/jpg", "image/png", "image/heic", "image/webp",
          "audio/mp4", "audio/m4a", "audio/x-m4a", "audio/mpeg", "audio/mp3", "audio/wav"
        ];
        if (!allowedMimeTypes.includes(mimeType.toLowerCase())) {
          return new Response("Forbidden MIME type format", { status: 400, headers: corsHeaders });
        }

        await env.MEDIA_BUCKET.put(key, request.body, {
          httpMetadata: { contentType: mimeType },
        });

        return new Response(null, { status: 200, headers: corsHeaders });
      }

      if (request.method !== "POST") {
        return new Response("Method Not Allowed", { status: 405, headers: corsHeaders });
      }

      // 1. Bearer Token Authorization (Prevents unauthorized R2 usage & billing hikes)
      const authHeader = request.headers.get("Authorization");
      const clientKey = env.CLIENT_SECRET_KEY || "intake_secure_shield_902";
      if (!authHeader || authHeader !== `Bearer ${clientKey}`) {
        return new Response(JSON.stringify({ error: "Unauthorized access" }), {
          status: 401,
          headers: { ...corsHeaders, "Content-Type": "application/json" }
        });
      }

      // 2. Parse request payload
      const { event_id, mime_type, file_extension } = await request.json();

      if (!event_id || !mime_type) {
        return new Response("Missing required fields: event_id, mime_type", { 
          status: 400, 
          headers: corsHeaders 
        });
      }

      // 3. Security: Prevent Path Traversal by enforcing a strict UUID v4 format
      const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
      if (!uuidRegex.test(event_id)) {
        return new Response("Invalid UUID format for event_id", { 
          status: 400, 
          headers: corsHeaders 
        });
      }

      // 4. Security: Prevent Arbitrary/Malicious Uploads (e.g. text/html, shell scripts) by restricting MIME types
      const allowedMimeTypes = [
        "image/jpeg", "image/jpg", "image/png", "image/heic", "image/webp",
        "audio/mp4", "audio/m4a", "audio/x-m4a", "audio/mpeg", "audio/mp3", "audio/wav"
      ];
      if (!allowedMimeTypes.includes(mime_type.toLowerCase())) {
        return new Response("Forbidden MIME type format", { 
          status: 400, 
          headers: corsHeaders 
        });
      }

      // Generate secure unique object key
      const ext = file_extension || mime_type.split("/")[1] || "webp";
      const sanitizedExt = ext.replace(/[^a-zA-Z0-9]/g, ""); // strip potential dots or slashes
      const objectKey = `meals/${event_id}/analysis_${Date.now()}.${sanitizedExt}`;
      const expires = Date.now() + 10 * 60 * 1000;
      const signature = await signUpload(env, objectKey, expires);
      const uploadUrl = new URL("/api/upload", url.origin);
      uploadUrl.searchParams.set("key", objectKey);
      uploadUrl.searchParams.set("expires", String(expires));
      uploadUrl.searchParams.set("sig", signature);

      return new Response(
        JSON.stringify({
          upload_url: uploadUrl.toString(),
          r2_key: objectKey,
          public_url: `${url.origin}/media/${objectKey}`
        }),
        {
          status: 200,
          headers: {
            ...corsHeaders,
            "Content-Type": "application/json",
          },
        }
      );
    } catch (error) {
      return new Response(
        JSON.stringify({ error: error.message }),
        { 
          status: 500, 
          headers: {
            ...corsHeaders,
            "Content-Type": "application/json"
          } 
        }
      );
    }
  },
};
