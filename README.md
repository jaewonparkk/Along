# Along — Plan the best day along the way

Along is an iOS day planner that turns must-visit places and loose ideas into a realistic itinerary based on travel time, opening hours, visit order, and how long you want to stay.

## The Problem

Planning a day in a new city usually means switching between search, maps, opening hours, reviews, and notes—and still ending up with an unrealistic schedule. Along brings those decisions into one flow and builds a day that can actually work.

## Demo

> **Demo GIF / video:** Add the public demo link here.

<!-- Replace this block with one of the following:
[Watch the demo](https://your-demo-link.example)

or

![Along app demo](Docs/along-demo.gif)
-->

## Built With

SwiftUI · MapKit · CoreLocation · Google Places SDK · SwiftData · Swift Concurrency

## Features

- Add exact must-visit places or flexible ideas such as eating, coffee, shopping, and things to do.
- Arrange the visit order before creating the itinerary.
- Set a preferred day start, end time, and stay duration of up to three hours per stop.
- Find matching places with Google Places data.
- Build travel-aware walking, driving, or transit routes with MapKit.
- Schedule places around known opening hours without blocking places whose hours are unavailable.
- Show clear warnings when a requested order or time may not fit.
- Suggest coffee, food, shopping, or activities along the route when the day ends early.
- Open a place detail sheet with its photo, address, hours, open status, visit duration, and Apple Maps link.
- Save and reopen planned days locally with SwiftData—no account required.
- Guide first-time users through a branded splash, onboarding, and home experience.

## Tech Stack

| Area | Technology | Purpose |
| --- | --- | --- |
| UI | SwiftUI | Declarative screens, navigation, sheets, onboarding, and itinerary views |
| Maps and routing | MapKit | Map display, directions, route distance, and travel-time estimates |
| Location | CoreLocation | Current-location permission and starting-point updates |
| Place discovery | Google Places SDK for iOS | Place search, matching, photos, addresses, and opening-hour data |
| Persistence | SwiftData | Local storage for saved days without login or a backend |
| State and async work | Combine, async/await | Search updates, location changes, routing, and place enrichment |
| Language and platform | Swift 5, iOS | Native iPhone application |

## Project Structure

```text
Along/
├── AlongApp.swift                 # App entry point, Google Places setup, SwiftData container
├── LaunchSplashView.swift         # Branded launch experience
├── OnboardingView.swift           # First-run onboarding flow
├── AlongHomeView.swift            # Home and saved-day entry points
├── ContentView.swift              # Main map and planner container
├── PlanSetupView.swift            # Order, timing, duration, pace, and route preferences
├── ItineraryResultView.swift      # Generated schedule, warnings, route summary, and saving
├── PlaceSearchView.swift          # Place and flexible-stop search UI
├── PlaceDetailView.swift          # Photo, hours, open status, duration, and Apple Maps action
├── SavedDaysView.swift            # Locally saved itineraries
│
├── PlanningEngine.swift           # Coordinates place resolution, constraints, and itinerary creation
├── RouteOptimizer.swift           # Calculates an efficient route for the selected order and mode
├── ScheduleConstraintEngine.swift # Applies day bounds, stay durations, and known opening hours
├── DirectionService.swift         # MapKit direction and segment calculations
├── FlexibleStopResolver.swift     # Converts ideas such as coffee or shopping into real places
├── RouteSuggestionService.swift   # Finds optional stops along the route
├── GooglePlacesService.swift      # Google place enrichment, photos, hours, and open status
├── PlaceSearchService.swift       # Search coordination and result state
├── LocationManager.swift          # Core Location authorization and current location
│
├── PlannedPlace.swift             # Place model used while planning
├── PlanningModels.swift           # Itinerary and planning-domain models
├── SavedDay.swift                 # SwiftData persistence model
├── PlacesMetaData.swift           # Google Places metadata attached to map items
└── TravelMode.swift               # Walking, driving, and transit options
```

## Technical Highlights

- **Constraint-aware scheduling:** Along treats the user's selected order, day window, travel time, and stay duration as first-class planning inputs.
- **Opening-hours policy:** Known hours influence scheduling and warnings; missing hours do not prevent an itinerary from being created.
- **Flexible-stop resolution:** Broad requests are resolved into real nearby candidates before route construction.
- **Route-aware suggestions:** Optional stops are searched around the existing path so recommendations remain useful without creating a large detour.
- **Graceful fallback behavior:** The planner can still return the best available order with actionable warnings when every preference cannot be satisfied.
- **Local-first persistence:** Saved itineraries use SwiftData and remain on the device without authentication or a remote database.
- **Separation of concerns:** Search, Google Places enrichment, directions, optimization, scheduling, suggestions, persistence, and UI are separated into focused types.

## Setup

### Requirements

- macOS with a recent version of Xcode
- An iPhone or iOS Simulator supported by the project's deployment target
- A Google Cloud project with **Places API (New)** enabled
- A Google Places API key restricted to the iOS app's bundle identifier

### Run Locally

1. Clone the repository:

   ```bash
   git clone https://github.com/jaewonparkk/Along.git
   cd Along
   ```

2. Open the Xcode project:

   ```bash
   open Along.xcodeproj
   ```

3. In Xcode, select the **Along** target and open **Signing & Capabilities**.

4. Choose your development team and confirm that the bundle identifier is unique for your Apple Developer account.

5. Add your Google Places key:

   - Open **Target → Info**.
   - Add the key `GOOGLE_PLACES_API_KEY`.
   - Set its value to your restricted API key.
   - Never commit a production API key to Git.

6. Confirm that the local package at `Vendor/GooglePlacesPackage` resolves and that the `GooglePlaces` and `GooglePlacesSwift` products appear under package dependencies.

7. Select an iPhone Simulator or connected device and press **Run** (`⌘R`).

> Free Apple developer profiles can install only a limited number of development apps on a physical device. If installation fails because the limit was reached, delete one of the other development builds from the iPhone and run Along again.

## Privacy

Along requests location access only to start plans from the user's current position. Saved days are stored locally on the device with SwiftData.

## Status

Along is under active development. Routing, place availability, and opening-hour information depend on Apple Maps and Google Places data and should be treated as planning guidance.
