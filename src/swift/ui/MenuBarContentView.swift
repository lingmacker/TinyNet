import SwiftUI

struct MenuBarContentView: View {
    @ObservedObject var viewModel: NetSpeedViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            Divider()

            Button("退出") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(12)
        .frame(minWidth: 220)
    }
}
