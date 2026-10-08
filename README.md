# Local Flavors

iOS-App, die Speisekarten per Foto erfasst, die Gerichte mit Gemini ausliest und sie anhand von Online-Bewertungen des Restaurants einstuft.

## Was es macht

- Erkennt das Restaurant über den Standort (Google Places) oder lässt es manuell suchen und auswählen.
- Erfasst bis zu 8 Speisekartenseiten mit der Kamera oder aus der Fotobibliothek.
- Zeigt pro Gericht Score (1–10), Sentiment, geschätzte Anzahl Erwähnungen und eine deutsche Zusammenfassung der Bewertungen.
- Gliedert die Resultate in Empfehlungen pro Gang, «Top Preis-Leistung», «Lieber nicht» und alle Gerichte; Filter für vegetarisch, vegan und glutenfrei.
- Speichert die letzten 20 Scans lokal (UserDefaults); dazu Onboarding, Offline-Hinweis und Lokalisierung Deutsch/Englisch.

## Architektur

```
SwiftUI-App ── Firebase Callable Functions (europe-west6) ──> Cloud Functions (TypeScript)
  detectRestaurant / searchNearbyRestaurants ──> Google Places API (New)
  analyzeMenu(placeId, restaurantName, images[] als Base64-JPEG)
    1. parallel: Gemini-OCR der Bilder ──> MenuItem[]
                 Places-Details, bis zu 5 Reviews, Google-Review-Zusammenfassung
    2. Phase 1: Gemini mit Google-Search-Grounding ──> Review-Zusammenfassung
                (Firestore-Cache, 24 h pro placeId)
    3. Phase 2: Scoring in Batches à 65 Gerichte (parallel) ──> DishAnalysis[]
    4. Ranking ──> AnalysisResult { restaurant, topPicks, avoid, allDishes }
```

- Modell: `gemini-2.5-flash` für alle drei Schritte, `thinkingBudget: 0`, `temperature: 0` für Review-Suche und Scoring.
- Gemini liefert JSON-Arrays; das Backend repariert abgeschnittenes oder fehlerhaftes JSON, wiederholt Aufrufe bei 429/503 und normalisiert Sentiment-Werte.
- `DishAnalysis` enthält u.a. `score`, `mentions`, `sentiment` (`positive | mixed | negative | unmentioned`), `summary`, `courseType`, `baseGroup` (gruppiert Varianten) und `dietary`. `mentions` ist eine vom Modell hochgerechnete Schätzung auf Basis der Gesamtzahl Google-Bewertungen.
- Empfehlungen: max. 3 pro Gang (Vorspeise, Hauptgang, Dessert), nur positive Gerichte mit Score ≥ 7, dedupliziert nach `baseGroup`.
- Firestore ist für Clients gesperrt; nur die Functions greifen darauf zu.

## Tech-Stack

- iOS: Swift 5.9, SwiftUI, AVFoundation, PhotosUI, CoreLocation; Firebase iOS SDK 11 (FirebaseFunctions) via Swift Package Manager; XcodeGen (`project.yml`)
- Backend: Firebase Cloud Functions v2, TypeScript, Node 20, `@google/generative-ai`, Firestore
- APIs: Google Gemini API, Google Places API (New)

## Lokal starten

Voraussetzungen: Xcode 16, iOS 17+, Node 20, Firebase CLI und ein eigenes Firebase-Projekt (in `firebase/.firebaserc` eintragen).

Backend:

```bash
cd firebase/functions
npm install
npm run serve    # Build + Functions-Emulator (Port 5001, Emulator-UI 4000)
npm run deploy   # Deployment
```

Benötigte Secrets gemäss `firebase/functions/.env.example`: `GEMINI_API_KEY`, `GOOGLE_PLACES_API_KEY`. Produktiv mit `firebase functions:secrets:set <NAME>` setzen, für den Emulator in `firebase/functions/.secret.local` (per `.gitignore` ausgeschlossen).

App:

1. `GoogleService-Info.plist` des eigenen Firebase-Projekts nach `LocalFlavors/` legen (nicht im Repository).
2. `LocalFlavors.xcodeproj` öffnen oder mit `xcodegen generate` neu erzeugen, Signing-Team setzen und starten. Für den Kamera-Scan ist ein echtes Gerät nötig.
3. Für Tests gegen den Emulator ist in `LocalFlavorsApp.swift` ein `useEmulator`-Aufruf vorbereitet (auskommentiert).

## Projektkontext

Privates Projekt (März 2026).
