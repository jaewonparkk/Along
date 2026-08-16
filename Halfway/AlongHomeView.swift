import SwiftUI
import SwiftData

struct AlongHomeView: View {
    let onPlanNewDay: () -> Void

    @Query(sort: \SavedDay.createdAt, order: .reverse)
    private var savedDays: [SavedDay]

    @State private var isSavedDaysPresented = false

    private let cream = Color(red: 1, green: 248 / 255, blue: 243 / 255)
    private let pink = Color(red: 247 / 255, green: 189 / 255, blue: 189 / 255)
    private let mauve = Color(red: 199 / 255, green: 187 / 255, blue: 194 / 255)

    var body: some View {
        ZStack {
            cream.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    header
                    introduction
                    planCard
                    savedSection
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 36)
            }
        }
        .sheet(isPresented: $isSavedDaysPresented) {
            SavedDaysView()
        }
    }

    private var header: some View {
        HStack {
            Text("ALONG")
                .font(.system(.headline, design: .monospaced, weight: .black))
                .tracking(4)

            Spacer()

            Button {
                isSavedDaysPresented = true
            } label: {
                Image(systemName: "bookmark")
                    .foregroundStyle(.primary)
                    .frame(width: 44, height: 44)
                    .background(.white.opacity(0.72), in: Circle())
                    .overlay(Circle().stroke(mauve.opacity(0.55)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Saved Days")
        }
        .padding(.top, 14)
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: 14) {
            if !savedDays.isEmpty {
                Text(greeting)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Text(savedDays.isEmpty
                 ? "Where should we go\ntoday?"
                 : "Where do you want\ntoday to take you?")
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .tracking(-0.8)

            Text(savedDays.isEmpty
                 ? "Tell us what sounds good.\nWe’ll figure out the rest."
                 : "Plan around places you love, or just tell us what sounds good.")
                .font(.body)
                .foregroundStyle(.secondary)
                .lineSpacing(4)
        }
    }

    private var planCard: some View {
        Button(action: onPlanNewDay) {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Image(systemName: "sparkles")
                        .font(.title2)
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.headline)
                }

                VStack(alignment: .leading, spacing: 7) {
                    Text("Plan a new day")
                        .font(.title2.bold())
                    Text("Places + food + timing\nAlong figures out the flow.")
                        .font(.subheadline)
                        .foregroundStyle(.primary.opacity(0.62))
                        .lineSpacing(3)
                }
            }
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(22)
            .background(pink, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .shadow(color: pink.opacity(0.28), radius: 20, y: 10)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var savedSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Text("YOUR DAYS")
                    .font(.system(.caption, design: .monospaced, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(.secondary)
                Spacer()
                if !savedDays.isEmpty {
                    Button("See all") { isSavedDaysPresented = true }
                        .font(.caption.weight(.semibold))
                }
            }

            if savedDays.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "bookmark")
                        .font(.title2)
                        .foregroundStyle(mauve)
                    Text("No saved days yet.")
                        .font(.headline)
                    Text("Your plans will show up here.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
                .background(.white.opacity(0.52), in: RoundedRectangle(cornerRadius: 22))
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(mauve.opacity(0.38)))
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(savedDays.prefix(6)) { day in
                            Button {
                                isSavedDaysPresented = true
                            } label: {
                                savedDayCard(day)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .contentMargins(.horizontal, 1)
            }
        }
    }

    private func savedDayCard(_ day: SavedDay) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: "map.fill")
                .foregroundStyle(mauve)
            Spacer()
            Text(day.title)
                .font(.headline)
                .lineLimit(2)
            Text("\(day.stops.count) stops")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(width: 145, height: 132, alignment: .leading)
        .padding(16)
        .background(.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(mauve.opacity(0.42)))
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return "Good morning ☀︎" }
        if hour < 18 { return "Good afternoon ☀︎" }
        return "Good evening ☾"
    }
}

#Preview {
    AlongHomeView {}
        .modelContainer(for: SavedDay.self, inMemory: true)
}
