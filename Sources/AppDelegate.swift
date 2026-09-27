import AppKit
import UniformTypeIdentifiers

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controllers: [NoteWindowController] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = buildMainMenu()
        DispatchQueue.main.async {
            if self.controllers.isEmpty { self.newNote(nil) }
            NSApp.activate()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { newNote(nil) }
        return true
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        urls.forEach { open($0) }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        let unsaved = controllers.filter(\.isDirty)
        guard !unsaved.isEmpty else { return .terminateNow }
        reviewUnsaved(unsaved[...])
        return .terminateLater
    }

    private func reviewUnsaved(_ remaining: ArraySlice<NoteWindowController>) {
        guard let next = remaining.first else {
            return NSApp.reply(toApplicationShouldTerminate: true)
        }
        next.confirmClose { canClose in
            if canClose {
                self.reviewUnsaved(remaining.dropFirst())
            } else {
                NSApp.reply(toApplicationShouldTerminate: false)
            }
        }
    }

    // MARK: - Windows

    @discardableResult
    private func makeController() -> NoteWindowController {
        let controller = NoteWindowController()
        controller.onClose = { [weak self] closed in
            self?.controllers.removeAll { $0 === closed }
        }
        controller.onOpenRequest = { [weak self, weak controller] url in
            self?.open(url, replacing: controller)
        }
        controllers.append(controller)
        return controller
    }

    @objc func newNote(_ sender: Any?) {
        makeController().showWindow(nil)
    }

    /// Opens `url`, reusing its window if it is already open. A clean `requester` window (the drawer's) loads the note in place.
    private func open(_ url: URL, replacing requester: NoteWindowController? = nil) {
        if let existing = controllers.first(where: { $0.fileURL?.standardizedFileURL == url.standardizedFileURL }) {
            existing.showWindow(nil)
            return
        }

        let reusable = requester.flatMap { $0.isDirty ? nil : $0 }
            ?? controllers.first { $0.window?.isKeyWindow == true && $0.isEmptyUntitled }
        let controller = reusable ?? makeController()
        do {
            try controller.load(url)
            controller.showWindow(nil)
            NSDocumentController.shared.noteNewRecentDocumentURL(url)
        } catch {
            if reusable == nil { controller.close() }
            NSAlert(error: error).runModal()
        }
    }

    @objc func openNote(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.plainText, UTType("net.daringfireball.markdown")].compactMap { $0 }
        if FileManager.default.fileExists(atPath: NoteStore.folder.path) {
            panel.directoryURL = NoteStore.folder
        }
        guard panel.runModal() == .OK else { return }
        panel.urls.forEach { open($0) }
    }

    @objc func openNotesFolder(_ sender: Any?) {
        do {
            try NoteStore.ensureFolder()
            NSWorkspace.shared.open(NoteStore.folder)
        } catch {
            NSAlert(error: error).runModal()
        }
    }

    // MARK: - Menu

    private func buildMainMenu() -> NSMenu {
        let main = NSMenu()

        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About Jot", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Hide Jot", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(item("Hide Others", #selector(NSApplication.hideOtherApplications(_:)), "h", [.command, .option]))
        appMenu.addItem(withTitle: "Show All", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit Jot", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        main.addItem(submenu(appMenu, title: "Jot"))

        let fileMenu = NSMenu(title: "File")
        fileMenu.addItem(withTitle: "New Note", action: #selector(newNote(_:)), keyEquivalent: "n")
        fileMenu.addItem(withTitle: "Open…", action: #selector(openNote(_:)), keyEquivalent: "o")
        fileMenu.addItem(item("Open Notes Folder", #selector(openNotesFolder(_:)), "o", [.command, .shift]))
        fileMenu.addItem(.separator())
        fileMenu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        fileMenu.addItem(withTitle: "Save", action: #selector(NoteWindowController.saveNote(_:)), keyEquivalent: "s")
        main.addItem(submenu(fileMenu, title: "File"))

        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(item("Redo", Selector(("redo:")), "z", [.command, .shift]))
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenu.addItem(.separator())
        editMenu.addItem(findItem("Find…", .showFindInterface, "f"))
        editMenu.addItem(findItem("Find and Replace…", .showReplaceInterface, "f", [.command, .option]))
        editMenu.addItem(findItem("Find Next", .nextMatch, "g"))
        editMenu.addItem(findItem("Find Previous", .previousMatch, "g", [.command, .shift]))
        main.addItem(submenu(editMenu, title: "Edit"))

        let viewMenu = NSMenu(title: "View")
        viewMenu.addItem(item("Markdown", #selector(NoteWindowController.toggleMarkdown(_:)), "m", [.command, .shift]))
        viewMenu.addItem(withTitle: "Preview", action: #selector(NoteWindowController.togglePreview(_:)), keyEquivalent: "p")
        viewMenu.addItem(.separator())
        viewMenu.addItem(item("Notes Drawer", #selector(NoteWindowController.toggleNotes(_:)), "s", [.command, .control]))
        viewMenu.addItem(withTitle: "Shortcuts", action: #selector(NoteWindowController.toggleHelp(_:)), keyEquivalent: "/")
        main.addItem(submenu(viewMenu, title: "View"))

        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: "Zoom", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        main.addItem(submenu(windowMenu, title: "Window"))
        NSApp.windowsMenu = windowMenu

        return main
    }

    private func submenu(_ menu: NSMenu, title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.submenu = menu
        return item
    }

    private func item(_ title: String, _ action: Selector, _ key: String, _ modifiers: NSEvent.ModifierFlags) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.keyEquivalentModifierMask = modifiers
        return item
    }

    private func findItem(_ title: String, _ action: NSTextFinder.Action, _ key: String, _ modifiers: NSEvent.ModifierFlags = .command) -> NSMenuItem {
        let item = item(title, #selector(NSTextView.performFindPanelAction(_:)), key, modifiers)
        item.tag = action.rawValue
        return item
    }
}
