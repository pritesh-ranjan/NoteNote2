import AppKit
import SwiftUI
import Combine

public struct NoteSwitchFeedback: Identifiable, Equatable {
    public let id: UUID
    public let index: Int
    public let total: Int
    public let title: String
}

@MainActor
public final class GestureController: ObservableObject {
    public static let shared = GestureController()
    
    @Published public var switchFeedback: NoteSwitchFeedback?
    private var feedbackDismissTask: DispatchWorkItem?
    private var lastSearchPresentationTime: TimeInterval = 0
    private var lastNoteSwitchTime: TimeInterval = 0
    
    private init() {}
    
    /// Triggers a subtle tactile haptic feedback on MacBook Force Touch trackpads.
    public func triggerHaptic() {
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
    }
    
    /// Handles "Swipe from up" gesture -> opens the Spotlight HUD Search UI.
    public func handleSwipeFromUp() {
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastSearchPresentationTime > 0.6 else { return }
        lastSearchPresentationTime = now
        
        triggerHaptic()
        AppLogger.info("Swipe from up detected: presenting Search UI")
        SearchNotesWindowController.shared.presentSearch()
    }
    
    /// Cycles to the next note window in its original position and size.
    public func switchToNextNote(from currentNoteId: UUID) {
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastNoteSwitchTime > 0.35 else { return }
        lastNoteSwitchTime = now
        
        let notes = NotesStore.shared.notes
        guard !notes.isEmpty else { return }
        
        triggerHaptic()
        
        if notes.count == 1 {
            showFeedback(for: notes[0], index: 1, total: 1)
            return
        }
        
        let currentIndex = notes.firstIndex(where: { $0.id == currentNoteId }) ?? 0
        let nextIndex = (currentIndex + 1) % notes.count
        let targetNote = notes[nextIndex]
        
        AppLogger.info("Gesture switch to next note (\(nextIndex + 1)/\(notes.count)): '\(targetNote.displayTitle)'")
        StickyWindowManager.shared.focusNote(id: targetNote.id)
        showFeedback(for: targetNote, index: nextIndex + 1, total: notes.count)
    }
    
    /// Cycles to the previous note window in its original position and size.
    public func switchToPreviousNote(from currentNoteId: UUID) {
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastNoteSwitchTime > 0.35 else { return }
        lastNoteSwitchTime = now
        
        let notes = NotesStore.shared.notes
        guard !notes.isEmpty else { return }
        
        triggerHaptic()
        
        if notes.count == 1 {
            showFeedback(for: notes[0], index: 1, total: 1)
            return
        }
        
        let currentIndex = notes.firstIndex(where: { $0.id == currentNoteId }) ?? 0
        let prevIndex = (currentIndex - 1 + notes.count) % notes.count
        let targetNote = notes[prevIndex]
        
        AppLogger.info("Gesture switch to previous note (\(prevIndex + 1)/\(notes.count)): '\(targetNote.displayTitle)'")
        StickyWindowManager.shared.focusNote(id: targetNote.id)
        showFeedback(for: targetNote, index: prevIndex + 1, total: notes.count)
    }
    
    private func showFeedback(for note: NoteModel, index: Int, total: Int) {
        feedbackDismissTask?.cancel()
        
        withAnimation(.easeOut(duration: 0.18)) {
            self.switchFeedback = NoteSwitchFeedback(
                id: note.id,
                index: index,
                total: total,
                title: note.displayTitle
            )
        }
        
        let task = DispatchWorkItem { [weak self] in
            withAnimation(.easeInOut(duration: 0.28)) {
                self?.switchFeedback = nil
            }
        }
        feedbackDismissTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9, execute: task)
    }
}
