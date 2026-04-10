import SwiftUI
import AppKit
import CoreText

struct MenuBarSpeedLabel: View {
    @ObservedObject var viewModel: NetSpeedViewModel

    var body: some View {
        let upload = Self.formatSpeed(viewModel.uploadSpeed)
        let download = Self.formatSpeed(viewModel.downloadSpeed)
        let speedText = "↑ \(upload)\n↓ \(download)"
        let memory = Self.formatMemory(viewModel.memoryUsagePercent)
        let memoryText = viewModel.showMemoryUsageEnabled ? memory.map { "M\($0)" } : nil

        Image(nsImage: MenuBarIconGenerator.generateIcon(leftText: speedText, rightText: memoryText))
            .renderingMode(.template)
    }

    private static func formatMemory(_ memoryPercent: Float?) -> String? {
        guard let memoryPercent else {
            return nil
        }

        let clamped = min(100, max(0, memoryPercent))
        return String(format: "%02.0f%%", clamped)
    }

    private static func formatSpeed(_ speedKBps: Float) -> String {
        let kilo: Float = 1024
        let mega = kilo * 1024

        let value: Float
        let unit: String

        if speedKBps >= mega {
            value = speedKBps / mega
            unit = "GB"
        } else if speedKBps >= kilo {
            value = speedKBps / kilo
            unit = "MB"
        } else {
            value = speedKBps
            unit = "KB"
        }

        return String(format: "%6.2f%@/s", value, unit)
    }
}

@MainActor
final class MenuBarIconGenerator {
    private static let iconFont: NSFont = {
        loadCustomFont(size: 8)
    }()

    private static var cachedImages: [String: NSImage] = [:]

    static func generateIcon(leftText: String, rightText: String?) -> NSImage {
        let cacheKey = "\(leftText)|\(rightText ?? "")"
        if let cachedImage = cachedImages[cacheKey] {
            return cachedImage
        }

        let leftWidth: CGFloat = 66
        let rightWidth: CGFloat = rightText == nil ? 0 : 26
        let gap: CGFloat = rightText == nil ? 0 : 2
        let totalWidth = leftWidth + gap + rightWidth

        let image = NSImage(size: NSSize(width: totalWidth, height: 22), flipped: false) { rect in
            let style = NSMutableParagraphStyle()
            style.alignment = .right

            let attributes: [NSAttributedString.Key: Any] = [
                .font: iconFont,
                .paragraphStyle: style,
            ]

            let leftRect = NSRect(x: 0, y: 0, width: leftWidth, height: rect.height)
            leftText.draw(in: leftRect, withAttributes: attributes)

            if let rightText {
                let rightRect = NSRect(x: leftWidth + gap, y: 0, width: rightWidth, height: rect.height)
                rightText.draw(in: rightRect, withAttributes: attributes)
            }

            return true
        }

        image.isTemplate = true
        cachedImages[cacheKey] = image
        if cachedImages.count > 64 {
            cachedImages.removeAll(keepingCapacity: true)
            cachedImages[cacheKey] = image
        }
        return image
    }

    private static func loadCustomFont(size: CGFloat) -> NSFont {
        guard let fontURL = Bundle.main.url(forResource: "JetBrainsMono-Bold", withExtension: "ttf") else {
            return .monospacedSystemFont(ofSize: size, weight: .bold)
        }

        guard let dataProvider = CGDataProvider(url: fontURL as CFURL),
              let cgFont = CGFont(dataProvider),
              let postScriptName = cgFont.postScriptName as String?
        else {
            return .monospacedSystemFont(ofSize: size, weight: .bold)
        }

        _ = CTFontManagerRegisterGraphicsFont(cgFont, nil)

        return NSFont(name: postScriptName, size: size)
            ?? .monospacedSystemFont(ofSize: size, weight: .bold)
    }
}
