// Cloudflare Worker: r2-signer
// Generates secure presigned PUT URLs for client-side direct uploads to Cloudflare R2
// Hardened against Path Traversal, Arbitrary File Upload (SSRF/XSS), and Billing Exploits.

import { S3Client, PutObjectCommand } from "@aws-sdk/client-s3";
import { getSignedUrl } from "@aws-sdk/s3-request-presigner";

export default {
  async fetch(request, env) {
    const corsHeaders = {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "POST, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type, Authorization",
    };

    if (request.method === "OPTIONS") {
      return new Response(null, { headers: corsHeaders });
    }

    if (request.method !== "POST") {
      return new Response("Method Not Allowed", { status: 405, headers: corsHeaders });
    }

    try {
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

      // Initialize S3 client binding to Cloudflare R2 endpoint
      const s3Client = new S3Client({
        region: "auto",
        endpoint: `https://${env.R2_ACCOUNT_ID}.r2.cloudflarestorage.com`,
        credentials: {
          accessKeyId: env.R2_ACCESS_KEY_ID,
          secretAccessKey: env.R2_SECRET_ACCESS_KEY,
        },
      });

      // Generate presigned PUT URL
      const command = new PutObjectCommand({
        Bucket: env.R2_BUCKET_NAME,
        Key: objectKey,
        ContentType: mime_type,
      });

      // Signed URL expires in 10 minutes (600 seconds)
      const presignedUrl = await getSignedUrl(s3Client, command, { expiresIn: 600 });

      return new Response(
        JSON.stringify({
          upload_url: presignedUrl,
          r2_key: objectKey,
          public_url: `https://${env.CDN_DOMAIN}/${objectKey}`
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
