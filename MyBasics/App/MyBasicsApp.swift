import SwiftUI

@main
struct MyBasicsApp: App {
    @State private var environment = AppEnvironment.mock()

    var body: some Scene {
        WindowGroup {
            PlaceholderHomeView()
                .environment(environment)
        }
    }
}
