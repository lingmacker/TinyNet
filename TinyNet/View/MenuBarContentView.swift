import SwiftUI

struct MenuBarContentView: View {
    @ObservedObject var viewModel: NetSpeedViewModel
    @State private var hoveredMenuItem: String?

    var body: some View {
        VStack(spacing: 0) {
            menuItem("menu.launch_at_login", checked: viewModel.launchAtLoginEnabled) {
                viewModel.setLaunchAtLogin(!viewModel.launchAtLoginEnabled)
            }
            menuItem("menu.show_resource_usage", checked: viewModel.showResourceUsageEnabled) {
                viewModel.setShowResourceUsageEnabled(!viewModel.showResourceUsageEnabled)
            }

            menuDivider

            appNetworkSection
                .padding(.vertical, 5)

            menuDivider

            menuItem("menu.quit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .padding(5)
        .font(.system(size: 12, weight: .regular))
        .foregroundStyle(.primary)
        .frame(width: 320)
        .background(.white)
        .environment(\.colorScheme, .light)
        .onAppear {
            viewModel.syncLaunchAtLoginStatus()
        }
    }

    @ViewBuilder
    private var appNetworkSection: some View {
        if viewModel.appNetworkUnavailable {
            networkStatus("menu.network.unavailable", systemImage: "wifi.exclamationmark")
        } else if !viewModel.appNetworkLoaded {
            HStack(spacing: 10) {
                ProgressView().controlSize(.small)
                Text(String(localized: "menu.network.loading"))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 64)
        } else if viewModel.appNetworkUsage.isEmpty {
            networkStatus("menu.network.empty", systemImage: "network")
        } else {
            let visibleUsage = viewModel.appNetworkUsage.prefix(5)
            let maximumBps = visibleUsage.map {
                Double($0.downloadBps) + Double($0.uploadBps)
            }.max() ?? 0

            VStack(spacing: 0) {
                ForEach(visibleUsage) { usage in
                    AppNetworkRow(usage: usage, maximumBps: maximumBps)
                }
            }
        }
    }

    private var menuDivider: some View {
        Divider()
            .padding(.leading, 25)
            .padding(.trailing, 8)
            .padding(.vertical, 5)
    }

    private func menuItem(
        _ key: String.LocalizationValue, checked: Bool? = nil, action: @escaping () -> Void
    ) -> some View {
        let title = String(localized: key)
        let highlighted = hoveredMenuItem == title
        return Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .semibold))
                    .opacity(checked == true ? 1 : 0)
                    .frame(width: 16)
                    .accessibilityHidden(true)
                Text(title)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 4)
            .frame(height: 26)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(highlighted ? Color.white : Color.black)
        .background(highlighted ? Color.accentColor : .clear, in: RoundedRectangle(cornerRadius: 4))
        .onHover { hoveredMenuItem = $0 ? title : nil }
        .accessibilityAddTraits(checked == true ? .isSelected : [])
    }

    private func networkStatus(_ key: String.LocalizationValue, systemImage: String) -> some View {
        Label(String(localized: key), systemImage: systemImage)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, minHeight: 64)
            .padding(.horizontal, 12)
    }
}

private struct AppNetworkRow: View {
    let usage: AppNetworkUsage
    let maximumBps: Double
    @State private var icon: NSImage?

    private var serviceSymbol: String {
        switch usage.application.name {
        case "mDNSResponder": return "network"
        case "rapportd": return "airplayaudio"
        default: return "gearshape.fill"
        }
    }

    private var description: String {
        let total = ByteCountFormatter.string(fromByteCount: Int64(clamping: usage.totalBytes), countStyle: .binary)
        return "\(usage.application.name)\n\(String(localized: "menu.network.download")): \(formatNetworkRate(usage.downloadBps))\n\(String(localized: "menu.network.upload")): \(formatNetworkRate(usage.uploadBps))\n\(String(localized: "menu.network.total")): \(total)\n\(String(localized: "menu.network.scope"))"
    }

    var body: some View {
        HStack(alignment: .top, spacing: 7) {
            Group {
                if let icon {
                    Image(nsImage: icon).resizable()
                } else {
                    Image(systemName: serviceSymbol)
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(serviceSymbol == "gearshape.fill" ? Color.gray : Color.blue)
                }
            }
            .frame(width: 14, height: 14)
            .accessibilityHidden(true)

            VStack(spacing: 3) {
                HStack(spacing: 5) {
                    Text(usage.application.name)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(usage.totalBps == 0 ? Color(white: 0.38) : Color.black)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(formatNetworkRate(usage.downloadBps))
                        .foregroundStyle(Color(white: usage.downloadBps == 0 ? 0.44 : 0.28))
                        .frame(width: 70, alignment: .trailing)
                    Text(formatNetworkRate(usage.uploadBps))
                        .foregroundStyle(Color(white: usage.uploadBps == 0 ? 0.44 : 0.28))
                        .frame(width: 70, alignment: .trailing)
                }
                .font(.system(size: 10, weight: .medium))
                .monospacedDigit()

                GeometryReader { geometry in
                    let total = Double(usage.downloadBps) + Double(usage.uploadBps)
                    let relativeLength = networkRateBarLength(
                        downloadBps: usage.downloadBps, uploadBps: usage.uploadBps, maximumBps: maximumBps
                    )
                    let width = total == 0 ? 0 : min(geometry.size.width, max(3, geometry.size.width * relativeLength))
                    HStack(spacing: 0) {
                        Color.blue.frame(width: width * Double(usage.downloadBps) / max(total, 1))
                        Color.green.frame(width: width * Double(usage.uploadBps) / max(total, 1))
                    }
                    .clipShape(Capsule())
                }
                .frame(height: 2)
                .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, 10)
        .padding(.top, 4)
        .frame(height: 28, alignment: .top)
        .help(description)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(description)
        .onAppear {
            if let path = usage.application.bundlePath {
                icon = NSWorkspace.shared.icon(forFile: path)
            }
        }
    }
}
