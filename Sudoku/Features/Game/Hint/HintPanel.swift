//
//  HintPanel.swift
//  Sudoku
//

import SwiftUI

/// Floating Liquid Glass panel that walks through a hint page by page, forwards and backwards.
/// It takes the place of the controls and number pad and fills their space, so the board never
/// moves while the player reads.
struct HintPanel: View {
    let model: GameModel
    let activeHint: GameModel.ActiveHint

    @State private var isShowingDetail = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            ScrollView {
                Text(verbatim: activeHint.page.text)
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .id(activeHint.pageIndex)
                    .transition(.opacity)
            }
            .scrollBounceBehavior(.basedOnSize)
            .frame(maxHeight: .infinity, alignment: .top)

            if !activeHint.hint.steps.isEmpty {
                Button {
                    isShowingDetail = true
                } label: {
                    Label("Explain in Detail", systemImage: "book")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
                .controlSize(.small)
            }

            navigation
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .glassEffect(in: .rect(cornerRadius: 28))
        .animation(.snappy, value: activeHint.pageIndex)
        .sheet(isPresented: $isShowingDetail) {
            HintDetailSheet(model: model, hint: activeHint.hint)
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
                PageIndicator(index: activeHint.pageIndex, count: activeHint.pages.count)
                Spacer(minLength: 0)

                if activeHint.canGoForward {
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
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 32, height: 32)
                .background(.fill.tertiary, in: .circle)
                .opacity(isEnabled ? 1 : 0.4)
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(Text(title))
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
