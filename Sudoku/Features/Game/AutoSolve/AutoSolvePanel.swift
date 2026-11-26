//
//  AutoSolvePanel.swift
//  Sudoku
//

import SwiftUI

/// Liquid Glass panel shown while auto solve runs, in place of the controls and number pad.
/// Shows the step about to be applied, overall progress, step back, play/pause, step forward and
/// the speed.
struct AutoSolvePanel: View {
    let model: GameModel
    let state: AutoSolveState

    var body: some View {
        @Bindable var settings = model.settings
        VStack(alignment: .leading, spacing: 12) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    if let hint = state.hint {
                        Text(verbatim: HintText.title(for: hint))
                            .font(.headline)
                    }
                    if let page = state.page {
                        Text(verbatim: page.text)
                            .font(.body)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollBounceBehavior(.basedOnSize)
            .frame(maxHeight: .infinity, alignment: .top)

            ProgressView(value: Double(filledCells), total: Double(Geometry.cellCount))
                .accessibilityLabel(Text("Progress"))

            HStack(spacing: 12) {
                Button {
                    model.autoSolvePreviousStep()
                } label: {
                    Label("Previous Step", systemImage: "backward.frame.fill")
                        .labelStyle(.iconOnly)
                        .frame(width: 24, height: 24)
                }
                .glassButton()
                .buttonBorderShape(.circle)
                .disabled(!model.canStepAutoSolveBack)

                Button {
                    model.toggleAutoSolvePause()
                } label: {
                    Label(state.isPaused ? "Resume" : "Pause", systemImage: state.isPaused ? "play.fill" : "pause.fill")
                        .labelStyle(.iconOnly)
                        .frame(width: 24, height: 24)
                        .contentTransition(.symbolEffect(.replace))
                }
                .glassProminentButton()
                .buttonBorderShape(.circle)
                .disabled(state.isStuck)

                Button {
                    model.autoSolveNextStep()
                } label: {
                    Label("Next Step", systemImage: "forward.frame.fill")
                        .labelStyle(.iconOnly)
                        .frame(width: 24, height: 24)
                }
                .glassButton()
                .buttonBorderShape(.circle)
                .disabled(state.isStuck)

                Spacer(minLength: 0)

                // A compact menu showing the current speed; a segmented control doesn't fit "0.5x".
                Menu {
                    Picker("Speed", selection: $settings.autoSolveSpeed) {
                        ForEach(AutoSolveSpeed.allCases) { speed in
                            Text(verbatim: speed.label).tag(speed)
                        }
                    }
                } label: {
                    Label {
                        Text(verbatim: settings.autoSolveSpeed.label)
                            .monospacedDigit()
                    } icon: {
                        Image(systemName: "gauge.with.dots.needle.67percent")
                    }
                    .font(.body.weight(.semibold))
                }
                .glassButton()
                .accessibilityLabel(Text("Speed"))
                .accessibilityValue(Text(verbatim: settings.autoSolveSpeed.label))
            }
            .controlSize(.large)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .glassOrMaterial(in: .rect(cornerRadius: 28))
        .animation(.snappy, value: state.appliedSteps)
        .animation(.snappy, value: state.isPaused)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Auto Solve")
                    .font(.title3.bold())
                Text(status)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }
            Spacer()
            PanelIconButton(title: "Stop", systemImage: "xmark") {
                model.stopAutoSolve()
            }
        }
    }

    private var status: LocalizedStringKey {
        if state.isStuck {
            "Stopped"
        } else if state.isPaused {
            "Paused"
        } else {
            "Step \(state.appliedSteps + 1)"
        }
    }

    private var filledCells: Int {
        model.game.values.count { $0 != 0 }
    }
}
