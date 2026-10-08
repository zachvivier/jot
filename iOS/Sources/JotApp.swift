import SwiftUI

@main
struct JotApp: App {
    var body: some Scene {
        WindowGroup {
            NoteScreen()
                .preferredColorScheme(.dark)
                .tint(Color(uiColor: Theme.accentUIColor))
        }
    }
}

enum Theme {
    /// The Mac editor's dark background (#1E1E1E) and its slightly lighter sidebar.
    static let background = Color(white: 0.118)
    static let drawer = Color(red: 0.165, green: 0.165, blue: 0.172)
    /// The orange bar on the app icon.
    static let accentUIColor = UIColor(red: 0.949, green: 0.549, blue: 0.2, alpha: 1)
}
