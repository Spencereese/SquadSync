import Foundation

/// The app says "group" (or the group's name), never "squad". "SquadSync", the
/// app's name, is fine. `scripts/check-copy.py` runs the same rule over every
/// user-facing string in the source; this is the in-app twin for tests.
enum CopyCheck {
    /// The first offending word, or nil when the text is clean.
    static func offending(_ text: String) -> String? {
        let cleaned = text.replacingOccurrences(of: "squadsync", with: "", options: .caseInsensitive)
        guard let range = cleaned.range(of: "squad", options: .caseInsensitive) else { return nil }
        var start = range.lowerBound
        while start > cleaned.startIndex, cleaned[cleaned.index(before: start)].isLetter {
            start = cleaned.index(before: start)
        }
        var end = range.upperBound
        while end < cleaned.endIndex, cleaned[end].isLetter || cleaned[end] == "'" {
            end = cleaned.index(after: end)
        }
        return String(cleaned[start..<end])
    }
}
