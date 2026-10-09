import SwiftUI

/// A sheet that lists saved notes, newest first. Tap to open; swipe left to delete.
/// Close it with the three-lines button, a downward drag, or a tap on the note above.
struct NotesDrawer: View {
    let notes: [NoteFile]
    let currentURL: URL?
    let onOpen: (URL) -> Void
    let onDelete: (URL) -> Void
    let onNew: () -> Void
    let onClose: () -> Void

    @State private var dragOffset: CGFloat = 0
    private static let shape = UnevenRoundedRectangle(topLeadingRadius: 16, topTrailingRadius: 16)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .contentShape(Rectangle())
                .gesture(
                    // Measured against the screen: the header moves with the drag, so local coordinates feed back and jitter.
                    DragGesture(coordinateSpace: .global)
                        .onChanged { dragOffset = max(0, $0.translation.height) }
                        .onEnded { value in
                            if value.predictedEndTranslation.height > 120 {
                                onClose()
                            } else {
                                withAnimation(.easeOut(duration: 0.2)) { dragOffset = 0 }
                            }
                        }
                )

            if notes.isEmpty {
                Text("No notes yet.\nJot saves as you type.")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
                Spacer()
            } else {
                List(notes, id: \.url) { note in
                    row(for: note)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .background {
            Self.shape
                .fill(Theme.drawer)
                .stroke(.white.opacity(0.08))
                .ignoresSafeArea(edges: .bottom)
        }
        .offset(y: dragOffset)
    }

    private var header: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(.white.opacity(0.18))
                .frame(width: 36, height: 5)
                .padding(.top, 6)
            HStack(alignment: .center, spacing: 8) {
                Text("Notes")
                    .font(.system(size: 15, weight: .semibold))
                Text("On My iPhone › Jot")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Spacer()
                FaintButton(symbol: "square.and.pencil", label: "New note", action: onNew)
                FaintButton(symbol: "line.3.horizontal", label: "Close notes", isActive: true, action: onClose)
            }
            .padding(.leading, 20)
            .padding(.trailing, 6)
        }
    }

    private func row(for note: NoteFile) -> some View {
        let isCurrent = note.url.standardizedFileURL == currentURL?.standardizedFileURL
        return Button {
            onOpen(note.url)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(note.name)
                    .font(.system(size: 15))
                    .lineLimit(1)
                Text("\(note.modified.formatted(.relative(presentation: .named))) · \(note.url.pathExtension)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(
            RoundedRectangle(cornerRadius: 8)
                .fill(.white.opacity(isCurrent ? 0.08 : 0))
                .padding(.horizontal, 10)
        )
        .listRowSeparator(.hidden)
        .swipeActions {
            Button(role: .destructive) {
                onDelete(note.url)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}
