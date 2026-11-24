//
//  CellView.swift
//  Sudoku
//
//  Created by Emre Kaya on 26.10.2024.
//

import SwiftUI

struct CellView: View {
    
    let cell: Cell
    
    var body: some View {
        
        Button(action: {
            
        }) {
            Grid {
                if cell.value == nil {
                    ForEach((0...2), id: \.self) { r in
                        GridRow {
                            ForEach((1...3), id: \.self) { c in
                                let val = c + r * 3
                                Text("\(val)")
                                    .foregroundColor(.gray)
                                    .opacity(cell.notes.contains(val) ? 1 : 0)
                                    .italic()
                            }
                        }
                    }
                } else {
                    Text("\(cell.value ?? 0)")
                        .foregroundColor(cell.fixed ? .black : .blue)
                        .bold(cell.fixed)
                        .font(.system(size: 20))
                }
            }
        }.background(cell.selected ? .selectedCell : .white)
    }
}

#Preview {
    CellView(cell: .init(row: 0, column: 0, value: nil, notes: [1,2,3,4,5,6,7,8,9], fixed: false, selected: true))
    CellView(cell: Cell.fixed(row: 0, column: 0, value: 1))
    CellView(cell: .init(row: 0, column: 0, value: 1, notes: [], fixed: true, selected: false))
    CellView(cell: .init(row: 0, column: 0, value: 1, notes: [], fixed: false, selected: false))
}
