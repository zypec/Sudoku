//
//  GameView.swift
//  Sudoku
//

import SwiftUI

/// The game screen. Portrait: status, board, controls and a one-row number pad stacked vertically.
/// Wide (iPad, landscape): board on the left, controls and a 3x3 keypad on the right.
struct GameView: View {
    let model: GameModel

    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var outcome: Outcome?
    @State private var isShowingSettings = false

    private enum Outcome {
        case solved
        case lost
    }

    var body: some View {
        GeometryReader { proxy in
            if proxy.size.width > proxy.size.height {
                HStack(spacing: 24) {
                    BoardView(model: model)
                    VStack(spacing: 16) {
                        GameStatusView(game: model.game, settings: model.settings)
                        Spacer(minLength: 0)
                        inputArea(keypadColumns: 3)
                    }
                    .frame(maxWidth: 360)
                }
                .padding()
            } else {
                VStack(spacing: 16) {
                    GameStatusView(game: model.game, settings: model.settings)
                    BoardView(model: model)
                    Spacer(minLength: 0)
                    inputArea(keypadColumns: 9)
                }
                .padding()
            }
        }
        .animation(.snappy, value: model.activeHint != nil)
        .overlay {
            if model.isPreparingNewGame {
                ProgressView()
                    .controlSize(.large)
                    .padding(24)
                    .glassEffect(in: .rect(cornerRadius: 20))
            }
        }
        .navigationTitle(Text(model.game.puzzle.difficulty.title))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                optionsMenu
            }
        }
        .sheet(isPresented: $isShowingSettings) {
            SettingsView()
        }
        .task(id: isClockRunning) {
            guard isClockRunning else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { break }
                model.tick()
            }
        }
        .onChange(of: model.game.isFinished) { _, isFinished in
            guard isFinished else { return }
            outcome = model.game.isSolved ? .solved : .lost
        }
        // Ticks aren't saved individually, so save the clock when leaving the foreground or the screen.
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                model.save()
            }
        }
        .onDisappear {
            model.save()
        }
        .alert(outcomeTitle, item: $outcome) { _ in
            Button("New Game") {
                Task { await model.startNewGame() }
            }
            Button("Home", role: .cancel) {
                dismiss()
            }
        } message: { outcome in
            switch outcome {
            case .solved:
                Text("You solved it in \(GameStatusView.formattedTime(model.game.elapsedSeconds)).")
            case .lost:
                Text("You reached the mistake limit.")
            }
        }
        .sensoryFeedback(trigger: model.selectedCell) { _, _ in
            haptics ? .selection : nil
        }
        .sensoryFeedback(trigger: model.game.mistakeCount) { _, _ in
            haptics && model.settings.showsMistakes ? .error : nil
        }
        .sensoryFeedback(trigger: model.game.isSolved) { _, isSolved in
            haptics && isSolved ? .success : nil
        }
    }

    /// Actions used rarely enough to sit behind a menu: Auto Notes (which replaces every pencil
    /// mark) and Settings.
    private var optionsMenu: some View {
        Menu("More", systemImage: "ellipsis") {
            if model.settings.showsAutoNotesButton {
                Button("Auto Notes", systemImage: "square.grid.3x3") {
                    model.fillNotes()
                }
                .disabled(model.game.isFinished)
                Divider()
            }
            Button("Settings", systemImage: "gearshape") {
                isShowingSettings = true
            }
        }
    }

    private var haptics: Bool {
        model.settings.hapticsEnabled
    }

    /// Controls and number pad, or the hint panel in their place while a hint is open.
    @ViewBuilder
    private func inputArea(keypadColumns: Int) -> some View {
        if let activeHint = model.activeHint {
            HintPanel(model: model, activeHint: activeHint)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        } else {
            VStack(spacing: 16) {
                GameControlsView(model: model)
                NumberPadView(model: model, columns: keypadColumns)
            }
            .transition(.opacity)
        }
    }

    private var outcomeTitle: LocalizedStringKey {
        outcome == .lost ? "Game Over" : "Puzzle Solved!"
    }

    /// The clock only runs while the app is in the foreground, the game is in progress and the
    /// board is visible (not covered by Settings).
    private var isClockRunning: Bool {
        scenePhase == .active && !model.game.isFinished && !model.isPreparingNewGame && !isShowingSettings
    }
}

/// Mistake counter and elapsed time above the board.
struct GameStatusView: View {
    let game: SudokuGame
    let settings: AppSettings

    var body: some View {
        HStack {
            // A game with a mistake limit always shows the counter, even if mistakes were hidden
            // after it started, so the player is never surprised by a loss.
            if settings.showsMistakes || game.mistakeLimit != nil {
                mistakes
                    .foregroundStyle(game.mistakeCount > 0 ? AnyShapeStyle(Color.red) : AnyShapeStyle(.secondary))
            }
            Spacer()
            if settings.showsTimer {
                Text(verbatim: Self.formattedTime(game.elapsedSeconds))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(Text("Elapsed time"))
                    .accessibilityValue(Text(Duration.seconds(game.elapsedSeconds).formatted(.units(allowed: [.hours, .minutes, .seconds], width: .wide))))
            }
        }
        .font(.subheadline.weight(.medium))
        .frame(minHeight: 20)
    }

    private var mistakes: Text {
        if let limit = game.mistakeLimit {
            Text("Mistakes: \(game.mistakeCount)/\(limit)")
        } else {
            Text("Mistakes: \(game.mistakeCount)")
        }
    }

    static func formattedTime(_ seconds: Int) -> String {
        Duration.seconds(seconds).formatted(.time(pattern: seconds >= 3600 ? .hourMinuteSecond : .minuteSecond))
    }
}

#Preview {
    var generator = SeededRandomNumberGenerator(seed: 1)
    let game = SudokuGame(puzzle: PuzzleGenerator.generate(.easy, using: &generator), mistakeLimit: 3)
    let model = GameModel(game: game, settings: AppSettings())
    model.select(Geometry.cell(row: 4, column: 4))
    model.fillNotes()
    return NavigationStack {
        GameView(model: model)
    }
}

#Preview("Notes mode") {
    var generator = SeededRandomNumberGenerator(seed: 1)
    let game = SudokuGame(puzzle: PuzzleGenerator.generate(.easy, using: &generator), mistakeLimit: 3)
    let model = GameModel(game: game, settings: AppSettings())
    model.select(Geometry.cell(row: 4, column: 4))
    model.toggleNotesMode()
    return NavigationStack {
        GameView(model: model)
    }
}

#Preview("Hint") {
    var generator = SeededRandomNumberGenerator(seed: 1)
    var game = SudokuGame(puzzle: PuzzleGenerator.generate(.medium, using: &generator), mistakeLimit: 3)
    // Advance to the first hint that eliminates candidates.
    while case .step(let step, _) = HintFinder.hint(for: game), step.eliminations.isEmpty {
        game.apply(step)
    }
    let model = GameModel(game: game, settings: AppSettings())
    model.requestHint()
    model.advanceHint()
    model.advanceHint()
    return NavigationStack {
        GameView(model: model)
    }
}
