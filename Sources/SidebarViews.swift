import AppKit

/// A borderless icon button that stays faint until hovered or active.
final class FaintButton: NSButton {
    var isActive = false {
        didSet { updateTint() }
    }
    private var isHovering = false

    init(symbol: String, label: String, target: AnyObject, action: Selector) {
        super.init(frame: .zero)
        image = NSImage(systemSymbolName: symbol, accessibilityDescription: label)
        symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 13, weight: .regular)
        imagePosition = .imageOnly
        isBordered = false
        toolTip = label
        self.target = target
        self.action = action
        translatesAutoresizingMaskIntoConstraints = false
        updateTint()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect], owner: self))
    }

    override func mouseEntered(with event: NSEvent) {
        isHovering = true
        updateTint()
    }

    override func mouseExited(with event: NSEvent) {
        isHovering = false
        updateTint()
    }

    private func updateTint() {
        contentTintColor = isActive || isHovering ? .secondaryLabelColor : .tertiaryLabelColor
    }
}

private func label(_ text: String, size: CGFloat = 12, weight: NSFont.Weight = .regular, color: NSColor = .labelColor) -> NSTextField {
    let field = NSTextField(labelWithString: text)
    field.font = .systemFont(ofSize: size, weight: weight)
    field.textColor = color
    field.lineBreakMode = .byTruncatingTail
    field.translatesAutoresizingMaskIntoConstraints = false
    return field
}

// MARK: - Help

/// Explains the shortcuts and the two bottom-bar buttons.
final class HelpPanelView: NSView {
    private static let shortcuts: [(String, String)] = [
        ("⌘S", "Save to ~/notes"),
        ("⌘N", "New note"),
        ("⌘O", "Open a note"),
        ("⇧⌘O", "Show notes folder"),
        ("⇧⌘M", "Markdown on / off"),
        ("⌘P", "Preview Markdown"),
        ("esc", "Leave preview"),
        ("⌘F", "Find"),
        ("⌃⌘S", "Notes drawer"),
        ("⌘/", "This panel"),
        ("⌘W", "Close note"),
    ]

    override init(frame: NSRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false

        let rows = Self.shortcuts.map { key, action in
            [label(key, weight: .medium, color: .secondaryLabelColor), label(action)]
        }
        let grid = NSGridView(views: rows)
        grid.rowSpacing = 7
        grid.columnSpacing = 12
        grid.column(at: 0).width = 40

        let buttons = NSGridView(views: [
            [symbol("xmark"), label("Delete: hover a note")],
            [symbol("square.and.arrow.up"), label("Share or copy")],
            [symbol("sidebar.right"), label("Notes drawer")],
            [symbol("gearshape"), label("Shortcuts and help")],
        ])
        buttons.rowSpacing = 7
        buttons.columnSpacing = 12
        buttons.column(at: 0).width = 40

        let about = label(
            "Nothing is saved until you press ⌘S. New notes are named after their first line. Markdown notes save as .md, plain notes as .txt.",
            size: 11,
            color: .secondaryLabelColor
        )
        about.lineBreakMode = .byWordWrapping
        about.preferredMaxLayoutWidth = NoteWindowController.sidebarWidth - 40

        let stack = NSStackView(views: [
            label("Shortcuts", size: 13, weight: .semibold), grid,
            label("Buttons", size: 13, weight: .semibold), buttons,
            about,
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.setCustomSpacing(22, after: grid)
        stack.setCustomSpacing(22, after: buttons)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 18),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -20),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    private func symbol(_ name: String) -> NSImageView {
        let view = NSImageView(image: NSImage(systemSymbolName: name, accessibilityDescription: nil)!)
        view.contentTintColor = .secondaryLabelColor
        return view
    }
}

// MARK: - Notes list

/// Lists the notes folder, newest first. A click opens the note; the X that appears on hover deletes it.
final class NotesListView: NSView, NSTableViewDataSource, NSTableViewDelegate {
    var onOpen: ((URL) -> Void)?
    var onDelete: ((URL) -> Void)?
    var currentURL: URL? {
        didSet { highlightCurrent() }
    }

    private var notes: [NoteFile] = []
    private let table = NSTableView()
    private let emptyLabel = label("No notes yet.\nPress ⌘S to save one.", color: .tertiaryLabelColor)
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        formatter.doesRelativeDateFormatting = true
        return formatter
    }()

    override init(frame: NSRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false

        let title = label("Notes", size: 13, weight: .semibold)
        let path = label("~/notes", size: 11, color: .tertiaryLabelColor)

        table.addTableColumn(NSTableColumn(identifier: .init("note")))
        table.headerView = nil
        table.style = .inset
        table.rowHeight = 40
        table.backgroundColor = .clear
        table.dataSource = self
        table.delegate = self
        table.target = self
        table.action = #selector(rowClicked)

        let scroll = NSScrollView()
        scroll.documentView = table
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.translatesAutoresizingMaskIntoConstraints = false

        emptyLabel.alignment = .center
        emptyLabel.maximumNumberOfLines = 2

        [title, path, scroll, emptyLabel].forEach(addSubview)
        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: topAnchor, constant: 18),
            title.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            path.firstBaselineAnchor.constraint(equalTo: title.firstBaselineAnchor),
            path.leadingAnchor.constraint(equalTo: title.trailingAnchor, constant: 8),
            scroll.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 8),
            scroll.leadingAnchor.constraint(equalTo: leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: bottomAnchor),
            emptyLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            emptyLabel.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 40),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    func reload() {
        notes = NoteStore.listNotes()
        table.reloadData()
        emptyLabel.isHidden = !notes.isEmpty
        highlightCurrent()
    }

    private func highlightCurrent() {
        let target = currentURL?.standardizedFileURL
        if let row = notes.firstIndex(where: { $0.url.standardizedFileURL == target }) {
            table.selectRowIndexes([row], byExtendingSelection: false)
        } else {
            table.deselectAll(nil)
        }
    }

    @objc private func rowClicked() {
        guard notes.indices.contains(table.clickedRow) else { return }
        onOpen?(notes[table.clickedRow].url)
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        notes.count
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        NoteRowBackground()
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cell = tableView.makeView(withIdentifier: NoteRowView.identifier, owner: self) as? NoteRowView ?? NoteRowView()
        let note = notes[row]
        cell.title.stringValue = note.name
        cell.detail.stringValue = "\(dateFormatter.string(from: note.modified)) · \(note.url.pathExtension)"
        cell.onDelete = { [weak self] in self?.onDelete?(note.url) }
        return cell
    }
}

/// Marks the open note with a soft highlight that looks the same whether or not the list has focus.
private final class NoteRowBackground: NSTableRowView {
    override var isEmphasized: Bool {
        get { false }
        set {}
    }

    override func drawSelection(in dirtyRect: NSRect) {
        NSColor.labelColor.withAlphaComponent(0.08).setFill()
        NSBezierPath(roundedRect: bounds.insetBy(dx: 10, dy: 2), xRadius: 6, yRadius: 6).fill()
    }
}

private final class NoteRowView: NSTableCellView {
    static let identifier = NSUserInterfaceItemIdentifier("NoteRow")
    let title = label("", size: 13)
    let detail = label("", size: 11, color: .secondaryLabelColor)
    var onDelete: (() -> Void)?
    private lazy var deleteButton = FaintButton(symbol: "xmark", label: "Move to Trash", target: self, action: #selector(deleteClicked))

    init() {
        super.init(frame: .zero)
        identifier = Self.identifier
        deleteButton.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 10, weight: .semibold)
        deleteButton.isHidden = true
        addSubview(title)
        addSubview(detail)
        addSubview(deleteButton)
        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            title.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            title.trailingAnchor.constraint(lessThanOrEqualTo: deleteButton.leadingAnchor, constant: -6),
            detail.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 1),
            detail.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            detail.trailingAnchor.constraint(lessThanOrEqualTo: deleteButton.leadingAnchor, constant: -6),
            deleteButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            deleteButton.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect], owner: self))
    }

    override func mouseEntered(with event: NSEvent) {
        deleteButton.isHidden = false
    }

    override func mouseExited(with event: NSEvent) {
        deleteButton.isHidden = true
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        deleteButton.isHidden = true
    }

    @objc private func deleteClicked() {
        onDelete?()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }
}
