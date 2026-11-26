//
//  HintPanel.swift
//  Sudoku
//

import SwiftUI

/// Floating Liquid Glass panel that walks through a hint page by page, forwards and backwards.
/// It takes the place of the controls and number pad and fills their space, so the board never
/// moves while the player reads. "Explain in Detail" switches to the visual explanation, which
/// plays the hint's proof on the board frame by frame and can run on its own.
struct HintPanel: View {
    let model: GameModel
    let activeHint: GameModel.ActiveHint

    @State private var isShowingGuide = false
    @State private var isPlaying = false
    @Namespace private var glassNamespace

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            ScrollView {
                // No crossfade: two sentences fading over each other are hard to read.
                Text(HintStyling.styled(activeHint.page.text))
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transaction { $0.animation = nil }
            }
            .scrollBounceBehavior(.basedOnSize)
            .frame(maxHeight: .infinity, alignment: .top)

            navigation
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .glassEffect(in: .rect(cornerRadius: 28))
        .animation(.snappy(duration: 0.2), value: activeHint.index)
        .sheet(isPresented: $isShowingGuide) {
            HintDetailSheet(model: model, hint: activeHint.hint)
        }
        // Auto play: one frame every few seconds until the end.
        .task(id: isPlaying ? activeHint.index : -1) {
            guard isPlaying else { return }
            try? await Task.sleep(for: .seconds(2.4))
            guard !Task.isCancelled else { return }
            if activeHint.canGoForward {
                model.showNextHintPage()
            } else {
                isPlaying = false
            }
        }
        .onChange(of: activeHint.isVisual) { _, isVisual in
            isPlaying = isVisual
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                // In a chain the title follows the technique of the page being read.
                Text(verbatim: activeHint.title ?? activeHint.page.technique?.title ?? HintText.title(for: activeHint.hint))
                    .font(.title3.bold())
                    .contentTransition(.opacity)
                if let subtitle = activeHint.page.technique.map({ String(localized: $0.subtitle) }) ?? HintText.subtitle(for: activeHint.hint) {
                    Text(verbatim: subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if !activeHint.hint.steps.isEmpty {
                if activeHint.isVisual {
                    PanelIconButton(title: "About the Technique", systemImage: "book") {
                        isShowingGuide = true
                    }
                }
                PanelIconButton(title: "Explain in Detail", systemImage: activeHint.isVisual ? "play.rectangle.fill" : "play.rectangle", isOn: activeHint.isVisual) {
                    withAnimation(.snappy(duration: 0.25)) {
                        if activeHint.isVisual {
                            model.endVisualExplanation()
                        } else {
                            model.startVisualExplanation()
                        }
                    }
                }
            }
            if !model.isPractice {
                PanelIconButton(title: "Reveal Cell", systemImage: "eye") {
                    model.revealCell()
                }
                .disabled(model.revealTarget == nil)
            }
            PanelIconButton(title: "Close", systemImage: "xmark") {
                model.closeHint()
            }
        }
    }

    @ViewBuilder
    private var navigation: some View {
        switch activeHint.hint {
        case .incorrectEntries:
            Button("Erase Mistakes") {
                model.eraseMistakes()
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .frame(maxWidth: .infinity, alignment: .trailing)
        case .impossibleNotes, .notesMissingSolution:
            // A smart hint first only says there is a wrong note; the player may look for it.
            Group {
                if activeHint.isConcealed {
                    Button("Show Which") {
                        model.showWhichNotesAreWrong()
                    }
                } else {
                    Button("Fix Notes") {
                        model.fixNotes()
                    }
                }
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .frame(maxWidth: .infinity, alignment: .trailing)
        case .notesIncomplete:
            Button("Complete Notes") {
                model.completeNotes()
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .frame(maxWidth: .infinity, alignment: .trailing)
        case .unavailable:
            EmptyView()
        case .step, .chain:
            // One glass container, so switching to the visual explanation morphs the buttons:
            // Next turns from a capsule into a circle and Play grows out of the glass beside it.
            GlassEffectContainer(spacing: 20) {
                ZStack {
                    HStack(spacing: 12) {
                        GlassControl(systemImage: "chevron.left", title: "Back", id: "back", namespace: glassNamespace) {
                            model.showPreviousHintPage()
                        }
                        .disabled(!activeHint.canGoBack)

                        Spacer(minLength: 0)
                        forwardButton
                    }
                    VStack(spacing: 10) {
                        PageIndicator(index: activeHint.index, count: activeHint.count, namespace: glassNamespace)
                        if activeHint.isVisual {
                            GlassControl(systemImage: isPlaying ? "pause.fill" : "play.fill", title: isPlaying ? "Pause" : "Play", id: "play", namespace: glassNamespace) {
                                isPlaying.toggle()
                            }
                        }
                    }
                }
            }
            .controlSize(.large)
        }
    }
}

extension HintPanel {
    /// Next, or Apply on the last page. In the visual explanation it's just an arrow, since the
    /// row also holds the play button.
    @ViewBuilder
    fileprivate var forwardButton: some View {
        if activeHint.canGoForward, activeHint.isVisual {
            GlassControl(systemImage: "chevron.right", title: "Next", id: "forward", namespace: glassNamespace, isProminent: true) {
                model.showNextHintPage()
            }
        } else if activeHint.canGoForward {
            GlassControl(systemImage: "chevron.right", title: "Next", id: "forward", namespace: glassNamespace, isProminent: true, showsTitle: true) {
                model.showNextHintPage()
            }
        } else {
            GlassControl(systemImage: "checkmark", title: "Apply", id: "forward", namespace: glassNamespace, isProminent: true, showsTitle: true) {
                model.applyHint()
            }
        }
    }
}

/// A Liquid Glass button for the hint panel's bottom row: a circle with an icon, or a capsule with
/// a title. Each has a glass ID, so inside a `GlassEffectContainer` its shape morphs when the row
/// changes instead of popping.
private struct GlassControl: View {
    let systemImage: String
    let title: LocalizedStringKey
    let id: String
    let namespace: Namespace.ID
    var isProminent = false
    var showsTitle = false
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            Group {
                if showsTitle {
                    HStack(spacing: 4) {
                        Text(title)
                        Image(systemName: systemImage)
                            .font(.body.weight(.semibold))
                    }
                    .font(.headline)
                    .padding(.horizontal, 20)
                    .frame(height: 48)
                } else {
                    Image(systemName: systemImage)
                        .font(.body.weight(.semibold))
                        .frame(width: 48, height: 48)
                        .contentTransition(.symbolEffect(.replace))
                }
            }
            .foregroundStyle(isProminent ? AnyShapeStyle(Color.white) : AnyShapeStyle(.primary))
            .opacity(isEnabled ? 1 : 0.35)
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .glassEffect(isProminent ? .regular.tint(.accentColor).interactive() : .regular.interactive(), in: .capsule)
        .glassEffectID(id, in: namespace)
        .accessibilityLabel(Text(title))
    }
}

/// Small round icon button used in the headers of the hint and auto solve panels.
struct PanelIconButton: View {
    let title: LocalizedStringKey
    let systemImage: String
    var isOn = false
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(isOn ? AnyShapeStyle(Color.white) : AnyShapeStyle(.secondary))
                .frame(width: 32, height: 32)
                .background(isOn ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.fill.tertiary), in: .circle)
                .opacity(isEnabled ? 1 : 0.4)
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(Text(title))
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

/// Progress through the pages. One short bar per page; with many pages (a visual explanation)
/// it becomes a single bar that fills up, so it always fits. The two forms share a geometry ID, so
/// switching between them morphs instead of jumping.
private struct PageIndicator: View {
    let index: Int
    let count: Int
    let namespace: Namespace.ID

    var body: some View {
        Group {
            // Kept narrow enough to clear the Next capsule beside it.
            if count <= 6 {
                HStack(spacing: 5) {
                    ForEach(0..<count, id: \.self) { item in
                        Capsule()
                            .fill(item <= index ? AnyShapeStyle(.tint) : AnyShapeStyle(.fill.tertiary))
                            .frame(width: item == index ? 18 : 8, height: 4)
                    }
                }
                .matchedGeometryEffect(id: "progress", in: namespace)
            } else {
                Capsule()
                    .fill(.fill.tertiary)
                    .frame(width: 90, height: 4)
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(.tint)
                            .frame(width: 90 * CGFloat(index + 1) / CGFloat(max(count, 1)), height: 4)
                    }
                    .matchedGeometryEffect(id: "progress", in: namespace)
            }
        }
        .animation(.snappy, value: index)
        .accessibilityElement()
        .accessibilityLabel(Text("Step \(index + 1) of \(count)"))
    }
}
