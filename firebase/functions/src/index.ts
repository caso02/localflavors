// Fix Node 25 fetch failures (undici DNS resolution issue)
import { setDefaultResultOrder } from "node:dns";
setDefaultResultOrder("ipv4first");

import { Agent, setGlobalDispatcher } from "undici";
const agent = new Agent({
  connect: { autoSelectFamily: false }, // Force IPv4, skip IPv6 attempts
});
setGlobalDispatcher(agent);

import { onCall, HttpsError } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import { detectNearbyRestaurant, searchRestaurants } from "./services/placesService";
import { handleAnalyzeMenu } from "./analyzeMenu";
import {
  DetectRestaurantRequest,
  AnalyzeMenuRequest,
  SearchRestaurantsRequest,
  Restaurant,
} from "./types";

// Define secrets (set via `firebase functions:secrets:set`)
const geminiApiKey = defineSecret("GEMINI_API_KEY");
const placesApiKey = defineSecret("GOOGLE_PLACES_API_KEY");

// ============================================
// Cloud Function: detectRestaurant
// ============================================

export const detectRestaurant = onCall(
  {
    region: "europe-west6",
    secrets: [placesApiKey],
    timeoutSeconds: 15,
    memory: "256MiB",
    invoker: "public",
  },
  async (request) => {
    const data = request.data as DetectRestaurantRequest;

    // Validate input
    if (typeof data.latitude !== "number" || typeof data.longitude !== "number") {
      throw new HttpsError(
        "invalid-argument",
        "latitude and longitude must be numbers"
      );
    }

    if (
      data.latitude < -90 || data.latitude > 90 ||
      data.longitude < -180 || data.longitude > 180
    ) {
      throw new HttpsError(
        "invalid-argument",
        "Invalid coordinates"
      );
    }

    try {
      const restaurant = await detectNearbyRestaurant(
        data.latitude,
        data.longitude
      );
      return restaurant;
    } catch (error: any) {
      console.error("[detectRestaurant] Error:", error.message);
      throw new HttpsError("not-found", error.message);
    }
  }
);

// ============================================
// Cloud Function: searchRestaurants
// ============================================

export const searchNearbyRestaurants = onCall(
  {
    region: "europe-west6",
    secrets: [placesApiKey],
    timeoutSeconds: 15,
    memory: "256MiB",
    invoker: "public",
  },
  async (request) => {
    const data = request.data as SearchRestaurantsRequest;

    if (typeof data.latitude !== "number" || typeof data.longitude !== "number") {
      throw new HttpsError("invalid-argument", "latitude and longitude must be numbers");
    }

    try {
      if (data.query && data.query.trim().length > 0) {
        // Text search
        const results = await searchRestaurants(data.query, data.latitude, data.longitude);
        return { restaurants: results };
      } else {
        // Nearby search — reuse detectNearbyRestaurant but we want multiple results
        // The existing function returns only 1, so we call searchRestaurants with empty-ish query
        const results = await searchRestaurants("restaurant", data.latitude, data.longitude);
        return { restaurants: results };
      }
    } catch (error: any) {
      console.error("[searchRestaurants] Error:", error.message);
      throw new HttpsError("internal", error.message);
    }
  }
);

// ============================================
// Cloud Function: analyzeMenu
// ============================================

export const analyzeMenu = onCall(
  {
    region: "europe-west6",
    secrets: [geminiApiKey, placesApiKey],
    timeoutSeconds: 300,
    memory: "512MiB",
    invoker: "public",
  },
  async (request) => {
    const data = request.data as AnalyzeMenuRequest;

    console.log("[analyzeMenu] Received request:", {
      placeId: data.placeId,
      restaurantName: data.restaurantName,
      imageCount: data.images?.length,
      imageSizes: data.images?.map((img: string) => `${Math.round(img.length / 1024)}KB base64`),
    });

    // Validate input
    if (!data.placeId || typeof data.placeId !== "string") {
      throw new HttpsError("invalid-argument", "placeId is required");
    }
    if (!data.restaurantName || typeof data.restaurantName !== "string") {
      throw new HttpsError("invalid-argument", "restaurantName is required");
    }
    if (!data.images || !Array.isArray(data.images) || data.images.length === 0) {
      throw new HttpsError("invalid-argument", "At least one image is required");
    }

    // Build restaurant object from request data
    const restaurant: Restaurant = {
      placeId: data.placeId,
      name: data.restaurantName,
      address: "", // Will be enriched if needed
    };

    try {
      const result = await handleAnalyzeMenu(data, restaurant);
      console.log("[analyzeMenu] Success:", {
        dishCount: result.allDishes.length,
        topPicks: result.topPicks.length,
        avoid: result.avoid.length,
      });
      return result;
    } catch (error: any) {
      console.error("[analyzeMenu] Error:", error.message, error.stack);
      throw new HttpsError("internal", error.message);
    }
  }
);
