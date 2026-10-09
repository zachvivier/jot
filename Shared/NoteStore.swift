import Foundation

struct NoteFile {
    let url: URL
    let modified: Date

    var name: String { url.deletingPathExtension().lastPathComponent }
}

enum NoteStore {
    #if os(iOS)
    /// The app's Documents folder, shown in the Files app under On My iPhone › Jot.
    static var folder = URL.documentsDirectory
    #else
    static var folder = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("notes", isDirectory: true)
    #endif
    static let noteExtensions: Set<String> = ["txt", "md", "markdown"]
    static let didChange = Notification.Name("JotNotesDidChange")
    static let trashedKey = "trashedURL"

    static func ensureFolder() throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    /// Notes in the notes folder, most recently modified first.
    static func listNotes() -> [NoteFile] {
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: .skipsHiddenFiles
        )) ?? []

        return urls
            .filter { noteExtensions.contains($0.pathExtension.lowercased()) }
            .map { url in
                let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
                return NoteFile(url: url, modified: modified ?? .distantPast)
            }
            .sorted { $0.modified > $1.modified }
    }

    /// Builds a file name from the first non-empty line of the note, or a timestamp if the note is blank.
    static func suggestedName(for text: String) -> String {
        let firstLine = text
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty } ?? ""

        let cleaned = firstLine
            .replacingOccurrences(of: "[*~`]", with: "", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "#>-+ \t"))
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .trimmingCharacters(in: CharacterSet(charactersIn: ". "))

        if cleaned.isEmpty {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH.mm.ss"
            return "Note \(formatter.string(from: Date()))"
        }
        return String(cleaned.prefix(60)).trimmingCharacters(in: .whitespaces)
    }

    /// Returns a URL in `directory` that does not collide with an existing file ("Name.txt", "Name 2.txt", ...).
    /// A file at `excluding` does not count as a collision, so a note can keep its own name.
    static func uniqueURL(base: String, ext: String, in directory: URL, excluding: URL? = nil) -> URL {
        var candidate = directory.appendingPathComponent(base).appendingPathExtension(ext)
        var counter = 2
        while FileManager.default.fileExists(atPath: candidate.path),
              candidate.standardizedFileURL.path.lowercased() != excluding?.standardizedFileURL.path.lowercased() {
            candidate = directory.appendingPathComponent("\(base) \(counter)").appendingPathExtension(ext)
            counter += 1
        }
        return candidate
    }
}
