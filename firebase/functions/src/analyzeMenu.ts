import { extractMenuItems, analyzeWithGrounding } from "./services/geminiService";
import { fetchReviews, fetchRestaurantDetails } from "./services/placesService";
import {
  AnalyzeMenuRequest,
  AnalysisResult,
  Restaurant,
  DishAnalysis,
} from "./types";

/**
 * Main orchestrator for menu analysis.
 *
 * Flow:
 * 1. Validate input
 * 2. Gemini OCR: Extract menu items from images
 * 3. Gemini Grounding: Analyze dishes against Google Maps reviews
 * 4. Rank and structure results
 */
export async function handleAnalyzeMenu(
  data: AnalyzeMenuRequest,
  restaurant: Restaurant
): Promise<AnalysisResult> {
  // --- Validate ---
  if (!data.images || data.images.length === 0) {
    throw new Error("No menu images provided");
  }
  if (data.images.length > 8) {
    throw new Error("Maximum 8 menu pages allowed");
  }

  // --- Step 1: OCR + Fetch Reviews/Details + Phase 1 Review Search in parallel ---
  // Phase 1 review search only needs reviews + restaurant details, NOT OCR results.
  // So we start it as soon as reviews/details are ready, while OCR may still be running.
  console.log(`[analyzeMenu] Starting OCR + review pipeline in parallel`);
  const startTime = Date.now();

  // Start OCR independently
  const ocrPromise = extractMenuItems(data.images);

  // Fetch reviews + details, then immediately start Phase 1 review search
  const reviewPipelinePromise = (async () => {
    const [placesReviews, restaurantDetails] = await Promise.all([
      fetchReviews(data.placeId).catch((err) => {
        console.warn(`[analyzeMenu] Could not fetch reviews: ${err.message}`);
        return [] as string[];
      }),
      fetchRestaurantDetails(data.placeId).catch((err) => {
        console.warn(`[analyzeMenu] Could not fetch restaurant details: ${err.message}`);
        return {} as Partial<Restaurant>;
      }),
    ]);

    // Enrich restaurant object
    if (restaurantDetails.address) restaurant.address = restaurantDetails.address;
    if (restaurantDetails.rating) restaurant.rating = restaurantDetails.rating;
    if (restaurantDetails.totalRatings) restaurant.totalRatings = restaurantDetails.totalRatings;
    if (restaurantDetails.generativeSummary) restaurant.generativeSummary = restaurantDetails.generativeSummary;

    console.log(`[analyzeMenu] Reviews + details ready (${Date.now() - startTime}ms). Starting Phase 1 review search...`);

    return { placesReviews, restaurantDetails };
  })();

  // Wait for both OCR and review pipeline
  const [menuItems, { placesReviews }] = await Promise.all([
    ocrPromise,
    reviewPipelinePromise,
  ]);

  console.log(`[analyzeMenu] OCR + review pipeline done (${Date.now() - startTime}ms). ${menuItems.length} menu items, ${placesReviews.length} direct reviews, ${restaurant.rating}★ (${restaurant.totalRatings} reviews)`);

  if (menuItems.length === 0) {
    throw new Error("No menu items could be extracted from the images");
  }

  // --- Step 2: Score dishes (Phase 1 review search + Phase 2 scoring) ---
  console.log(`[analyzeMenu] Starting review analysis + scoring`);
  const { dishes: analyses, cached } = await analyzeWithGrounding(
    data.restaurantName,
    restaurant.address,
    menuItems,
    placesReviews,
    restaurant.totalRatings,
    data.placeId,
    restaurant.generativeSummary
  );
  console.log(`[analyzeMenu] Analysis complete in ${Date.now() - startTime}ms for ${analyses.length} dishes${cached ? " (⚡ cached reviews)" : ""}`);

  // --- Step 3: Rank and Structure ---
  const result = structureResults(restaurant, analyses);

  // --- Debug: Full result dump ---
  console.log(`[analyzeMenu] === FULL RESULT ===`);
  console.log(`[analyzeMenu] Restaurant: ${result.restaurant.name} (${result.restaurant.rating}★, ${result.restaurant.totalRatings} reviews)`);
  console.log(`[analyzeMenu] Top Picks (${result.topPicks.length}):`);
  for (const d of result.topPicks) {
    console.log(`  🔥 [${d.courseType}] ${d.name} — Score: ${d.score}/10, Mentions: ${d.mentions}, Sentiment: ${d.sentiment}, BaseGroup: ${d.baseGroup ?? "none"}`);
  }
  console.log(`[analyzeMenu] Avoid (${result.avoid.length}):`);
  for (const d of result.avoid) {
    console.log(`  👎 [${d.courseType}] ${d.name} — Score: ${d.score}/10, Mentions: ${d.mentions}, Sentiment: ${d.sentiment}`);
  }
  console.log(`[analyzeMenu] All Dishes (${result.allDishes.length}):`);
  for (const d of result.allDishes) {
    const icon = d.sentiment === "unmentioned" ? "⬜" : d.score >= 7 ? "🟢" : d.score >= 5 ? "🟡" : "🔴";
    console.log(`  ${icon} [${d.courseType ?? "?"}] ${d.name} — Score: ${d.score}/10, Mentions: ${d.mentions}, Sentiment: ${d.sentiment}, Price: ${d.price ?? "-"}`);
  }
  console.log(`[analyzeMenu] === END RESULT ===`);

  return result;
}

/**
 * Structure the raw dish analyses into the final result format.
 * Identifies top picks per course type and avoid dishes.
 * Deduplicates by baseGroup so similar dishes (e.g. 3 poutine variants)
 * don't all appear in top picks.
 */
function structureResults(
  restaurant: Restaurant,
  allDishes: DishAnalysis[]
): AnalysisResult {
  // Sort by score descending
  const sorted = [...allDishes].sort((a, b) => b.score - a.score);

  // Only consider mentioned dishes for top picks / avoid
  const mentioned = sorted.filter((d) => d.sentiment !== "unmentioned");

  // Top picks: up to 3 per course type (starter, main, dessert only — no sides/drinks/sauces)
  // Deduplicated by baseGroup so similar dishes don't all appear
  const seenGroups = new Set<string>();
  const topPicks: DishAnalysis[] = [];
  const topPickCourses = ["main", "starter", "dessert"];

  for (const courseType of topPickCourses) {
    const courseDishes = mentioned.filter((d) => {
      if (d.sentiment !== "positive" || d.score < 7) return false;
      if (d.courseType !== courseType) return false;
      if (d.baseGroup && seenGroups.has(d.baseGroup)) return false;
      return true;
    });

    // Take up to 3 per course type, tracking baseGroups
    let count = 0;
    for (const d of courseDishes) {
      if (count >= 3) break;
      if (d.baseGroup && seenGroups.has(d.baseGroup)) continue;
      topPicks.push(d);
      if (d.baseGroup) seenGroups.add(d.baseGroup);
      count++;
    }
  }

  // Avoid: dishes with negative sentiment or mixed with very low score
  const avoid = mentioned
    .filter((d) =>
      (d.sentiment === "negative" && d.score <= 4) ||
      (d.sentiment === "mixed" && d.score <= 3)
    )
    .slice(-3)
    .reverse();

  return {
    restaurant,
    topPicks,
    avoid,
    allDishes: sorted,
  };
}
