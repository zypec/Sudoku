//
//  HintText.swift
//  Sudoku
//

import Foundation

/// Localized names used by hints. The engine only returns structured steps; the sentences built
/// from them live in `HintWalkthrough`.
enum HintText {
    static func title(for hint: Hint) -> String {
        switch hint {
        case .incorrectEntries:
            String(localized: "Incorrect Digits")
        case .unavailable:
            String(localized: "No Hint Available")
        case .step(let step, _):
            step.technique.title
        }
    }

    static func subtitle(for hint: Hint) -> String? {
        guard case .step(let step, _) = hint else { return nil }
        return String(localized: step.technique.subtitle)
    }

    // MARK: Names

    /// "row 3", "column 5", "box 1" (1-based, lowercase for use inside sentences).
    static func houseName(_ house: House) -> String {
        let number = house.index + 1
        return switch house.kind {
        case .row: String(localized: "row \(number)")
        case .column: String(localized: "column \(number)")
        case .box: String(localized: "box \(number)")
        }
    }

    /// "row 3, column 5".
    static func cellName(_ cell: CellIndex) -> String {
        String(localized: "row \(Geometry.row(of: cell) + 1), column \(Geometry.column(of: cell) + 1)")
    }

    /// "1, 2 and 3" (or "1, 2 or 3") in the current language.
    static func digitList(_ digits: CandidateSet, type: ListFormatStyle<StringStyle, [String]>.ListType = .and) -> String {
        digits.map(String.init).formatted(.list(type: type))
    }
}

extension TechniqueKind {
    /// The technique's established English name, used in every language.
    var title: String {
        switch self {
        case .fullHouse: "Full House"
        case .hiddenSingle: "Hidden Single"
        case .nakedSingle: "Naked Single"
        case .pointing: "Pointing"
        case .claiming: "Claiming"
        case .nakedPair: "Naked Pair"
        case .hiddenPair: "Hidden Pair"
        case .nakedTriple: "Naked Triple"
        case .hiddenTriple: "Hidden Triple"
        case .nakedQuad: "Naked Quad"
        case .hiddenQuad: "Hidden Quad"
        case .xWing: "X-Wing"
        case .skyscraper: "Skyscraper"
        case .twoStringKite: "2-String Kite"
        case .xyWing: "XY-Wing"
        case .xyzWing: "XYZ-Wing"
        case .wWing: "W-Wing"
        }
    }

    /// A short localized description shown under the name.
    var subtitle: LocalizedStringResource {
        switch self {
        case .fullHouse: "Last empty cell in a house"
        case .hiddenSingle: "Only place for a digit"
        case .nakedSingle: "Only digit for a cell"
        case .pointing: "Digit locked in a box line"
        case .claiming: "Digit locked in a line's box"
        case .nakedPair: "Two cells, two digits"
        case .hiddenPair: "Two digits, two cells"
        case .nakedTriple: "Three cells, three digits"
        case .hiddenTriple: "Three digits, three cells"
        case .nakedQuad: "Four cells, four digits"
        case .hiddenQuad: "Four digits, four cells"
        case .xWing: "Rectangle on two lines"
        case .skyscraper: "Two links sharing a base"
        case .twoStringKite: "Row and column joined in a box"
        case .xyWing: "Pivot with two pincers"
        case .xyzWing: "Three-digit pivot with two pincers"
        case .wWing: "Twin pairs joined by a link"
        }
    }
}
