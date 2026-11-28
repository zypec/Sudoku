//
//  Motion.swift
//  Sudoku
//

import SwiftUI

/// The app's animation timings in one place. A bare `.snappy` lasts half a second, which feels
/// sluggish for controls tapped many times a minute, so views use these instead.
extension Animation {
    /// A change the player causes with a tap and expects at once: notes mode, a button filling in,
    /// a counter ticking.
    static let quick = Animation.snappy(duration: 0.18)
    /// Panels, overlays and board highlights coming and going.
    static let panel = Animation.snappy(duration: 0.25)
}
