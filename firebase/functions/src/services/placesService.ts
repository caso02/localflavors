import { Restaurant } from "../types";

const PLACES_API_BASE = "https://places.googleapis.com/v1/places";

/**
 * Detect the nearest restaurant using Google Places API (New).
 * Uses Nearby Search to find restaurants within 50m of the given coordinates.
 */
export async function detectNearbyRestaurant(
  latitude: number,
  longitude: number
): Promise<Restaurant> {
  const apiKey = process.env.GOOGLE_PLACES_API_KEY;
  if (!apiKey) {
    throw new Error("GOOGLE_PLACES_API_KEY is not configured");
  }

  const response = await fetch(
    `${PLACES_API_BASE}:searchNearby`,
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-Goog-Api-Key": apiKey,
        "X-Goog-FieldMask":
          "places.id,places.displayName,places.formattedAddress,places.rating,places.userRatingCount",
      },
      body: JSON.stringify({
        includedTypes: ["restaurant"],
        maxResultCount: 5,
        locationRestriction: {
          circle: {
            center: { latitude, longitude },
            radius: 500.0, // 500 meters
          },
        },
      }),
    }
  );

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`Places API error: ${response.status} - ${errorText}`);
  }

  const data = await response.json();
  const places = data.places;

  if (!places || places.length === 0) {
    throw new Error("No restaurants found nearby");
  }

  // Return the closest/most relevant restaurant
  const place = places[0];

  return {
    placeId: place.id,
    name: place.displayName?.text ?? "Unknown Restaurant",
    address: place.formattedAddress ?? "",
    rating: place.rating ?? undefined,
    totalRatings: place.userRatingCount ?? undefined,
  };
}

/**
 * Fetch restaurant details (address, rating, review count) via Places API.
 */
export async function fetchRestaurantDetails(placeId: string): Promise<Partial<Restaurant>> {
  const apiKey = process.env.GOOGLE_PLACES_API_KEY;
  if (!apiKey) {
    throw new Error("GOOGLE_PLACES_API_KEY is not configured");
  }

  const response = await fetch(
    `${PLACES_API_BASE}/${placeId}`,
    {
      method: "GET",
      headers: {
        "X-Goog-Api-Key": apiKey,
        "X-Goog-FieldMask": "formattedAddress,rating,userRatingCount,generativeSummary",
      },
    }
  );

  if (!response.ok) {
    console.warn(`[placesService] Failed to fetch details: ${response.status}`);
    return {};
  }

  const data = await response.json();

  // Extract generativeSummary text
  const generativeSummary = data.generativeSummary?.overview?.text ?? null;
  if (generativeSummary) {
    console.log(`[placesService] generativeSummary found (${generativeSummary.length} chars): ${generativeSummary.substring(0, 200)}...`);
  } else {
    console.log(`[placesService] No generativeSummary available for this place`);
  }

  return {
    address: data.formattedAddress ?? "",
    rating: data.rating ?? undefined,
    totalRatings: data.userRatingCount ?? undefined,
    generativeSummary: generativeSummary ?? undefined,
  };
}

/**
 * Fetch reviews for a restaurant via Places API.
 * Returns up to 5 review texts (Places API limit).
 */
export async function fetchReviews(placeId: string): Promise<string[]> {
  const apiKey = process.env.GOOGLE_PLACES_API_KEY;
  if (!apiKey) {
    throw new Error("GOOGLE_PLACES_API_KEY is not configured");
  }

  const response = await fetch(
    `${PLACES_API_BASE}/${placeId}`,
    {
      method: "GET",
      headers: {
        "X-Goog-Api-Key": apiKey,
        "X-Goog-FieldMask": "reviews",
      },
    }
  );

  if (!response.ok) {
    console.warn(`[placesService] Failed to fetch reviews: ${response.status}`);
    return [];
  }

  const data = await response.json();
  const reviews = data.reviews ?? [];

  return reviews.map((r: any) => r.text?.text ?? "").filter((t: string) => t.length > 0);
}

export async function searchRestaurants(
  query: string,
  latitude: number,
  longitude: number
): Promise<Restaurant[]> {
  const apiKey = process.env.GOOGLE_PLACES_API_KEY;
  if (!apiKey) {
    throw new Error("GOOGLE_PLACES_API_KEY is not configured");
  }

  const response = await fetch(
    `${PLACES_API_BASE}:searchText`,
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-Goog-Api-Key": apiKey,
        "X-Goog-FieldMask":
          "places.id,places.displayName,places.formattedAddress,places.rating,places.userRatingCount",
      },
      body: JSON.stringify({
        textQuery: query,
        includedType: "restaurant",
        maxResultCount: 5,
        locationBias: {
          circle: {
            center: { latitude, longitude },
            radius: 500.0,
          },
        },
      }),
    }
  );

  if (!response.ok) {
    throw new Error(`Places API search error: ${response.status}`);
  }

  const data = await response.json();
  const places = data.places ?? [];

  return places.map((place: any) => ({
    placeId: place.id,
    name: place.displayName?.text ?? "Unknown",
    address: place.formattedAddress ?? "",
    rating: place.rating ?? undefined,
    totalRatings: place.userRatingCount ?? undefined,
  }));
}
