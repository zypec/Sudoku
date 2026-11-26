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
        case .impossibleNotes:
            String(localized: "Impossible Notes")
        case .notesMissingSolution:
            String(localized: "Notes Missing a Digit")
        case .notesIncomplete:
            String(localized: "Incomplete Notes")
        case .unavailable:
            String(localized: "No Hint Available")
        case .step, .chain:
            hint.mainTechnique.map(\.title) ?? ""
        }
    }

    static func subtitle(for hint: Hint) -> String? {
        hint.mainTechnique.map { String(localized: $0.subtitle) }
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

    /// "row 1, row 4 and row 7" in the current language.
    static func houseList(_ houses: [House]) -> String {
        houses.map(houseName).formatted(.list(type: .and))
    }

    /// "1, 2 and 3" (or "1, 2 or 3") in the current language.
    static func digitList(_ digits: CandidateSet, type: ListFormatStyle<StringStyle, [String]>.ListType = .and) -> String {
        digits.map(String.init).formatted(.list(type: type))
    }
}

extension Hint {
    /// The technique a hint is about: the hardest one in a chain (the singles at its end are the
    /// easy part).
    var mainTechnique: TechniqueKind? {
        steps.max { $0.technique.level < $1.technique.level }?.technique
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
        case .uniqueRectangleType1: "Unique Rectangle Type 1"
        case .uniqueRectangleType2: "Unique Rectangle Type 2"
        case .uniqueRectangleType4: "Unique Rectangle Type 4"
        case .swordfish: "Swordfish"
        case .jellyfish: "Jellyfish"
        case .emptyRectangle: "Empty Rectangle"
        case .simpleColoring: "Simple Coloring"
        case .finnedXWing: "Finned X-Wing"
        case .finnedSwordfish: "Finned Swordfish"
        case .bug: "BUG+1"
        case .remotePair: "Remote Pair"
        case .xChain: "X-Chain"
        case .xyChain: "XY-Chain"
        case .aic: "AIC"
        case .alsXZ: "ALS-XZ"
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
        case .uniqueRectangleType1, .uniqueRectangleType2, .uniqueRectangleType4: "Avoiding a second solution"
        case .swordfish: "Digit locked in three lines"
        case .jellyfish: "Digit locked in four lines"
        case .emptyRectangle: "Box corner and a strong link"
        case .simpleColoring: "Two colors along strong links"
        case .finnedXWing: "X-Wing with a fin"
        case .finnedSwordfish: "Swordfish with a fin"
        case .bug: "All cells two-valued but one"
        case .remotePair: "A chain of identical pairs"
        case .xChain: "Chain of links on one digit"
        case .xyChain: "Chain of two-candidate cells"
        case .aic: "Alternating inference chain"
        case .alsXZ: "Two almost locked sets"
        }
    }
}
