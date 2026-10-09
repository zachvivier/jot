import SwiftUI
import UIKit

private let textInset = UIEdgeInsets(top: 18, left: 18, bottom: 18, right: 18)

/// Plain-text editor with the same typing aids as Apple Notes. Markdown is styled live as you type,
/// and the edit menu adds Markdown formatting.
struct EditorView: UIViewRepresentable {
    @Binding var text: String
    /// Increase to move the cursor into the editor.
    var focusRequest: Int

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.delegate = context.coordinator
        view.backgroundColor = .clear
        view.textContainerInset = textInset
        view.typingAttributes = MarkdownHighlighter.baseAttributes
        view.keyboardDismissMode = .interactive
        view.alwaysBounceVertical = true
        view.tintColor = Theme.accentUIColor
        return view
    }

    func updateUIView(_ view: UITextView, context: Context) {
        context.coordinator.parent = self
        if view.text != text {
            view.text = text
            Coordinator.restyle(view)
            view.selectedRange = NSRange(location: 0, length: 0)
            view.setContentOffset(.zero, animated: false)
        }
        if context.coordinator.focusRequest != focusRequest {
            context.coordinator.focusRequest = focusRequest
            DispatchQueue.main.async { view.becomeFirstResponder() }
        }
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: EditorView
        var focusRequest = 0

        init(parent: EditorView) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
            Self.restyle(textView)
        }

        /// Skips styling while a word is still being composed (dictation, Japanese, and similar keyboards).
        static func restyle(_ textView: UITextView) {
            guard textView.markedTextRange == nil else { return }
            MarkdownHighlighter.style(textView.textStorage)
            textView.typingAttributes = MarkdownHighlighter.baseAttributes
        }

        func textView(_ textView: UITextView, editMenuForTextIn range: NSRange, suggestedActions: [UIMenuElement]) -> UIMenu? {
            guard range.length > 0 else { return nil }
            let styles = [("Bold", "bold", "**"), ("Italic", "italic", "*"), ("Strikethrough", "strikethrough", "~~")]
            let actions = styles.map { title, symbol, marker in
                UIAction(title: title, image: UIImage(systemName: symbol)) { [weak self, weak textView] _ in
                    guard let self, let textView else { return }
                    self.toggle(marker, in: textView, range: range)
                }
            }
            let format = UIMenu(title: "Format", image: UIImage(systemName: "textformat"), children: actions)
            var elements = suggestedActions
            elements.insert(format, at: min(1, elements.count))
            return UIMenu(children: elements)
        }

        /// Wraps the selection in `marker`, or removes the marker if the selection is already wrapped.
        private func toggle(_ marker: String, in textView: UITextView, range: NSRange) {
            let text = textView.text as NSString
            let length = marker.utf16.count
            let selected = text.substring(with: range)
            let target: NSRange
            let replacement: String
            let selection: NSRange

            if Self.isWrapped(range, by: marker, in: text) {
                target = NSRange(location: range.location - length, length: range.length + 2 * length)
                replacement = selected
                selection = NSRange(location: target.location, length: range.length)
            } else if selected.hasPrefix(marker), selected.hasSuffix(marker), range.length > 2 * length {
                target = range
                replacement = String(selected.dropFirst(marker.count).dropLast(marker.count))
                selection = NSRange(location: range.location, length: range.length - 2 * length)
            } else {
                target = range
                replacement = marker + selected + marker
                selection = NSRange(location: range.location + length, length: range.length)
            }

            guard let start = textView.position(from: textView.beginningOfDocument, offset: target.location),
                  let end = textView.position(from: start, offset: target.length),
                  let textRange = textView.textRange(from: start, to: end)
            else { return }
            textView.replace(textRange, withText: replacement)
            textView.selectedRange = selection
            parent.text = textView.text
            Self.restyle(textView)
        }

        /// True when the same run of marker characters sits on both sides of `range`. A run of three
        /// is bold plus italic, so either marker can be removed from it.
        private static func isWrapped(_ range: NSRange, by marker: String, in text: NSString) -> Bool {
            let character = marker.utf16.first!
            var before = 0
            while range.location - before > 0, text.character(at: range.location - before - 1) == character { before += 1 }
            var after = 0
            while NSMaxRange(range) + after < text.length, text.character(at: NSMaxRange(range) + after) == character { after += 1 }
            return before == after && (before == marker.utf16.count || before == 3)
        }
    }
}

/// Read-only Markdown preview, rendered by the same code as the Mac app.
struct PreviewView: UIViewRepresentable {
    let source: String

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.isEditable = false
        view.backgroundColor = .clear
        view.textContainerInset = textInset
        view.alwaysBounceVertical = true
        view.tintColor = Theme.accentUIColor
        return view
    }

    func updateUIView(_ view: UITextView, context: Context) {
        guard context.coordinator.renderedSource != source else { return }
        context.coordinator.renderedSource = source
        view.attributedText = MarkdownRenderer.render(source)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        var renderedSource: String?
    }
}
