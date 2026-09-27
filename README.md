# Jot

A small, minimal plain-text editor for macOS. Think TextEdit without the formatting toolbar and without the save dialog.

![Jot editing a Markdown note with the notes drawer open](docs/editor.png)

![The same note in Markdown preview with the shortcuts panel open](docs/preview.png)

- Notes open as plain text. Turn on Markdown per note and preview it with ⌘P.
- Nothing is saved until you press ⌘S. The first save goes straight to `~/notes`, which Jot creates if it does not exist. There is no save dialog.
- Each note is named after its first line, for example `Grocery list.txt`. A blank note gets a timestamp name.
- A drawer lists the notes in `~/notes`, newest first. Click one to open it.
- Share a note by Mail, Messages, or any other macOS share option, or copy it.
- Hover over a note in the drawer and click its X to move it to the Trash. There is no prompt; restore it from the Trash if needed. Unsaved edits in an open window are kept as an untitled note.
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

The three faint icons at the bottom right share the note, open the notes drawer, and open the shortcuts panel.

## Build and install

Runs on macOS 14 or later on Apple silicon. Building needs Xcode 26 or later, which compiles the layered app icon. The Command Line Tools alone are not enough.

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
| `AppIcon.icon` | Layered app icon with light and dark variants. Open it in Icon Composer to edit. |
| `build.sh` | Compiles and bundles `Jot.app` |

## Known limits

The preview uses Apple's Markdown parser. Horizontal rules and task-list checkboxes are not rendered, and tables show as simple tab-aligned columns.

## License

[MIT](LICENSE)
