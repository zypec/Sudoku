//
//  SeededRandomNumberGenerator.swift
//  Sudoku
//

/// Deterministic SplitMix64 generator: the same seed yields the same sequence on every device and
/// OS version, which reproducible puzzles (e.g. the daily puzzle) rely on.
struct SeededRandomNumberGenerator: RandomNumberGenerator, Sendable {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

extension RandomNumberGenerator {
    /// An integer in `0..<upperBound` derived only from `next()`, so the result doesn't depend on the
    /// standard library's implementation of `next(upperBound:)`. The modulo bias is negligible here.
    mutating func stableIndex(below upperBound: Int) -> Int {
        precondition(upperBound > 0, "upperBound must be positive")
        return Int(next() % UInt64(upperBound))
    }
}

extension Array {
    /// Fisher–Yates shuffle that, unlike `shuffle(using:)`, is guaranteed to give the same order for
    /// the same generator state on every OS version.
    mutating func stableShuffle(using generator: inout some RandomNumberGenerator) {
        guard count > 1 else { return }
        for i in stride(from: count - 1, to: 0, by: -1) {
            swapAt(i, generator.stableIndex(below: i + 1))
        }
    }
}
