//
//  TrainingViews.swift
//  Sudoku
//

import SwiftUI

// MARK: Library

/// The technique library: every technique by level, with the player's practice progress.
struct TrainingView: View {
    var body: some View {
        List {
            ForEach(Difficulty.allCases) { level in
                Section {
                    ForEach(TechniqueKind.allCases.filter { $0.level == level.level }, id: \.self) { technique in
                        // A destination link: value links don't mix with the home screen's
                        // `navigationDestination(isPresented:)` and never pushed.
                        NavigationLink {
                            TechniqueDetailView(technique: technique)
                        } label: {
                            TechniqueRow(technique: technique)
                        }
                    }
                } header: {
                    Text(level.title)
                }
            }
        }
        .navigationTitle("Training")
    }
}

private struct TechniqueRow: View {
    let technique: TechniqueKind

    var body: some View {
        let count = TrainingPositions.bundled.positions(for: technique).count
        let solved = min(TrainingProgress.shared.solvedPositions(of: technique).count, count)
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: technique.title)
                    .font(.body.weight(.semibold))
                Text(technique.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if count == 0 {
                Text("Soon")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                Gauge(value: Double(solved), in: 0...Double(count)) {
                    EmptyView()
                } currentValueLabel: {
                    Text(verbatim: "\(solved)")
                        .monospacedDigit()
                }
                .gaugeStyle(.accessoryCircularCapacity)
                .tint(solved == count ? .green : .accentColor)
                .scaleEffect(0.6)
                .frame(width: 34, height: 34)
                .accessibilityLabel(Text("\(solved) of \(count) solved"))
            }
        }
    }
}

// MARK: Technique

/// One technique: an animated example on a real position, how it works and how to spot it, and
/// the way into practice.
struct TechniqueDetailView: View {
    let technique: TechniqueKind

    @Environment(AppSettings.self) private var settings

    private var positionCount: Int {
        TrainingPositions.bundled.positions(for: technique).count
    }

    var body: some View {
        let guide = technique.guide
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(Difficulty(rawValue: technique.level)?.title ?? "Easy")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Difficulty(rawValue: technique.level)?.color ?? .accentColor)
                    Text(technique.subtitle)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                if positionCount > 0 {
                    TechniqueExample(technique: technique)
                }

                GuideCard(title: "How It Works", text: guide.howItWorks, systemImage: "lightbulb")
                GuideCard(title: "How to Spot It", text: guide.howToSpot, systemImage: "eye")

                if positionCount > 0 {
                    NavigationLink {
                        PracticeView(technique: technique)
                    } label: {
                        Label("Start Practice", systemImage: "target")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                    .controlSize(.large)
                    Text("Positions: \(positionCount)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                } else {
                    Label("Practice positions for this technique are coming soon.", systemImage: "clock")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle(Text(verbatim: technique.title))
    }
}

private struct GuideCard: View {
    let title: LocalizedStringKey
    let text: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.headline)
            Text(verbatim: text)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.fill.quaternary, in: .rect(cornerRadius: 20))
    }
}

/// The technique's visual explanation playing on its first practice position, on a loop.
private struct TechniqueExample: View {
    let technique: TechniqueKind

    @Environment(AppSettings.self) private var settings
    @State private var model: GameModel?
    @State private var isPlaying = true

    var body: some View {
        VStack(spacing: 12) {
            if let model, let hint = model.activeHint {
                BoardView(model: model)
                    .allowsHitTesting(false)
                    .frame(maxWidth: 420)
                Text(verbatim: hint.page.text)
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, minHeight: 60, alignment: .topLeading)
                    .transaction { $0.animation = nil }
                HStack(spacing: 20) {
                    controlButton("chevron.left", title: "Back") { model.showPreviousHintPage() }
                        .disabled(!hint.canGoBack)
                    controlButton(isPlaying ? "pause.fill" : "play.fill", title: isPlaying ? "Pause" : "Play") { isPlaying.toggle() }
                    controlButton("chevron.right", title: "Next") { model.showNextHintPage() }
                        .disabled(!hint.canGoForward)
                }
                .task(id: isPlaying ? hint.index : -1) {
                    guard isPlaying else { return }
                    try? await Task.sleep(for: .seconds(2.4))
                    guard !Task.isCancelled else { return }
                    if hint.canGoForward {
                        model.showNextHintPage()
                    } else {
                        // Start over after a pause on the conclusion.
                        model.startVisualExplanation()
                    }
                }
            }
        }
        .padding(16)
        .background(.fill.quaternary, in: .rect(cornerRadius: 20))
        .task {
            guard model == nil,
                  let position = TrainingPositions.bundled.positions(for: technique).first,
                  let setup = PracticeSetup(position: position, technique: technique, transform: .identity)
            else { return }
            let example = GameModel(game: setup.game, settings: settings, followsMistakeLimitSetting: false)
            example.requestHint()
            example.startVisualExplanation()
            model = example
        }
    }

    private func controlButton(_ systemImage: String, title: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .labelStyle(.iconOnly)
                .frame(width: 24, height: 24)
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .controlSize(.large)
    }
}

// MARK: Practice

/// A practice session: the game screen with the task in place of the status bar.
struct PracticeView: View {
    let technique: TechniqueKind

    @Environment(AppSettings.self) private var settings
    @State private var practice: PracticeModel?

    var body: some View {
        Group {
            if let practice {
                GameView(model: practice.game, practice: practice)
                    .id(practice.loadID)
            } else {
                ContentUnavailableView("Practice positions for this technique are coming soon.", systemImage: "clock")
            }
        }
        .task {
            if practice == nil {
                practice = PracticeModel(technique: technique, settings: settings)
            }
        }
    }
}

/// The practice task above the board: what to find, progress, and feedback on each move.
struct PracticeBanner: View {
    let practice: PracticeModel

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(color)
                .symbolEffect(.bounce, value: practice.status)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            switch practice.status {
            case .wrongMove:
                Button("Undo", systemImage: "arrow.uturn.backward") {
                    practice.undoWrongMove()
                }
                .buttonStyle(.glass)
            case .solved:
                Button("Next") {
                    practice.nextPosition()
                }
                .buttonStyle(.glassProminent)
            case .working:
                Text("\(practice.positionIndex + 1) of \(practice.positionCount)")
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(background, in: .rect(cornerRadius: 16))
        .animation(.snappy, value: practice.status)
        .sensoryFeedback(trigger: practice.status) { _, status in
            switch status {
            case .solved: .success
            case .wrongMove: .error
            case .working: nil
            }
        }
    }

    private var symbol: String {
        switch practice.status {
        case .working: "target"
        case .wrongMove: "xmark.circle.fill"
        case .solved: "checkmark.circle.fill"
        }
    }

    private var color: Color {
        switch practice.status {
        case .working: .accentColor
        case .wrongMove: .red
        case .solved: .green
        }
    }

    private var background: Color {
        switch practice.status {
        case .working: Color.accentColor.opacity(0.1)
        case .wrongMove: Color.red.opacity(0.12)
        case .solved: Color.green.opacity(0.14)
        }
    }

    private var title: String {
        let name = practice.technique.title
        return switch practice.status {
        case .working: String(localized: "Find the \(name)")
        case .wrongMove: String(localized: "That move isn't part of this \(name).")
        case .solved: String(localized: "Well done!")
        }
    }

    private var detail: String {
        switch practice.status {
        case .working(let done, let total):
            if practice.isPlacement {
                return String(localized: "Place the digit it gives.")
            }
            return String(localized: "Remove the candidates it rules out (\(done) of \(total)).")
        case .wrongMove:
            return String(localized: "Undo it and look again, or ask for a hint.")
        case .solved:
            return String(localized: "You found it.")
        }
    }
}
