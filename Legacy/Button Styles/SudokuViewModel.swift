import SwiftUI
import Combine

class SudokuViewModel: ObservableObject {
    // 9x9 Sudoku board, 0 represents empty cell
    @Published var board: [[Int]]
    // 9x9 Bool grid indicating which cells are given (immutable)
    @Published var given: [[Bool]]
    // Selected cell position (row, col), nil if none selected
    @Published var selectedPosition: (row: Int, col: Int)?
    // Difficulty level for new game generation
    @Published var difficulty: Difficulty = .medium
    // Undo stack storing previous board states
    private var undoStack: [[[Int]]] = []
    // Notes for cells (optional): 9x9 grid of sets of possible numbers
    @Published var notes: [[Set<Int>]]
    
    enum Difficulty {
        case easy, medium, hard
    }
    
    init() {
        // Initialize empty board and given arrays
        board = Array(repeating: Array(repeating: 0, count: 9), count: 9)
        given = Array(repeating: Array(repeating: false, count: 9), count: 9)
        notes = Array(repeating: Array(repeating: Set<Int>(), count: 9), count: 9)
        newGame()
    }
    
    // MARK: - Game Setup
    
    func newGame() {
        // Generate a new Sudoku puzzle based on difficulty
        let puzzle = SudokuGenerator.generate(difficulty: difficulty)
        board = puzzle.board
        given = puzzle.given
        notes = Array(repeating: Array(repeating: Set<Int>(), count: 9), count: 9)
        undoStack.removeAll()
        selectedPosition = nil
    }
    
    // MARK: - Input Handling
    
    func selectCell(row: Int, col: Int) {
        guard row >= 0 && row < 9 && col >= 0 && col < 9 else { return }
        selectedPosition = (row, col)
    }
    
    func setNumber(_ number: Int) {
        guard let pos = selectedPosition else { return }
        guard number >= 1 && number <= 9 else { return }
        guard !given[pos.row][pos.col] else { return }
        // Save current state for undo
        undoStack.append(board.map { $0 })
        // Set number
        board[pos.row][pos.col] = number
        // Clear notes for cell
        notes[pos.row][pos.col].removeAll()
    }
    
    func clearCell() {
        guard let pos = selectedPosition else { return }
        guard !given[pos.row][pos.col] else { return }
        undoStack.append(board.map { $0 })
        board[pos.row][pos.col] = 0
        notes[pos.row][pos.col].removeAll()
    }
    
    // Optional notes handling stub
    
    func toggleNote(_ number: Int) {
        guard let pos = selectedPosition else { return }
        guard !given[pos.row][pos.col] else { return }
        if notes[pos.row][pos.col].contains(number) {
            notes[pos.row][pos.col].remove(number)
        } else {
            notes[pos.row][pos.col].insert(number)
        }
    }
    
    // MARK: - Undo
    
    func undo() {
        guard let prev = undoStack.popLast() else { return }
        board = prev
    }
    
    // MARK: - Validation
    
    func isValid() -> Bool {
        // Check every row, column, and 3x3 box for duplicates (excluding zeros)
        for i in 0..<9 {
            var rowSet = Set<Int>()
            var colSet = Set<Int>()
            var boxSet = Set<Int>()
            for j in 0..<9 {
                let rowVal = board[i][j]
                if rowVal != 0 {
                    if rowSet.contains(rowVal) { return false }
                    rowSet.insert(rowVal)
                }
                let colVal = board[j][i]
                if colVal != 0 {
                    if colSet.contains(colVal) { return false }
                    colSet.insert(colVal)
                }
                let boxRow = (i / 3) * 3 + j / 3
                let boxCol = (i % 3) * 3 + j % 3
                let boxVal = board[boxRow][boxCol]
                if boxVal != 0 {
                    if boxSet.contains(boxVal) { return false }
                    boxSet.insert(boxVal)
                }
            }
        }
        return true
    }
    
    func isComplete() -> Bool {
        for row in 0..<9 {
            for col in 0..<9 {
                if board[row][col] == 0 { return false }
            }
        }
        return isValid()
    }
}

// MARK: - Puzzle Generator (simple stub)

fileprivate struct SudokuPuzzle {
    let board: [[Int]]
    let given: [[Bool]]
}

fileprivate struct SudokuGenerator {
    static func generate(difficulty: SudokuViewModel.Difficulty) -> SudokuPuzzle {
        // For simplicity, return a fixed puzzle with given cells marked
        
        // Example puzzle (partial)
        let puzzle: [[Int]] = [
            [5,3,0,0,7,0,0,0,0],
            [6,0,0,1,9,5,0,0,0],
            [0,9,8,0,0,0,0,6,0],
            [8,0,0,0,6,0,0,0,3],
            [4,0,0,8,0,3,0,0,1],
            [7,0,0,0,2,0,0,0,6],
            [0,6,0,0,0,0,2,8,0],
            [0,0,0,4,1,9,0,0,5],
            [0,0,0,0,8,0,0,7,9]
        ]
        
        var given = Array(repeating: Array(repeating: false, count: 9), count: 9)
        for r in 0..<9 {
            for c in 0..<9 {
                given[r][c] = puzzle[r][c] != 0
            }
        }
        
        return SudokuPuzzle(board: puzzle, given: given)
    }
}
