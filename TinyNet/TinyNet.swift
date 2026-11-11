import SwiftUI

@main
struct TinyNet: App {
    @NSApplicationDelegateAdaptor(TinyNetDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

@MainActor
private final class TinyNetDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        menuBarController = MenuBarController(viewModel: NetSpeedViewModel())
    }
}
