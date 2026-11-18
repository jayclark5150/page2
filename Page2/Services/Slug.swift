import Foundation

/// Builds stable, unique slugs for user added sources.
enum Slug {
    /// Lowercases, turns runs of non alphanumerics into single dashes, trims dashes.
    static func make(from text: String) -> String {
        let lowered = text.lowercased()
        var result = ""
        var lastWasDash = false
        for character in lowered {
            if character.isLetter || character.isNumber {
                result.append(character)
                lastWasDash = false
            } else if !lastWasDash {
                result.append("-")
                lastWasDash = true
            }
        }
        let trimmed = result.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return trimmed.isEmpty ? "source" : trimmed
    }

    /// Returns base if free, otherwise base-2, base-3, and so on.
    static func unique(_ base: String, taken: Set<String>) -> String {
        guard taken.contains(base) else { return base }
        var index = 2
        while taken.contains("\(base)-\(index)") { index += 1 }
        return "\(base)-\(index)"
    }
}
