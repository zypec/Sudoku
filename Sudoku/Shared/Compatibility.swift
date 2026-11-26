//
//  Compatibility.swift
//  Sudoku
//

import SwiftUI

// The app runs from iOS 17 on. Liquid Glass (iOS 26) and the zoom transition (iOS 18) are used where
// the system has them; below that, the closest older look takes their place here, in one file, so the
// screens call one name and never check the version themselves.

extension View {
    /// Liquid Glass in `shape`, or a material in it before iOS 26. A tint colors either; `interactive`
    /// makes the glass respond to touch.
    @ViewBuilder
    func glassOrMaterial<S: Shape>(in shape: S, tint: Color? = nil, interactive: Bool = false) -> some View {
        if #available(iOS 26, *) {
            glassEffect(glass(tint: tint, interactive: interactive), in: shape)
        } else {
            background {
                ZStack {
                    shape.fill(.regularMaterial)
                    if let tint {
                        shape.fill(tint.opacity(0.18))
                    }
                }
            }
        }
    }

    @available(iOS 26, *)
    private func glass(tint: Color?, interactive: Bool) -> Glass {
        var glass = Glass.regular
        if let tint {
            glass = glass.tint(tint)
        }
        return interactive ? glass.interactive() : glass
    }

    /// Ties glass to others of the same id, so changing between them morphs (iOS 26 on).
    @ViewBuilder
    func glassID(_ id: some Hashable & Sendable, in namespace: Namespace.ID) -> some View {
        if #available(iOS 26, *) {
            glassEffectID(id, in: namespace)
        } else {
            self
        }
    }

    /// The prominent glass button style, or a filled capsule before iOS 26.
    @ViewBuilder
    func glassProminentButton() -> some View {
        if #available(iOS 26, *) {
            buttonStyle(.glassProminent)
        } else {
            buttonStyle(.borderedProminent).buttonBorderShape(.capsule)
        }
    }

    /// The glass button style, or a tinted capsule before iOS 26.
    @ViewBuilder
    func glassButton() -> some View {
        if #available(iOS 26, *) {
            buttonStyle(.glass)
        } else {
            buttonStyle(.bordered).buttonBorderShape(.capsule)
        }
    }

    /// A sheet that zooms out of the view marked with `zoomSource(id:in:)` (iOS 18 on); before, it
    /// slides up as sheets do.
    @ViewBuilder
    func zoomTransition(sourceID: some Hashable, in namespace: Namespace.ID) -> some View {
        if #available(iOS 18, *) {
            navigationTransition(.zoom(sourceID: sourceID, in: namespace))
        } else {
            self
        }
    }

    /// Where a `zoomTransition` grows from (iOS 18 on).
    @ViewBuilder
    func zoomSource(id: some Hashable, in namespace: Namespace.ID) -> some View {
        if #available(iOS 18, *) {
            matchedTransitionSource(id: id, in: namespace)
        } else {
            self
        }
    }
}

/// Glass shapes that sit together and blend and morph as one (iOS 26 on); before, just the content.
struct GlassGroup<Content: View>: View {
    var spacing: CGFloat? = nil
    @ViewBuilder let content: Content

    var body: some View {
        if #available(iOS 26, *) {
            GlassEffectContainer(spacing: spacing) {
                content
            }
        } else {
            content
        }
    }
}

/// The toolbar's close button: the system's round one from iOS 26, an xmark before.
struct CloseButton: View {
    let action: () -> Void

    var body: some View {
        if #available(iOS 26, *) {
            Button(role: .close, action: action)
        } else {
            Button("Close", systemImage: "xmark", action: action)
        }
    }
}
