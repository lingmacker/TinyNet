import SwiftUI
import AppKit
import CoreText

struct MenuBarSpeedLabel: View {
    @ObservedObject var viewModel: NetSpeedViewModel

    var body: some View {
        let upload = Self.formatSpeed(viewModel.uploadSpeed)
        let download = Self.formatSpeed(viewModel.downloadSpeed)
        let text = "↑ \(upload)\n↓ \(download)"

        Image(nsImage: MenuBarIconGenerator.generateIcon(text: text))
            .renderingMode(.template)
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

    private static var cachedText: String = ""
    private static var cachedImage: NSImage?

    static func generateIcon(text: String) -> NSImage {
        if text == cachedText, let cachedImage {
            return cachedImage
        }

        let image = NSImage(size: NSSize(width: 66, height: 22), flipped: false) { rect in
            let style = NSMutableParagraphStyle()
            style.alignment = .right

            let attributes: [NSAttributedString.Key: Any] = [
                .font: iconFont,
                .paragraphStyle: style,
            ]

            let textSize = text.size(withAttributes: attributes)
            let textRect = NSRect(
                x: (rect.width - textSize.width) / 2,
                y: (rect.height - textSize.height) / 2,
                width: textSize.width,
                height: textSize.height
            )

            text.draw(in: textRect, withAttributes: attributes)
            return true
        }

        image.isTemplate = true
        cachedText = text
        cachedImage = image
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
