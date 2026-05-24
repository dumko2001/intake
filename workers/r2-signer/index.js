// Cloudflare Worker: r2-signer
// Generates presigned PUT URLs for client-side direct uploads to Cloudflare R2

import { S3Client, PutObjectCommand } from "@aws-sdk/client-s3";
import { getSignedUrl } from "@aws-sdk/s3-request-presigner";

export default {
  async fetch(request, env) {
    // 1. Enable CORS for cross-origin client uploads
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
      // 2. Parse request payload
      const { event_id, mime_type, file_extension } = await request.json();

      if (!event_id || !mime_type) {
        return new Response("Missing required fields: event_id, mime_type", { 
          status: 400, 
          headers: corsHeaders 
        });
      }

      // Generate unique R2 key
      const ext = file_extension || mime_type.split("/")[1] || "webp";
      const objectKey = `meals/${event_id}/analysis_${Date.now()}.${ext}`;

      // 3. Initialize S3 client binding to Cloudflare R2 endpoint
      const s3Client = new S3Client({
        region: "auto",
        endpoint: `https://${env.R2_ACCOUNT_ID}.r2.cloudflarestorage.com`,
        credentials: {
          accessKeyId: env.R2_ACCESS_KEY_ID,
          secretAccessKey: env.R2_SECRET_ACCESS_KEY,
        },
      });

      // 4. Generate presigned PUT URL
      const command = new PutObjectCommand({
        Bucket: env.R2_BUCKET_NAME,
        Key: objectKey,
        ContentType: mime_type,
      });

      // Signed URL expires in 10 minutes (600 seconds)
      const presignedUrl = await getSignedUrl(s3Client, command, { expiresIn: 600 });

      // 5. Return upload payload back to iOS client
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
