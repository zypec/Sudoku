import Foundation

// Represents a single cell in a Sudoku board
public struct SudokuCell: Hashable {
    public var value: Int? // nil if empty, else 1-9
    
    public init(value: Int? = nil) {
        if let v = value, (v < 1 || v > 9) {
            self.value = nil
        } else {
            self.value = value
        }
    }
    
    public var isEmpty: Bool {
        return value == nil
    }
}

// Represents a 9x9 Sudoku board
public struct SudokuBoard {
    public private(set) var grid: [[SudokuCell]]
    
    public init() {
        grid = Array(repeating: Array(repeating: SudokuCell(), count: 9), count: 9)
    }
    
    public subscript(row: Int, col: Int) -> SudokuCell {
        get {
            grid[row][col]
        }
        set {
            grid[row][col] = newValue
        }
    }
    
    public func isValid(row: Int, col: Int, value: Int) -> Bool {
        guard value >= 1 && value <= 9 else { return false }
        // Check row
        for c in 0..<9 {
            if c != col, grid[row][c].value == value {
                return false
            }
        }
        // Check column
        for r in 0..<9 {
            if r != row, grid[r][col].value == value {
                return false
            }
        }
        // Check 3x3 box
        let boxRowStart = (row / 3) * 3
        let boxColStart = (col / 3) * 3
        for r in boxRowStart..<boxRowStart+3 {
            for c in boxColStart..<boxColStart+3 {
                if r != row || c != col, grid[r][c].value == value {
                    return false
                }
            }
        }
        return true
    }
    
    public func isComplete() -> Bool {
        for row in 0..<9 {
            for col in 0..<9 {
                if grid[row][col].isEmpty {
                    return false
                }
            }
        }
        return true
    }
    
    // Solve the board using simple backtracking
    @discardableResult
    public mutating func solve() -> Bool {
        for row in 0..<9 {
            for col in 0..<9 {
                if grid[row][col].isEmpty {
                    for val in 1...9 {
                        if isValid(row: row, col: col, value: val) {
                            grid[row][col] = SudokuCell(value: val)
                            if solve() {
                                return true
                            } else {
                                grid[row][col] = SudokuCell()
                            }
                        }
                    }
                    return false
                }
            }
        }
        return true
    }
    
    // Generate a solved board by filling the board randomly and backtracking
    public static func generateSolved() -> SudokuBoard {
        var board = SudokuBoard()
        board.fillRandomly()
        _ = board.solve()
        return board
    }
    
    private mutating func fillRandomly() {
        var numbers = Array(1...9).shuffled()
        for col in 0..<9 {
            grid[0][col] = SudokuCell(value: numbers[col])
        }
    }
    
    // Generate a puzzle by removing numbers from a solved board
    public static func generatePuzzle(removeCount: Int = 40) -> SudokuBoard {
        var board = generateSolved()
        var removed = 0
        while removed < removeCount {
            let row = Int.random(in: 0..<9)
            let col = Int.random(in: 0..<9)
            if !board.grid[row][col].isEmpty {
                let backup = board.grid[row][col]
                board.grid[row][col] = SudokuCell()
                
                // Optional: Check for uniqueness of solution by attempting to solve
                // For minimal implementation, we skip uniqueness check
                
                removed += 1
            }
        }
        return board
    }
}
