import AppKit
import Combine
import SwiftUI

@MainActor
final class MenuBarController: NSObject, NSWindowDelegate {
    private let viewModel: NetSpeedViewModel
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let panel = MenuPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
    private var subscription: AnyCancellable?
    private var localMonitor: Any?
    private var globalMonitor: Any?

    init(viewModel: NetSpeedViewModel) {
        self.viewModel = viewModel
        super.init()

        statusItem.button?.target = self
        statusItem.button?.action = #selector(toggleMenu)
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        statusItem.button?.setAccessibilityLabel("TinyNet")

        panel.title = "TinyNet"
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.level = .popUpMenu
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        panel.delegate = self
        panel.onDismiss = { [weak self] in self?.closeMenu() }

        subscription = viewModel.objectWillChange.receive(on: RunLoop.main).sink { [weak self] _ in
            self?.updatePresentation()
        }
        updatePresentation()
    }

    deinit {
        MainActor.assumeIsolated {
            if let localMonitor { NSEvent.removeMonitor(localMonitor) }
            if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
            panel.orderOut(nil)
            NSStatusBar.system.removeStatusItem(statusItem)
        }
    }

    @objc private func toggleMenu() {
        if panel.isVisible {
            closeMenu()
            return
        }

        let content = MenuHostingView(rootView: MenuBarContentView(viewModel: viewModel))
        content.sizingOptions = [.intrinsicContentSize]
        content.onSizeChange = { [weak self] in self?.positionMenu() }
        panel.contentView = content
        positionMenu()
        panel.makeKeyAndOrderFront(nil)
        statusItem.button?.highlight(true)

        let clicks: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: clicks) { [weak self] event in
            if let self, event.window !== self.panel, event.window !== self.statusItem.button?.window {
                self.closeMenu()
            }
            return event
        }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: clicks) { [weak self] _ in
            self?.closeMenu()
        }
    }

    private func closeMenu() {
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        localMonitor = nil
        globalMonitor = nil
        panel.orderOut(nil)
        panel.contentView = nil
        statusItem.button?.highlight(false)
    }

    func windowDidResignKey(_ notification: Notification) {
        closeMenu()
    }

    private func updatePresentation() {
        statusItem.button?.image = MenuBarSpeedLabel(viewModel: viewModel).image
    }

    private func positionMenu() {
        guard let button = statusItem.button, let window = button.window,
              let screen = window.screen, let content = panel.contentView else { return }
        let anchor = window.convertToScreen(button.convert(button.bounds, to: nil))
        let frame = Self.menuFrame(size: content.fittingSize, anchor: anchor, screen: screen.visibleFrame)
        if panel.frame != frame {
            panel.setFrame(frame, display: true)
            panel.invalidateShadow()
        }
    }

    static func menuFrame(size: NSSize, anchor: NSRect, screen: NSRect) -> NSRect {
        let x = max(screen.minX + 4, min(anchor.midX - size.width / 2, screen.maxX - size.width - 4))
        let y = max(screen.minY + 4, min(anchor.minY - 4, screen.maxY) - size.height)
        return NSRect(origin: NSPoint(x: x, y: y), size: size)
    }
}

private final class MenuHostingView: NSHostingView<MenuBarContentView> {
    var onSizeChange: (() -> Void)?

    override func invalidateIntrinsicContentSize() {
        super.invalidateIntrinsicContentSize()
        DispatchQueue.main.async { [weak self] in self?.onSizeChange?() }
    }
}

private final class MenuPanel: NSPanel {
    var onDismiss: (() -> Void)?
    override var canBecomeKey: Bool { true }

    override func cancelOperation(_ sender: Any?) {
        onDismiss?()
    }
}
