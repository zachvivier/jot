import LinkPresentation
import UIKit

/// Shares a note as text (Messages, Mail, Copy) but as its file over AirDrop, so a Mac receives "Name.txt".
final class NoteShareItem: NSObject, UIActivityItemSource {
    private let text: String
    private let fileURL: URL?
    private let subject: String

    init(text: String, fileURL: URL?, subject: String) {
        self.text = text
        self.fileURL = fileURL
        self.subject = subject
    }

    func activityViewControllerPlaceholderItem(_ controller: UIActivityViewController) -> Any {
        text
    }

    func activityViewController(_ controller: UIActivityViewController, itemForActivityType type: UIActivity.ActivityType?) -> Any? {
        if type == .airDrop, let fileURL { return fileURL }
        return text
    }

    func activityViewController(_ controller: UIActivityViewController, subjectForActivityType type: UIActivity.ActivityType?) -> String {
        subject
    }

    func activityViewControllerLinkMetadata(_ controller: UIActivityViewController) -> LPLinkMetadata? {
        let metadata = LPLinkMetadata()
        metadata.title = subject
        return metadata
    }
}

enum ShareSheet {
    static func present(_ item: NoteShareItem) {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        guard var top = scene?.keyWindow?.rootViewController else { return }
        while let presented = top.presentedViewController { top = presented }

        let controller = UIActivityViewController(activityItems: [item], applicationActivities: nil)
        controller.popoverPresentationController?.sourceView = top.view
        top.present(controller, animated: true)
    }
}
