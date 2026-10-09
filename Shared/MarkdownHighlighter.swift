#if os(iOS)
import UIKit
#else
import AppKit
#endif

/// Styles Markdown in place while the text stays plain: headings grow, emphasis shows,
/// and the markers fade but stay visible and editable.
enum MarkdownHighlighter {
    static let bodySize: CGFloat = 15
    private static let headingSizes: [CGFloat] = [24, 20, 18, 16, 15, 15]

    static var baseFont: PlatformFont { .monospacedSystemFont(ofSize: bodySize, weight: .regular) }

    static var baseAttributes: [NSAttributedString.Key: Any] {
        [.font: baseFont, .foregroundColor: PlatformColor.labelColor, .paragraphStyle: paragraph()]
    }

    private static let heading = regex(#"^(#{1,6})[ \t]+\S.*$"#)
    private static let quote = regex(#"^>[ \t]?"#)
    private static let listItem = regex(#"^[ \t]*(?:[-*+]|\d+[.)])[ \t]+"#)
    private static let rule = regex(#"^[ \t]*(?:\*{3,}|-{3,}|_{3,})[ \t]*$"#)
    private static let fence = regex(#"^[ \t]*```"#)
    private static let inlineCode = regex(#"`[^`\n]+`"#)
    private static let bold = regex(#"(\*\*|__)(?=\S)(.+?)(?<=\S)\1"#)
    private static let italic = regex(#"(?<![*\w])([*_])(?=[^\s*_])(.+?)(?<=[^\s*_])\1(?![*\w])"#)
    private static let strike = regex(#"~~(?=\S)(.+?)(?<=\S)~~"#)
    private static let link = regex(#"\[([^\]\n]+)\]\(([^)\n]+)\)"#)

    static func style(_ storage: NSTextStorage) {
        let text = storage.string as NSString
        let whole = NSRange(location: 0, length: text.length)
        storage.beginEditing()
        storage.setAttributes(baseAttributes, range: whole)

        var inFence = false
        var codeRanges: [NSRange] = []
        text.enumerateSubstrings(in: whole, options: [.byLines, .substringNotRequired]) { _, lineRange, enclosingRange, _ in
            let line = text.substring(with: lineRange)
            if matches(fence, line) {
                inFence.toggle()
                codeRanges.append(enclosingRange)
                fade(storage, enclosingRange)
                return
            }
            if inFence {
                codeRanges.append(enclosingRange)
                storage.addAttribute(.backgroundColor, value: codeBackground, range: enclosingRange)
                storage.addAttribute(.foregroundColor, value: PlatformColor.secondaryLabelColor, range: enclosingRange)
                return
            }
            styleBlock(line, lineRange: lineRange, enclosingRange: enclosingRange, in: storage)
        }

        for match in inlineCode.matches(in: storage.string, range: whole) where !overlaps(match.range, codeRanges) {
            codeRanges.append(match.range)
            storage.addAttribute(.backgroundColor, value: codeBackground, range: match.range)
            fade(storage, NSRange(location: match.range.location, length: 1))
            fade(storage, NSRange(location: NSMaxRange(match.range) - 1, length: 1))
        }

        styleSpans(bold, in: storage, skipping: codeRanges) { addTraits(storage, $0, bold: true, italic: false) }
        styleSpans(italic, in: storage, skipping: codeRanges) { addTraits(storage, $0, bold: false, italic: true) }
        styleSpans(strike, in: storage, skipping: codeRanges) {
            storage.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: $0)
        }

        for match in link.matches(in: storage.string, range: whole) where !overlaps(match.range, codeRanges) {
            fade(storage, match.range)
            storage.addAttribute(.foregroundColor, value: accent, range: match.range(at: 1))
        }

        storage.endEditing()
    }

    // MARK: - Blocks

    private static func styleBlock(_ line: String, lineRange: NSRange, enclosingRange: NSRange, in storage: NSTextStorage) {
        let local = NSRange(location: 0, length: (line as NSString).length)

        if let match = heading.firstMatch(in: line, range: local) {
            let level = match.range(at: 1).length
            let size = headingSizes[level - 1]
            let style = paragraph()
            style.paragraphSpacingBefore = level <= 2 ? 8 : 4
            storage.addAttributes([
                .font: PlatformFont.monospacedSystemFont(ofSize: size, weight: .bold),
                .paragraphStyle: style,
            ], range: enclosingRange)
            fade(storage, NSRange(location: lineRange.location, length: level + 1))
        } else if rule.firstMatch(in: line, range: local) != nil {
            fade(storage, lineRange)
        } else if let match = quote.firstMatch(in: line, range: local) {
            storage.addAttribute(.foregroundColor, value: PlatformColor.secondaryLabelColor, range: lineRange)
            fade(storage, NSRange(location: lineRange.location, length: match.range.length))
        } else if let match = listItem.firstMatch(in: line, range: local) {
            let style = paragraph()
            style.headIndent = CGFloat(match.range.length) * characterWidth
            storage.addAttribute(.paragraphStyle, value: style, range: enclosingRange)
            storage.addAttribute(.foregroundColor, value: PlatformColor.tertiaryLabelColor, range: NSRange(location: lineRange.location, length: match.range.length))
        }
    }

    // MARK: - Inline

    /// Styles group 2 (or the only group) of each match and fades the markers around it.
    private static func styleSpans(
        _ pattern: NSRegularExpression,
        in storage: NSTextStorage,
        skipping excluded: [NSRange],
        apply: (NSRange) -> Void
    ) {
        let whole = NSRange(location: 0, length: storage.length)
        for match in pattern.matches(in: storage.string, range: whole) where !overlaps(match.range, excluded) {
            let inner = match.range(at: match.numberOfRanges - 1)
            apply(inner)
            fade(storage, NSRange(location: match.range.location, length: inner.location - match.range.location))
            fade(storage, NSRange(location: NSMaxRange(inner), length: NSMaxRange(match.range) - NSMaxRange(inner)))
        }
    }

    private static func addTraits(_ storage: NSTextStorage, _ range: NSRange, bold: Bool, italic: Bool) {
        storage.enumerateAttribute(.font, in: range) { value, subrange, _ in
            let font = value as? PlatformFont ?? baseFont
            storage.addAttribute(.font, value: font.adding(bold: bold, italic: italic), range: subrange)
        }
    }

    // MARK: - Helpers

    private static var accent: PlatformColor {
        PlatformColor(red: 0.949, green: 0.549, blue: 0.2, alpha: 1)
    }

    private static var codeBackground: PlatformColor {
        PlatformColor.quaternaryLabelColor.withAlphaComponent(0.15)
    }

    private static var characterWidth: CGFloat {
        ("M" as NSString).size(withAttributes: [.font: baseFont]).width
    }

    private static func paragraph() -> NSMutableParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.lineHeightMultiple = 1.2
        return style
    }

    private static func fade(_ storage: NSTextStorage, _ range: NSRange) {
        guard range.length > 0 else { return }
        storage.addAttribute(.foregroundColor, value: PlatformColor.tertiaryLabelColor, range: range)
    }

    private static func overlaps(_ range: NSRange, _ others: [NSRange]) -> Bool {
        others.contains { NSIntersectionRange($0, range).length > 0 }
    }

    private static func matches(_ pattern: NSRegularExpression, _ line: String) -> Bool {
        pattern.firstMatch(in: line, range: NSRange(location: 0, length: (line as NSString).length)) != nil
    }

    private static func regex(_ pattern: String) -> NSRegularExpression {
        try! NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines])
    }
}
