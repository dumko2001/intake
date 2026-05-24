// Cloudflare Worker: ai-analyzer
// Pure Multimodal Edge Ingestion Pipeline supporting Audio + Image direct Files API caches,
// AI-driven dynamic UI forms generation, and synchronous recomputation feedback loops.

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

    let tempImageName = null;
    let tempAudioName = null;

    try {
      const payload = await request.json();
      
      // =======================================================================
      // BRANCH A: Recompute / Calibration Feedback Loop
      // =======================================================================
      if (payload.action === "recompute") {
        const { event_id, selection_option, original_detected_items, previous_estimates } = payload;
        
        if (!event_id || !selection_option || !original_detected_items || !previous_estimates) {
          return new Response(
            JSON.stringify({ error: "Missing recompute fields" }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
          );
        }

        // Call Gemini text-only model to run rapid, clean re-calibration
        const recomputePrompt = `
          You are the Nutrition Recalibration stage of the "Intake" personal nutrition telemetry system.
          The user has responded to your dynamic portion calibration question.
          
          === INITIAL PARSING ESTIMATES ===
          Detected Items: ${JSON.stringify(original_detected_items)}
          Previous Estimates: ${JSON.stringify(previous_estimates)}
          =================================
          
          === USER CALIBRATION CHOICE ===
          The user corrected the quantity: "${selection_option}"
          ===============================
          
          Recalculate the calories and macros (protein, carbs, fat, fiber) strictly using this absolute correction value.
          Scale the specific item's grams and total estimates proportionally.
          
          Output your adjusted calibration strictly in this JSON format:
          {
            "estimates": {
              "calories_low": 720,
              "calories_high": 920,
              "calories_likely": 820,
              "protein_g": 26,
              "carbs_g": 98,
              "fat_g": 20,
              "fiber_g": 7,
              "confidence_score": 95,
              "uncertainty_reasons": ["calibrated rice quantity"]
            }
          }
        `;

        const gatewayUrl = `https://gateway.ai.cloudflare.com/v1/${env.CF_ACCOUNT_ID}/${env.CF_GATEWAY_NAME}/google-ai-studio/v1beta/models/gemini-2.5-flash:generateContent`;

        const geminiResponse = await fetch(gatewayUrl, {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "x-goog-api-key": env.GEMINI_API_KEY
          },
          body: JSON.stringify({
            contents: [
              {
                parts: [{ text: recomputePrompt }]
              }
            ],
            generationConfig: {
              responseMimeType: "application/json"
            }
          })
        });

        if (!geminiResponse.ok) {
          const errorText = await geminiResponse.text();
          throw new Error(`Gemini Recompute failed via Gateway: ${geminiResponse.status} - ${errorText}`);
        }

        const geminiData = await geminiResponse.json();
        const rawText = geminiData.candidates[0].content.parts[0].text;
        const recomputedEstimates = JSON.parse(rawText.trim());

        return new Response(JSON.stringify({ event_id, ...recomputedEstimates }), {
          status: 200,
          headers: { ...corsHeaders, "Content-Type": "application/json" }
        });
      }

      // =======================================================================
      // BRANCH B: Pure Multimodal Ingestion Ingestion (Audio + Image)
      // =======================================================================
      const { event_id, user_id, image_url, audio_url, model_name } = payload;

      if (!event_id || !user_id || !image_url) {
        return new Response(
          JSON.stringify({ error: "Missing required ingestion fields: event_id, user_id, image_url" }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      // 1. Fetch raw image binary from secure R2 URL
      const imageResponse = await fetch(image_url);
      if (!imageResponse.ok) {
        throw new Error(`Failed to fetch image from URL: ${image_url}`);
      }
      const imageBuffer = await imageResponse.arrayBuffer();
      const imageMime = imageResponse.headers.get("content-type") || "image/jpeg";

      // 2. Upload raw image directly to Gemini Files API (Zero-Base64 Edge stream!)
      const imgBoundary = "intake_boundary_img_upload";
      const imgMetadata = JSON.stringify({ file: { displayName: `Plate ${event_id}`, mimeType: imageMime } });
      const imgHeader = `--${imgBoundary}\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n${imgMetadata}\r\n--${imgBoundary}\r\nContent-Type: ${imageMime}\r\n\r\n`;
      const imgFooter = `\r\n--${imgBoundary}--\r\n`;

      const encoder = new TextEncoder();
      const imgHeaderBytes = encoder.encode(imgHeader);
      const imgFooterBytes = encoder.encode(imgFooter);
      const imgPayload = new Uint8Array(imgHeaderBytes.byteLength + imageBuffer.byteLength + imgFooterBytes.byteLength);
      imgPayload.set(imgHeaderBytes, 0);
      imgPayload.set(new Uint8Array(imageBuffer), imgHeaderBytes.byteLength);
      imgPayload.set(imgFooterBytes, imgHeaderBytes.byteLength + imageBuffer.byteLength);

      const imgUploadResponse = await fetch(`https://generativelanguage.googleapis.com/upload/v1beta/files?key=${env.GEMINI_API_KEY}`, {
        method: "POST",
        headers: {
          "X-Goog-Upload-Protocol": "multipart",
          "Content-Type": `multipart/related; boundary=${imgBoundary}`
        },
        body: imgPayload
      });

      if (!imgUploadResponse.ok) {
        const errorMsg = await imgUploadResponse.text();
        throw new Error(`Image Upload to Gemini Files API Failed: ${imgUploadResponse.status} - ${errorMsg}`);
      }

      const imgUploadData = await imgUploadResponse.json();
      const imageUri = imgUploadData.file.uri;
      tempImageName = imgUploadData.file.name; // e.g. "files/img123"

      // 3. Handle optional audio voice notes Direct Ingestion
      let audioUri = null;
      if (audio_url) {
        const audioResponse = await fetch(audio_url);
        if (audioResponse.ok) {
          const audioBuffer = await audioResponse.arrayBuffer();
          const audioMime = audioResponse.headers.get("content-type") || "audio/mp4";

          // Upload raw voice note audio to Gemini Files API
          const audBoundary = "intake_boundary_aud_upload";
          const audMetadata = JSON.stringify({ file: { displayName: `Voice ${event_id}`, mimeType: audioMime } });
          const audHeader = `--${audBoundary}\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n${audMetadata}\r\n--${audBoundary}\r\nContent-Type: ${audioMime}\r\n\r\n`;
          const audFooter = `\r\n--${audBoundary}--\r\n`;

          const audHeaderBytes = encoder.encode(audHeader);
          const audFooterBytes = encoder.encode(audFooter);
          const audPayload = new Uint8Array(audHeaderBytes.byteLength + audioBuffer.byteLength + audFooterBytes.byteLength);
          audPayload.set(audHeaderBytes, 0);
          audPayload.set(new Uint8Array(audioBuffer), audHeaderBytes.byteLength);
          audPayload.set(audFooterBytes, audHeaderBytes.byteLength + audioBuffer.byteLength);

          const audUploadResponse = await fetch(`https://generativelanguage.googleapis.com/upload/v1beta/files?key=${env.GEMINI_API_KEY}`, {
            method: "POST",
            headers: {
              "X-Goog-Upload-Protocol": "multipart",
              "Content-Type": `multipart/related; boundary=${audBoundary}`
            },
            body: audPayload
          });

          if (audUploadResponse.ok) {
            const audUploadData = await audUploadResponse.json();
            audioUri = audUploadData.file.uri;
            tempAudioName = audUploadData.file.name; // e.g. "files/aud123"
          }
        }
      }

      // =======================================================================
      // STEP 4: Google Gemini Vision Generation via Cloudflare AI Gateway
      // =======================================================================
      const systemPrompt = `
        You are the Vision & Nutrition Estimation engine of the "Intake" personal nutrition observatory.
        Analyze this food image along with the optional raw voice audio annotation.
        Natively listen to the audio file and cross-reference its details with the meal picture to determine ingredients and quantities.
        
        CRITICAL NUTRITION OBSERVATORY INSTRUCTIONS:
        1. Parse the meal into isolated items with objective, physical units (e.g. portion_unit: "cup", "slice", "bowl", "piece", "gram" and portion_value: 1.5, 2, 350) instead of subjective adjectives like "Large/Medium/Small".
        2. Do not assume or hardcode portion picker selections. Analyze the biggest volumetric or ingredient uncertainty in this specific plate and dynamically construct a calibration question and UI schema to let the user clarify this uncertainty.
        
        DYNAMIC FORM UI DESIGN PARAMETERS:
        Match the "ui_type" directly to the food structure:
        - "slice_counter": For cut slices (e.g., pizza, pies, cakes). options: ["1 slice", "2 slices", "3 slices", "4+ slices"]
        - "fraction_picker": For wholes, fractions, or halves (e.g. fruits, apples, bananas, sandwiches). options: ["Quarter", "Half", "Three-Quarter", "Whole"]
        - "unit_slider": For grains, liquids, or mass servings (e.g. rice servings, soup bowls, oil spoons). options: ["0.5 cup", "1 cup", "1.5 cups", "2+ cups"] or ["1 spoon", "2 spoons", "3+ spoons"]
        - "single_choice": Standard default discrete choices.
        
        Provide your output strictly in this JSON structure:
        {
          "meal_type": "breakfast" | "lunch" | "dinner" | "snack",
          "detected_items": [
            {
              "name_detected": "Kerala Matta Rice",
              "name_normalized": "brown rice",
              "portion_unit": "cup" | "slice" | "bowl" | "piece" | "gram",
              "portion_value": 1.5,
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
            "id": "refine_rice_qty",
            "question": "How many cups of Matta Rice did you serve?",
            "options": ["0.5 cup", "1 cup", "1.5 cups", "2+ cups"],
            "default_option": "1.5 cups",
            "correction_type": "portion",
            "ui_type": "unit_slider" | "slice_counter" | "fraction_picker" | "single_choice"
          }
        }
      `;

      // Use verified live model: gemini-3.5-flash
      const selectedModel = model_name || "gemini-3.5-flash";
      const gatewayUrl = `https://gateway.ai.cloudflare.com/v1/${env.CF_ACCOUNT_ID}/${env.CF_GATEWAY_NAME}/google-ai-studio/v1beta/models/${selectedModel}:generateContent`;

      const contentsParts = [
        { text: systemPrompt },
        { fileData: { fileUri: imageUri, mimeType: imageMime } }
      ];

      if (audioUri) {
        const audioMime = tempAudioName ? "audio/mp4" : "audio/m4a";
        contentsParts.push({ fileData: { fileUri: audioUri, mimeType: audioMime } });
      }

      const geminiResponse = await fetch(gatewayUrl, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "x-goog-api-key": env.GEMINI_API_KEY
        },
        body: JSON.stringify({
          contents: [
            {
              parts: contentsParts
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
          portion_unit: item.portion_unit,
          portion_value: item.portion_value,
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
      // Visual and audio cache purged instantly to safeguard visual and vocal privacy
      if (tempImageName) {
        try {
          await fetch(`https://generativelanguage.googleapis.com/v1beta/${tempImageName}?key=${env.GEMINI_API_KEY}`, {
            method: "DELETE"
          });
        } catch (_) {}
      }
      if (tempAudioName) {
        try {
          await fetch(`https://generativelanguage.googleapis.com/v1beta/${tempAudioName}?key=${env.GEMINI_API_KEY}`, {
            method: "DELETE"
          });
        } catch (_) {}
      }

      return new Response(JSON.stringify(responsePayload), {
        status: 200,
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json"
        }
      });
    } catch (error) {
      console.error("FATAL Ingestion Error:", error.message);

      // Attempt secure file purge cleanup if uploads were made before pipeline failed
      if (tempImageName) {
        try {
          await fetch(`https://generativelanguage.googleapis.com/v1beta/${tempImageName}?key=${env.GEMINI_API_KEY}`, {
            method: "DELETE"
          });
        } catch (_) {}
      }
      if (tempAudioName) {
        try {
          await fetch(`https://generativelanguage.googleapis.com/v1beta/${tempAudioName}?key=${env.GEMINI_API_KEY}`, {
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
