//
//  HintText.swift
//  Sudoku
//

import Foundation

/// Localized wording for hints. The engine only returns structured steps; every sentence the
/// player reads is built here.
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

    static func message(for hint: Hint, stage: HintStage) -> String {
        switch hint {
        case .incorrectEntries:
            return String(localized: "Some digits on the board are incorrect. Fix them before looking for the next step.")
        case .unavailable:
            return String(localized: "The next step needs a technique that isn't available yet. You can reveal a cell instead.")
        case .step(let step, _):
            switch stage {
            case .nudge:
                let house = step.focusHouses.first.map(houseName) ?? ""
                return String(localized: "There's a \(step.technique.title) in \(house).")
            case .explanation:
                return explanation(of: step)
            case .result:
                return result(of: step)
            }
        }
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

    /// "1, 2 and 3" in the current language.
    static func digitList(_ digits: CandidateSet) -> String {
        digits.map(String.init).formatted(.list(type: .and))
    }

    // MARK: Sentences

    private static func explanation(of step: SolveStep) -> String {
        let house = step.focusHouses.first.map(houseName) ?? ""
        let digit = step.patternDigits.min() ?? 0
        let digits = digitList(step.patternDigits)
        let count = step.patternCells.count

        switch step.technique {
        case .fullHouse:
            return String(localized: "Only one cell is empty in \(house), and \(digit) is the only digit missing there.")
        case .hiddenSingle:
            return String(localized: "In \(house), \(digit) fits in only one cell.")
        case .nakedSingle:
            let cell = step.patternCells.first.map(cellName) ?? ""
            return String(localized: "Only one candidate is left in the cell at \(cell): \(digit).")
        case .pointing:
            let line = step.focusHouses.dropFirst().first.map(houseName) ?? ""
            return String(localized: "In \(house), every candidate for \(digit) lies in \(line). So inside this box \(digit) must be in \(line), and it can be removed from the rest of \(line).")
        case .claiming:
            let box = step.focusHouses.dropFirst().first.map(houseName) ?? ""
            return String(localized: "In \(house), every candidate for \(digit) lies inside \(box). So inside \(box), \(digit) must be in \(house), and it can be removed from the box's other cells.")
        case .nakedPair, .nakedTriple, .nakedQuad:
            return String(localized: "In \(house), the \(count) highlighted cells can only hold \(digits). These digits must fill those cells, so they can be removed from the rest of \(house).")
        case .hiddenPair, .hiddenTriple, .hiddenQuad:
            return String(localized: "In \(house), \(digits) can only go in the \(count) highlighted cells. Those cells must hold exactly these digits, so their other candidates can be removed.")
        }
    }

    private static func result(of step: SolveStep) -> String {
        if let placement = step.placements.first {
            return String(localized: "Place \(placement.digit) at \(cellName(placement.cell)).")
        }
        let removed = step.eliminations.reduce(CandidateSet()) { $0.union($1.digits) }
        return String(localized: "Remove \(digitList(removed)) from the highlighted cells.")
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
        }
    }
}
