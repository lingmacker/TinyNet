import SwiftUI

struct MenuBarContentView: View {
    @ObservedObject var viewModel: NetSpeedViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: Binding(
                get: { viewModel.launchAtLoginEnabled },
                set: { viewModel.setLaunchAtLogin($0) }
            )) {
                Text(String(localized: "menu.launch_at_login", table: "Localizable"))
            }

            Toggle(isOn: Binding(
                get: { viewModel.showResourceUsageEnabled },
                set: { viewModel.setShowResourceUsageEnabled($0) }
            )) {
                Text(String(localized: "menu.show_resource_usage", table: "Localizable"))
            }

            Divider()

            Button(String(localized: "menu.quit", table: "Localizable")) {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(12)
        .frame(minWidth: 220)
        .onAppear {
            viewModel.syncLaunchAtLoginStatus()
        }
    }
}
