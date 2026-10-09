import SwiftUI

/// The single editing screen: text fills the page, a faint strip at the bottom holds the controls,
/// and the notes drawer slides up from the bottom.
struct NoteScreen: View {
    @State private var model = NoteModel()
    @State private var showsNotes = false
    @State private var focusRequest = 0
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    page
                    bottomBar
                }
                .background(Theme.background.ignoresSafeArea())

                if showsNotes {
                    Color.black.opacity(0.25)
                        .ignoresSafeArea()
                        .onTapGesture { returnToNote() }
                        .transition(.opacity)

                    NotesDrawer(
                        notes: model.notes,
                        currentURL: model.fileURL,
                        onOpen: { url in
                            model.open(url)
                            setNotes(false)
                        },
                        onDelete: model.delete,
                        onNew: newNote,
                        onClose: returnToNote
                    )
                    .frame(height: geometry.size.height * 0.55)
                    .transition(.move(edge: .bottom))
                }
            }
        }
        .onAppear {
            if !model.hasText { focusRequest += 1 }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { model.save() }
        }
        .alert("Jot couldn't save", isPresented: hasError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.errorMessage ?? "")
        }
    }

    /// The editor stays in place while previewing, so the cursor and scroll position survive.
    private var page: some View {
        ZStack {
            EditorView(text: Binding(get: { model.text }, set: model.edit), focusRequest: focusRequest)
                .opacity(model.isPreviewing ? 0 : 1)
                .allowsHitTesting(!model.isPreviewing)
                .accessibilityHidden(model.isPreviewing)
            if model.isPreviewing {
                PreviewView(source: model.text)
            }
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 0) {
            Text(model.title)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .truncationMode(.middle)
                .padding(.leading, 20)
            Spacer(minLength: 12)

            FaintButton(symbol: model.isPreviewing ? "eye.fill" : "eye", label: "Preview", isActive: model.isPreviewing, action: togglePreview)
                .keyboardShortcut("p")
            FaintButton(symbol: "square.and.arrow.up", label: "Share", action: share)
            FaintButton(symbol: "line.3.horizontal", label: "Notes", isActive: showsNotes) {
                setNotes(!showsNotes)
            }
            .keyboardShortcut("s", modifiers: [.control, .command])

            Menu {
                Button("New Note", systemImage: "square.and.pencil", action: newNote)
                    .keyboardShortcut("n")
                if let url = model.fileURL {
                    Button("Delete Note", systemImage: "trash", role: .destructive) {
                        model.delete(url)
                    }
                }
            } label: {
                FaintIcon(symbol: "ellipsis", isActive: false)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("More")
        }
        .padding(.trailing, 6)
        .frame(height: 40)
    }

    private var hasError: Binding<Bool> {
        Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })
    }

    private func setNotes(_ open: Bool) {
        if open {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            model.save()
            model.refreshNotes()
        }
        withAnimation(.easeInOut(duration: 0.22)) { showsNotes = open }
    }

    private func returnToNote() {
        setNotes(false)
        if !model.isPreviewing { focusRequest += 1 }
    }

    private func togglePreview() {
        if model.isPreviewing {
            model.isPreviewing = false
            focusRequest += 1
        } else {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            model.isPreviewing = true
        }
    }

    private func newNote() {
        model.newNote()
        setNotes(false)
        focusRequest += 1
    }

    private func share() {
        guard model.hasText else { return }
        model.save()
        let subject = model.fileURL?.deletingPathExtension().lastPathComponent ?? NoteStore.suggestedName(for: model.text)
        ShareSheet.present(NoteShareItem(text: model.text, fileURL: model.fileURL, subject: subject))
    }
}

/// An icon that stays faint until its panel or mode is active, like the Mac's bottom buttons.
struct FaintIcon: View {
    let symbol: String
    let isActive: Bool

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 15))
            .foregroundStyle(isActive ? .secondary : .tertiary)
            .frame(width: 40, height: 40)
            .contentShape(Rectangle())
    }
}

struct FaintButton: View {
    let symbol: String
    let label: String
    var isActive = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            FaintIcon(symbol: symbol, isActive: isActive)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
