//
//  RaceCode.swift
//  Sudoku
//

import Foundation

/// Crockford's base 32, as puzzle and training codes are written: no I, L, O or U, and an O or I typed
/// anyway is read as 0 or 1.
enum CrockfordBase32 {
    private static let alphabet = Array("0123456789ABCDEFGHJKMNPQRSTVWXYZ")

    /// `value` in exactly `digits` characters, most significant first.
    static func encode(_ value: UInt64, digits: Int) -> String {
        String((0..<digits).reversed().map { alphabet[Int((value >> UInt64($0 * 5)) & 31)] })
    }

    static func decode(_ text: some StringProtocol) -> UInt64? {
        var value: UInt64 = 0
        for character in text {
            let read: Character = switch character {
            case "O": "0"
            case "I", "L": "1"
            default: character
            }
            guard let digit = alphabet.firstIndex(of: read) else { return nil }
            value = value << 5 | UInt64(digit)
        }
        return value
    }

    /// A pasted code, upper-cased, without spaces and dashes.
    static func normalized(_ code: some StringProtocol) -> String {
        code.uppercased().filter { !$0.isWhitespace && $0 != "-" }
    }

    /// A short fingerprint of `text` (FNV-1a), the same on every device.
    static func fingerprint(_ text: String) -> UInt64 {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in text.utf8 {
            hash = (hash ^ UInt64(byte)) &* 0x100_0000_01b3
        }
        return hash
    }
}

/// The codes a race is played with, with no server: whoever starts a race shares its code, and each
/// player who finishes shares a result code that everyone adds to the race.
///
/// A race code is `R`, the puzzle's short code (`PuzzleCode`, 9 characters), the deadline in hours
/// since 2026 (4 characters) and two random characters that tell apart races on the same puzzle and
/// deadline: `RXXX-XXXX-XXXX-XXXX`.
///
/// A result code is a fingerprint of its race (3 characters), the moment it was finished in minutes
/// since 2026 (5), the solving time in seconds (4) and a check over all of it and the player's name
/// (2), followed by the name: `XXX-XXXXX-XXXX-XX Emre`. The check keeps a mistyped or edited code from
/// counting; it isn't meant to stop a friend who wants to cheat.
enum RaceCode {
    /// The start of time for both codes.
    static let epoch = Date(timeIntervalSince1970: 1_767_225_600)  // 2026-01-01 00:00 UTC

    // MARK: Race

    static func raceCode(puzzleCode: String, deadline: Date, salt: UInt64) -> String? {
        let puzzle = CrockfordBase32.normalized(puzzleCode)
        guard puzzle.count == 9 else { return nil }
        let hours = UInt64(max(0, deadline.timeIntervalSince(epoch) / 3600).rounded(.up))
        let text = "R" + puzzle + CrockfordBase32.encode(hours, digits: 4) + CrockfordBase32.encode(salt & 1023, digits: 2)
        return stride(from: 0, to: 16, by: 4).map { start in
            String(text.dropFirst(start).prefix(4))
        }.joined(separator: "-")
    }

    /// The puzzle code and the deadline in a race code, or `nil` when it isn't one.
    static func parseRace(_ code: String) -> (puzzleCode: String, deadline: Date, id: String)? {
        let text = CrockfordBase32.normalized(code)
        guard text.count == 16, text.first == "R", let hours = CrockfordBase32.decode(text.dropFirst(10).prefix(4)),
              CrockfordBase32.decode(text.dropFirst()) != nil
        else { return nil }
        return (String(text.dropFirst().prefix(9)), epoch.addingTimeInterval(TimeInterval(hours) * 3600), text)
    }

    // MARK: Result

    struct Result: Hashable, Codable, Sendable {
        let name: String
        let finishedAt: Date
        let seconds: Int
        /// The code and the name, as shared.
        let code: String
    }

    static func resultCode(raceID: String, name: String, finishedAt: Date, seconds: Int) -> String {
        let tag = CrockfordBase32.fingerprint(raceID) & 0x7FFF
        let minutes = UInt64(max(0, finishedAt.timeIntervalSince(epoch) / 60))
        let body = CrockfordBase32.encode(tag, digits: 3) + CrockfordBase32.encode(minutes & 0x1FF_FFFF, digits: 5)
            + CrockfordBase32.encode(UInt64(max(0, min(seconds, 0xF_FFFF))), digits: 4)
        let check = CrockfordBase32.fingerprint(body + name) & 1023
        let text = body + CrockfordBase32.encode(check, digits: 2)
        let groups = "\(text.prefix(3))-\(text.dropFirst(3).prefix(5))-\(text.dropFirst(8).prefix(4))-\(text.suffix(2))"
        return name.isEmpty ? groups : "\(groups) \(name)"
    }

    /// The result in a result code of the race `raceID`; `nil` when it isn't one, belongs to another
    /// race, or was changed.
    static func parseResult(_ code: String, raceID: String) -> Result? {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        // The code is the first word; the rest is the name.
        let head = trimmed.prefix { !$0.isWhitespace }
        let name = trimmed.dropFirst(head.count).trimmingCharacters(in: .whitespaces)
        let text = CrockfordBase32.normalized(head)
        guard text.count == 14,
              let tag = CrockfordBase32.decode(text.prefix(3)),
              let minutes = CrockfordBase32.decode(text.dropFirst(3).prefix(5)),
              let seconds = CrockfordBase32.decode(text.dropFirst(8).prefix(4)),
              let check = CrockfordBase32.decode(text.suffix(2)),
              tag == CrockfordBase32.fingerprint(raceID) & 0x7FFF,
              check == CrockfordBase32.fingerprint(String(text.prefix(12)) + name) & 1023
        else { return nil }
        return Result(name: name, finishedAt: epoch.addingTimeInterval(TimeInterval(minutes) * 60), seconds: Int(seconds),
                      code: resultCode(raceID: raceID, name: name, finishedAt: epoch.addingTimeInterval(TimeInterval(minutes) * 60), seconds: Int(seconds)))
    }
}
