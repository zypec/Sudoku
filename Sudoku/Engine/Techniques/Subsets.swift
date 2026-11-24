//
//  Subsets.swift
//  Sudoku
//

/// Naked pair / triple / quad. When `size` empty cells of a house together have only `size`
/// candidates, those digits must fill exactly these cells — so they can be removed from every
/// other cell of the house.
struct NakedSubset: Technique {
    let size: Int

    init(size: Int) {
        precondition((2...4).contains(size), "Subsets have 2 to 4 cells")
        self.size = size
    }

    var kind: TechniqueKind {
        switch size {
        case 2: .nakedPair
        case 3: .nakedTriple
        default: .nakedQuad
        }
    }

    func findStep(in board: Board) -> SolveStep? {
        for house in Geometry.houses {
            let emptyCells = house.cells.filter { board.value(at: $0) == 0 }
            // There must be at least one other cell to eliminate from.
            guard emptyCells.count > size else { continue }
            // A cell with more candidates than the subset size can't belong to it.
            let members = emptyCells.filter { (2...size).contains(board.candidates(at: $0).count) }

            for subset in members.combinations(ofSize: size) {
                let digits = subset.reduce(CandidateSet()) { $0.union(board.candidates(at: $1)) }
                guard digits.count == size else { continue }

                let eliminations: [Elimination] = emptyCells.compactMap { cell in
                    guard !subset.contains(cell) else { return nil }
                    let removed = board.candidates(at: cell).intersection(digits)
                    return removed.isEmpty ? nil : Elimination(cell: cell, digits: removed)
                }
                guard !eliminations.isEmpty else { continue }
                return SolveStep(
                    technique: kind,
                    eliminations: eliminations,
                    focusHouses: [house],
                    patternCells: subset,
                    patternDigits: digits
                )
            }
        }
        return nil
    }
}

/// Hidden pair / triple / quad. When `size` digits can only go in the same `size` cells of a house,
/// those cells must hold exactly these digits — so every other candidate can be removed from them.
struct HiddenSubset: Technique {
    let size: Int

    init(size: Int) {
        precondition((2...4).contains(size), "Subsets have 2 to 4 digits")
        self.size = size
    }

    var kind: TechniqueKind {
        switch size {
        case 2: .hiddenPair
        case 3: .hiddenTriple
        default: .hiddenQuad
        }
    }

    func findStep(in board: Board) -> SolveStep? {
        for house in Geometry.houses {
            let cells = house.cells
            // Where each digit can still go in this house (empty for placed digits).
            let positions: [[CellIndex]] = (0...9).map { digit in
                digit == 0 ? [] : cells.filter { board.candidates(at: $0).contains(digit) }
            }
            // A digit with more possible cells than the subset size can't belong to it.
            let members = Geometry.digits.filter { (2...size).contains(positions[$0].count) }

            for subset in members.combinations(ofSize: size) {
                let subsetCells = Set(subset.flatMap { positions[$0] }).sorted()
                guard subsetCells.count == size else { continue }

                let digits = CandidateSet(subset)
                let eliminations: [Elimination] = subsetCells.compactMap { cell in
                    let removed = board.candidates(at: cell).subtracting(digits)
                    return removed.isEmpty ? nil : Elimination(cell: cell, digits: removed)
                }
                guard !eliminations.isEmpty else { continue }
                return SolveStep(
                    technique: kind,
                    eliminations: eliminations,
                    focusHouses: [house],
                    patternCells: subsetCells,
                    patternDigits: digits
                )
            }
        }
        return nil
    }
}
