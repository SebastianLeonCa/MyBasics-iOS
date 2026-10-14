import SwiftUI

@main
struct MyBasicsApp: App {
    @State private var environment = AppEnvironment.makeDefault()

    var body: some Scene {
        WindowGroup {
            RootView(environment: environment)
                .environment(environment)
        }
    }
}
