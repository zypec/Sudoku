//
//  HintStylingTests.swift
//  SudokuTests
//

import SwiftUI
import Testing
@testable import Sudoku

@MainActor
@Suite("Hint styling")
struct HintStylingTests {
    /// The parts of `text` drawn in the accent color, and those drawn in a heavier weight.
    private func marked(_ text: String) -> (accent: [String], bold: [String]) {
        let styled = HintStyling.styled(text)
        var accent: [String] = [], bold: [String] = []
        for run in styled.runs {
            let part = String(styled[run.range].characters)
            if run.foregroundColor == .accentColor {
                accent.append(part)
            } else if run.font != nil {
                bold.append(part)
            }
        }
        return (accent, bold)
    }

    @Test func digitsAndPlacesArePickedOut() {
        let (accent, bold) = marked("Then the cell at row 9, column 8 must be 7.")
        #expect(accent == ["7"])
        #expect(bold == ["row 9, column 8"])
    }

    @Test func countersAreNotDigits() {
        let (accent, bold) = marked("Case 1 of 2: suppose 8 is in the cell at row 3, column 2.")
        #expect(accent == ["8"])
        #expect(bold == ["row 3, column 2"])
        #expect(marked("Remove the candidates it rules out (3 of 5).").accent.isEmpty)
    }

    @Test func houseNamesAndDigitLists() {
        let (accent, bold) = marked("In box 4, 2 and 6 fit only in row 5.")
        #expect(accent == ["2", "6"])
        #expect(bold == ["box 4", "row 5"])
    }
}
