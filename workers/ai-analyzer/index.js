// Cloudflare Worker: ai-analyzer
// Staged ingestion pipeline leveraging Google Gemini Files API, AI Gateway observability, and dynamic personal priors

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

    let fileName = null; // Stored to ensure cleanup on failures
    try {
      const { event_id, user_id, image_url, voice_transcription, model_name } = await request.json();

      if (!event_id || !user_id || !image_url) {
        return new Response(
          JSON.stringify({ error: "Missing required fields: event_id, user_id, image_url" }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      // =======================================================================
      // STEP 1: Fetch raw image binary from R2
      // =======================================================================
      const imageResponse = await fetch(image_url);
      if (!imageResponse.ok) {
        throw new Error(`Failed to fetch image from secure URL: ${image_url}`);
      }
      const imageBuffer = await imageResponse.arrayBuffer();
      const mimeType = imageResponse.headers.get("content-type") || "image/jpeg";

      // =======================================================================
      // STEP 2: Gemini Files API Ingestion (Binary multipart upload)
      // =======================================================================
      const boundary = "intake_boundary_upload_stream";
      const metadata = JSON.stringify({
        file: {
          displayName: `Ingestion Event ${event_id}`,
          mimeType: mimeType
        }
      });

      // Construct multipart/related body
      const headerStr = `--${boundary}\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n${metadata}\r\n--${boundary}\r\nContent-Type: ${mimeType}\r\n\r\n`;
      const footerStr = `\r\n--${boundary}--\r\n`;

      const encoder = new TextEncoder();
      const headerBytes = encoder.encode(headerStr);
      const footerBytes = encoder.encode(footerStr);

      const combinedBody = new Uint8Array(headerBytes.byteLength + imageBuffer.byteLength + footerBytes.byteLength);
      combinedBody.set(headerBytes, 0);
      combinedBody.set(new Uint8Array(imageBuffer), headerBytes.byteLength);
      combinedBody.set(footerBytes, headerBytes.byteLength + imageBuffer.byteLength);

      // Upload binary directly to Gemini Files API
      const uploadUrl = `https://generativelanguage.googleapis.com/upload/v1beta/files?key=${env.GEMINI_API_KEY}`;
      const uploadResponse = await fetch(uploadUrl, {
        method: "POST",
        headers: {
          "X-Goog-Upload-Protocol": "multipart",
          "Content-Type": `multipart/related; boundary=${boundary}`
        },
        body: combinedBody
      });

      if (!uploadResponse.ok) {
        const errorMsg = await uploadResponse.text();
        throw new Error(`Gemini Files API Upload Failed: ${uploadResponse.status} - ${errorMsg}`);
      }

      const uploadData = await uploadResponse.json();
      const fileUri = uploadData.file.uri;
      fileName = uploadData.file.name; // e.g. "files/xyz123"

      // =======================================================================
      // STEP 3: Retrieve Compounding Personal Priors (Supabase Memory Feed)
      // =======================================================================
      let userPriorsBlock = "";
      try {
        const memoryResponse = await fetch(
          `${env.SUPABASE_URL}/rest/v1/personal_food_memory?user_id=eq.${user_id}`,
          {
            headers: {
              "apikey": env.SUPABASE_ANON_KEY,
              "Authorization": `Bearer ${env.SUPABASE_ANON_KEY}`
            }
          }
        );
        const memories = await memoryResponse.json();
        
        if (memories && memories.length > 0) {
          userPriorsBlock = memories.map(m => 
            `- ${m.display_name} (${m.food_signature}): Usual portion is "${m.usual_portion_label}", typical calories: ${m.usual_calories_low}-${m.usual_calories_high} kcal (likely ${m.usual_calories_likely}). Confidence Score: ${m.confidence_score}%.`
          ).join("\n");
        }
      } catch (dbError) {
        console.error("Supabase Memory query failed:", dbError);
      }

      // =======================================================================
      // STEP 4: Google Gemini Vision Generation via Cloudflare AI Gateway
      // =======================================================================
      const systemPrompt = `
        You are the Vision & Nutrition Estimation engine of the "Intake" personal nutrition observatory.
        Analyze this food image (provided via the Files API URI) along with optional voice annotation context.
        
        CRITICAL PORTION CALIBRATION CALCULATION:
        You must adjust and calibrate your visual estimates using the User's Personal Food Memory priors below!
        If a detected item matches an established food memory signature (by display name or type), leverage the documented portion size and calorie anchors as your baseline calibration to scale the calories and macros realistically.
        
        === USER'S PERSONAL FOOD MEMORY (PRIORS) ===
        ${userPriorsBlock || "No personal memory anchors established yet."}
        ============================================
        
        Break down the meal into individual ingredients, estimate their portion weights (grams) and confidence.
        Calculate calories and macronutrients (protein, carbs, fat, fiber) as a range.
        Do not output mock values. If you cannot recognize the items, fail fast.
        
        Provide your output strictly in this JSON structure:
        {
          "meal_type": "breakfast" | "lunch" | "dinner" | "snack",
          "detected_items": [
            {
              "name_detected": "Kerala Matta Rice",
              "name_normalized": "brown rice",
              "portion_label": "Large" | "Medium" | "Small",
              "estimated_grams_low": 250,
              "estimated_grams_high": 350,
              "estimated_grams_likely": 300,
              "confidence": "High" | "Medium" | "Low"
            }
          ],
          "estimates": {
            "calories_low": 650,
            "calories_high": 850,
            "calories_likely": 750,
            "protein_g": 24,
            "carbs_g": 90,
            "fat_g": 18,
            "fiber_g": 6,
            "confidence_score": 85,
            "uncertainty_reasons": ["depth of plate", "coconut oil quantity in curry"]
          },
          "one_question": {
            "id": "q_rice_qty",
            "question": "Was the Matta Rice serving closer to Small, Medium, or Large?",
            "options": ["Small", "Medium", "Large"],
            "default_option": "Large",
            "correction_type": "portion"
          }
        }
      `;

      // Use verified live model: gemini-3.5-flash
      const selectedModel = model_name || "gemini-3.5-flash";

      // Configure Cloudflare AI Gateway Google AI Studio proxied URL
      const gatewayUrl = `https://gateway.ai.cloudflare.com/v1/${env.CF_ACCOUNT_ID}/${env.CF_GATEWAY_NAME}/google-ai-studio/v1beta/models/${selectedModel}:generateContent`;

      const geminiResponse = await fetch(gatewayUrl, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "x-goog-api-key": env.GEMINI_API_KEY // Cloudflare AI Gateway secure header routing
        },
        body: JSON.stringify({
          contents: [
            {
              parts: [
                { text: systemPrompt },
                { text: `Voice Annotation Context: ${voice_transcription || "None provided"}` },
                {
                  fileData: {
                    fileUri: fileUri,
                    mimeType: mimeType
                  }
                }
              ]
            }
          ],
          generationConfig: {
            responseMimeType: "application/json"
          }
        })
      });

      if (!geminiResponse.ok) {
        const errorText = await geminiResponse.text();
        throw new Error(`Gemini Vision Parse via AI Gateway Failed: ${geminiResponse.status} - ${errorText}`);
      }

      const geminiData = await geminiResponse.json();
      const rawTextResult = geminiData.candidates[0].content.parts[0].text;
      const parsedVision = JSON.parse(rawTextResult.trim());

      // =======================================================================
      // STEP 5: Structured Ingestion Response Payload
      // =======================================================================
      const responsePayload = {
        event_id,
        meal_type: parsedVision.meal_type,
        detected_items: parsedVision.detected_items.map(item => ({
          name_detected: item.name_detected,
          name_normalized: item.name_normalized,
          portion_label: item.portion_label,
          estimated_grams_low: item.estimated_grams_low,
          estimated_grams_high: item.estimated_grams_high,
          estimated_grams_likely: item.estimated_grams_likely,
          confidence: item.confidence
        })),
        estimates: {
          calories_low: parsedVision.estimates.calories_low,
          calories_high: parsedVision.estimates.calories_high,
          calories_likely: parsedVision.estimates.calories_likely,
          protein_g: parsedVision.estimates.protein_g,
          carbs_g: parsedVision.estimates.carbs_g,
          fat_g: parsedVision.estimates.fat_g,
          fiber_g: parsedVision.estimates.fiber_g || 0,
          confidence_score: parsedVision.estimates.confidence_score,
          uncertainty_reasons: parsedVision.estimates.uncertainty_reasons
        },
        one_question: parsedVision.one_question
      };

      // =======================================================================
      // STEP 6: Asynchronous Cleanup of Files API
      // =======================================================================
      // Personal visual information is deleted from Google cache instantly after parsing!
      try {
        await fetch(`https://generativelanguage.googleapis.com/v1beta/${fileName}?key=${env.GEMINI_API_KEY}`, {
          method: "DELETE"
        });
      } catch (cleanupError) {
        console.error("Failed to delete temp file from Gemini:", cleanupError);
      }

      return new Response(JSON.stringify(responsePayload), {
        status: 200,
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json"
        }
      });
    } catch (error) {
      // Hard fail and fail loudly for ingestion debugging
      console.error("FATAL Ingestion Error:", error.message);

      // Attempt files cleanup if file was uploaded before failure
      if (fileName) {
        try {
          await fetch(`https://generativelanguage.googleapis.com/v1beta/${fileName}?key=${env.GEMINI_API_KEY}`, {
            method: "DELETE"
          });
        } catch (_) {}
      }

      return new Response(
        JSON.stringify({
          error: "Ingestion pipeline failure",
          message: error.message
        }),
        {
          status: 500,
          headers: {
            ...corsHeaders,
            "Content-Type": "application/json"
          }
        }
      );
    }
  }
};
