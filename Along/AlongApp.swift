import SwiftUI
import GooglePlaces
import SwiftData


@main
struct AlongApp: App {

    init() {

        guard
            let apiKey =
                Bundle.main.object(
                    forInfoDictionaryKey:
                        "GOOGLE_PLACES_API_KEY"
                ) as? String,
            !apiKey
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                .isEmpty
        else {

            fatalError(
                """
                GOOGLE_PLACES_API_KEY is missing.

                Xcode:
                Target → Info
                → add GOOGLE_PLACES_API_KEY
                → paste your restricted Google Places API key.
                """
            )
        }


        let success =
            GMSPlacesClient
                .provideAPIKey(
                    apiKey
                )


        if !success {

            print(
                "⚠️ Google Places API key could not be configured."
            )
        }
    }


    var body: some Scene {

        WindowGroup {

            AppEntryView()
        }
        .modelContainer(for: [SavedDay.self, SavedPlace.self])
    }
}
