# Contributing to NoteNote 📌

Thank you for your interest in contributing to NoteNote! We welcome bug reports, feature suggestions, and code contributions.

---

## 🛠️ Development Setup & Prerequisites

Before you begin, ensure your Mac meets the following requirements:

- **macOS**: macOS Sonoma 14.0 or newer.
- **Swift / Xcode**: Swift 5.9+ and Xcode 15+ (or Xcode Command Line Tools: `xcode-select --install`).
- **Git**: Installed and configured on your machine.

---

## 🚀 Getting Started

1. **Fork the Repository**:
   Click the **Fork** button at the top right of the GitHub repository.

2. **Clone your fork**:
   ```bash
   git clone https://github.com/<your-username>/NoteNote2.git
   cd NoteNote2
   ```

3. **Build the Application**:
   You can build using `make` or the provided scripts:
   ```bash
   make build
   ```
   Or directly via Swift Package Manager:
   ```bash
   swift build -c release
   ```

4. **Run the App**:
   ```bash
   make run
   ```

5. **Generate a Distribution DMG**:
   ```bash
   make dmg
   ```

---

## 📂 Project Structure

- `Package.swift`: Swift Package Manager configuration targeting macOS 14+.
- `Sources/NoteNoteApp/`:
  - `main.swift`: Application entry point with `@MainActor` isolation.
  - `AppDelegate.swift`: App lifecycle, menu bar setup, and global shortcuts.
  - `Models/`: Data structures for notes (`NoteModel`), color schemes (`NoteColor`), and preferences (`AppSettings`).
  - `Services/`: Persistent storage (`NotesStore`), frontmost app tracking (`AppWatcherService`), hotkeys, biometrics, and screen capture.
  - `Windows/`: Window management, status bar controllers, HUD quick add window.
  - `Views/`: SwiftUI views for sticky notes, live markdown editor, checklist parser, formatting bar, and settings.
- `Resources/`: App icon (`AppIcon.icns`, `AppIcon.png`) and `Info.plist` (sets `LSUIElement` for menu bar accessory mode).
- `scripts/`:
  - `build_app.sh`: Compiles and bundles `NoteNote.app`.
  - `build_dmg.sh`: Packages and customizes the drag-and-drop installer `.dmg`.

---

## 📋 Contribution Workflow

1. **Create a Feature Branch**:
   ```bash
   git checkout -b feature/my-new-feature
   ```
   or for bugfixes:
   ```bash
   git checkout -b fix/issue-description
   ```

2. **Make Your Changes**:
   - Keep code clean, idiomatic Swift, and well-structured.
   - Use SwiftUI and AppKit APIs compatible with macOS 14.0+.
   - Ensure notes state serialization (`Codable`) remains backward-compatible.

3. **Verify Your Changes**:
   Ensure the application builds and runs cleanly:
   ```bash
   make clean
   make build
   make run
   ```

4. **Commit & Push**:
   Write clear, descriptive commit messages:
   ```bash
   git commit -m "feat: add keyboard shortcut for font cycling"
   git push origin feature/my-new-feature
   ```

5. **Open a Pull Request**:
   Go to your fork on GitHub and submit a Pull Request targeting the `main` branch. Describe the problem your PR solves and attach screenshots or screen recordings for any UI changes.

---

## 📄 License

By contributing to NoteNote, you agree that your contributions will be licensed under the project's [MIT License](LICENSE).
