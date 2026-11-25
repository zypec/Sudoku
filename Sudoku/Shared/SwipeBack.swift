//
//  SwipeBack.swift
//  Sudoku
//

import SwiftUI
import UIKit

extension View {
    /// Turns off both swipe-back gestures (from the edge and from anywhere in the content) while this
    /// view is on screen, so it can only be left with the back button.
    func disablesSwipeBack() -> some View {
        background(SwipeBackDisabler())
    }
}

/// SwiftUI has no modifier for the pop gestures, so a hidden child view controller reaches the
/// navigation controller and switches them off while the screen is visible.
private struct SwipeBackDisabler: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> Controller {
        Controller()
    }

    func updateUIViewController(_ controller: Controller, context: Context) {}

    final class Controller: UIViewController {
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            setGesturesEnabled(false)
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            setGesturesEnabled(true)
        }

        private func setGesturesEnabled(_ isEnabled: Bool) {
            navigationController?.interactiveContentPopGestureRecognizer?.isEnabled = isEnabled
            navigationController?.interactivePopGestureRecognizer?.isEnabled = isEnabled
        }
    }
}
