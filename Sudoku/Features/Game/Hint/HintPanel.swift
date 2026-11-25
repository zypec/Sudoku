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

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            ScrollView {
                // No crossfade: two sentences fading over each other are hard to read.
                Text(verbatim: activeHint.page.text)
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
        .animation(.snappy, value: activeHint.index)
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
                Text(verbatim: activeHint.page.technique?.title ?? HintText.title(for: activeHint.hint))
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
                    if activeHint.isVisual {
                        model.endVisualExplanation()
                    } else {
                        model.startVisualExplanation()
                    }
                }
            }
            PanelIconButton(title: "Reveal Cell", systemImage: "eye") {
                model.revealCell()
            }
            .disabled(model.revealTarget == nil)
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
            Button("Fix Notes") {
                model.fixNotes()
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .frame(maxWidth: .infinity, alignment: .trailing)
        case .unavailable:
            EmptyView()
        case .step, .chain:
            HStack(spacing: 12) {
                Button {
                    model.showPreviousHintPage()
                } label: {
                    Label("Back", systemImage: "chevron.left")
                        .labelStyle(.iconOnly)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .disabled(!activeHint.canGoBack)

                Spacer(minLength: 0)
                if activeHint.isVisual {
                    Button {
                        isPlaying.toggle()
                    } label: {
                        Label(isPlaying ? "Pause" : "Play", systemImage: isPlaying ? "pause.fill" : "play.fill")
                            .labelStyle(.iconOnly)
                            .frame(width: 24, height: 24)
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)
                    Text(verbatim: "\(activeHint.index + 1) / \(activeHint.count)")
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                } else {
                    PageIndicator(index: activeHint.index, count: activeHint.count)
                }
                Spacer(minLength: 0)

                if activeHint.canGoForward, activeHint.isVisual {
                    // The visual row also holds play and a counter, so Next is just an arrow.
                    Button {
                        model.showNextHintPage()
                    } label: {
                        Label("Next", systemImage: "chevron.right")
                            .labelStyle(.iconOnly)
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.glassProminent)
                    .buttonBorderShape(.circle)
                } else if activeHint.canGoForward {
                    Button {
                        model.showNextHintPage()
                    } label: {
                        HStack(spacing: 4) {
                            Text("Next")
                            Image(systemName: "chevron.right")
                                .font(.body.weight(.semibold))
                        }
                    }
                    .buttonStyle(.glassProminent)
                } else {
                    Button("Apply") {
                        model.applyHint()
                    }
                    .buttonStyle(.glassProminent)
                }
            }
            .controlSize(.large)
        }
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

/// One short bar per page; the current and earlier pages are filled.
private struct PageIndicator: View {
    let index: Int
    let count: Int

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<count, id: \.self) { item in
                Capsule()
                    .fill(item <= index ? AnyShapeStyle(.tint) : AnyShapeStyle(.fill.tertiary))
                    .frame(width: item == index ? 18 : 8, height: 4)
            }
        }
        .accessibilityElement()
        .accessibilityLabel(Text("Step \(index + 1) of \(count)"))
    }
}
