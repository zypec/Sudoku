//
//  HintStyling.swift
//  Sudoku
//

import SwiftUI

/// A hint's words with what to look for picked out, so a sentence can be scanned before it is read:
/// places (cells and houses) in bold, digits in the accent color, and a visual proof's "Case 1 of 2:"
/// in a quieter color. The text itself stays exactly as `HintText` wrote it.
enum HintStyling {
    /// Every cell and house name as `HintText` writes them in the current language, longest first, so
    /// "row 3, column 5" is found whole before "row 3" could match its start.
    private static let places: [String] = {
        let cells = Geometry.cells.map(HintText.cellName)
        let houses = Geometry.houses.map(HintText.houseName)
        return (cells + houses).sorted { $0.count > $1.count }
    }()

    /// Numbers that count rather than name a digit: a case's header ("Case 1 of 2:", "1. durum (2
    /// durumdan):") and progress in brackets ("(3 of 5)", "(3 / 5)").
    private static var counters: [Regex<Substring>] {
        [#/^(?:Case \d+ of \d+:|\d+\. durum \(\d+ durumdan\):)/#, #/\(\d+ (?:of|\/) \d+\)/#]
    }

    static func styled(_ text: String) -> AttributedString {
        var result = AttributedString(text)
        // Index ranges of `text` already styled, so a digit inside a name or a counter is left alone.
        var taken: [Range<String.Index>] = []
        func isFree(_ range: Range<String.Index>) -> Bool {
            !taken.contains { $0.overlaps(range) }
        }
        func style(_ range: Range<String.Index>, _ apply: (inout AttributedSubstring) -> Void) {
            taken.append(range)
            guard let lower = AttributedString.Index(range.lowerBound, within: result),
                  let upper = AttributedString.Index(range.upperBound, within: result)
            else { return }
            apply(&result[lower..<upper])
        }

        for counter in counters {
            for match in text.matches(of: counter) where isFree(match.range) {
                style(match.range) { $0.foregroundColor = .secondary }
            }
        }
        for place in places {
            var start = text.startIndex
            while let range = text.range(of: place, range: start..<text.endIndex) {
                if isFree(range) {
                    style(range) { $0.font = .app(.body, weight: .semibold) }
                }
                start = range.upperBound
            }
        }
        for range in digits(in: text) where isFree(range) {
            style(range) {
                $0.font = .app(.body, weight: .bold)
                $0.foregroundColor = .accentColor
            }
        }
        return result
    }

    /// Each digit 1 to 9 standing on its own: not part of a longer number, and not a Turkish ordinal
    /// ("3. satır", a period and then a word in lowercase).
    private static func digits(in text: String) -> [Range<String.Index>] {
        let characters = Array(text.indices)
        var found: [Range<String.Index>] = []
        for (position, index) in characters.enumerated() {
            let character = text[index]
            guard let value = character.wholeNumberValue, (1...9).contains(value), character.isASCII else { continue }
            let before = position > 0 ? text[characters[position - 1]] : " "
            let after = position + 1 < characters.count ? text[characters[position + 1]] : " "
            if before.isNumber || before == "." || after.isNumber { continue }
            if after == ".", position + 3 < characters.count, text[characters[position + 2]] == " ",
               text[characters[position + 3]].isLowercase {
                continue
            }
            found.append(index..<text.index(after: index))
        }
        return found
    }
}
