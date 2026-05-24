// Cloudflare Worker: ai-analyzer
// Pure Multimodal Edge Ingestion Pipeline supporting Audio + Image direct Files API caches,
// Barcode routing via Open Food Facts API, and a secure /api/save transaction ledger.

export default {
  async fetch(request, env) {
    const corsHeaders = {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type, Authorization",
    };

    if (request.method === "OPTIONS") {
      return new Response(null, { headers: corsHeaders });
    }

    const authHeader = request.headers.get("Authorization");
    const clientKey = env.CLIENT_SECRET_KEY || "intake_secure_shield_902";
    if (!authHeader || authHeader !== `Bearer ${clientKey}`) {
      return new Response(JSON.stringify({ error: "Unauthorized access" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" }
      });
    }

    const url = new URL(request.url);
    const path = url.pathname;

    const validateHost = (urlStr) => {
      const parsed = new URL(urlStr);
      const allowedHosts = [
        env.CDN_DOMAIN || "intake-media.57014886c6cd87ebacf23a94e56a6e0c.r2.cloudflarestorage.com",
        "images.unsplash.com",
        "generativelanguage.googleapis.com"
      ];
      const isAllowed = allowedHosts.some(host => parsed.hostname === host || parsed.hostname.endsWith(host));
      if (!isAllowed) {
        throw new Error(`SSRF Blocked: URL host ${parsed.hostname} is forbidden`);
      }
    };

    const validateUUID = (uuid) => {
      const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
      if (!uuidRegex.test(uuid)) {
        throw new Error("Invalid UUID structure");
      }
    };

    try {
      // =======================================================================
      // ROUTE 1: GET /api/history (Fetch user food events & latest estimates)
      // =======================================================================
      if (request.method === "GET" && path === "/api/history") {
        const userId = url.searchParams.get("user_id") || "usr_sidharth_902";
        
        const eventsQuery = await env.DB.prepare(`
          SELECT * FROM food_events 
          WHERE user_id = ? 
          ORDER BY created_at DESC 
          LIMIT 50
        `).bind(userId).all();
        
        const events = eventsQuery.results || [];
        const enrichedEvents = [];
        
        for (const event of events) {
          const itemsQuery = await env.DB.prepare(`
            SELECT * FROM meal_items WHERE event_id = ?
          `).bind(event.id).all();
          
          const estimateQuery = await env.DB.prepare(`
            SELECT * FROM estimate_versions 
            WHERE event_id = ? 
            ORDER BY created_at DESC 
            LIMIT 1
          `).bind(event.id).first();
          
          enrichedEvents.push({
            ...event,
            items: itemsQuery.results || [],
            latest_estimate: estimateQuery || null
          });
        }
        
        return new Response(JSON.stringify(enrichedEvents), {
          status: 200,
          headers: { ...corsHeaders, "Content-Type": "application/json" }
        });
      }

      // =======================================================================
      // ROUTE 2: GET /api/rollup (Fetch 14-day history rollup)
      // =======================================================================
      if (request.method === "GET" && path === "/api/rollup") {
        const userId = url.searchParams.get("user_id") || "usr_sidharth_902";
        
        const rollupsQuery = await env.DB.prepare(`
          SELECT * FROM daily_rollups 
          WHERE user_id = ? 
          ORDER BY date DESC 
          LIMIT 14
        `).bind(userId).all();
        
        const sortedRollups = (rollupsQuery.results || []).reverse();
        
        return new Response(JSON.stringify(sortedRollups), {
          status: 200,
          headers: { ...corsHeaders, "Content-Type": "application/json" }
        });
      }

      // Read POST payload
      let payload = {};
      if (request.method === "POST") {
        payload = await request.json();
      }

      // =======================================================================
      // ROUTE 3: POST /api/recompute (Text-only recalculation - Stateless)
      // =======================================================================
      if (path === "/api/recompute" || payload.action === "recompute") {
        const { event_id, selection_option, original_detected_items, previous_estimates } = payload;
        
        if (!event_id || !selection_option || !original_detected_items || !previous_estimates) {
          return new Response(
            JSON.stringify({ error: "Missing recompute fields" }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
          );
        }

        validateUUID(event_id);

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
            contents: [{ parts: [{ text: recomputePrompt }] }],
            generationConfig: { responseMimeType: "application/json" }
          })
        });

        if (!geminiResponse.ok) {
          const errorText = await geminiResponse.text();
          throw new Error(`Gemini Recompute failed via Gateway: ${geminiResponse.status} - ${errorText}`);
        }

        const geminiData = await geminiResponse.json();
        const rawText = geminiData.candidates[0].content.parts[0].text;
        const parsed = JSON.parse(rawText.trim());
        const newEstimates = parsed.estimates;

        return new Response(JSON.stringify({ event_id, estimates: newEstimates }), {
          status: 200,
          headers: { ...corsHeaders, "Content-Type": "application/json" }
        });
      }

      // =======================================================================
      // ROUTE 4: POST /api/save (Commit final transaction ledger in D1)
      // =======================================================================
      if (path === "/api/save") {
        const { event_id, user_id, meal_time, meal_type, capture_type, raw_text_note, image_url, items, estimates } = payload;

        if (!event_id || !user_id || !items || !estimates) {
          return new Response(
            JSON.stringify({ error: "Missing required D1 save parameters" }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
          );
        }

        validateUUID(event_id);
        if (image_url) {
          validateHost(image_url);
        }

        const timeStr = meal_time || new Date().toISOString().split("T")[1].slice(0, 5);
        const typeStr = meal_type || "lunch";
        const capType = capture_type || "photo";

        // 1. Write food event log
        await env.DB.prepare(`
          INSERT INTO food_events (
            id, user_id, meal_time, meal_type, capture_type, status, 
            raw_text_note, primary_image_url, thumbnail_url, timezone
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        `).bind(
          event_id,
          user_id,
          timeStr,
          typeStr,
          capType,
          "saved",
          raw_text_note || null,
          image_url || null,
          image_url || null,
          "Asia/Kolkata"
        ).run();

        // 2. Write individual ingredients
        for (const item of items) {
          const itemId = crypto.randomUUID();
          await env.DB.prepare(`
            INSERT INTO meal_items (
              id, event_id, name_detected, name_normalized, portion_unit, portion_value, estimated_grams_likely, confidence
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
          `).bind(
            itemId,
            event_id,
            item.nameDetected || item.name_detected,
            item.nameNormalized || item.name_normalized,
            item.portionUnit || item.portion_unit,
            item.portionValue || item.portion_value,
            item.estimatedGramsLikely || item.estimated_grams_likely || 0,
            item.confidence
          ).run();
        }

        // 3. Write final estimate version
        const primaryEstId = crypto.randomUUID();
        await env.DB.prepare(`
          INSERT INTO estimate_versions (
            id, event_id, model_provider, model_name, prompt_version, 
            nutrition_engine_version, calories_low, calories_high, calories_likely, 
            protein_g, carbs_g, fat_g, fiber_g, confidence_score, uncertainty_reasons
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        `).bind(
          primaryEstId,
          event_id,
          "google-ai",
          "gemini-3.5-flash",
          "v2.2",
          "ledger-v1",
          estimates.caloriesLow || estimates.calories_low,
          estimates.caloriesHigh || estimates.calories_high,
          estimates.caloriesLikely || estimates.calories_likely,
          estimates.proteinG || estimates.protein_g,
          estimates.carbsG || estimates.carbs_g,
          estimates.fatG || estimates.fat_g,
          estimates.fiberG || estimates.fiber_g || 0,
          estimates.confidenceScore || estimates.confidence_score,
          JSON.stringify(estimates.uncertaintyReasons || estimates.uncertainty_reasons)
        ).run();

        // 4. Update aggregates daily rollup
        const todayDate = new Date().toISOString().split("T")[0];
        const isPhoto = image_url ? 1 : 0;
        const isNoPhoto = image_url ? 0 : 1;

        await env.DB.prepare(`
          INSERT INTO daily_rollups (
            user_id, date, calories_low, calories_high, calories_likely, 
            protein_g, carbs_g, fat_g, events_count, photo_logs_count, no_image_logs_count, confidence_score
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, 1, ?, ?, ?)
          ON CONFLICT(user_id, date) DO UPDATE SET
            calories_low = calories_low + ?,
            calories_high = calories_high + ?,
            calories_likely = calories_likely + ?,
            protein_g = protein_g + ?,
            carbs_g = carbs_g + ?,
            fat_g = fat_g + ?,
            events_count = events_count + 1,
            photo_logs_count = photo_logs_count + ?,
            no_image_logs_count = no_image_logs_count + ?
        `).bind(
          user_id, todayDate,
          estimates.caloriesLow || estimates.calories_low,
          estimates.caloriesHigh || estimates.calories_high,
          estimates.caloriesLikely || estimates.calories_likely,
          estimates.proteinG || estimates.protein_g,
          estimates.carbsG || estimates.carbs_g,
          estimates.fatG || estimates.fat_g,
          isPhoto,
          isNoPhoto,
          estimates.confidenceScore || estimates.confidence_score,
          
          estimates.caloriesLow || estimates.calories_low,
          estimates.caloriesHigh || estimates.calories_high,
          estimates.caloriesLikely || estimates.calories_likely,
          estimates.proteinG || estimates.protein_g,
          estimates.carbsG || estimates.carbs_g,
          estimates.fatG || estimates.fat_g,
          isPhoto,
          isNoPhoto
        ).run();

        return new Response(JSON.stringify({ status: "committed" }), {
          status: 200,
          headers: { ...corsHeaders, "Content-Type": "application/json" }
        });
      }

      // =======================================================================
      // ROUTE 5: POST /api/ingest (Standard Media/Barcode Ingestion - Stateless)
      // =======================================================================
      if (path === "/api/ingest" || path === "/") {
        const { event_id, user_id, image_url, audio_url, model_name, barcode } = payload;

        if (!event_id || !user_id) {
          return new Response(
            JSON.stringify({ error: "Missing required identification keys" }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
          );
        }

        validateUUID(event_id);

        // --- BRANCH A: Barcode routing via Open Food Facts API ---
        if (barcode) {
          const barcodeClean = barcode.trim();
          const offUrl = `https://world.openfoodfacts.org/api/v2/product/${barcodeClean}`;
          
          try {
            const offRes = await fetch(offUrl, {
              headers: { "User-Agent": "IntakeApp - iOS - Version 1.0" }
            });
            
            if (offRes.ok) {
              const offData = await offRes.json();
              if (offData.status === 1 && offData.product) {
                const prod = offData.product;
                const name = prod.product_name || "Packaged Food Product";
                const generic = prod.generic_name || name;
                
                // Parse ingredients and active warnings/additives
                const ingredientsText = prod.ingredients_text || "No ingredients list provided";
                const allergens = prod.allergens_from_ingredients || "";
                const additives = prod.additives_tags || [];
                
                // Formulate warning flags
                const warnings = [];
                if (allergens.length > 0) warnings.push(`Allergens: ${allergens}`);
                if (additives.length > 3) warnings.push("High density of artificial additives detected");
                if (prod.nutriments?.sugars_100g > 15) warnings.push("High sugar warning (>15g / 100g)");
                if (prod.nutriments?.["saturated-fat_100g"] > 5) warnings.push("High saturated fat warning");
                
                const cals = Math.round((prod.nutriments?.["energy-kcal_serving"] || prod.nutriments?.["energy-kcal_100"] || 120));
                const prot = Math.round((prod.nutriments?.proteins_serving || prod.nutriments?.proteins_100g || 2));
                const carbs = Math.round((prod.nutriments?.carbohydrates_serving || prod.nutriments?.carbohydrates_100g || 15));
                const fat = Math.round((prod.nutriments?.fat_serving || prod.nutriments?.fat_100g || 3));
                const fiber = Math.round((prod.nutriments?.fiber_serving || prod.nutriments?.fiber_100g || 0));

                const offResponse = {
                  meal_type: "snack",
                  detected_items: [
                    {
                      name_detected: name,
                      name_normalized: generic,
                      portion_unit: prod.serving_size ? "serving" : "100g",
                      portion_value: 1.0,
                      estimated_grams_likely: Math.round(prod.serving_quantity || 100),
                      confidence: "High"
                    }
                  ],
                  estimates: {
                    calories_low: Math.round(cals * 0.9),
                    calories_high: Math.round(cals * 1.1),
                    calories_likely: cals,
                    protein_g: prot,
                    carbs_g: carbs,
                    fat_g: fat,
                    fiber_g: fiber,
                    confidence_score: 98,
                    uncertainty_reasons: warnings
                  },
                  one_question: {
                    id: "refine_barcode_qty",
                    question: `How much of this ${name} did you eat?`,
                    options: ["Quarter Pack", "Half Pack", "Whole Pack", "Two Packs"],
                    default_option: "Whole Pack",
                    correction_type: "portion",
                    ui_type: "fraction_picker"
                  }
                };

                return new Response(JSON.stringify(offResponse), {
                  status: 200,
                  headers: { ...corsHeaders, "Content-Type": "application/json" }
                });
              }
            }
          } catch (_) {
            // OFF fetch fails: fall through automatically to Gemini visual router!
          }
        }

        // --- BRANCH B: Gemini Visual/Audio parser (Barcode Miss or standard photo capture) ---
        if (!image_url) {
          return new Response(
            JSON.stringify({ error: "Missing image asset URL for visual ingestion" }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
          );
        }

        validateHost(image_url);
        if (audio_url) {
          validateHost(audio_url);
        }

        let tempImageName = null;
        let tempAudioName = null;

        const imageResponse = await fetch(image_url);
        if (!imageResponse.ok) {
          throw new Error(`Failed to fetch image from URL: ${image_url}`);
        }
        const imageBuffer = await imageResponse.arrayBuffer();
        const imageMime = imageResponse.headers.get("content-type") || "image/jpeg";

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
        tempImageName = imgUploadData.file.name;

        let audioUri = null;
        if (audio_url) {
          const audioResponse = await fetch(audio_url);
          if (audioResponse.ok) {
            const audioBuffer = await audioResponse.arrayBuffer();
            const audioMime = audioResponse.headers.get("content-type") || "audio/mp4";

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
              tempAudioName = audUploadData.file.name;
            }
          }
        }

        const systemPrompt = `
          You are the Vision & Nutrition Estimation engine of the "Intake" personal nutrition observatory.
          Analyze this food image along with the optional raw voice audio annotation.
          Natively listen to the audio file and cross-reference its details with the meal picture to determine ingredients and quantities.
          
          CRITICAL NUTRITION OBSERVATORY INSTRUCTIONS:
          1. Parse the meal into isolated items with objective, physical units (e.g. portion_unit: "cup", "slice", "bowl", "piece", "gram" and portion_value: 1.5, 2, 350) instead of subjective adjectives like "Large/Medium/Small".
          2. Do not assume or hardcode portion picker selections. Analyze the biggest volumetric or ingredient uncertainty in this specific plate and dynamically construct a calibration question and UI schema to let the user clarify this uncertainty.
          3. Do not include subjective words in the picker choices. Options must represent strict objective scales (e.g., ["0.5 cup", "1 cup", "1.5 cups", "2+ cups"], ["1 slice", "2 slices", "3 slices", "4+ slices"], ["Quarter", "Half", "Three-Quarter", "Whole"]).
          
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
            contents: [{ parts: contentsParts }],
            generationConfig: { responseMimeType: "application/json" }
          })
        });

        if (!geminiResponse.ok) {
          const errorText = await geminiResponse.text();
          throw new Error(`Gemini Vision Parse Failed: ${geminiResponse.status} - ${errorText}`);
        }

        const geminiData = await geminiResponse.json();
        const rawTextResult = geminiData.candidates[0].content.parts[0].text;
        const parsedVision = JSON.parse(rawTextResult.trim());

        // Secure file deletion hooks
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

        return new Response(JSON.stringify({ event_id, ...parsedVision }), {
          status: 200,
          headers: { ...corsHeaders, "Content-Type": "application/json" }
        });
      }

    } catch (error) {
      console.error("FATAL Ingestion Error:", error.message);
      return new Response(
        JSON.stringify({ error: "Ingestion pipeline failure", message: error.message }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }
  }
};
