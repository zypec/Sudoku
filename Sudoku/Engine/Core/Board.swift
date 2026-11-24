//
//  Board.swift
//  Sudoku
//

/// A Sudoku position: placed digits plus the remaining candidates of every empty cell.
///
/// Candidates start out as "every digit not already placed in a peer" and only ever shrink,
/// either because a digit is placed in a peer or because a technique eliminates them.
struct Board: Hashable, Sendable {
    /// Placed digit of every cell, `0` when empty.
    private(set) var values: [Digit]
    /// Remaining candidates of every cell; always empty for filled cells.
    private(set) var candidates: [CandidateSet]

    /// An empty board where every cell can hold every digit.
    init() {
        values = Array(repeating: 0, count: Geometry.cellCount)
        candidates = Array(repeating: .all, count: Geometry.cellCount)
    }

    /// A board with the given digits placed and candidates derived from them.
    init(values: [Digit]) {
        precondition(values.count == Geometry.cellCount, "A board needs 81 values")
        precondition(values.allSatisfy { (0...9).contains($0) }, "Values must be in 0...9")
        self.values = values
        candidates = Geometry.cells.map { cell in
            guard values[cell] == 0 else { return .empty }
            let seen = CandidateSet(Geometry.peers[cell].lazy.map { values[$0] }.filter { $0 != 0 })
            return CandidateSet.all.subtracting(seen)
        }
    }

    /// Parses 81 characters row by row: `1`–`9` are digits, `0`, `.` or `-` are empty cells.
    /// Whitespace is ignored. Returns `nil` for malformed input.
    init?(string: String) {
        var parsed: [Digit] = []
        parsed.reserveCapacity(Geometry.cellCount)
        for character in string where !character.isWhitespace {
            switch character {
            case "1"..."9":
                guard let digit = character.wholeNumberValue else { return nil }
                parsed.append(digit)
            case "0", ".", "-":
                parsed.append(0)
            default:
                return nil
            }
        }
        guard parsed.count == Geometry.cellCount else { return nil }
        self.init(values: parsed)
    }

    func value(at cell: CellIndex) -> Digit {
        values[cell]
    }

    func candidates(at cell: CellIndex) -> CandidateSet {
        candidates[cell]
    }

    var emptyCells: [CellIndex] {
        Geometry.cells.filter { values[$0] == 0 }
    }

    /// Whether some house contains the same digit twice.
    var hasConflict: Bool {
        Geometry.houses.contains { house in
            var seen = CandidateSet()
            for cell in house.cells where values[cell] != 0 {
                if seen.contains(values[cell]) { return true }
                seen.insert(values[cell])
            }
            return false
        }
    }

    /// Whether the position can no longer lead to a solution: a conflict, or an empty cell without candidates.
    var isContradictory: Bool {
        hasConflict || Geometry.cells.contains { values[$0] == 0 && candidates[$0].isEmpty }
    }

    /// Every cell is filled and no house contains a duplicate.
    var isSolved: Bool {
        !values.contains(0) && !hasConflict
    }

    /// Places `digit` in `cell` and removes it from the candidates of every peer.
    mutating func place(_ digit: Digit, at cell: CellIndex) {
        precondition(Geometry.digits.contains(digit), "Invalid digit \(digit)")
        values[cell] = digit
        candidates[cell] = .empty
        for peer in Geometry.peers[cell] {
            candidates[peer].remove(digit)
        }
    }

    /// Removes `digits` from the candidates of `cell`. Returns whether anything changed.
    @discardableResult
    mutating func eliminate(_ digits: CandidateSet, from cell: CellIndex) -> Bool {
        let remaining = candidates[cell].subtracting(digits)
        guard remaining != candidates[cell] else { return false }
        candidates[cell] = remaining
        return true
    }

    /// 81-character representation using `.` for empty cells.
    var stringValue: String {
        String(values.map { $0 == 0 ? "." : Character(String($0)) })
    }
}

extension Board: CustomStringConvertible {
    var description: String { stringValue }
}
