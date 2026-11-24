//
//  Combinations.swift
//  Sudoku
//

extension Array {
    /// Every `size`-element combination of the array's elements, each keeping the original order.
    /// `[1, 2, 3].combinations(ofSize: 2)` is `[[1, 2], [1, 3], [2, 3]]`.
    func combinations(ofSize size: Int) -> [[Element]] {
        guard size > 0 else { return [[]] }
        guard size <= count else { return [] }

        var result: [[Element]] = []
        var indices = Array<Int>(0..<size)
        while true {
            result.append(indices.map { self[$0] })
            // Find the rightmost index that can still move right, advance it, and reset the ones after it.
            var position = size - 1
            while position >= 0 && indices[position] == count - size + position {
                position -= 1
            }
            guard position >= 0 else { return result }
            indices[position] += 1
            for next in (position + 1)..<size {
                indices[next] = indices[next - 1] + 1
            }
        }
    }
}
