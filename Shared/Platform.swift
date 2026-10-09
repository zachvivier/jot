#if os(iOS)
import UIKit

typealias PlatformFont = UIFont
typealias PlatformColor = UIColor

extension UIColor {
    static var labelColor: UIColor { .label }
    static var secondaryLabelColor: UIColor { .secondaryLabel }
    static var tertiaryLabelColor: UIColor { .tertiaryLabel }
    static var quaternaryLabelColor: UIColor { .quaternaryLabel }
}

extension UIFont {
    func adding(bold: Bool, italic: Bool) -> UIFont {
        var traits: UIFontDescriptor.SymbolicTraits = []
        if bold { traits.insert(.traitBold) }
        if italic { traits.insert(.traitItalic) }
        guard !traits.isEmpty,
              let descriptor = fontDescriptor.withSymbolicTraits(fontDescriptor.symbolicTraits.union(traits))
        else { return self }
        return UIFont(descriptor: descriptor, size: pointSize)
    }
}
#else
import AppKit

typealias PlatformFont = NSFont
typealias PlatformColor = NSColor

extension NSFont {
    func adding(bold: Bool, italic: Bool) -> NSFont {
        var traits: NSFontDescriptor.SymbolicTraits = []
        if bold { traits.insert(.bold) }
        if italic { traits.insert(.italic) }
        guard !traits.isEmpty else { return self }
        let descriptor = fontDescriptor.withSymbolicTraits(fontDescriptor.symbolicTraits.union(traits))
        return NSFont(descriptor: descriptor, size: pointSize) ?? self
    }
}
#endif
