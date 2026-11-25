//
//  TechniqueGuide.swift
//  Sudoku
//

import Foundation

/// A plain-language explanation of a technique for players who don't know it yet: the rule itself
/// and how to find it on a board. Used by the detailed hint explanation and the training library.
struct TechniqueGuide {
    let howItWorks: String
    let howToSpot: String
}

extension TechniqueKind {
    /// Cells (or digits) in a subset, or lines in a fish.
    private var size: Int {
        switch self {
        case .nakedPair, .hiddenPair: 2
        case .nakedTriple, .hiddenTriple, .swordfish, .finnedSwordfish: 3
        case .nakedQuad, .hiddenQuad, .jellyfish: 4
        default: 2
        }
    }

    var guide: TechniqueGuide {
        let size = size
        switch self {
        case .fullHouse:
            return TechniqueGuide(
                howItWorks: String(localized: "When a row, column or box has only one empty cell left, that cell gets the one digit the house is still missing."),
                howToSpot: String(localized: "Look for houses with eight digits already filled in.")
            )
        case .hiddenSingle:
            return TechniqueGuide(
                howItWorks: String(localized: "Every house needs each digit exactly once. If a digit has only one cell left in a house, because every other empty cell already sees that digit, it must go there, even if the cell itself still has other candidates."),
                howToSpot: String(localized: "Pick a digit and a house, then rule out the cells that see that digit in their row, column or box. Boxes are usually the easiest place to start.")
            )
        case .nakedSingle:
            return TechniqueGuide(
                howItWorks: String(localized: "A cell's candidates are the digits not yet in its row, column or box. When only one candidate is left, that digit goes in the cell."),
                howToSpot: String(localized: "Look for cells whose row, column and box together already hold eight different digits, or cells with a single note.")
            )
        case .pointing:
            return TechniqueGuide(
                howItWorks: String(localized: "If, inside a box, a digit can only go in cells that are all in one row or column, the box's copy of that digit is in that line. So no cell of that line outside the box can hold it."),
                howToSpot: String(localized: "In each box, check where a digit can go. If the spots form a straight line, look along that line outside the box.")
            )
        case .claiming:
            return TechniqueGuide(
                howItWorks: String(localized: "If, inside a row or column, a digit can only go in cells that are all in one box, the line's copy of that digit is in that box. So no other cell of the box can hold it."),
                howToSpot: String(localized: "In each row and column, check where a digit can go. If all the spots fall in one box, the rest of that box loses the digit.")
            )
        case .nakedPair, .nakedTriple, .nakedQuad:
            return TechniqueGuide(
                howItWorks: String(localized: "If \(size) cells in a house together have only \(size) candidates, those digits must fill exactly those cells. So none of them can go anywhere else in the house."),
                howToSpot: String(localized: "Look for two cells with the same two notes, or three cells whose notes use only three digits between them. Each cell doesn't need every digit.")
            )
        case .hiddenPair, .hiddenTriple, .hiddenQuad:
            return TechniqueGuide(
                howItWorks: String(localized: "If \(size) digits can only go in the same \(size) cells of a house, those cells must hold exactly these digits. Any other candidate in those cells can be removed."),
                howToSpot: String(localized: "Count where each digit can go in a house. Digits limited to the same few cells point to a hidden subset, often hidden among many other notes.")
            )
        case .xWing:
            return TechniqueGuide(
                howItWorks: String(localized: "If a digit fits in exactly two cells in each of two rows, and those cells sit in the same two columns, the digit must take two opposite corners of that rectangle. Either way both columns get their copy there, so the digit can be removed from the rest of those columns. The same works with rows and columns swapped."),
                howToSpot: String(localized: "Pick a digit and look for rows or columns where it has only two spots. Two of them lining up form an X-Wing.")
            )
        case .swordfish, .jellyfish:
            return TechniqueGuide(
                howItWorks: String(localized: "This is an X-Wing with \(size) lines. If, in \(size) rows, a digit fits only in cells within the same \(size) columns, those rows use up the digit in each of those columns. So it can be removed from the rest of the columns."),
                howToSpot: String(localized: "Look for a digit with two or three spots in several rows, all within the same few columns. Not every row needs a spot in every column.")
            )
        case .finnedXWing, .finnedSwordfish:
            return TechniqueGuide(
                howItWorks: String(localized: "A finned fish is an X-Wing or Swordfish with one or two extra cells, the fin, inside a single box. If the fin doesn't hold the digit, the fish works as usual; if it does, it rules out the cells it sees. Cells hit in both cases, in the fin's box and in the fish's columns, lose the digit."),
                howToSpot: String(localized: "Look for an almost X-Wing where one row has an extra spot near a corner, in the same box as that corner.")
            )
        case .skyscraper:
            return TechniqueGuide(
                howItWorks: String(localized: "Two rows each have a digit in exactly two cells, and one end of each pair is in the same column. Those two ends see each other, so at most one of them holds the digit, which means at least one of the other two ends does. A cell that sees both of those ends can't hold it."),
                howToSpot: String(localized: "Look for two rows (or columns) where a digit has only two spots, lined up at one end but not at the other.")
            )
        case .twoStringKite:
            return TechniqueGuide(
                howItWorks: String(localized: "A row and a column each have a digit in exactly two cells, and one cell of each pair sits in the same box. Those two can't both hold the digit, so at least one of the far ends does. A cell that sees both far ends can't hold it."),
                howToSpot: String(localized: "Look for a row pair and a column pair on the same digit that meet in a box.")
            )
        case .xyWing:
            return TechniqueGuide(
                howItWorks: String(localized: "A pivot cell with two candidates, X and Y, sees two cells with XZ and YZ. Whatever the pivot holds, one of the two other cells becomes Z. So any cell that sees both of them can't be Z."),
                howToSpot: String(localized: "Look at cells with exactly two notes. One that shares a digit with each of two others, which in turn share a third digit, forms a wing.")
            )
        case .xyzWing:
            return TechniqueGuide(
                howItWorks: String(localized: "Like an XY-Wing, but the pivot has all three digits X, Y and Z. Then Z is in the pivot or in one of the other two cells, so only cells that see all three lose Z."),
                howToSpot: String(localized: "Look for a cell with three notes next to two cells with two notes that use only its digits.")
            )
        case .wWing:
            return TechniqueGuide(
                howItWorks: String(localized: "Two cells have the same two candidates, X and Y, but don't see each other. If X fits in only two cells of some house, one seeing each of them, then one of the two cells must be Y. A cell that sees both can't be Y."),
                howToSpot: String(localized: "Find two identical two-note cells far apart, then a house where one of their digits has only two spots, one near each.")
            )
        case .emptyRectangle:
            return TechniqueGuide(
                howItWorks: String(localized: "When a box's candidates for a digit all lie on one row and one column of the box, the box's copy of that digit is on that row or on that column. Combined with a house elsewhere where the digit has only two spots, this rules out the cell where both possibilities meet."),
                howToSpot: String(localized: "Look for a box where a digit's notes form an L or a cross, then a row or column with only two spots for that digit.")
            )
        case .simpleColoring:
            return TechniqueGuide(
                howItWorks: String(localized: "Follow the houses where a digit has exactly two spots, and color the cells along them alternately in two colors. One color holds the digit everywhere, the other nowhere. If two cells of the same color see each other, that color is the false one. A cell that sees both colors can't hold the digit."),
                howToSpot: String(localized: "Pick a digit that has many houses with only two spots and trace the chain they form.")
            )
        case .uniqueRectangleType1, .uniqueRectangleType2, .uniqueRectangleType4:
            return TechniqueGuide(
                howItWorks: String(localized: "A proper puzzle has exactly one solution. Four cells in two rows, two columns and two boxes that could all end up as only A or B would allow two solutions, since A and B could be swapped. So the solution must break the pattern, and depending on the other candidates in the corners, that rules out digits in the corners or around them."),
                howToSpot: String(localized: "Look for cells with the same pair of notes forming three or four corners of a rectangle that spans two boxes.")
            )
        case .bug:
            return TechniqueGuide(
                howItWorks: String(localized: "If every empty cell had exactly two candidates, the puzzle would have two solutions. So when all cells but one have two candidates and that one has three, its extra digit, the one that appears three times in its house, must be its solution."),
                howToSpot: String(localized: "Late in a puzzle, check whether almost every empty cell has just two notes.")
            )
        case .remotePair:
            return TechniqueGuide(
                howItWorks: String(localized: "In a chain of cells that all have the same two candidates, each seeing the next, the two digits alternate along the chain. Cells an odd number of steps apart hold different digits, so a cell that sees both can hold neither."),
                howToSpot: String(localized: "Look for several cells with the same pair of notes that link up through rows, columns and boxes.")
            )
        case .xChain:
            return TechniqueGuide(
                howItWorks: String(localized: "A chain on one digit alternates strong links (a house where the digit has exactly two spots) and weak links (two spots that see each other). If it starts and ends with a strong link, at least one of its ends holds the digit, so a cell that sees both ends can't."),
                howToSpot: String(localized: "Follow the houses where a digit has two spots, hopping between them through cells that see each other.")
            )
        case .xyChain:
            return TechniqueGuide(
                howItWorks: String(localized: "A chain of two-candidate cells, each sharing a digit with the next. If the first cell isn't X, the chain forces the last cell to be X. So one of the two ends is X, and a cell that sees both can't be X."),
                howToSpot: String(localized: "Start at a cell with two notes and keep stepping to a cell it sees that shares one of its digits.")
            )
        case .aic:
            return TechniqueGuide(
                howItWorks: String(localized: "An alternating inference chain mixes every kind of link: strong links in houses or inside two-candidate cells, and weak links between candidates that can't both be true. Starting and ending with a strong link proves that one of its two ends is true, which rules out anything that contradicts both."),
                howToSpot: String(localized: "When nothing simpler works, follow pairs and two-note cells and see where an assumption leads.")
            )
        case .alsXZ:
            return TechniqueGuide(
                howItWorks: String(localized: "An almost locked set is a group of cells in one house with one more candidate than cells. If two such groups share a digit X and every X in one sees every X in the other, at most one holds X. The other is then locked and holds all its other digits, so a digit Z they share is in at least one group, and a cell that sees every Z in both can't be Z."),
                howToSpot: String(localized: "Look for two-note cells and small groups of cells with one extra candidate, connected by a digit they both contain.")
            )
        }
    }
}
