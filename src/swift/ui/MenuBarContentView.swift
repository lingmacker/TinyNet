import SwiftUI

struct MenuBarContentView: View {
    @ObservedObject var viewModel: NetSpeedViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: Binding(
                get: { viewModel.launchAtLoginEnabled },
                set: { viewModel.setLaunchAtLogin($0) }
            )) {
                Text("开机启动")
            }

            if let launchAtLoginErrorText = viewModel.launchAtLoginErrorText {
                Text(launchAtLoginErrorText)
                    .foregroundStyle(.red)
                    .font(.caption)
            }

            Divider()

            Button("退出") {
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
