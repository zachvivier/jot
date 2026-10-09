import Foundation
import Observation

/// Holds the open note and saves it shortly after each edit. iOS can end a background app
/// without warning, so there is no manual save step as there is on the Mac.
@MainActor
@Observable
final class NoteModel {
    private(set) var text = ""
    private(set) var fileURL: URL?
    private(set) var notes: [NoteFile] = []
    var isPreviewing = false
    var errorMessage: String?

    private var isDirty = false
    private var namesFromFirstLine = true
    private var saveTask: Task<Void, Never>?

    private static let lastNoteKey = "lastNote"
    private static let saveDelay = Duration.seconds(1)
    private static let deletedFolder = NoteStore.folder.appendingPathComponent("Recently Deleted", isDirectory: true)

    var hasText: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var title: String {
        fileURL?.lastPathComponent ?? "Untitled"
    }

    init() {
        if let name = UserDefaults.standard.string(forKey: Self.lastNoteKey) {
            let url = NoteStore.folder.appendingPathComponent(name)
            if FileManager.default.fileExists(atPath: url.path) {
                try? load(url)
            }
        }
        refreshNotes()
    }

    func edit(_ newText: String) {
        guard newText != text else { return }
        text = newText
        isDirty = true
        scheduleSave()
    }

    func newNote() {
        save()
        reset()
    }

    func open(_ url: URL) {
        guard url.standardizedFileURL != fileURL?.standardizedFileURL else { return }
        save()
        do {
            try load(url)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Moves the note to a "Recently Deleted" folder, visible in the Files app, so it can be restored.
    func delete(_ url: URL) {
        do {
            try FileManager.default.createDirectory(at: Self.deletedFolder, withIntermediateDirectories: true)
            let destination = NoteStore.uniqueURL(
                base: url.deletingPathExtension().lastPathComponent,
                ext: url.pathExtension,
                in: Self.deletedFolder
            )
            try FileManager.default.moveItem(at: url, to: destination)
            if url.standardizedFileURL == fileURL?.standardizedFileURL { reset() }
        } catch {
            errorMessage = error.localizedDescription
        }
        refreshNotes()
    }

    func refreshNotes() {
        notes = NoteStore.listNotes()
    }

    func save() {
        saveTask?.cancel()
        guard isDirty else { return }
        guard fileURL != nil || hasText else {
            isDirty = false
            return
        }

        do {
            try NoteStore.ensureFolder()
            let target = targetURL()
            if let fileURL, target != fileURL {
                try FileManager.default.moveItem(at: fileURL, to: target)
                self.fileURL = target
            }
            try text.write(to: target, atomically: true, encoding: .utf8)
            fileURL = target
            isDirty = false
            UserDefaults.standard.set(target.lastPathComponent, forKey: Self.lastNoteKey)
            refreshNotes()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Picks the file to write. New notes are Markdown; existing files keep their extension.
    /// While a note is still named after its first line, the name follows edits to that line.
    private func targetURL() -> URL {
        guard let fileURL else {
            return NoteStore.uniqueURL(base: NoteStore.suggestedName(for: text), ext: "md", in: NoteStore.folder)
        }
        let ext = fileURL.pathExtension
        let currentBase = fileURL.deletingPathExtension().lastPathComponent
        let base = namesFromFirstLine && hasText ? NoteStore.suggestedName(for: text) : currentBase
        return NoteStore.uniqueURL(base: base, ext: ext, in: fileURL.deletingLastPathComponent(), excluding: fileURL)
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: Self.saveDelay)
            guard !Task.isCancelled else { return }
            self?.save()
        }
    }

    private func load(_ url: URL) throws {
        var encoding = String.Encoding.utf8
        let loaded = try String(contentsOf: url, usedEncoding: &encoding)
        saveTask?.cancel()
        text = loaded
        fileURL = url
        isPreviewing = false
        isDirty = false
        namesFromFirstLine = Self.isNamedAfterFirstLine(url, text: loaded)
        UserDefaults.standard.set(url.lastPathComponent, forKey: Self.lastNoteKey)
    }

    private func reset() {
        saveTask?.cancel()
        text = ""
        fileURL = nil
        isPreviewing = false
        isDirty = false
        namesFromFirstLine = true
        UserDefaults.standard.removeObject(forKey: Self.lastNoteKey)
    }

    /// True for "Groceries.txt" or "Groceries 2.txt" when the first line is "Groceries".
    private static func isNamedAfterFirstLine(_ url: URL, text: String) -> Bool {
        let base = url.deletingPathExtension().lastPathComponent
        let suggested = NoteStore.suggestedName(for: text)
        if base == suggested { return true }
        guard base.hasPrefix(suggested + " ") else { return false }
        return Int(base.dropFirst(suggested.count + 1)) != nil
    }
}
