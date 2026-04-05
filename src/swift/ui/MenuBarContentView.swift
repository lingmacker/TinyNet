import SwiftUI

struct MenuBarContentView: View {
    @ObservedObject var viewModel: NetSpeedViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TinyNet")
                .font(.headline)

            if let errorText = viewModel.errorText {
                Text(errorText)
                    .foregroundStyle(.red)
                    .font(.caption)
            }

            Divider()

            Button("刷新") {
                viewModel.refresh()
            }

            Button("退出") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(12)
        .frame(minWidth: 220)
    }
}
