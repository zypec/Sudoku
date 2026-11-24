//
//  HintPanel.swift
//  Sudoku
//

import SwiftUI

/// Floating Liquid Glass panel that walks through a hint stage by stage. Replaces the controls and
/// number pad while open so the board stays fully visible.
struct HintPanel: View {
    let model: GameModel
    let activeHint: GameModel.ActiveHint

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            if case .step = activeHint.hint {
                StageIndicator(stage: activeHint.stage)
            }

            Text(verbatim: HintText.message(for: activeHint.hint, stage: activeHint.stage))
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
                .id(activeHint.stage)
                .transition(.opacity)

            HStack(spacing: 12) {
                Button("Reveal Cell", systemImage: "eye") {
                    model.revealCell()
                }
                .buttonStyle(.glass)
                .disabled(model.revealTarget == nil)

                Spacer(minLength: 0)

                primaryButton
            }
            .controlSize(.large)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(in: .rect(cornerRadius: 28))
        .animation(.snappy, value: activeHint.stage)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: HintText.title(for: activeHint.hint))
                    .font(.title3.bold())
                if let subtitle = HintText.subtitle(for: activeHint.hint) {
                    Text(verbatim: subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button {
                model.closeHint()
            } label: {
                Image(systemName: "xmark")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 32)
                    .background(.fill.tertiary, in: .circle)
            }
            .buttonStyle(.pressable)
            .accessibilityLabel(Text("Close"))
        }
    }

    @ViewBuilder
    private var primaryButton: some View {
        switch activeHint.hint {
        case .incorrectEntries:
            Button("Erase Mistakes") {
                model.eraseMistakes()
            }
            .buttonStyle(.glassProminent)
        case .unavailable:
            EmptyView()
        case .step:
            switch activeHint.stage {
            case .nudge:
                Button("Show More") {
                    model.advanceHint()
                }
                .buttonStyle(.glassProminent)
            case .explanation:
                Button("Show Result") {
                    model.advanceHint()
                }
                .buttonStyle(.glassProminent)
            case .result:
                Button("Apply") {
                    model.applyHint()
                }
                .buttonStyle(.glassProminent)
            }
        }
    }
}

/// Three short bars showing how far the hint has been revealed.
private struct StageIndicator: View {
    let stage: HintStage

    var body: some View {
        HStack(spacing: 6) {
            ForEach(HintStage.allCases, id: \.self) { item in
                Capsule()
                    .fill(item <= stage ? AnyShapeStyle(.tint) : AnyShapeStyle(.fill.tertiary))
                    .frame(width: 24, height: 4)
            }
        }
        .accessibilityElement()
        .accessibilityLabel(Text("Step \(stage.rawValue + 1) of \(HintStage.allCases.count)"))
    }
}
