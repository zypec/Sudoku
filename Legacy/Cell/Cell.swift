//
//  A.swift
//  Sudoku
//
//  Created by Emre Kaya on 26.10.2024.
//

struct Cell: Codable {

    var row: Int
    var column: Int
    var value: Int?
    var notes: [Int]
    var fixed: Bool
    var selected: Bool
 
    static func fixed(row: Int, column: Int, value: Int) -> Self {
        return .init(row: row, column: column, value: value, notes: [], fixed: true, selected: false)
    }
    
}
