// ============================================
// Types matching the iOS API Contract exactly
// ============================================

// --- Restaurant ---

export interface Restaurant {
  placeId: string;
  name: string;
  address: string;
  rating?: number;
  totalRatings?: number;
  generativeSummary?: string;
}

// --- Menu Items (from OCR) ---

export interface MenuItem {
  id: string;
  name: string;
  price: string | null;
  category: string | null;
  description: string | null;
  courseType: string | null; // "starter" | "main" | "dessert" | "drink" | "side" | "menu"
  dietary: string[]; // e.g. ["vegetarian", "gluten-free"]
}

// --- Dish Analysis (from Grounding) ---

export type Sentiment = "positive" | "mixed" | "negative" | "unmentioned";

export interface DishAnalysis {
  id: string;
  name: string;
  price: string | null;
  score: number; // 1-10
  mentions: number;
  sentiment: Sentiment;
  summary: string;
  category: string | null;
  courseType: string | null; // "starter" | "main" | "dessert" | "drink" | "side" | "menu"
  baseGroup: string | null; // Groups similar dishes (e.g. all poutine variants → "poutine")
  dietary: string[]; // e.g. ["vegetarian", "vegan", "gluten-free"]
}

// --- Full Analysis Result ---

export interface AnalysisResult {
  restaurant: Restaurant;
  topPicks: DishAnalysis[];
  avoid: DishAnalysis[];
  allDishes: DishAnalysis[];
}

// --- Request/Response Types ---

export interface DetectRestaurantRequest {
  latitude: number;
  longitude: number;
}

export interface AnalyzeMenuRequest {
  placeId: string;
  restaurantName: string;
  images: string[]; // base64-encoded JPEG strings
}

export interface SearchRestaurantsRequest {
  query?: string;
  latitude: number;
  longitude: number;
}
