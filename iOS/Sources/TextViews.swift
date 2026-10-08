import SwiftUI
import UIKit

private let textInset = UIEdgeInsets(top: 18, left: 18, bottom: 18, right: 18)

/// Plain-text editor that matches the Mac: monospaced, no smart quotes or autocorrect, spell check on.
struct EditorView: UIViewRepresentable {
    @Binding var text: String
    /// Increase to move the cursor into the editor.
    var focusRequest: Int

    private static let attributes: [NSAttributedString.Key: Any] = {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineHeightMultiple = 1.2
        return [
            .font: UIFont.monospacedSystemFont(ofSize: 15, weight: .regular),
            .foregroundColor: UIColor.label,
            .paragraphStyle: paragraph,
        ]
    }()

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.delegate = context.coordinator
        view.backgroundColor = .clear
        view.textContainerInset = textInset
        view.typingAttributes = Self.attributes
        view.autocorrectionType = .no
        view.spellCheckingType = .yes
        view.smartQuotesType = .no
        view.smartDashesType = .no
        view.smartInsertDeleteType = .no
        view.keyboardDismissMode = .interactive
        view.alwaysBounceVertical = true
        view.tintColor = Theme.accentUIColor
        return view
    }

    func updateUIView(_ view: UITextView, context: Context) {
        context.coordinator.parent = self
        if view.text != text {
            view.attributedText = NSAttributedString(string: text, attributes: Self.attributes)
            view.typingAttributes = Self.attributes
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
