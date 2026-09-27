# Jot

A small, minimal plain-text editor for macOS. Think TextEdit without the formatting toolbar and without the save dialog.

- Notes open as plain text. Turn on Markdown per note and preview it with ⌘P.
- Nothing is saved until you press ⌘S. The first save goes straight to `~/notes`, which Jot creates if it does not exist. There is no save dialog.
- Each note is named after its first line, for example `Grocery list.txt`. A blank note gets a timestamp name.
- A drawer lists the notes in `~/notes`, newest first. Click one to open it.
- Native AppKit app, no dependencies. Markdown is rendered with Apple's built-in parser.

## Shortcuts

| Keys | Action |
| --- | --- |
| ⌘S | Save to `~/notes` |
| ⌘N | New note |
| ⌘O | Open a note |
| ⇧⌘O | Show the notes folder in Finder |
| ⇧⌘M | Markdown on / off (saves as `.md` or `.txt`) |
| ⌘P | Preview Markdown |
| esc | Leave preview, or close the sidebar |
| ⌘F | Find |
| ⌃⌘S | Notes drawer |
| ⌘/ | Shortcuts panel |
| ⌘W | Close note |

The two faint icons at the bottom right open the notes drawer and the shortcuts panel.

## Build and install

Requires macOS 14 or later on Apple silicon, and Xcode or the Xcode Command Line Tools (`xcode-select --install`).

```sh
git clone https://github.com/zachvivier/jot.git
cd jot
./build.sh            # builds build/Jot.app
./build.sh --install  # also copies it to ~/Applications
```

To keep it in the Dock, open Jot, right-click its Dock icon, and choose **Options → Keep in Dock**.

The build is ad-hoc signed, not notarized. A copy you build yourself runs normally. If you copy a built app from another Mac, macOS may block it the first time. Right-click the app and choose **Open** to allow it.

## Project layout

| Path | Purpose |
| --- | --- |
| `Sources/AppDelegate.swift` | App lifecycle, menus, opening files |
| `Sources/NoteWindowController.swift` | Editor window, saving, preview, sidebar |
| `Sources/SidebarViews.swift` | Notes drawer, shortcuts panel, bottom buttons |
| `Sources/MarkdownRenderer.swift` | Markdown to styled text for the preview |
| `Sources/NoteStore.swift` | `~/notes` folder, file naming, note listing |
| `make-icon.swift` | Draws the app icon at build time |
| `build.sh` | Compiles and bundles `Jot.app` |

## Known limits

The preview uses Apple's Markdown parser. Horizontal rules and task-list checkboxes are not rendered, and tables show as simple tab-aligned columns.

## License

[MIT](LICENSE)
