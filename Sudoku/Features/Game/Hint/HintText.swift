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
        case .step(let step, let board):
            switch stage {
            case .nudge:
                let title = step.technique.title
                if let house = step.focusHouses.first {
                    return String(localized: "Look for \(title) in \(houseName(house)).")
                }
                // Wings have no single house; point at their pivot instead.
                let cell = step.patternCells.first.map(cellName) ?? ""
                return String(localized: "Look for \(title) around the cell at \(cell).")
            case .explanation:
                return explanation(of: step, on: board)
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

    /// "1, 2 and 3" (or "1, 2 or 3") in the current language.
    static func digitList(_ digits: CandidateSet, type: ListFormatStyle<StringStyle, [String]>.ListType = .and) -> String {
        digits.map(String.init).formatted(.list(type: type))
    }

    // MARK: Sentences

    private static func explanation(of step: SolveStep, on board: Board) -> String {
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
        case .xWing, .skyscraper, .twoStringKite:
            return singleDigitPatternExplanation(of: step, digit: digit)
        case .xyWing, .xyzWing, .wWing:
            return wingExplanation(of: step, on: board)
        }
    }

    /// X-Wing, Skyscraper and 2-String Kite. See each technique for the order of its houses and cells.
    private static func singleDigitPatternExplanation(of step: SolveStep, digit: Digit) -> String {
        let houses = step.focusHouses.map(houseName)
        let cells = step.patternCells.map(cellName)
        guard houses.count >= 3, cells.count >= 2 else { return "" }

        switch step.technique {
        case .xWing:
            guard houses.count == 4 else { return "" }
            return String(localized: "In \(houses[0]) and \(houses[1]), \(digit) fits in only two cells each, and these four cells lie in \(houses[2]) and \(houses[3]). However \(digit) is placed in the two lines, it fills one cell in each of \(houses[2]) and \(houses[3]), so it can be removed from their other cells.")
        case .skyscraper:
            return String(localized: "In \(houses[0]) and \(houses[1]), \(digit) fits in only two cells each. Two of these cells share \(houses[2]), so at most one of them is \(digit). That means \(digit) must be in at least one of the other two cells: \(cells[0]) or \(cells[1]). Any cell that sees both of them can't be \(digit).")
        default:
            return String(localized: "In \(houses[0]) and in \(houses[1]), \(digit) fits in only two cells each. One cell from each pair lies in \(houses[2]), and since they see each other, at most one of them is \(digit). So \(digit) must be in at least one of the other ends: \(cells[0]) or \(cells[1]). Any cell that sees both of them can't be \(digit).")
        }
    }

    /// XY-Wing, XYZ-Wing and W-Wing. See each technique for the order of its cells.
    private static func wingExplanation(of step: SolveStep, on board: Board) -> String {
        let removed = step.eliminations.reduce(CandidateSet()) { $0.union($1.digits) }
        guard let z = removed.single, step.patternCells.count >= 3 else { return "" }
        let cells = step.patternCells.map(cellName)
        let pivot = board.candidates(at: step.patternCells[0])
        // The pivot digit each pincer shares (other than z).
        let x = board.candidates(at: step.patternCells[1]).intersection(pivot).subtracting([z]).min() ?? 0
        let y = board.candidates(at: step.patternCells[2]).intersection(pivot).subtracting([z]).min() ?? 0

        switch step.technique {
        case .xyWing:
            return String(localized: "The cell at \(cells[0]) can only be \(x) or \(y). If it's \(x), the cell at \(cells[1]) must be \(z); if it's \(y), the cell at \(cells[2]) must be \(z). Either way one of these two cells is \(z), so any cell that sees both can't be \(z).")
        case .xyzWing:
            let options = digitList(pivot, type: .or)
            return String(localized: "The cell at \(cells[0]) can only be \(options). If it's \(x), the cell at \(cells[1]) must be \(z); if it's \(y), the cell at \(cells[2]) must be \(z); otherwise it is \(z) itself. So one of these three cells is \(z), and any cell that sees all three can't be \(z).")
        default:
            // W-Wing: z is the eliminated digit, the other one carries the strong link.
            let link = step.patternDigits.subtracting([z]).min() ?? 0
            let house = step.focusHouses.first.map(houseName) ?? ""
            return String(localized: "The cells at \(cells[0]) and \(cells[1]) can only be \(link) or \(z). In \(house), \(link) fits in only two cells, and each of them sees one of these cells. Whichever holds \(link), the cell it sees can't be \(link) and must be \(z). So one of the two cells is \(z), and any cell that sees both can't be \(z).")
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
