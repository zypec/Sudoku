//
//  HintHighlights.swift
//  Sudoku
//

/// What the board shows for one page of a hint: colored cells, marked candidates and links
/// between candidates. Built up page by page by `HintWalkthrough`.
struct HintHighlights: Equatable {
    /// Background of a cell. When several apply, the later case wins.
    enum Fill: Int, Comparable {
        /// A house the explanation is about.
        case house
        /// A cell the step changes.
        case target
        /// A placed digit that rules out candidates (e.g. for a hidden single).
        case blocker
        /// A cell that is part of the pattern.
        case pattern
        /// A wrong entry.
        case incorrect

        static func < (lhs: Fill, rhs: Fill) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    /// How a candidate is drawn. `alternativeA` and `alternativeB` color two mutually exclusive
    /// cases, e.g. the two diagonals of an X-Wing. `context` shows a candidate the hint isn't about,
    /// so players who don't take notes can see every possibility around the pattern.
    enum Mark: Equatable {
        case context
        case emphasized
        case alternativeA
        case alternativeB
        case eliminated
    }

    struct CellStyle: Equatable {
        var fill: Fill?
        var marks: [Digit: Mark] = [:]
        /// Digit the step places, drawn as a preview.
        var ghostDigit: Digit?

        var markedDigits: CandidateSet {
            CandidateSet(marks.keys)
        }
    }

    /// A link between two candidates (usually the same digit in two cells, or two digits of one
    /// cell). Strong: at least one is true. Weak: at most one is true.
    struct Link: Hashable {
        let from: CellIndex
        let fromDigit: Digit
        let to: CellIndex
        let toDigit: Digit
        let isStrong: Bool
    }

    private(set) var styles: [CellIndex: CellStyle] = [:]
    private(set) var links: [Link] = []

    func style(for cell: CellIndex) -> CellStyle? {
        styles[cell]
    }

    var isEmpty: Bool {
        styles.isEmpty && links.isEmpty
    }

    // MARK: Building

    mutating func fill(_ cells: some Sequence<CellIndex>, _ fill: Fill) {
        for cell in cells {
            let current = styles[cell, default: CellStyle()].fill
            if current.map({ $0 < fill }) ?? true {
                styles[cell, default: CellStyle()].fill = fill
            }
        }
    }

    mutating func fill(_ houses: [House]) {
        fill(houses.flatMap(\.cells), .house)
    }

    mutating func mark(_ digits: CandidateSet, in cell: CellIndex, as mark: Mark) {
        for digit in digits {
            styles[cell, default: CellStyle()].marks[digit] = mark
        }
    }

    mutating func link(_ from: CellIndex, _ to: CellIndex, digit: Digit, isStrong: Bool) {
        link(ChainNode(cell: from, digit: digit), ChainNode(cell: to, digit: digit), isStrong: isStrong)
    }

    mutating func link(_ from: ChainNode, _ to: ChainNode, isStrong: Bool) {
        let link = Link(from: from.cell, fromDigit: from.digit, to: to.cell, toDigit: to.digit, isStrong: isStrong)
        if !links.contains(link) {
            links.append(link)
        }
    }

    /// Adds `digits` as context candidates, leaving digits the hint already marks alone.
    mutating func showCandidates(_ digits: CandidateSet, in cell: CellIndex) {
        for digit in digits where styles[cell]?.marks[digit] == nil {
            styles[cell, default: CellStyle()].marks[digit] = .context
        }
    }

    mutating func ghost(_ digit: Digit, in cell: CellIndex) {
        styles[cell, default: CellStyle()].ghostDigit = digit
    }
}
