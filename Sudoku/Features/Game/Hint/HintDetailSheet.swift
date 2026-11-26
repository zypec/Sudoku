//
//  HintDetailSheet.swift
//  Sudoku
//

import SwiftUI

/// The detailed explanation of a hint, for players who don't know the technique yet: how the rule
/// works, how to spot it, and every step of it in this puzzle. It can show every candidate around
/// the hint on the board and add them to the player's notes, since many techniques only become
/// visible with notes. Opens as a half-height sheet so the board stays in view.
struct HintDetailSheet: View {
    let model: GameModel
    let hint: Hint

    @Environment(\.dismiss) private var dismiss

    /// Every technique in the hint, in order (a chain can use several).
    private var techniques: [TechniqueKind] {
        var result: [TechniqueKind] = []
        for step in hint.steps where !result.contains(step.technique) {
            result.append(step.technique)
        }
        return result
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle(isOn: Binding(get: { model.showsHintCandidates }, set: model.setShowsHintCandidates)) {
                        Label("Show All Candidates", systemImage: "square.grid.3x3")
                    }
                    Button("Add Them to My Notes", systemImage: "pencil") {
                        model.addHintCandidatesToNotes()
                    }
                    .disabled(!model.canAddHintCandidatesToNotes)
                } footer: {
                    Text("Many techniques only show up once every possible digit is written in the cells. Notes are added only to cells that have none.")
                }

                ForEach(techniques, id: \.self) { technique in
                    let guide = technique.guide
                    Section {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("How It Works")
                                .font(.app(.headline))
                            Text(verbatim: guide.howItWorks)
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            Text("How to Spot It")
                                .font(.app(.headline))
                            Text(verbatim: guide.howToSpot)
                        }
                    } header: {
                        Text(verbatim: "\(technique.title)  \(String(localized: technique.subtitle))")
                    }
                }

                Section("In This Puzzle") {
                    ForEach(Array(steps.enumerated()), id: \.offset) { index, text in
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text(verbatim: "\(index + 1)")
                                .font(.app(.subheadline, weight: .bold))
                                .monospacedDigit()
                                .foregroundStyle(.tint)
                            Text(verbatim: text)
                        }
                    }
                }
            }
            .navigationTitle(Text("Detailed Explanation"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        // Low enough that the whole board stays visible above it; pull up to read more.
        .presentationDetents([.fraction(0.4), .large])
        .presentationBackgroundInteraction(.enabled(upThrough: .fraction(0.4)))
        .onAppear {
            model.setShowsHintCandidates(true)
        }
    }

    /// The reasoning pages of the hint, in order, without the opening nudge.
    private var steps: [String] {
        HintWalkthrough.pages(for: hint).filter { $0.kind != .nudge && $0.kind != .spotting }.map(\.text)
    }
}
