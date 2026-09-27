import AppKit

/// Turns Markdown source into a styled, read-only NSAttributedString using Foundation's built-in parser.
enum MarkdownRenderer {
    static let bodySize: CGFloat = 15
    private static let listIndent: CGFloat = 18
    private static let quoteIndent: CGFloat = 18

    static func render(_ source: String) -> NSAttributedString {
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .full,
            failurePolicy: .returnPartiallyParsedIfPossible
        )
        guard let parsed = try? AttributedString(markdown: source, options: options) else {
            return NSAttributedString(string: source, attributes: [
                .font: NSFont.systemFont(ofSize: bodySize),
                .foregroundColor: NSColor.labelColor,
            ])
        }

        let output = NSMutableAttributedString()
        var previousBlock: PresentationIntent?
        var previousListItem: Int?
        var paragraph = NSParagraphStyle()

        for run in parsed.runs {
            let block = run.presentationIntent
            let kinds = block?.components ?? []
            let listItem = kinds.first { if case .listItem = $0.kind { return true } else { return false } }

            if block != previousBlock {
                if output.length > 0 {
                    let separator = sameTableRow(previousBlock, block) ? "\t" : "\n"
                    let carried = output.attributes(at: output.length - 1, effectiveRange: nil)
                    output.append(NSAttributedString(string: separator, attributes: carried))
                }

                let startsListItem = listItem != nil && listItem?.identity != previousListItem
                paragraph = paragraphStyle(for: kinds, startsListItem: startsListItem)

                if startsListItem, let listItem {
                    output.append(NSAttributedString(
                        string: listPrefix(for: listItem, in: kinds) + "\t",
                        attributes: [
                            .font: NSFont.systemFont(ofSize: bodySize),
                            .foregroundColor: NSColor.secondaryLabelColor,
                            .paragraphStyle: paragraph,
                        ]
                    ))
                }
                previousListItem = listItem?.identity
                previousBlock = block
            }

            var text = String(parsed[run.range].characters)
            if kinds.contains(where: { if case .codeBlock = $0.kind { return true } else { return false } }) {
                while text.hasSuffix("\n") { text.removeLast() }
            }

            var attributes = inlineAttributes(for: kinds, inline: run.inlinePresentationIntent)
            attributes[.paragraphStyle] = paragraph
            if let link = run.link {
                attributes[.link] = link
            }
            output.append(NSAttributedString(string: text, attributes: attributes))
        }

        return output
    }

    private static func sameTableRow(_ lhs: PresentationIntent?, _ rhs: PresentationIntent?) -> Bool {
        func row(_ intent: PresentationIntent?) -> Int? {
            intent?.components.first {
                switch $0.kind {
                case .tableRow, .tableHeaderRow: return true
                default: return false
                }
            }?.identity
        }
        guard let left = row(lhs), let right = row(rhs) else { return false }
        return left == right
    }

    private static func listPrefix(for item: PresentationIntent.IntentType, in kinds: [PresentationIntent.IntentType]) -> String {
        guard case .listItem(let ordinal) = item.kind else { return "" }
        let ordered = kinds.first {
            switch $0.kind {
            case .orderedList, .unorderedList: return true
            default: return false
            }
        }
        if case .orderedList = ordered?.kind {
            return "\(ordinal)."
        }
        return "•"
    }

    private static func paragraphStyle(for kinds: [PresentationIntent.IntentType], startsListItem: Bool) -> NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.lineHeightMultiple = 1.2
        style.paragraphSpacing = 10

        var indent: CGFloat = 0
        var listDepth = 0

        for kind in kinds.map(\.kind) {
            switch kind {
            case .orderedList, .unorderedList:
                listDepth += 1
            case .blockQuote:
                indent += quoteIndent
                style.paragraphSpacingBefore = 8
            case .codeBlock:
                indent += 12
                style.lineHeightMultiple = 1.1
            case .header(let level):
                style.paragraphSpacingBefore = level <= 2 ? 12 : 6
                style.paragraphSpacing = 6
            case .table:
                style.tabStops = (1...8).map { NSTextTab(textAlignment: .left, location: CGFloat($0) * 160) }
                style.paragraphSpacing = 4
            default:
                break
            }
        }

        if listDepth > 0 {
            let textStart = indent + CGFloat(listDepth) * listIndent
            style.firstLineHeadIndent = startsListItem ? textStart - listIndent : textStart
            style.headIndent = textStart
            style.tabStops = [NSTextTab(textAlignment: .left, location: textStart)]
            style.paragraphSpacing = 4
        } else {
            style.firstLineHeadIndent = indent
            style.headIndent = indent
        }
        return style
    }

    private static func inlineAttributes(
        for kinds: [PresentationIntent.IntentType],
        inline: InlinePresentationIntent?
    ) -> [NSAttributedString.Key: Any] {
        var font = NSFont.systemFont(ofSize: bodySize)
        var color = NSColor.labelColor
        var attributes: [NSAttributedString.Key: Any] = [:]

        for kind in kinds.map(\.kind) {
            switch kind {
            case .header(let level):
                let sizes: [CGFloat] = [26, 21, 18, 16, 15, 15]
                font = NSFont.systemFont(ofSize: sizes[min(level, 6) - 1], weight: level <= 2 ? .bold : .semibold)
            case .codeBlock:
                font = NSFont.monospacedSystemFont(ofSize: bodySize - 2, weight: .regular)
                attributes[.backgroundColor] = NSColor.quaternaryLabelColor.withAlphaComponent(0.12)
            case .blockQuote:
                color = .secondaryLabelColor
            case .tableHeaderRow:
                font = NSFont.systemFont(ofSize: bodySize, weight: .semibold)
            default:
                break
            }
        }

        if let inline {
            var traits: NSFontDescriptor.SymbolicTraits = []
            if inline.contains(.stronglyEmphasized) { traits.insert(.bold) }
            if inline.contains(.emphasized) { traits.insert(.italic) }
            if !traits.isEmpty {
                let descriptor = font.fontDescriptor.withSymbolicTraits(font.fontDescriptor.symbolicTraits.union(traits))
                font = NSFont(descriptor: descriptor, size: font.pointSize) ?? font
            }
            if inline.contains(.code) {
                font = NSFont.monospacedSystemFont(ofSize: font.pointSize - 1, weight: .regular)
                attributes[.backgroundColor] = NSColor.quaternaryLabelColor.withAlphaComponent(0.12)
            }
            if inline.contains(.strikethrough) {
                attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
            }
        }

        attributes[.font] = font
        attributes[.foregroundColor] = color
        return attributes
    }
}
