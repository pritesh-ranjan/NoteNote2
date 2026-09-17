import Foundation

extension String {
    /// Returns the string with leading Markdown syntax (headings, checklist boxes, bullet symbols) removed
    public var cleanMarkdownStripped: String {
        let trimmed = self.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return "" }
        
        var clean = trimmed
        if clean.hasPrefix("#") {
            clean = clean.replacingOccurrences(of: "^#+\\s*", with: "", options: .regularExpression)
        } else if clean.hasPrefix("- [") || clean.hasPrefix("* [") {
            clean = clean.replacingOccurrences(of: "^[-*]\\s*\\[[ xX]\\]\\s*", with: "", options: .regularExpression)
        } else if clean.hasPrefix("- ") || clean.hasPrefix("* ") || clean.hasPrefix("• ") || clean.hasPrefix("+ ") {
            clean = clean.replacingOccurrences(of: "^[-*•+]\\s*", with: "", options: .regularExpression)
        }
        return clean.trimmingCharacters(in: .whitespaces)
    }
}

extension Date {
    /// Returns a human-friendly relative time string (e.g. "Just now", "5m ago", "2h ago", "3d ago")
    public var relativeTimeString: String {
        let interval = Date().timeIntervalSince(self)
        if interval < 60 {
            return "Just now"
        } else if interval < 3600 {
            let minutes = max(1, Int(interval / 60))
            return "\(minutes)m ago"
        } else if interval < 86400 {
            let hours = max(1, Int(interval / 3600))
            return "\(hours)h ago"
        } else {
            let days = max(1, Int(interval / 86400))
            return "\(days)d ago"
        }
    }
}
