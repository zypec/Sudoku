//
//  Game.swift
//  Sudoku
//
//  Created by Emre Kaya on 26.10.2024.
//

struct Game: Codable {
 
    var activeCell: Cell?
    var cells: [Cell]
    
    func generateDefaults() {
        
    }
}
