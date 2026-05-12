import SwiftUI

@main
struct ReplrApp: App {
    @AppStorage("onboardingComplete") var onboardingComplete = false

    var body: some Scene {
        WindowGroup {
            if onboardingComplete {
                ContentView()
            } else {
                OnboardingView(onComplete: { onboardingComplete = true })
            }
        }
    }
}

struct ContentView: View {
    var body: some View {
        TabView {
            SummariesView()
                .tabItem { Label("Summaries", systemImage: "bubble.left.and.bubble.right") }
            TonesView()
                .tabItem { Label("Tones", systemImage: "slider.horizontal.3") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .task {
            let txID = await SubscriptionManager.shared.currentTransactionID()
            UserDefaults(suiteName: "group.com.yourname.replr")?.set(txID, forKey: "transaction_id")
        }
    }
}
