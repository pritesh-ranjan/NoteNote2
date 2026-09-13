# NoteNote for Mac 📌

[![Platform](https://img.shields.io/badge/platform-macOS%2014.0%2B-blue.svg)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange.svg)](https://swift.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![CI Build](https://github.com/pritesh-ranjan/NoteNote2/actions/workflows/build.yml/badge.svg)](https://github.com/pritesh-ranjan/NoteNote2/actions)

A lightweight, native, and silky-smooth sticky notes app for macOS built with **Swift, SwiftUI, and AppKit**.

It lives directly in your menu bar with zero Dock clutter, stays visible above fullscreen apps, attaches notes to specific Mac apps, docks to screen edges, and protects private notes from screen shares.

---

## ✨ Features

- 📌 **Always on Top (Survives Fullscreen Apps)**: Floats above your workspace even when apps like Xcode, VS Code, Figma, or Safari enter fullscreen (`.floating` + `.canJoinAllSpaces`, `.fullScreenAuxiliary`).
- 🔗 **App-Aware Notes**: Link a note to any Mac app (e.g. Figma, Slack, Safari). The note appears automatically when that app becomes active and hides when you switch away without stealing focus.
- 🛡️ **Screen Sharing Privacy (Hide From Screen Capture)**: One-click privacy shield using AppKit's `window.sharingType = .none`. Private notes stay visible to you on screen, but remain 100% invisible in Zoom, Google Meet, Teams, screenshots, and screen recordings!
- ⭲ **Edge Dock**: Dock any note to the left or right display edge as a sleek, compact handle. Hover or click to reveal it smoothly.
- ⚡ **Quick Add Capture (`⌘⇧N`)**: Spotlight-style capture modal anywhere on your Mac. Type thoughts, pick a color, hit `Return` to save and dismiss, or `⌘Return` to open floating.
- 👁️ **Show / Hide All (`⌘⇧H`)**: Instantly toggle all stickies when you need a clear screen.
- 📝 **Live Markdown & Interactive Checklists**:
  - Interactive checkboxes (`- [ ]` / `- [x]`) that toggle on click with live progress tracking.
  - Headers, bold (`**`), italic (`*`), strikethrough (`~~`), code blocks (`` ` ``).
  - Quick formatting bar at the bottom with word and character counters.
- 🖼️ **Sticky Screenshots & Floating Image Overlays**: Snip any screen area (`⌘⇧S`) or paste images directly into floating sticky notes with opacity sliders and click-through mode.
- 🔒 **Touch ID / Biometric Lock**: Protect confidential notes behind a frosted glass shield with Touch ID / passcode authentication.
- 🗂️ **Layout Modes**: Free placement, Cascade Stack (`⌘⇧2`), or clean Grid Tile (`⌘⇧3`).
- 🎨 **Curated Pastel & Glass Palette**: Sun Yellow, Pastel Rose, Fresh Mint, Sky Blue, Soft Lavender, Charcoal Dark, and Frosted Glass Acrylic.

---

## 🛠️ Prerequisites

To build and run NoteNote from source, you need:
- **macOS Sonoma 14.0** or later
- **Swift 5.9+** and **Xcode 15+** (or Command Line Tools: `xcode-select --install`)

---

## 🚀 Quick Start & Building

### 1. Clone the Repository
```bash
git clone https://github.com/pritesh-ranjan/NoteNote2.git
cd NoteNote2
```

### 2. Build & Launch Instantly
```bash
make run
```
*(This compiles release binaries, bundles `NoteNote.app`, and launches it immediately.)*

### 3. Build Options via `make`

| Command | Action |
| --- | --- |
| `make` or `make build` | Compiles and packages `NoteNote.app` release bundle |
| `make run` | Builds and launches `NoteNote.app` |
| `make dmg` | Packages a styled drag-and-drop installer `NoteNote.dmg` |
| `make clean` | Cleans build artifacts (`.build`, `NoteNote.app`, `*.dmg`) |

You can also build directly using the Swift Package Manager CLI:
```bash
swift build -c release
```

---

## ⌨️ Keyboard Shortcuts

| Shortcut | Action |
| --- | --- |
| `⌘ ⇧ N` | **Quick Add Capture** (Spotlight-style input) |
| `⌘ ⇧ H` | **Show / Hide All** Stickies |
| `⌘ ⇧ S` | **Capture Sticky Screenshot** |
| `⌘ N` | **New Sticky Note** |
| `⌘ ⇧ 2` | **Cascade Stack** Layout |
| `⌘ ⇧ 3` | **Tile Grid** Layout |
| `⌘ ,` | **Preferences / Settings** |

---

## 📂 Architecture & Codebase

```
NoteNote/
├── .github/workflows/          # GitHub Actions CI workflow (macos-14)
├── Makefile                    # Single-command build, run, package, and clean
├── Package.swift               # SwiftPM configuration targeting macOS 14+
├── CONTRIBUTING.md             # Contribution, forking, and pull request guide
├── LICENSE                     # MIT License
├── README.md                   # Project overview & documentation
├── Resources/
│   ├── Info.plist              # Menu bar accessory config (LSUIElement = true)
│   ├── AppIcon.png
│   └── AppIcon.icns            # macOS native app icon
├── scripts/
│   ├── build_app.sh            # Bundles release .app with ad-hoc signature
│   └── build_dmg.sh            # Styled drag-and-drop installer DMG generator
└── Sources/NoteNoteApp/
    ├── main.swift              # Main entry point with MainActor isolation
    ├── AppDelegate.swift       # Menu bar setup, hotkeys, window management
    ├── Models/
    │   ├── NoteModel.swift     # Note data model with Sendable & Codable
    │   ├── NoteColor.swift     # Theme palette & AppKit/SwiftUI color mappings
    │   └── AppSettings.swift   # Preferences model
    ├── Services/
    │   ├── NotesStore.swift    # Data store & auto-save to Application Support
    │   ├── AppWatcherService.swift # Workspace frontmost app tracking
    │   ├── HotkeyService.swift # Global shortcut monitors
    │   ├── TouchIDService.swift# LocalAuthentication biometric lock
    │   └── ScreenCaptureService.swift # Interactive screenshot & clipboard capture
    ├── Windows/
    │   ├── StickyPanel.swift   # Custom borderless NSPanel with window levels
    │   ├── StickyWindowManager.swift # Coordinator for active sticky panels
    │   ├── MenuBarController.swift   # NSStatusItem menu bar integration
    │   ├── QuickAddWindowController.swift # HUD capture modal
    │   └── SettingsWindowController.swift # Preferences window
    ├── Views/
    │   ├── StickyNoteView.swift      # Main container view
    │   ├── NoteHeaderView.swift      # Drag bar, color picker, Touch ID lock, actions
    │   ├── NoteEditorView.swift      # Live markdown text editor & checklists
    │   ├── NoteFormatBar.swift       # Bottom formatting toolbar & word count
    │   ├── DockTabHandleView.swift   # Collapsed edge dock pill tab
    │   ├── QuickAddView.swift        # HUD quick capture view
    │   ├── AppPickerSheet.swift      # Running macOS application selector
    │   ├── ImageOverlayView.swift    # Floating screenshot & image view
    │   └── SettingsView.swift        # Tabbed preferences interface
    └── Utilities/
        └── WindowDragArea.swift      # Native AppKit window drag helper
```

---

## 💾 Storage & Data

Notes and preferences are stored locally in:
```
~/Library/Application Support/NoteNote/
├── notes.json
├── settings.json
└── Images/
```
Auto-save is debounced and instantaneous. Notes can also be exported anytime to `.md` (Markdown) or `.txt` (Plain Text).

---

## 🤝 Contributing

Contributions are welcome! Please check out [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on how to fork, develop, and submit pull requests.

---

## 📄 License

Distributed under the [MIT License](LICENSE).
