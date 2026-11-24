import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = SudokuViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar with New Game button and Difficulty picker
            HStack {
                Button("New Game") {
                    viewModel.newGame()
                }
                .buttonStyle(PlayButton())

                Spacer()

                Picker("Difficulty", selection: $viewModel.difficulty) {
                    ForEach(SudokuViewModel.Difficulty.allCases, id: \.self) { difficulty in
                        Text(difficulty.rawValue.capitalized).tag(difficulty)
                    }
                }
                .pickerStyle(MenuPickerStyle())
            }
            .padding()

            // Sudoku grid
            SudokuGridView(grid: $viewModel.grid, selectedCell: $viewModel.selectedCell)

            // Number pad
            NumberPad(selectedNumber: $viewModel.selectedNumber, onSelect: viewModel.enterNumber)
                .padding(.vertical)
        }
    }
}

// MARK: - SudokuGridView

struct SudokuGridView: View {
    @Binding var grid: [[Int]]
    @Binding var selectedCell: (row: Int, col: Int)?

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let cellSize = size / 9

            VStack(spacing: 0) {
                ForEach(0..<9, id: \.self) { row in
                    HStack(spacing: 0) {
                        ForEach(0..<9, id: \.self) { col in
                            let number = grid[row][col]
                            CellView(number: number, isSelected: selectedCell?.row == row && selectedCell?.col == col)
                                .frame(width: cellSize, height: cellSize)
                                .border(lineWidth: (col % 3 == 2 && col != 8) ? 2 : 1, color: .black, edges: [.trailing])
                                .border(lineWidth: (row % 3 == 2 && row != 8) ? 2 : 1, color: .black, edges: [.bottom])
                                .onTapGesture {
                                    selectedCell = (row, col)
                                }
                        }
                    }
                }
            }
            .frame(width: size, height: size)
            .border(Color.black, width: 2)
            .padding()
        }
        .aspectRatio(1, contentMode: .fit)
    }

    struct CellView: View {
        let number: Int
        let isSelected: Bool

        var body: some View {
            ZStack {
                Rectangle()
                    .foregroundColor(isSelected ? Color.blue.opacity(0.3) : Color.white)
                if number != 0 {
                    Text("\(number)")
                        .font(.title2)
                        .foregroundColor(.black)
                }
            }
        }
    }
}

// MARK: - NumberPad

struct NumberPad: View {
    @Binding var selectedNumber: Int?
    var onSelect: (Int?) -> Void

    private let numbers = Array(1...9)

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                // Clear button
                Button(action: {
                    selectedNumber = nil
                    onSelect(nil)
                }) {
                    Text("Clear")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red.opacity(0.7))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
            HStack(spacing: 8) {
                ForEach(numbers.prefix(3), id: \.self) { number in
                    NumberButton(number: number, selectedNumber: $selectedNumber, onSelect: onSelect)
                }
            }
            HStack(spacing: 8) {
                ForEach(numbers[3..<6], id: \.self) { number in
                    NumberButton(number: number, selectedNumber: $selectedNumber, onSelect: onSelect)
                }
            }
            HStack(spacing: 8) {
                ForEach(numbers[6..<9], id: \.self) { number in
                    NumberButton(number: number, selectedNumber: $selectedNumber, onSelect: onSelect)
                }
            }
        }
        .padding(.horizontal)
    }

    struct NumberButton: View {
        let number: Int
        @Binding var selectedNumber: Int?
        var onSelect: (Int?) -> Void

        var isSelected: Bool { selectedNumber == number }

        var body: some View {
            Button {
                selectedNumber = number
                onSelect(number)
            } label: {
                Text("\(number)")
                    .font(.title2)
                    .frame(maxWidth: .infinity, maxHeight: 44)
                    .background(isSelected ? Color.blue.opacity(0.7) : Color.gray.opacity(0.2))
                    .foregroundColor(isSelected ? .white : .black)
                    .cornerRadius(8)
            }
        }
    }
}
