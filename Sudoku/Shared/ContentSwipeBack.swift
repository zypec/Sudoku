//
//  ContentSwipeBack.swift
//  Sudoku
//

import SwiftUI
import UIKit

extension View {
    /// Turns off the "swipe anywhere to go back" gesture while this view is on screen, so dragging
    /// across content (like the board) never leaves the screen by accident. Swiping from the left
    /// edge still goes back.
    func disablesContentSwipeBack() -> some View {
        background(ContentSwipeBackDisabler())
    }
}

/// SwiftUI has no modifier for the content pop gesture, so a hidden child view controller reaches
/// the navigation controller and switches it off while the screen is visible.
private struct ContentSwipeBackDisabler: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> Controller {
        Controller()
    }

    func updateUIViewController(_ controller: Controller, context: Context) {}

    final class Controller: UIViewController {
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            navigationController?.interactiveContentPopGestureRecognizer?.isEnabled = false
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            navigationController?.interactiveContentPopGestureRecognizer?.isEnabled = true
        }
    }
}
