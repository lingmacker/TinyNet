import SwiftUI

@main
struct TinyNetMenuApp: App {
    @StateObject private var viewModel = NetSpeedViewModel()

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView(viewModel: viewModel)
        } label: {
            MenuBarSpeedLabel(viewModel: viewModel)
        }
    }
}
