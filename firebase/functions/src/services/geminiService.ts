import {
  GoogleGenerativeAI,
} from "@google/generative-ai";
import { MenuItem, DishAnalysis } from "../types";
import { getCachedReviewSummary, setCachedReviewSummary } from "./cacheService";

let genAI: GoogleGenerativeAI;

function getGenAI(): GoogleGenerativeAI {
  if (!genAI) {
    const apiKey = process.env.GEMINI_API_KEY;
    if (!apiKey) {
      throw new Error("GEMINI_API_KEY is not configured");
    }
    genAI = new GoogleGenerativeAI(apiKey);
  }
  return genAI;
}

// ============================================
// Retry helper for flaky Gemini API calls
// ============================================

async function withRetry<T>(
  fn: () => Promise<T>,
  label: string,
  maxRetries = 3,
  delayMs = 1500
): Promise<T> {
  for (let attempt = 1; attempt <= maxRetries + 1; attempt++) {
    try {
      const callStart = Date.now();
      console.log(`[geminiService] ${label} attempt ${attempt}/${maxRetries + 1} starting...`);
      const result = await fn();
      console.log(`[geminiService] ${label} attempt ${attempt} succeeded in ${Date.now() - callStart}ms`);
      return result;
    } catch (err: any) {
      const isLastAttempt = attempt > maxRetries;
      const errType = err.constructor?.name || "Unknown";
      const errCode = err.code || "none";
      const errCause = err.cause ? `cause: ${err.cause.message || err.cause}` : "no cause";
      const isRetryable = err.message?.includes("fetch failed") ||
        err.message?.includes("503") ||
        err.message?.includes("429") ||
        err.message?.includes("RESOURCE_EXHAUSTED") ||
        err.message?.includes("ECONNRESET") ||
        err.message?.includes("timeout");

      console.error(`[geminiService] ${label} attempt ${attempt}/${maxRetries + 1} FAILED:
  type: ${errType}
  code: ${errCode}
  message: ${err.message}
  ${errCause}
  retryable: ${isRetryable}
  isLast: ${isLastAttempt}
  stack: ${err.stack?.split("\n").slice(0, 3).join(" | ")}`);

      if (isLastAttempt || !isRetryable) {
        throw err;
      }

      const delay = delayMs * attempt;
      console.warn(`[geminiService] Retrying ${label} in ${delay}ms...`);
      await new Promise((resolve) => setTimeout(resolve, delay));
    }
  }
  throw new Error("Unreachable");
}

// ============================================
// Step 1: Menu OCR via Gemini Multimodal
// ============================================

const OCR_PROMPT = `You are analyzing restaurant menu images. Extract ALL food and drink items.

Return a valid JSON array with this structure:
[
  {
    "id": "unique-id-1",
    "name": "Dish Name",
    "price": "€12.50" or null,
    "category": "Antipasti" or null,
    "description": "Brief description if visible" or null,
    "courseType": "main" or null,
    "dietary": ["vegetarian"] or []
  }
]

courseType MUST be one of: "starter", "main", "dessert", "drink", "side", "menu"
- "starter": Appetizers, starters, soups, salads, small plates, tapas, antipasti
- "main": Main courses, burgers, steaks, pasta, pizza, curry, fish, entrees
- "dessert": Desserts, ice cream, cakes, sweet items
- "drink": All beverages (alcoholic and non-alcoholic)
- "side": Side dishes, extras, add-ons, dips, sauces
- "menu": Set menus, combos, meal deals, kids menus
- Determine courseType from the menu section headers AND the dish itself

dietary MUST be an array with zero or more of: "vegetarian", "vegan", "gluten-free"
- "vegetarian": No meat, no fish. Eggs and dairy OK. Look for (V), vegetarisch, 🌿 symbols.
- "vegan": No animal products at all. Look for (VG), vegan, 🌱 symbols.
- "gluten-free": No wheat/gluten. Look for (GF), glutenfrei, 🌾 symbols.
- Infer from ingredients if not explicitly marked (e.g. "Gemüse-Curry mit Reis" → ["vegetarian"])
- If vegan, also include "vegetarian" (vegan implies vegetarian)
- Drinks are NOT tagged unless explicitly relevant (e.g. milkshake is vegetarian but don't tag water/coffee)
- If unsure, leave empty []

Rules:
- Include EVERY food and drink item on the menu
- Preserve the original language of dish names
- Include prices exactly as shown (with currency symbol)
- Group by category if categories are visible on the menu
- Ignore decorative text, restaurant name, headers, footers, page numbers
- If multiple pages are provided, combine into one deduplicated list. CRITICAL: The same dish appearing on different pages (e.g. dessert menu printed on two pages, or ice cream listed both as a section and individually) must only appear ONCE. Deduplicate by matching name + price — if both match, keep only one entry.
- Generate a unique id for each item (e.g., "dish-1", "dish-2")
- Return ONLY the JSON array, no markdown, no explanation

PORTION SIZES: If a dish offers multiple portion sizes (e.g. "1 Stück 20.50 / 2 Stück 29.50"), create ONE entry per size but use the FULL dish name including the parent name:
- CORRECT: "Quarkteigkrapfen Rind (1 Stück)" with price "20.50"
- CORRECT: "Quarkteigkrapfen Rind (2 Stück)" with price "29.50"
- WRONG: "1 Stück" as standalone dish name
- WRONG: "2 Stück" as standalone dish name
Always include the parent dish name so each entry makes sense on its own.

SUB-VARIANTS: If dishes are listed under a category header (e.g. "HEFETEIGFLADEN" with variants "Speck", "Bella Italia"), include the parent name in each variant:
- CORRECT: "Hefeteigfladen Speck", "Hefeteigfladen Bella Italia"
- WRONG: "Speck", "Bella Italia" (meaningless without context)
The dish name must be self-explanatory — a user seeing ONLY the name should understand what it is.`;

export async function extractMenuItems(
  base64Images: string[]
): Promise<MenuItem[]> {
  const ai = getGenAI();
  const model = ai.getGenerativeModel({
    model: "gemini-2.5-flash",
    generationConfig: {
      maxOutputTokens: 65536,
      // @ts-ignore — thinkingConfig is supported by gemini-2.5-flash but not yet in SDK types
      thinkingConfig: { thinkingBudget: 0 }, // Disable thinking for OCR — pure extraction, no reasoning needed
    },
  } as any);

  // Build multimodal content: images + prompt
  const imageParts = base64Images.map((base64) => ({
    inlineData: {
      mimeType: "image/jpeg" as const,
      data: base64,
    },
  }));

  console.log(`[geminiService] OCR: sending ${base64Images.length} image(s), total size: ${Math.round(base64Images.reduce((sum, img) => sum + img.length, 0) / 1024)}KB base64`);

  const result = await withRetry(
    () => model.generateContent([...imageParts, { text: OCR_PROMPT }]),
    "OCR",
    3,  // 3 retries (4 attempts total)
    2000 // 2s initial delay
  );

  const responseText = result.response.text();
  console.log(`[geminiService] OCR response length: ${responseText.length} chars`);
  console.log(`[geminiService] OCR response preview (first 500): ${responseText.substring(0, 500)}`);
  console.log(`[geminiService] OCR response end (last 500): ${responseText.substring(Math.max(0, responseText.length - 500))}`);

  // Log finish reason and token usage
  const candidate = result.response.candidates?.[0];
  console.log(`[geminiService] OCR finish reason: ${candidate?.finishReason || "unknown"}`);
  const usage = result.response.usageMetadata;
  console.log(`[geminiService] OCR tokens — prompt: ${usage?.promptTokenCount}, output: ${usage?.candidatesTokenCount}, total: ${usage?.totalTokenCount}`);

  // Strip markdown code block markers (```json ... ```)
  let cleaned = responseText.replace(/```json\s*/gi, "").replace(/```\s*/g, "").trim();

  // Try to find JSON array
  let jsonMatch = cleaned.match(/\[[\s\S]*\]/);

  // If no closing ], the response was truncated — try to repair
  if (!jsonMatch && cleaned.includes("[")) {
    console.warn("[geminiService] OCR: Response appears truncated, attempting repair...");
    const startIdx = cleaned.indexOf("[");
    let truncated = cleaned.substring(startIdx);

    // Remove any trailing incomplete object (everything after last complete })
    const lastBrace = truncated.lastIndexOf("}");
    if (lastBrace > 0) {
      truncated = truncated.substring(0, lastBrace + 1);
      // Remove trailing comma if present
      truncated = truncated.replace(/,\s*$/, "");
      // Close the array
      truncated += "]";
      jsonMatch = [truncated];
      console.log(`[geminiService] OCR: Repaired truncated array (${truncated.length} chars)`);
    }
  }

  if (!jsonMatch) {
    console.error("[geminiService] OCR: No JSON array found. Response preview:", responseText.substring(0, 500));
    throw new Error("Failed to extract menu items: no JSON array in response");
  }

  try {
    const items: MenuItem[] = safeParseJSON(jsonMatch[0]);
    console.log(`[geminiService] OCR: parsed ${items.length} menu items`);
    return items;
  } catch (parseError: any) {
    console.error("[geminiService] OCR JSON parse failed:", parseError.message);
    console.error("[geminiService] OCR JSON preview:", jsonMatch[0].substring(0, 500));
    throw parseError;
  }
}

// ============================================
// Step 2: Two-Phase Review Analysis
// Phase 1: Search reviews once → structured summary
// Phase 2: Score dishes using shared summary (no search)
// ============================================

const BATCH_SIZE = 65; // Larger batches = fewer API calls (130 dishes → 2 batches)

/**
 * Two-phase analysis for consistent scoring:
 * Phase 1: One Gemini call WITH Google Search to gather all review data
 * Phase 2: Batch scoring calls WITHOUT search, using shared review context
 */
export async function analyzeWithGrounding(
  restaurantName: string,
  restaurantAddress: string,
  menuItems: MenuItem[],
  placesReviews: string[] = [],
  totalRatings?: number,
  placeId?: string,
  generativeSummary?: string
): Promise<{ dishes: DishAnalysis[]; cached: boolean }> {
  // --- Phase 1: Search reviews once (with cache) ---
  let reviewSummary: string | null = null;
  let cached = false;

  if (placeId) {
    reviewSummary = await getCachedReviewSummary(placeId);
    if (reviewSummary) {
      cached = true;
      console.log(`[geminiService] Phase 1: ⚡ Using cached review summary (${reviewSummary.length} chars)`);
    }
  }

  const pipelineStart = Date.now();

  if (!reviewSummary) {
    console.log(`[geminiService] Phase 1: Searching reviews for "${restaurantName}"...`);
    const p1Start = Date.now();
    reviewSummary = await searchRestaurantReviews(
      restaurantName,
      restaurantAddress,
      placesReviews,
      totalRatings,
      generativeSummary
    );
    console.log(`[geminiService] Phase 1 complete in ${Date.now() - p1Start}ms. Review summary: ${reviewSummary.length} chars`);
    console.log(`[geminiService] Review summary preview: ${reviewSummary.substring(0, 500)}...`);

    // Cache the result (don't await — fire and forget)
    if (placeId) {
      setCachedReviewSummary(placeId, restaurantName, reviewSummary).catch(() => {});
    }
  }

  // --- Phase 2: Score dishes in batches using shared context ---
  const batches: MenuItem[][] = [];
  for (let i = 0; i < menuItems.length; i += BATCH_SIZE) {
    batches.push(menuItems.slice(i, i + BATCH_SIZE));
  }

  console.log(`[geminiService] Phase 2: Scoring ${menuItems.length} dishes in ${batches.length} batch(es) (all parallel, gemini-2.5-flash)`);

  // Run all batches in parallel (thinking disabled = no more fetch issues)
  const p2Start = Date.now();
  const batchResults = await Promise.all(
    batches.map(async (batch, batchIdx) => {
      try {
        console.log(`[geminiService] Scoring batch ${batchIdx + 1}/${batches.length} (${batch.length} dishes)...`);
        const result = await scoreBatch(restaurantName, batch, reviewSummary!, totalRatings);
        console.log(`[geminiService] Scoring batch ${batchIdx + 1} done (${result.length} dishes scored)`);
        return result;
      } catch (err: any) {
        console.error(`[geminiService] Scoring batch ${batchIdx + 1} failed: ${err.message}`);
        return batch.map((item) => ({
          id: item.id,
          name: item.name,
          price: item.price,
          score: 5,
          mentions: 0,
          sentiment: "unmentioned" as const,
          summary: "Analyse konnte nicht durchgeführt werden.",
          category: item.category,
          courseType: item.courseType ?? null,
          baseGroup: null,
          dietary: item.dietary ?? [],
        }));
      }
    })
  );

  console.log(`[geminiService] Phase 2 complete in ${Date.now() - p2Start}ms. Total pipeline: ${Date.now() - pipelineStart}ms`);
  return { dishes: batchResults.flat(), cached };
}

// ============================================
// Phase 1: Search reviews for the restaurant
// ============================================

async function searchRestaurantReviews(
  restaurantName: string,
  restaurantAddress: string,
  placesReviews: string[],
  totalRatings?: number,
  generativeSummary?: string
): Promise<string> {
  const ai = getGenAI();

  const model = ai.getGenerativeModel({
    model: "gemini-2.5-flash",
    generationConfig: {
      temperature: 0,
      maxOutputTokens: 16384,
      // @ts-ignore
      thinkingConfig: { thinkingBudget: 0 },
    },
    tools: [
      {
        googleSearch: {},
      } as any,
    ],
  } as any);

  const reviewContext = placesReviews.length > 0
    ? `\n\nDIRECT GOOGLE REVIEWS (${placesReviews.length} most relevant, provided by Google):\n${placesReviews.map((r, i) => `Review ${i + 1}: "${r}"`).join("\n\n")}\n`
    : "";

  const generativeSummaryContext = generativeSummary
    ? `\n\nGOOGLE'S AI SUMMARY OF ALL ${totalRatings ?? ""} REVIEWS (generated by Google from the COMPLETE review corpus — this is the most authoritative source):\n"${generativeSummary}"\n\nIMPORTANT: Any dish mentioned in Google's AI summary is a CONFIRMED popular dish — it was significant enough for Google's algorithm to highlight it across all reviews. Treat these as Tier 1 / Tier 2 dishes.\n`
    : "";

  const prompt = `You are a restaurant review researcher. Your job is to find and catalog ALL food/drink mentions in reviews for "${restaurantName}" at "${restaurantAddress}".
${generativeSummaryContext}${reviewContext}
TASK: Search for reviews of this restaurant online and COMBINE with the sources above to create a comprehensive review summary.

Your data sources, in order of authority:
1. GOOGLE'S AI SUMMARY (above) — the gold standard, based on ALL reviews
2. DIRECT GOOGLE REVIEWS (above) — ${placesReviews.length} individual reviews
3. YOUR ONLINE SEARCH — search for additional reviews on TripAdvisor, Yelp, food blogs

Search for:
- "${restaurantName} reviews"
- "${restaurantName} best dishes"
- "${restaurantName}" on TripAdvisor, Yelp, food blogs

OUTPUT FORMAT (plain text, NOT JSON):

## DISH INDEX
List EVERY specific food/drink item mentioned in ANY source. For each dish:
- Name it EXACTLY as a menu would (e.g. "Caesar Bowl" not "salad")
- Note how many distinct sources mention it
- Include sentiment and key quotes
Format: "- [dish name]: [X] distinct sources, [positive/mixed/negative], key quotes"

CRITICAL: If Google's AI summary mentions a dish/category, you MUST include it in the DISH INDEX with its specific name. Do NOT skip dishes that appear in the AI summary.

## SENTIMENT CLUSTERS
Group observations by food category with specific dish names.

## TOP KEYWORDS
Recurring terms from reviews.

## OVERALL RESTAURANT IMPRESSION
2-3 sentences summarizing the general consensus.

${totalRatings ? `This restaurant has ${totalRatings} total Google reviews.` : ""}

IMPORTANT: Be exhaustive — include EVERY dish mentioned in ANY source, even once. Better to include too many than too few.`;

  const result = await withRetry(
    () => model.generateContent(prompt),
    "Review search",
    2,
    3000
  );

  return result.response.text();
}

/**
 * Attempt to parse JSON, fixing common Gemini formatting issues.
 * Tries: raw parse → strip trailing commas → fix unescaped quotes in strings.
 */
function safeParseJSON(text: string): any[] {
  // Attempt 1: Direct parse
  try {
    return JSON.parse(text);
  } catch (e) {
    console.warn("[geminiService] Direct JSON parse failed, attempting fixes...");
  }

  // Attempt 2: Remove trailing commas before ] or }
  let fixed = text.replace(/,\s*([\]}])/g, "$1");
  try {
    return JSON.parse(fixed);
  } catch (e) {
    console.warn("[geminiService] Trailing comma fix didn't help, trying more fixes...");
  }

  // Attempt 3: Try to fix unescaped quotes inside string values
  // Replace unescaped quotes within string values (common Gemini issue)
  fixed = fixed.replace(
    /:\s*"((?:[^"\\]|\\.)*)"/g,
    (match, content) => {
      // Re-escape any unescaped internal quotes
      const cleaned = content.replace(/(?<!\\)"/g, '\\"');
      return `: "${cleaned}"`;
    }
  );
  try {
    return JSON.parse(fixed);
  } catch (e) {
    console.warn("[geminiService] All JSON fixes failed, trying line-by-line object extraction...");
  }

  // Attempt 4: Try to extract individual JSON objects from the array
  const objects: any[] = [];
  const objRegex = /\{[^{}]*\}/g;
  let match;
  while ((match = objRegex.exec(text)) !== null) {
    try {
      objects.push(JSON.parse(match[0]));
    } catch {
      // Skip malformed objects
    }
  }
  if (objects.length > 0) {
    console.log(`[geminiService] Recovered ${objects.length} objects via line-by-line extraction`);
    return objects;
  }

  // Give up
  throw new Error("Failed to parse Gemini JSON response after all fix attempts");
}

// ============================================
// Phase 2: Score dishes using shared review data
// ============================================

async function scoreBatch(
  restaurantName: string,
  menuItems: MenuItem[],
  reviewSummary: string,
  totalRatings?: number
): Promise<DishAnalysis[]> {
  const ai = getGenAI();

  // Use gemini-2.5-flash for scoring: much faster, no "thinking" overhead
  // Scoring is simple matching (dish name → review summary), doesn't need deep reasoning
  const model = ai.getGenerativeModel({
    model: "gemini-2.5-flash",
    generationConfig: {
      temperature: 0,
      maxOutputTokens: 65536,
      // @ts-ignore
      thinkingConfig: { thinkingBudget: 0 },
    },
  } as any);

  const foodReviewPool = totalRatings ? Math.round(totalRatings * 0.4) : null;

  const dishList = menuItems
    .map((item) => `- [${item.id}] ${item.name}${item.price ? ` (${item.price})` : ""}${item.courseType ? ` [${item.courseType}]` : ""}${item.dietary?.length ? ` {${item.dietary.join(", ")}}` : ""}`)
    .join("\n");

  const estimationContext = foodReviewPool
    ? `\nMENTION ESTIMATION — CRITICAL:
The review summary above shows "X distinct sources" per dish. These are just the sources we FOUND online.
The restaurant has ${totalRatings} total Google reviews. About 40% mention food → ~${foodReviewPool} food-mentioning reviews.
You MUST EXTRAPOLATE from the found sources to estimate TOTAL mentions across all ${foodReviewPool} food reviews.

DO NOT use the raw source count as the mention number! "3 distinct sources" does NOT mean 3 mentions.

ESTIMATION TIERS:
TIER 1 — SIGNATURE (3+ sources, enthusiastic praise, clearly a house specialty):
→ "mentions": ${Math.round(foodReviewPool * 0.15)}-${Math.round(foodReviewPool * 0.25)} (15-25% of food pool)

TIER 2 — POPULAR (1-2 sources, positive sentiment, recommended):
→ "mentions": ${Math.round(foodReviewPool * 0.05)}-${Math.round(foodReviewPool * 0.10)} (5-10% of food pool)

TIER 3 — OCCASIONALLY MENTIONED (mentioned once briefly, neutral):
→ "mentions": ${Math.round(foodReviewPool * 0.01)}-${Math.round(foodReviewPool * 0.03)} (1-3% of food pool)

TIER 4 — NOT IN REVIEW SUMMARY:
→ "mentions": 0, "score": 5, "sentiment": "unmentioned"

Example for this restaurant (${totalRatings} reviews, ~${foodReviewPool} food reviews):
- Signature dish found in 4 sources → mentions: ~${Math.round(foodReviewPool * 0.20)}
- Popular dish found in 2 sources → mentions: ~${Math.round(foodReviewPool * 0.07)}
- Briefly mentioned in 1 source → mentions: ~${Math.round(foodReviewPool * 0.02)}
- Not found at all → mentions: 0\n`
    : "";

  const prompt = `You are scoring restaurant dishes based on pre-collected review data.

RESTAURANT: "${restaurantName}"

REVIEW SUMMARY (collected from Google Reviews, TripAdvisor, blogs, etc.):
---
${reviewSummary}
---
${estimationContext}
DISHES TO SCORE:
${dishList}

INSTRUCTIONS:
Match each dish above against the review summary. A dish counts as "mentioned" ONLY if its SPECIFIC NAME (or an obvious variant/abbreviation) appears in the DISH INDEX.

MATCHING RULES — READ CAREFULLY:
1. "Burgers: 2 sources, positive" → ONLY the SPECIFIC burger mentioned gets credit. If reviews praise "Madness Burger" by name, only Madness Burger gets 7+. Other burgers (Linsenburger, Cheeseburger, Kids Burger) do NOT get the same score — they are different dishes. Generic "burgers" praise = max score 6 for unspecified variants.
2. "Nachos: positive" → "Macho Nachos" gets credit (obvious match), "Chips & Dips" does NOT.
3. "Desserts were good" or "sweet delicacies" → NO individual dessert gets credit. Generic category praise ≠ specific dish review.
4. "Curly Fries" → "Curly Fries" yes, "French Fries" NO.
5. "Fajitas: mixed" → ALL fajita variants share this data (same baseGroup).
6. Shared criticism: "Fajitas and Enchiladas had raw veggies" — if OTHER reviews ALSO criticize fajitas but NOT enchiladas, then fajitas are the primary target (full weight) and enchiladas are incidental (reduced weight, +1 score point).

CONDIMENTS & STANDARD SIDES ARE NOT DISHES:
Ketchup, Mayonnaise, BBQ sauce, mustard, sour cream, guacamole (as dip), chimichurri, butter, salad dressing — these are NEVER "mentioned in reviews" as standalone items. Even if the review summary says "sauces on burgers", this is about burgers, NOT about individual sauces. These items MUST be: mentions: 0, score: 5, sentiment: "unmentioned".
Only exception: If a condiment/side IS the reviewed item (e.g. "their guacamole is amazing" as a standalone appetizer).

BREAD, PRETZELS, BAGELS as sides:
Standard bread/pretzel sides (e.g. "Ofenfrische Brezel", "Bagel") are NOT signature dishes even if the review summary mentions bread in passing. These are accompaniments. Max score 6, and mentions should reflect their minor role — use TIER 3 at most, NOT tier 1/2.

KIDS MENUS are NOT signature dishes:
Items with courseType "menu" that are kids versions (e.g. "Kids Burger", "Kids Hörnli", "Chicken Nuggets" from kids menu) are simplified/smaller portions. They are NEVER reviewed individually. Score: 5, mentions: 0, sentiment: "unmentioned" — UNLESS the review summary specifically names the kids version.

ADD-ONS AND EXTRAS are NOT standalone dishes:
Items like "Extra Patty", "Extra Portion", "zusätzlichen Krapfen", "+6.00 Extra Linsen Patty" are add-ons to other dishes. They inherit NO review credit from the base dish. Score: 5, mentions: 0, sentiment: "unmentioned".

MENTIONS MUST MATCH THE SCORE — consistency rule:
- Score 9-10 → TIER 1 mentions only (signature level)
- Score 7-8 → TIER 2 mentions only (popular level)
- Score 6 → TIER 3 mentions at most (occasionally mentioned)
- Score 5 → mentions: 0
A dish with score 6 must NOT have 100+ mentions. A dish with score 9 must NOT have 10 mentions. The tier and score must be aligned.

CRITICAL RULES:
1. ONLY use data from the review summary above. Do NOT invent or hallucinate review data.
2. If a dish is NOT specifically named → mentions: 0, score: 5, sentiment: "unmentioned".
3. Size variants of the same dish (e.g. "200g" vs "300g") MUST share the same score, mentions, and sentiment.
4. Dishes with the SAME baseGroup MUST have the SAME mention count. They share the same review evidence. Do NOT artificially increment (+3, +5) per variant.
5. Mentions MUST be whole integers. VARY them between DIFFERENT dishes/baseGroups — but same baseGroup = same number.

For each dish, return JSON:
[
  {
    "id": "dish-1",
    "name": "Dish Name",
    "price": "€12.50" or null,
    "score": 7,
    "mentions": 145,
    "sentiment": "positive",
    "summary": "German summary with specific details from reviews",
    "category": "Burgers" or null,
    "courseType": "main" or null,
    "baseGroup": "poutine" or null,
    "dietary": ["vegetarian"] or []
  }
]

baseGroup RULES:
- Same base dish + different filling/topping/size/season → SAME baseGroup (e.g. all "Quarkteigkrapfen" variants including "Saison" → "quarkteigkrapfen")
- Different base ingredient or concept → DIFFERENT baseGroup even if same category. Examples:
  - "Madness Burger" (beef) ≠ "Linsenburger" (lentil) → different baseGroups ("madness-burger" vs "linsenburger")
  - "Cheeseburger" and "Bacon Cheeseburger" → same baseGroup (both beef burgers with toppings)
  - "Pizza Margherita" ≠ "Pizza Salami" → different baseGroups
- Unique dishes without variants → baseGroup = null
- Use lowercase, hyphenated identifiers
- "Saison" or seasonal variants of a dish are STILL the same baseGroup as the regular variants
- IMPORTANT: Dishes with different baseGroups MUST be scored independently. If reviews praise "Madness Burger" by name, Linsenburger does NOT inherit that praise — it has a different baseGroup and needs its own evidence.

SCORE (1-10) — based on review evidence AND how many sources mention it:
- 9-10: House specialty. Named as must-try by 3+ distinct sources with enthusiastic praise.
- 7-8: Specifically praised by name in 2+ reviews ("excellent", "best", "amazing").
- 6: Mentioned by name with neutral/lukewarm feedback. OR praised by only 1 source. OR only category-level mention.
- 5: NOT mentioned in reviews (default). OR mentioned in only 1 review with minor criticism.
- 4: Specifically criticized by 2+ distinct sources. A real pattern of complaints.
- 3: Criticized by 3+ sources. Clearly a problem dish that multiple reviewers warn about.
- 1-2: Overwhelmingly negative across many reviews. Consensus to avoid.

PROPORTIONALITY — READ THIS:
This restaurant has ${totalRatings ?? "many"} total reviews. Consider how significant the criticism is:
- 1 complaint out of ${totalRatings ?? "1000+"}  reviews = NEGLIGIBLE. Score 5, not 3-4.
- 2-3 complaints = worth noting. Score 4-5 depending on severity.
- 4+ complaints = real pattern. Score 3-4.
A SINGLE negative review should NEVER tank a dish below 5. Only a PATTERN of criticism (3+ sources) justifies score 3.

INCIDENTAL vs PRIMARY criticism:
If a review says "Fajitas and Enchiladas had raw veggies" but 3 other reviews ALSO criticize fajitas specifically while enchiladas appear in only this 1 review → Fajitas are PRIMARY target (lower score), Enchiladas are INCIDENTAL (score 5, minor flag).

SERVICE/MENU complaints are NOT food quality:
"Sauces not listed on menu" = service feedback, NOT food criticism. Do not lower food scores for service issues.

SENTIMENT:
- "positive": Majority of mentions are praise.
- "mixed": Both positive AND negative feedback, OR lukewarm ("okay", "decent").
- "negative": Majority of mentions are complaints or warnings.
- "unmentioned": Zero mentions in reviews.

SUMMARY (German):
- Quote or paraphrase what reviewers actually said
- For unmentioned: "Wurde in Rezensionen nicht erwähnt."
- Be specific: "Wird als besonders saftig und gut gewürzt gelobt" NOT "Positiv bewertet"

Keep exact id, name, price, category, courseType, dietary from input. Return ONLY the JSON array.`;

  console.log(`[geminiService] scoreBatch: prompt size ${prompt.length} chars, ${menuItems.length} dishes, reviewSummary ${reviewSummary.length} chars`);

  // Quick connectivity test before heavy call
  try {
    const testRes = await fetch("https://generativelanguage.googleapis.com/v1beta/models?key=test", { method: "GET" });
    console.log(`[geminiService] Connectivity test: ${testRes.status} ${testRes.statusText}`);
  } catch (testErr: any) {
    console.error(`[geminiService] Connectivity test FAILED: ${testErr.message} (cause: ${testErr.cause?.message || testErr.cause || "none"})`);
  }

  const result = await withRetry(
    () => model.generateContent(prompt),
    "Scoring batch"
  );
  const responseText = result.response.text();

  // Strip markdown code blocks
  let cleaned = responseText.replace(/```json\s*/gi, "").replace(/```\s*/g, "").trim();

  const jsonMatch = cleaned.match(/\[[\s\S]*\]/);
  if (!jsonMatch) {
    console.warn("[geminiService] No JSON array found in scoring response, returning defaults");
    return menuItems.map((item) => ({
      id: item.id,
      name: item.name,
      price: item.price,
      score: 5,
      mentions: 0,
      sentiment: "unmentioned" as const,
      summary: "Analyse konnte nicht durchgeführt werden.",
      category: item.category,
      courseType: item.courseType ?? null,
      baseGroup: null,
      dietary: item.dietary ?? [],
    }));
  }

  const raw: DishAnalysis[] = safeParseJSON(jsonMatch[0]);

  // Build lookup from original menu items to preserve OCR data
  const menuItemMap = new Map(menuItems.map((item) => [item.id, item]));

  // Post-process: sanitize mentions, sentiment, and enforce rules
  return raw.map((dish, index) => {
    const original = menuItemMap.get(dish.id);

    // Ensure mentions is a whole integer (Gemini sometimes returns decimals like 50.1)
    let mentions = Math.round(Number(dish.mentions) || 0);

    // Normalize sentiment — Gemini sometimes returns "neutral/positive", "mixed/positive" etc.
    let sentiment = dish.sentiment;
    if (typeof sentiment === "string") {
      const s = sentiment.toLowerCase().trim();
      if (s === "positive" || s.includes("positive") && !s.includes("negative")) {
        sentiment = "positive";
      } else if (s === "negative" || s.includes("negative")) {
        sentiment = "negative";
      } else if (s === "mixed" || s === "neutral" || s.includes("mixed") || s.includes("neutral")) {
        sentiment = "mixed";
      } else if (s === "unmentioned" || s === "unknown" || s === "none") {
        sentiment = "unmentioned";
      } else {
        sentiment = "unmentioned";
      }
    }

    // Enforce: unmentioned dishes MUST have 0 mentions
    if (sentiment === "unmentioned") {
      mentions = 0;
    }
    // Enforce: dishes with 0 mentions must be unmentioned
    if (mentions === 0 && sentiment !== "unmentioned") {
      mentions = 0;
    }

    // Use courseType from OCR (original) if Gemini didn't return one
    const courseType = dish.courseType || original?.courseType || null;

    // Enforce sides score cap
    let score = dish.score;
    if (courseType === "side" && score > 6) {
      score = 6;
    }

    return {
      ...dish,
      id: dish.id && !dish.id.includes("same-id") ? dish.id : `dish-${Date.now()}-${index}`,
      // Preserve OCR data that Gemini might drop
      price: dish.price ?? original?.price ?? null,
      category: dish.category || original?.category || null,
      courseType,
      mentions,
      score,
      sentiment: sentiment as "positive" | "mixed" | "negative" | "unmentioned",
      dietary: Array.isArray(dish.dietary) && dish.dietary.length > 0
        ? dish.dietary
        : original?.dietary ?? [],
    };
  });
}
