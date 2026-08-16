import SwiftUI

struct AppEntryView: View {
    @AppStorage("shouldSkipOnboardingV3") private var shouldSkipOnboarding = false
    @State private var isShowingSplash = true
    @State private var isShowingOnboarding = true
    @State private var isPlanning = false

    var body: some View {
        ZStack {
            if isShowingSplash {
                LaunchSplashView()
                    .transition(.opacity)
            } else if shouldSkipOnboarding || !isShowingOnboarding {
                if isPlanning {
                    ContentView(onHome: {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            isPlanning = false
                        }
                    })
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                } else {
                    AlongHomeView {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            isPlanning = true
                        }
                    }
                    .transition(.opacity)
                }
            } else {
                OnboardingView {
                    withAnimation(.easeInOut(duration: 0.45)) {
                        isShowingOnboarding = false
                    }
                } onDontShowAgain: {
                    withAnimation(.easeInOut(duration: 0.45)) {
                        shouldSkipOnboarding = true
                        isShowingOnboarding = false
                    }
                }
                .transition(.opacity)
            }
        }
        .statusBarHidden(isShowingSplash)
        .task {
            guard isShowingSplash else { return }
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.45)) {
                isShowingSplash = false
            }
        }
    }
}

struct OnboardingView: View {
    let onComplete: () -> Void
    let onDontShowAgain: () -> Void
    @State private var page = 0

    private let cream = Color(red: 1, green: 248 / 255, blue: 243 / 255)
    private let pink = Color(red: 247 / 255, green: 189 / 255, blue: 189 / 255)
    private let mauve = Color(red: 199 / 255, green: 187 / 255, blue: 194 / 255)

    var body: some View {
        ZStack {
            cream.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Text("ALONG")
                        .font(.system(.caption, design: .monospaced, weight: .black))
                        .tracking(3)
                    Spacer()
                    Button("Skip", action: onComplete)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)

                TabView(selection: $page) {
                    onboardingPage(
                        title: "Tell us what sounds good.",
                        subtitle: "Add must-visits and anything else you’re in the mood for.",
                        visual: AnyView(wantsVisual)
                    )
                    .tag(0)

                    onboardingPage(
                        title: "Along finds the best flow.",
                        subtitle: "We consider travel, opening hours, and timing to build your day.",
                        visual: AnyView(flowVisual)
                    )
                    .tag(1)

                    onboardingPage(
                        title: "Your day. Your call.",
                        subtitle: "Change any stop or explore alternatives whenever you want.",
                        visual: AnyView(alternativesVisual)
                    )
                    .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                HStack(spacing: 8) {
                    ForEach(0..<3, id: \.self) { index in
                        Capsule()
                            .fill(index == page ? Color.primary : mauve.opacity(0.55))
                            .frame(width: index == page ? 22 : 7, height: 7)
                            .animation(.easeInOut(duration: 0.2), value: page)
                    }
                }
                .padding(.bottom, 18)

                Button {
                    if page < 2 {
                        withAnimation { page += 1 }
                    } else {
                        onComplete()
                    }
                } label: {
                    HStack {
                        Text(page == 2 ? "Start exploring" : "Continue")
                        Image(systemName: "arrow.right")
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.primary, in: RoundedRectangle(cornerRadius: 18))
                }
                .padding(.horizontal, 24)

                if page == 2 {
                    Button("Don’t show this again", action: onDontShowAgain)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.top, 12)
                }

                Text("No account needed · Saved days stay on this device")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.top, page == 2 ? 8 : 12)
                    .padding(.bottom, 16)
            }
        }
    }

    private func onboardingPage(
        title: String,
        subtitle: String,
        visual: AnyView
    ) -> some View {
        VStack(spacing: 26) {
            VStack(spacing: 12) {
                Text(title)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                Text(subtitle)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
            .padding(.horizontal, 24)

            visual
                .padding(.horizontal, 24)
        }
        .padding(.top, 36)
    }

    private var wantsVisual: some View {
        VStack(spacing: 14) {
            onboardingCard(title: "♡  MUST VISIT") {
                stopLine("MFA Boston", icon: "building.columns.fill")
                Divider()
                stopLine("Newbury Street", icon: "mappin")
            }

            onboardingCard(title: "✦  I ALSO WANT TO...") {
                stopLine("Matcha", icon: "cup.and.saucer.fill")
                Divider()
                stopLine("Italian lunch", icon: "fork.knife")
                Divider()
                stopLine("Wine bar", icon: "wineglass.fill")
            }
        }
    }

    private var flowVisual: some View {
        VStack(alignment: .leading, spacing: 0) {
            timelineRow("11:00", "MFA Boston", "12 min")
            timelineRow("1:00", "Italian lunch", "8 min")
            timelineRow("3:30", "Matcha", "15 min")
            timelineRow("6:30", "Wine bar", nil)

            HStack(spacing: 7) {
                ForEach(["Opening hours", "Travel", "Your timing"], id: \.self) { text in
                    Text("✓ \(text)")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 7)
                        .background(pink.opacity(0.45), in: Capsule())
                }
            }
            .padding(.top, 18)
        }
        .padding(20)
        .background(.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 24))
    }

    private var alternativesVisual: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "cup.and.saucer.fill")
                    .foregroundStyle(pink)
                VStack(alignment: .leading, spacing: 3) {
                    Text("The Well Coffee House").font(.headline)
                    Text("Matcha · +4 min detour")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            Text("SEE ALTERNATIVES")
                .font(.system(.caption2, design: .monospaced, weight: .bold))
                .tracking(1.5)
                .foregroundStyle(.secondary)

            ForEach(
                Array([("Ogawa Coffee", "+3 min"), ("Jaho Coffee", "+6 min"), ("Cafe Susu", "+8 min")].enumerated()),
                id: \.offset
            ) { _, item in
                HStack {
                    Text(item.0)
                    Spacer()
                    Text(item.1).foregroundStyle(.secondary)
                    Image(systemName: "arrow.triangle.swap")
                        .foregroundStyle(mauve)
                }
                .font(.subheadline)
                if item.0 != "Cafe Susu" { Divider() }
            }
        }
        .padding(20)
        .background(.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 24))
    }

    private func onboardingCard<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(.caption2, design: .monospaced, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(.secondary)
            content()
        }
        .padding(18)
        .background(.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 22))
    }

    private func stopLine(_ text: String, icon: String) -> some View {
        Label(text, systemImage: icon)
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func timelineRow(_ time: String, _ place: String, _ travel: String?) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text(time)
                .font(.subheadline.monospacedDigit().weight(.bold))
                .frame(width: 48, alignment: .leading)
            VStack(alignment: .leading, spacing: 8) {
                Text(place).font(.headline)
                if let travel {
                    Label(travel, systemImage: "figure.walk")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Rectangle()
                        .fill(mauve.opacity(0.7))
                        .frame(width: 2, height: 20)
                        .padding(.leading, 6)
                }
            }
        }
    }
}

#Preview {
    OnboardingView(onComplete: {}, onDontShowAgain: {})
}
