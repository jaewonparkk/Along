import SwiftUI

struct LaunchSplashView: View {
    var body: some View {
        GeometryReader { proxy in
            Image("AlongHome")
                .resizable()
                .scaledToFill()
                .frame(width: proxy.size.width, height: proxy.size.height)
                .clipped()
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

#Preview {
    LaunchSplashView()
}
