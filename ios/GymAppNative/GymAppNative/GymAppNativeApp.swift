import SwiftUI
import SwiftData

@main
struct GymAppNativeApp: App {
  var body: some Scene {
    WindowGroup {
      ContentView()
    }
    .modelContainer(for: ActiveWorkoutRecord.self)
  }
}
