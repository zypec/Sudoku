//
//  AppFont.swift
//  Sudoku
//

import SwiftUI
import UIKit

/// The app's type: Helvetica Neue, as the project's site sets its words, in every text style and still
/// scaling with Dynamic Type. Helvetica Neue has no semibold, so semibold is set in Medium and anything
/// heavier than bold in Bold.
extension Font {
    /// A text style in Helvetica Neue, at the size the style has and growing with it.
    static func app(_ style: Font.TextStyle, weight: Font.Weight? = nil) -> Font {
        .custom(AppFont.name(for: weight ?? AppFont.defaultWeight(of: style)), size: AppFont.size(of: style), relativeTo: style)
    }

    /// A fixed size in Helvetica Neue that still grows with Dynamic Type, the way `style` does.
    static func app(size: CGFloat, weight: Font.Weight = .regular, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom(AppFont.name(for: weight), size: size, relativeTo: style)
    }
}

enum AppFont {
    static func name(for weight: Font.Weight) -> String {
        switch weight {
        case .ultraLight: "HelveticaNeue-UltraLight"
        case .thin: "HelveticaNeue-Thin"
        case .light: "HelveticaNeue-Light"
        case .medium, .semibold: "HelveticaNeue-Medium"
        case .bold, .heavy, .black: "HelveticaNeue-Bold"
        default: "HelveticaNeue"
        }
    }

    /// The sizes of the text styles at the default Dynamic Type setting.
    static func size(of style: Font.TextStyle) -> CGFloat {
        switch style {
        case .largeTitle: 34
        case .title: 28
        case .title2: 22
        case .title3: 20
        case .headline, .body: 17
        case .callout: 16
        case .subheadline: 15
        case .footnote: 13
        case .caption: 12
        case .caption2: 11
        default: 17
        }
    }

    /// The weight each style has in the system: headlines are semibold, everything else regular.
    static func defaultWeight(of style: Font.TextStyle) -> Font.Weight {
        style == .headline ? .semibold : .regular
    }

    /// Navigation bar titles in Helvetica Neue too, since the bar is drawn by UIKit.
    @MainActor
    static func styleNavigationBars() {
        let appearance = UINavigationBar.appearance()
        if let title = UIFont(name: name(for: .semibold), size: 17) {
            appearance.titleTextAttributes = [.font: UIFontMetrics(forTextStyle: .headline).scaledFont(for: title)]
        }
        if let large = UIFont(name: name(for: .bold), size: 34) {
            appearance.largeTitleTextAttributes = [.font: UIFontMetrics(forTextStyle: .largeTitle).scaledFont(for: large)]
        }
    }
}
