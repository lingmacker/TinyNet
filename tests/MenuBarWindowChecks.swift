import AppKit
import SwiftUI

// Standalone AppKit checks; run with `make test-ui` in a logged-in macOS session.
@MainActor
final class NetSpeedViewModel: ObservableObject {
    @Published var uploadSpeed: Float = 32
    @Published var downloadSpeed: Float = 2048
    @Published var memoryUsagePercent: Float? = 40
    @Published var cpuUsagePercent: Float? = 10
    @Published var launchAtLoginEnabled = true
    @Published var showResourceUsageEnabled = false
    @Published var appNetworkUnavailable = false
    @Published var appNetworkLoaded = false
    @Published var appNetworkUsage: [AppNetworkUsage] = []

    func setLaunchAtLogin(_ enabled: Bool) { launchAtLoginEnabled = enabled }
    func setShowResourceUsageEnabled(_ enabled: Bool) { showResourceUsageEnabled = enabled }
    func syncLaunchAtLoginStatus() {}
}

@main
struct MenuBarWindowChecks {
    @MainActor
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let model = NetSpeedViewModel()
        let controller = MenuBarController(viewModel: model)

        Task { @MainActor in
            func settle() async { try? await Task.sleep(for: .milliseconds(150)) }
            @MainActor func statusButtons(_ view: NSView) -> [NSStatusBarButton] {
                if let button = view as? NSStatusBarButton { return [button] }
                return view.subviews.flatMap(statusButtons)
            }
            await settle()
            let button = app.windows.compactMap(\.contentView).flatMap(statusButtons)
                .first { $0.target === controller }!
            let imageWidth = button.image!.size.width
            button.performClick(nil)
            await settle()
            let panel = app.windows.first { $0 is NSPanel && $0.isVisible }!
            assert(!panel.isOpaque && panel.backgroundColor.alphaComponent == 0)
            assert(panel.styleMask.contains(.nonactivatingPanel) && !panel.styleMask.contains(.titled))
            assert(panel.frame.width == 320)
            let initialHeight = panel.frame.height
            let top = panel.frame.maxY

            model.appNetworkUsage = (0..<5).map { index in
                AppNetworkUsage(application: NetworkApplication(id: "\(index)", name: "Application \(index)", bundlePath: nil), downloadBps: UInt64(index * 1024))
            }
            model.appNetworkLoaded = true
            model.showResourceUsageEnabled = true
            await settle()
            assert(panel.frame.height > initialHeight, "The menu must grow when app rows load: initial=\(initialHeight), frame=\(panel.frame), fitting=\(panel.contentView!.fittingSize)")
            assert(panel.frame.maxY == top, "Resizing must keep the menu anchored below the status item")
            assert(button.image!.size.width > imageWidth, "Enabling resource usage must resize the status item")

            for appearance in [NSAppearance.Name.aqua, .darkAqua] {
                app.appearance = NSAppearance(named: appearance)
                await settle()
                let content = panel.contentView!
                let bitmap = content.bitmapImageRepForCachingDisplay(in: content.bounds)!
                content.cacheDisplay(in: content.bounds, to: bitmap)
                assert(bitmap.colorAt(x: 0, y: 0)!.alphaComponent < 0.01, "The outer corner must be transparent")
                // WindowServer composites Liquid Glass; cached bitmaps only contain the foreground.
                let name = appearance == .aqua ? "light" : "dark"
                try! bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: ".build/menu-window-\(name).png"))
            }

            model.appNetworkUsage = []
            await settle()
            assert(panel.frame.height == initialHeight, "The menu must shrink when rows disappear")
            button.performClick(nil)
            assert(!panel.isVisible, "Clicking the status item again must close the menu")
            button.performClick(nil)
            await settle()
            let escape = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: panel.windowNumber, context: nil, characters: "\u{1b}", charactersIgnoringModifiers: "\u{1b}", isARepeat: false, keyCode: 53)!
            app.postEvent(escape, atStart: false)
            await settle()
            assert(!panel.isVisible, "Escape must close the menu")
            button.performClick(nil)
            await settle()
            let outsideClick = NSEvent.mouseEvent(with: .leftMouseDown, location: .zero, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: 0, context: nil, eventNumber: 0, clickCount: 1, pressure: 1)!
            app.postEvent(outsideClick, atStart: false)
            await settle()
            assert(!panel.isVisible, "A click outside the menu must close it")

            for screen in [NSRect(x: 0, y: 0, width: 1440, height: 900), NSRect(x: -1920, y: -200, width: 1920, height: 1080)] {
                for x in [screen.minX, screen.midX, screen.maxX] {
                    let frame = MenuBarController.menuFrame(size: NSSize(width: 320, height: 260), anchor: NSRect(x: x, y: screen.maxY, width: 24, height: 24), screen: screen)
                    assert(screen.contains(frame), "The menu must stay on the status item's display")
                    assert(frame.maxY == screen.maxY - 4)
                }
            }
            print("Menu window checks passed: sizing, appearance, toggling, Escape, outside clicks, display bounds")
            app.terminate(nil)
        }
        app.run()
    }
}
