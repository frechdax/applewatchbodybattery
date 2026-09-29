import SwiftUI

@main
struct BodyBatteryWatchApp: App {
    @StateObject private var health = HealthKitManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(health)
                .task {
                    await health.prepareBackgroundUpdates()
                }
        }
    }
}
