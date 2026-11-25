//
//  HintSpotting.swift
//  Sudoku
//

/// "How to spot it" for a hint: where on this board the player should have been looking, before
/// the reasoning starts. It shows the search space a player scans for the technique (the
/// two-candidate cells for wings and XY-Chains, every two-spot house of the digit for fish and
/// single-digit chains, and so on), not the answer.
enum HintSpotting {
    static func highlights(for step: SolveStep, board: Board) -> HintHighlights {
        var highlights = HintHighlights()
        let digit = step.patternDigits.min() ?? 0
        let house = step.focusHouses.first

        switch step.technique {
        case .fullHouse, .nakedSingle:
            highlights.fill(step.focusHouses)
            showCandidates(in: step.focusHouses.flatMap(\.cells), on: board, into: &highlights)

        case .hiddenSingle:
            // The house, and every copy of the digit already placed: they rule cells out.
            if let house {
                highlights.fill([house])
                for cell in house.cells where board.candidates(at: cell).contains(digit) {
                    highlights.mark([digit], in: cell, as: .emphasized)
                }
            }
            highlights.fill(Geometry.cells.filter { board.value(at: $0) == digit }, .blocker)

        case .pointing, .claiming:
            if let house {
                highlights.fill([house])
                for cell in house.cells where board.candidates(at: cell).contains(digit) {
                    highlights.mark([digit], in: cell, as: .emphasized)
                }
            }

        case .nakedPair, .nakedTriple, .nakedQuad:
            // Cells with only a few candidates are where naked subsets hide.
            if let house {
                highlights.fill([house])
                showCandidates(in: house.cells, on: board, into: &highlights)
                for cell in house.cells where board.value(at: cell) == 0 && board.candidates(at: cell).count <= step.patternCells.count {
                    highlights.mark(board.candidates(at: cell), in: cell, as: .emphasized)
                }
            }

        case .hiddenPair, .hiddenTriple, .hiddenQuad:
            if let house {
                highlights.fill([house])
                showCandidates(in: house.cells, on: board, into: &highlights)
            }

        case .xWing, .swordfish, .jellyfish, .finnedXWing, .finnedSwordfish, .skyscraper, .twoStringKite,
             .xChain, .simpleColoring, .emptyRectangle:
            // Every house where the digit has exactly two spots: the strong links these patterns use.
            showStrongLinks(of: digit, on: board, into: &highlights)

        case .xyWing, .xyzWing, .wWing, .remotePair, .xyChain, .bug, .alsXZ:
            // Two-candidate cells: wings and XY-Chains are built from them.
            showBivalueCells(on: board, into: &highlights)

        case .uniqueRectangleType1, .uniqueRectangleType2, .uniqueRectangleType4:
            // Cells holding the same pair, which may form corners of a rectangle.
            for cell in board.emptyCells where board.candidates(at: cell) == step.patternDigits {
                highlights.fill([cell], .house)
                highlights.mark(step.patternDigits, in: cell, as: .emphasized)
            }

        case .aic:
            showBivalueCells(on: board, into: &highlights)
            if let start = step.chain.first {
                showStrongLinks(of: start.digit, on: board, into: &highlights)
            }
        }
        return highlights
    }

    private static func showCandidates(in cells: [CellIndex], on board: Board, into highlights: inout HintHighlights) {
        for cell in cells where board.value(at: cell) == 0 {
            highlights.showCandidates(board.candidates(at: cell), in: cell)
        }
    }

    private static func showStrongLinks(of digit: Digit, on board: Board, into highlights: inout HintHighlights) {
        for house in Geometry.houses {
            let cells = board.cells(in: house, withCandidate: digit)
            guard cells.count == 2 else { continue }
            highlights.link(cells[0], cells[1], digit: digit, isStrong: true)
            for cell in cells {
                highlights.mark([digit], in: cell, as: .emphasized)
            }
        }
    }

    private static func showBivalueCells(on board: Board, into highlights: inout HintHighlights) {
        for cell in board.emptyCells where board.candidates(at: cell).count == 2 {
            highlights.fill([cell], .house)
            highlights.mark(board.candidates(at: cell), in: cell, as: .emphasized)
        }
    }
}
