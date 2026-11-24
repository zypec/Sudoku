//
//  CandidateSet.swift
//  Sudoku
//

/// A set of digits `1...9` stored as a bitmask (bit `d` set means digit `d` is present).
struct CandidateSet: Hashable, Sendable, Codable {
    private static let allMask: UInt16 = 0b11_1111_1110

    static let empty = CandidateSet()
    static let all = CandidateSet(rawValue: allMask)

    private(set) var rawValue: UInt16

    init() {
        rawValue = 0
    }

    init(rawValue: UInt16) {
        self.rawValue = rawValue & Self.allMask
    }

    init(_ digits: some Sequence<Digit>) {
        rawValue = 0
        for digit in digits {
            insert(digit)
        }
    }

    var count: Int { rawValue.nonzeroBitCount }
    var isEmpty: Bool { rawValue == 0 }

    /// The only digit in the set, or `nil` if the set doesn't contain exactly one digit.
    var single: Digit? {
        count == 1 ? rawValue.trailingZeroBitCount : nil
    }

    func contains(_ digit: Digit) -> Bool {
        Geometry.digits.contains(digit) && rawValue & (1 << digit) != 0
    }

    mutating func insert(_ digit: Digit) {
        precondition(Geometry.digits.contains(digit), "Invalid digit \(digit)")
        rawValue |= 1 << digit
    }

    mutating func remove(_ digit: Digit) {
        guard Geometry.digits.contains(digit) else { return }
        rawValue &= ~(1 << digit)
    }

    func union(_ other: CandidateSet) -> CandidateSet {
        CandidateSet(rawValue: rawValue | other.rawValue)
    }

    func intersection(_ other: CandidateSet) -> CandidateSet {
        CandidateSet(rawValue: rawValue & other.rawValue)
    }

    func subtracting(_ other: CandidateSet) -> CandidateSet {
        CandidateSet(rawValue: rawValue & ~other.rawValue)
    }

    func isSuperset(of other: CandidateSet) -> Bool {
        other.rawValue & ~rawValue == 0
    }
}

extension CandidateSet: Sequence {
    /// Iterates digits in ascending order.
    struct Iterator: IteratorProtocol {
        fileprivate var bits: UInt16

        mutating func next() -> Digit? {
            guard bits != 0 else { return nil }
            let digit = bits.trailingZeroBitCount
            bits &= bits - 1
            return digit
        }
    }

    func makeIterator() -> Iterator {
        Iterator(bits: rawValue)
    }

    var underestimatedCount: Int { count }
}

extension CandidateSet: ExpressibleByArrayLiteral {
    init(arrayLiteral digits: Digit...) {
        self.init(digits)
    }
}

extension CandidateSet: CustomStringConvertible {
    var description: String {
        "{" + map(String.init).joined() + "}"
    }
}
