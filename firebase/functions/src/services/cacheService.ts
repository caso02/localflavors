import * as admin from "firebase-admin";

// Initialize Firebase Admin if not already done
if (!admin.apps.length) {
  admin.initializeApp();
}

const COLLECTION = "reviewCache";
const TTL_HOURS = 24;

// In-memory fallback cache for when Firestore is unavailable (e.g. no emulator)
const memoryCache = new Map<string, { reviewSummary: string; timestamp: number; restaurantName: string }>();

interface CachedReviewSummary {
  reviewSummary: string;
  createdAt: admin.firestore.Timestamp;
  restaurantName: string;
}

function getDb(): admin.firestore.Firestore | null {
  try {
    return admin.firestore();
  } catch {
    return null;
  }
}

/**
 * Get cached review summary for a restaurant.
 * Returns null if not found or expired (>24h).
 * Falls back to in-memory cache if Firestore is unavailable.
 */
export async function getCachedReviewSummary(
  placeId: string
): Promise<string | null> {
  // Try Firestore first
  const db = getDb();
  if (db) {
    try {
      const doc = await db.collection(COLLECTION).doc(placeId).get();
      if (doc.exists) {
        const data = doc.data() as CachedReviewSummary;
        const ageMs = Date.now() - data.createdAt.toMillis();
        const ageHours = ageMs / (1000 * 60 * 60);

        if (ageHours <= TTL_HOURS && data.reviewSummary.length >= 3000) {
          console.log(`[cacheService] Firestore cache hit for ${placeId} (${Math.round(ageHours)}h old, ${data.reviewSummary.length} chars)`);
          return data.reviewSummary;
        }
        if (data.reviewSummary.length < 3000) {
          console.log(`[cacheService] Firestore cache too short for ${placeId} (${data.reviewSummary.length} chars < 3000), discarding`);
        }
        console.log(`[cacheService] Firestore cache expired for ${placeId} (${Math.round(ageHours)}h old)`);
        return null;
      }
    } catch (err: any) {
      console.warn(`[cacheService] Firestore read failed (${err.message}), trying memory cache...`);
    }
  }

  // Fallback: in-memory cache
  const cached = memoryCache.get(placeId);
  if (cached) {
    const ageHours = (Date.now() - cached.timestamp) / (1000 * 60 * 60);
    if (ageHours <= TTL_HOURS && cached.reviewSummary.length >= 3000) {
      console.log(`[cacheService] Memory cache hit for ${placeId} (${Math.round(ageHours * 60)}min old, ${cached.reviewSummary.length} chars)`);
      return cached.reviewSummary;
    }
    if (cached.reviewSummary.length < 3000) {
      console.log(`[cacheService] Memory cache too short for ${placeId} (${cached.reviewSummary.length} chars < 3000), discarding`);
      memoryCache.delete(placeId);
    }
    memoryCache.delete(placeId);
  }

  return null;
}

/**
 * Store review summary in cache.
 * Writes to both Firestore and in-memory cache.
 */
export async function setCachedReviewSummary(
  placeId: string,
  restaurantName: string,
  reviewSummary: string
): Promise<void> {
  // Always write to memory cache
  memoryCache.set(placeId, {
    reviewSummary,
    restaurantName,
    timestamp: Date.now(),
  });
  console.log(`[cacheService] Memory cached review summary for ${placeId} (${reviewSummary.length} chars)`);

  // Try Firestore (non-fatal if unavailable)
  const db = getDb();
  if (db) {
    try {
      await db.collection(COLLECTION).doc(placeId).set({
        reviewSummary,
        restaurantName,
        createdAt: new Date(),
      });
      console.log(`[cacheService] Firestore cached review summary for ${placeId}`);
    } catch (err: any) {
      console.warn(`[cacheService] Firestore write failed: ${err.message} (memory cache still active)`);
    }
  }
}
