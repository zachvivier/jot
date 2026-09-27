import AppKit

final class NoteWindowController: NSWindowController, NSWindowDelegate, NSTextViewDelegate, NSMenuItemValidation, NSSharingServicePickerDelegate {
    private static var cascadePoint = NSPoint.zero
    private static let editorFont = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
    private static let inset = NSSize(width: 28, height: 22)
    private static let barHeight: CGFloat = 30
    private static let minimumTextWidth: CGFloat = 320
    static let sidebarWidth: CGFloat = 250

    private enum SidebarPanel { case notes, help }

    private(set) var fileURL: URL?
    private(set) var isDirty = false {
        didSet { window?.isDocumentEdited = isDirty }
    }
    private var isMarkdown = false
    private var isPreviewing = false
    private var activePanel: SidebarPanel?
    private var panelLeading: [SidebarPanel: NSLayoutConstraint] = [:]
    private var panelTransition = 0

    private let editorScroll = NSTextView.scrollableTextView()
    private let previewScroll = NSTextView.scrollableTextView()
    private var editor: NSTextView { editorScroll.documentView as! NSTextView }
    private var preview: NSTextView { previewScroll.documentView as! NSTextView }

    private let sidebar = NSVisualEffectView()
    private let helpPanel = HelpPanelView()
    private let notesPanel = NotesListView()
    private var sidebarWidthConstraint: NSLayoutConstraint!
    private lazy var notesButton = FaintButton(symbol: "sidebar.right", label: "Notes (⌃⌘S)", target: self, action: #selector(toggleNotes(_:)))
    private lazy var shareButton = FaintButton(symbol: "square.and.arrow.up", label: "Share", target: self, action: #selector(shareNote(_:)))
    private lazy var helpButton = FaintButton(symbol: "gearshape", label: "Shortcuts (⌘/)", target: self, action: #selector(toggleHelp(_:)))

    var onClose: ((NoteWindowController) -> Void)?
    var onOpenRequest: ((URL) -> Void)?

    var isEmptyUntitled: Bool {
        fileURL == nil && !isDirty && editor.string.isEmpty
    }

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 560),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.minSize = NSSize(width: 360, height: 240)
        window.titlebarAppearsTransparent = true
        window.backgroundColor = .textBackgroundColor
        window.isReleasedWhenClosed = false
        super.init(window: window)

        window.delegate = self
        configureViews(in: window)
        configureSidebar(in: window.contentView!)
        notesPanel.onOpen = { [weak self] url in self?.onOpenRequest?(url) }
        notesPanel.onDelete = { [weak self] url in self?.trash(url) }
        NotificationCenter.default.addObserver(self, selector: #selector(notesDidChange(_:)), name: NoteStore.didChange, object: nil)
        window.center()
        Self.cascadePoint = window.cascadeTopLeft(from: Self.cascadePoint)
        updateTitle()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    private func configureViews(in window: NSWindow) {
        let container = NSView(frame: window.contentLayoutRect)
        for scroll in [editorScroll, previewScroll] {
            scroll.translatesAutoresizingMaskIntoConstraints = false
            scroll.drawsBackground = true
            scroll.backgroundColor = .textBackgroundColor
            scroll.hasVerticalScroller = true
            scroll.autohidesScrollers = true
            container.addSubview(scroll)
        }
        window.contentView = container

        let paragraph = NSMutableParagraphStyle()
        paragraph.lineHeightMultiple = 1.2

        editor.delegate = self
        editor.isRichText = false
        editor.importsGraphics = false
        editor.allowsUndo = true
        editor.usesFindBar = true
        editor.isIncrementalSearchingEnabled = true
        editor.isAutomaticQuoteSubstitutionEnabled = false
        editor.isAutomaticDashSubstitutionEnabled = false
        editor.isAutomaticTextReplacementEnabled = false
        editor.isAutomaticSpellingCorrectionEnabled = false
        editor.isContinuousSpellCheckingEnabled = true
        editor.textContainerInset = Self.inset
        editor.font = Self.editorFont
        editor.defaultParagraphStyle = paragraph
        editor.typingAttributes = [
            .font: Self.editorFont,
            .foregroundColor: NSColor.textColor,
            .paragraphStyle: paragraph,
        ]

        preview.isEditable = false
        preview.isSelectable = true
        preview.textContainerInset = Self.inset
        previewScroll.isHidden = true

        window.initialFirstResponder = editor
    }

    /// Lays out the text area, the right-hand sidebar, and the bottom strip that holds the two faint buttons.
    private func configureSidebar(in container: NSView) {
        sidebar.material = .sidebar
        sidebar.blendingMode = .withinWindow
        sidebar.state = .followsWindowActiveState
        sidebar.wantsLayer = true
        sidebar.layer?.masksToBounds = true
        sidebar.isHidden = true
        sidebar.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(sidebar)

        let separator = NSBox()
        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        sidebar.addSubview(separator)

        for kind in [SidebarPanel.help, .notes] {
            let panel = view(for: kind)
            let leading = panel.leadingAnchor.constraint(equalTo: sidebar.leadingAnchor)
            panelLeading[kind] = leading
            sidebar.addSubview(panel)
            NSLayoutConstraint.activate([
                panel.topAnchor.constraint(equalTo: sidebar.topAnchor),
                leading,
                panel.widthAnchor.constraint(equalToConstant: Self.sidebarWidth),
                panel.bottomAnchor.constraint(equalTo: sidebar.bottomAnchor, constant: -Self.barHeight),
            ])
        }

        container.addSubview(shareButton)
        container.addSubview(notesButton)
        container.addSubview(helpButton)

        sidebarWidthConstraint = sidebar.widthAnchor.constraint(equalToConstant: 0)
        var constraints = [
            sidebar.topAnchor.constraint(equalTo: container.topAnchor),
            sidebar.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            sidebar.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            sidebarWidthConstraint!,
            separator.topAnchor.constraint(equalTo: sidebar.topAnchor),
            separator.bottomAnchor.constraint(equalTo: sidebar.bottomAnchor),
            separator.leadingAnchor.constraint(equalTo: sidebar.leadingAnchor),
            separator.widthAnchor.constraint(equalToConstant: 1),
            helpButton.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            helpButton.centerYAnchor.constraint(equalTo: container.bottomAnchor, constant: -Self.barHeight / 2),
            notesButton.trailingAnchor.constraint(equalTo: helpButton.leadingAnchor, constant: -10),
            notesButton.centerYAnchor.constraint(equalTo: helpButton.centerYAnchor),
            shareButton.trailingAnchor.constraint(equalTo: notesButton.leadingAnchor, constant: -10),
            shareButton.centerYAnchor.constraint(equalTo: helpButton.centerYAnchor),
        ]
        for scroll in [editorScroll, previewScroll] {
            constraints += [
                scroll.topAnchor.constraint(equalTo: container.topAnchor),
                scroll.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                scroll.trailingAnchor.constraint(equalTo: sidebar.leadingAnchor),
                scroll.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -Self.barHeight),
            ]
        }
        NSLayoutConstraint.activate(constraints)
    }

    // MARK: - Loading and saving

    func load(_ url: URL) throws {
        var encoding = String.Encoding.utf8
        let text = try String(contentsOf: url, usedEncoding: &encoding)
        editor.string = text
        editor.undoManager?.removeAllActions()
        editor.setSelectedRange(NSRange(location: 0, length: 0))
        fileURL = url
        isMarkdown = ["md", "markdown"].contains(url.pathExtension.lowercased())
        isDirty = false
        setPreviewing(false)
        updateTitle()
    }

    @discardableResult
    private func save() -> Bool {
        let ext = isMarkdown ? "md" : "txt"
        let fileManager = FileManager.default

        do {
            let target: URL
            if let current = fileURL {
                if current.pathExtension.lowercased() == ext || !NoteStore.noteExtensions.contains(current.pathExtension.lowercased()) {
                    target = current
                } else {
                    let renamed = NoteStore.uniqueURL(
                        base: current.deletingPathExtension().lastPathComponent,
                        ext: ext,
                        in: current.deletingLastPathComponent()
                    )
                    try fileManager.moveItem(at: current, to: renamed)
                    target = renamed
                }
            } else {
                try NoteStore.ensureFolder()
                target = NoteStore.uniqueURL(base: NoteStore.suggestedName(for: editor.string), ext: ext, in: NoteStore.folder)
            }

            try editor.string.write(to: target, atomically: true, encoding: .utf8)
            fileURL = target
            isDirty = false
            updateTitle()
            NotificationCenter.default.post(name: NoteStore.didChange, object: self)
            return true
        } catch {
            if let window { NSAlert(error: error).beginSheetModal(for: window) }
            return false
        }
    }

    /// Asks what to do with unsaved changes. Calls back with `true` when it is safe to close.
    func confirmClose(then completion: @escaping (Bool) -> Void) {
        guard isDirty, let window else { return completion(true) }
        window.makeKeyAndOrderFront(nil)

        let alert = NSAlert()
        alert.messageText = "Save changes to “\(fileURL?.lastPathComponent ?? "Untitled")”?"
        alert.informativeText = fileURL == nil
            ? "New notes are saved to ~/notes."
            : "Your changes will be lost if you don't save them."
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: "Don't Save")

        alert.beginSheetModal(for: window) { response in
            switch response {
            case .alertFirstButtonReturn: completion(self.save())
            case .alertThirdButtonReturn: completion(true)
            default: completion(false)
            }
        }
    }

    // MARK: - Actions

    @objc func deleteNote(_ sender: Any?) {
        guard let fileURL else { return NSSound.beep() }
        trash(fileURL)
    }

    /// Moves the file to the Trash without asking. Windows showing it react in `notesDidChange`.
    private func trash(_ url: URL) {
        do {
            try FileManager.default.trashItem(at: url, resultingItemURL: nil)
            NotificationCenter.default.post(name: NoteStore.didChange, object: self, userInfo: [NoteStore.trashedKey: url])
        } catch {
            if let window { NSAlert(error: error).beginSheetModal(for: window) }
        }
    }

    private func resetToBlank() {
        editor.string = ""
        editor.undoManager?.removeAllActions()
        fileURL = nil
        isMarkdown = false
        isDirty = false
        setPreviewing(false)
        updateTitle()
    }

    @objc func saveNote(_ sender: Any?) {
        save()
    }

    @objc func toggleMarkdown(_ sender: Any?) {
        isMarkdown.toggle()
        if !isMarkdown { setPreviewing(false) }
        if fileURL != nil { isDirty = true }
        updateTitle()
    }

    @objc func togglePreview(_ sender: Any?) {
        guard isMarkdown else { return NSSound.beep() }
        setPreviewing(!isPreviewing)
    }

    @objc func toggleNotes(_ sender: Any?) {
        setPanel(activePanel == .notes ? nil : .notes)
    }

    @objc func toggleHelp(_ sender: Any?) {
        setPanel(activePanel == .help ? nil : .help)
    }

    /// Shows the system share menu (Mail, Messages, and so on) for the note's text, plus a Copy item.
    @objc func shareNote(_ sender: Any?) {
        guard !editor.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return NSSound.beep() }
        let picker = NSSharingServicePicker(items: [editor.string])
        picker.delegate = self
        picker.show(relativeTo: shareButton.bounds, of: shareButton, preferredEdge: .maxY)
    }

    func sharingServicePicker(
        _ picker: NSSharingServicePicker,
        sharingServicesForItems items: [Any],
        proposedSharingServices proposed: [NSSharingService]
    ) -> [NSSharingService] {
        let text = items.first as? String ?? ""
        let copy = NSSharingService(
            title: "Copy",
            image: NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: "Copy")!,
            alternateImage: nil
        ) {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
        }
        return [copy] + proposed
    }

    func sharingServicePicker(_ picker: NSSharingServicePicker, didChoose service: NSSharingService?) {
        service?.subject = fileURL?.deletingPathExtension().lastPathComponent ?? NoteStore.suggestedName(for: editor.string)
    }

    override func cancelOperation(_ sender: Any?) {
        if isPreviewing {
            setPreviewing(false)
        } else if activePanel != nil {
            setPanel(nil)
        }
    }

    private func setPanel(_ panel: SidebarPanel?) {
        guard panel != activePanel else { return }
        let previous = activePanel
        activePanel = panel
        notesButton.isActive = panel == .notes
        helpButton.isActive = panel == .help

        guard let panel else { return animateSidebar(open: false) }
        if panel == .notes { notesPanel.reload() }
        if let previous {
            switchPanel(from: previous, to: panel)
        } else {
            showOnly(panel)
            animateSidebar(open: true)
        }
    }

    private func view(for panel: SidebarPanel) -> NSView {
        panel == .notes ? notesPanel : helpPanel
    }

    private func showOnly(_ panel: SidebarPanel) {
        panelTransition += 1
        for kind in [SidebarPanel.help, .notes] {
            view(for: kind).isHidden = kind != panel
            view(for: kind).alphaValue = 1
            panelLeading[kind]?.constant = 0
        }
    }

    /// Crossfades between panels with a short slide. Help sits to the right of Notes, matching the buttons.
    private func switchPanel(from old: SidebarPanel, to new: SidebarPanel) {
        panelTransition += 1
        let transition = panelTransition
        let shift: CGFloat = new == .help ? 24 : -24
        let incoming = view(for: new)
        let outgoing = view(for: old)

        incoming.alphaValue = 0
        incoming.isHidden = false
        panelLeading[new]?.constant = shift
        sidebar.layoutSubtreeIfNeeded()

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.22
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            incoming.animator().alphaValue = 1
            outgoing.animator().alphaValue = 0
            panelLeading[new]?.animator().constant = 0
            panelLeading[old]?.animator().constant = -shift
        }, completionHandler: { [weak self] in
            guard let self, self.panelTransition == transition else { return }
            outgoing.isHidden = true
            outgoing.alphaValue = 1
            self.panelLeading[old]?.constant = 0
        })
    }

    /// Slides the sidebar in or out. The text area narrows to make room, so nothing is covered.
    private func animateSidebar(open: Bool) {
        guard let window else { return }
        let openMinimum = Self.minimumTextWidth + Self.sidebarWidth

        if open {
            sidebar.isHidden = false
            let shortfall = openMinimum - window.contentLayoutRect.width
            if shortfall > 0 {
                var frame = window.frame
                frame.size.width += shortfall
                if let screen = window.screen?.visibleFrame, frame.maxX > screen.maxX {
                    frame.origin.x = max(screen.minX, screen.maxX - frame.width)
                }
                window.setFrame(frame, display: true, animate: true)
            }
        } else if let responder = window.firstResponder as? NSView, responder.isDescendant(of: sidebar) {
            window.makeFirstResponder(isPreviewing ? preview : editor)
        }
        window.minSize = NSSize(width: open ? openMinimum : 360, height: 240)

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.22
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            sidebarWidthConstraint.animator().constant = open ? Self.sidebarWidth : 0
        }, completionHandler: { [weak self] in
            guard let self, self.activePanel == nil else { return }
            self.sidebar.isHidden = true
        })
    }

    /// Refreshes the drawer. If this window's note was trashed, clears it, or keeps any unsaved edits as an untitled note.
    @objc private func notesDidChange(_ notification: Notification) {
        if let trashed = notification.userInfo?[NoteStore.trashedKey] as? URL,
           trashed.standardizedFileURL == fileURL?.standardizedFileURL {
            if isDirty {
                fileURL = nil
                updateTitle()
            } else {
                resetToBlank()
            }
        }
        reloadNotesIfShown()
    }

    private func reloadNotesIfShown() {
        if activePanel == .notes { notesPanel.reload() }
    }

    private func setPreviewing(_ previewing: Bool) {
        isPreviewing = previewing
        if previewing {
            preview.textStorage?.setAttributedString(MarkdownRenderer.render(editor.string))
            preview.scrollToBeginningOfDocument(nil)
        }
        previewScroll.isHidden = !previewing
        editorScroll.isHidden = previewing
        window?.makeFirstResponder(previewing ? preview : editor)
        updateTitle()
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.action {
        case #selector(toggleMarkdown(_:)):
            menuItem.state = isMarkdown ? .on : .off
            return true
        case #selector(togglePreview(_:)):
            menuItem.state = isPreviewing ? .on : .off
            return isMarkdown
        case #selector(toggleNotes(_:)):
            menuItem.state = activePanel == .notes ? .on : .off
            return true
        case #selector(deleteNote(_:)):
            return fileURL != nil
        case #selector(toggleHelp(_:)):
            menuItem.state = activePanel == .help ? .on : .off
            return true
        default:
            return true
        }
    }

    private func updateTitle() {
        guard let window else { return }
        window.title = fileURL?.lastPathComponent ?? "Untitled"
        window.representedURL = fileURL
        notesPanel.currentURL = fileURL
        var subtitle = isMarkdown ? "Markdown" : "Plain text"
        if isPreviewing { subtitle += " · Preview" }
        window.subtitle = subtitle
    }

    // MARK: - Delegates

    func textDidChange(_ notification: Notification) {
        isDirty = true
    }

    func windowDidBecomeKey(_ notification: Notification) {
        reloadNotesIfShown()
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard isDirty else { return true }
        confirmClose { canClose in
            if canClose {
                self.isDirty = false
                sender.close()
            }
        }
        return false
    }

    func windowWillClose(_ notification: Notification) {
        onClose?(self)
    }
}
