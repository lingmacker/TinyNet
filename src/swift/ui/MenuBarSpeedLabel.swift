import SwiftUI
import AppKit
import CoreText

struct MenuBarSpeedLabel: View {
    @ObservedObject var viewModel: NetSpeedViewModel

    var body: some View {
        let upload = Self.leftPad(viewModel.uploadText, to: 8)
        let download = Self.leftPad(viewModel.downloadText, to: 8)
        let text = "↑ \(upload)\n↓ \(download)"

        Image(nsImage: MenuBarIconGenerator.generateIcon(text: text))
            .renderingMode(.template)
    }

    private static func leftPad(_ value: String, to length: Int) -> String {
        if value.count >= length {
            return value
        }

        return String(repeating: " ", count: length - value.count) + value
    }
}

final class MenuBarIconGenerator {
    static func generateIcon(
        text: String,
        font: NSFont = MenuBarIconGenerator.loadCustomFont(size: 8)
    ) -> NSImage {
        let image = NSImage(size: NSSize(width: 66, height: 22), flipped: false) { rect in
            let style = NSMutableParagraphStyle()
            style.alignment = .right

            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .paragraphStyle: style,
            ]

            let textSize = text.size(withAttributes: attributes)
            let textRect = NSRect(
                x: rect.width - textSize.width - 2,
                y: (rect.height - textSize.height) / 2,
                width: textSize.width,
                height: textSize.height
            )

            text.draw(in: textRect, withAttributes: attributes)
            return true
        }

        image.isTemplate = true
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

        CTFontManagerRegisterGraphicsFont(cgFont, nil)

        return NSFont(name: postScriptName, size: size)
            ?? .monospacedSystemFont(ofSize: size, weight: .bold)
    }
}
