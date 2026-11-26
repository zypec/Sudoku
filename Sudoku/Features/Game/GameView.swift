//
//  GameView.swift
//  Sudoku
//

import SwiftUI

/// The game screen. Portrait: status, board, controls and a one-row number pad stacked vertically.
/// Wide (iPad, landscape): board on the left, controls and a 3x3 keypad on the right.
struct GameView: View {
    let model: GameModel
    /// Set when the game is a training position: a task banner replaces the status bar.
    var practice: PracticeModel?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var outcome: GameOutcome?
    @State private var isShowingSettings = false
    /// Briefly shows that the puzzle code was copied.
    @State private var isShowingCodeCopied = false


    var body: some View {
        GeometryReader { proxy in
            if proxy.size.width > proxy.size.height {
                HStack(spacing: 24) {
                    BoardView(model: model)
                    VStack(spacing: 16) {
                        statusArea
                        inputArea(keypadColumns: 3)
                    }
                    .frame(maxWidth: 360)
                }
                .padding()
            } else {
                VStack(spacing: 16) {
                    statusArea
                    BoardView(model: model)
                        .layoutPriority(1)
                    inputArea(keypadColumns: 9)
                }
                .padding()
            }
        }
        // Paused: the game stays in view but blurred, so it can't be studied with the clock stopped.
        .blur(radius: model.isPaused ? 6 : 0)
        .allowsHitTesting(!model.isPaused)
        .animation(.snappy(duration: 0.25), value: model.activeHint != nil)
        .animation(.snappy(duration: 0.25), value: model.autoSolve != nil)
        .overlay {
            if model.isPreparingNewGame {
                ProgressView()
                    .controlSize(.large)
                    .padding(24)
                    .glassOrMaterial(in: .rect(cornerRadius: 20))
            }
        }
        .navigationTitle(practice.map { $0.isRandom ? Text("Random Practice") : Text(verbatim: $0.technique.title) } ?? Text(model.game.puzzle.difficulty.title))
        .navigationBarTitleDisplayMode(.inline)
        // Swipes never leave a game (they're easy to trigger on the board); only the back button does.
        .disablesSwipeBack()
        .overlay {
            if model.isPaused {
                PauseView(model: model)
                    .transition(.opacity)
            }
        }
        .animation(.snappy, value: model.isPaused)
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
        .onChange(of: model.game.values) { _, _ in
            practice?.evaluate()
        }
        .onChange(of: model.game.notes) { _, _ in
            practice?.evaluate()
        }
        .onChange(of: model.settings.mistakeLimitSetting) { _, _ in
            model.applyMistakeLimitSetting()
        }
        .onChange(of: model.game.isFinished) { _, isFinished in
            guard isFinished, practice == nil else { return }
            outcome = GameOutcome(game: model.game)
        }
        // Ticks aren't saved individually, so save the clock when leaving the foreground or the screen.
        .onChange(of: scenePhase) { _, phase in
            // Leaving the app pauses the game; it waits on the pause screen when the player returns.
            if phase == .background {
                model.pause()
            } else if phase != .active {
                model.pauseAutoSolve()
                model.save()
            }
        }
        .onDisappear {
            model.stopAutoSolve()
            model.save()
        }
        .overlay(alignment: .top) {
            if isShowingCodeCopied {
                Label(practice == nil ? LocalizedStringKey("Puzzle code copied") : LocalizedStringKey("Training code copied"), systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .glassOrMaterial(in: .capsule)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .task {
                        try? await Task.sleep(for: .seconds(1.6))
                        withAnimation(.snappy) { isShowingCodeCopied = false }
                    }
            }
        }
        .sensoryFeedback(.success, trigger: isShowingCodeCopied) { _, shown in shown && haptics }
        .sheet(item: $outcome) { outcome in
            GameResultSheet(model: model, outcome: outcome) {
                self.outcome = nil
                Task { await model.startNewGame() }
            } onHome: {
                self.outcome = nil
                dismiss()
            } onTakeBack: {
                self.outcome = nil
                model.takeBackLosingMistake()
            } onPlayAgain: {
                self.outcome = nil
                model.playAgain()
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
    /// mark), Auto Solve and Settings.
    private var optionsMenu: some View {
        Menu("More", systemImage: "ellipsis") {
            if model.settings.showsAutoNotesButton, !model.isPractice {
                Button("Auto Notes", systemImage: "square.grid.3x3") {
                    model.fillNotes()
                }
                .disabled(model.game.isFinished)
            }
            if !model.isPractice {
                Button("Auto Solve", systemImage: "play.circle") {
                    model.startAutoSolve()
                }
                .disabled(model.game.isFinished || model.autoSolve != nil)
                Button("Copy Puzzle Code", systemImage: "doc.on.doc") {
                    UIPasteboard.general.string = PuzzleCode.code(for: model.game.puzzle)
                    withAnimation(.snappy) { isShowingCodeCopied = true }
                }
                Divider()
            }
            if let practice {
                Button("Copy Training Code", systemImage: "doc.on.doc") {
                    UIPasteboard.general.string = practice.pick.code
                    withAnimation(.snappy) { isShowingCodeCopied = true }
                }
                Divider()
            }
            Button("Settings", systemImage: "gearshape") {
                model.pauseAutoSolve()
                isShowingSettings = true
            }
        }
    }

    /// The status bar, or the practice task in training.
    @ViewBuilder
    private var statusArea: some View {
        if let practice {
            PracticeBanner(practice: practice)
        } else {
            GameStatusView(model: model)
        }
    }

    private var haptics: Bool {
        model.settings.hapticsEnabled
    }

    /// Controls and number pad, with the hint or auto solve panel covering them while open. The controls
    /// stay in the layout (hidden) so the board keeps its size, and the panel fills all the space
    /// below the board.
    private func inputArea(keypadColumns: Int) -> some View {
        let isShowingHint = model.isShowingHintHighlights
        return ZStack(alignment: .bottom) {
            VStack(spacing: 16) {
                GameControlsView(model: model)
                NumberPadView(model: model, columns: keypadColumns)
            }
            .opacity(isShowingHint ? 0 : 1)
            .allowsHitTesting(!isShowingHint)
            .accessibilityHidden(isShowingHint)

            if let autoSolve = model.autoSolve {
                AutoSolvePanel(model: model, state: autoSolve)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else if let activeHint = model.activeHint {
                HintPanel(model: model, activeHint: activeHint)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .frame(maxHeight: .infinity, alignment: .bottom)
    }


    /// The clock only runs while the app is in the foreground, the game is in progress and the
    /// board is visible (not covered by Settings).
    private var isClockRunning: Bool {
        scenePhase == .active && !model.game.isFinished && !model.isPreparingNewGame && !isShowingSettings && !model.isPaused
    }
}

/// Mistake counter, elapsed time and the pause button above the board.
struct GameStatusView: View {
    let model: GameModel

    private var game: SudokuGame {
        model.game
    }

    private var settings: AppSettings {
        model.settings
    }

    var body: some View {
        HStack(spacing: 8) {
            // A game with a mistake limit always shows the counter, even if mistakes were hidden
            // after it started, so the player is never surprised by a loss.
            if let limit = game.mistakeLimit {
                HeartsChip(limit: limit, mistakes: game.mistakeCount)
            } else if settings.showsMistakes {
                mistakeCount
            }
            Spacer()
            if settings.showsTimer {
                TimerChip(model: model)
            }
            Button(action: model.pause) {
                    Image(systemName: "pause.fill")
                        .font(.subheadline.weight(.bold))
                        .frame(width: 32, height: 32)
                        .background(.fill.tertiary, in: .circle)
                }
                .buttonStyle(.pressable)
                .disabled(game.isFinished)
                .accessibilityLabel(Text("Pause"))
        }
        .font(.subheadline.weight(.semibold))
        .frame(minHeight: 32)
    }

    /// Without a limit, mistakes are just counted.
    private var mistakeCount: some View {
        HStack(spacing: 5) {
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(game.mistakeCount > 0 ? AnyShapeStyle(Color.red) : AnyShapeStyle(.tertiary))
            Text(verbatim: "\(game.mistakeCount)")
                .fontDesign(.rounded)
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.fill.tertiary, in: .capsule)
        .animation(.snappy, value: game.mistakeCount)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Mistakes: \(game.mistakeCount)"))
    }

    static func formattedTime(_ seconds: Int) -> String {
        Duration.seconds(seconds).formatted(.time(pattern: seconds >= 3600 ? .hourMinuteSecond : .minuteSecond))
    }
}

/// Elapsed time. Reads the clock on its own, so the tick every second redraws only this chip.
private struct TimerChip: View {
    let model: GameModel

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "stopwatch")
                .foregroundStyle(.secondary)
            Text(verbatim: GameStatusView.formattedTime(model.elapsedSeconds))
                .fontDesign(.rounded)
                .monospacedDigit()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.fill.tertiary, in: .capsule)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Elapsed time"))
        .accessibilityValue(Text(Duration.seconds(model.elapsedSeconds).formatted(.units(allowed: [.hours, .minutes, .seconds], width: .wide))))
    }
}

/// The tries left before the mistake limit. Normally a single heart; after each mistake (or when
/// tapped) it opens for a moment to show every heart, the lost ones empty, then closes again. The
/// heart turns gray when only the last try is left.
private struct HeartsChip: View {
    let limit: Int
    let mistakes: Int

    @State private var isOpen = false
    /// Bumped to open the chip; a new bump restarts the timer.
    @State private var openRequest = 0

    private var remaining: Int {
        max(0, limit - mistakes)
    }

    /// Open, the first heart is one of the row; closed, it stands for all of them and turns gray
    /// on the last try.
    private func firstHeartStyle(isLost: Bool) -> AnyShapeStyle {
        if isOpen {
            isLost ? AnyShapeStyle(.tertiary) : AnyShapeStyle(Color.red)
        } else {
            remaining <= 1 ? AnyShapeStyle(.tertiary) : AnyShapeStyle(Color.red)
        }
    }

    var body: some View {
        Button {
            // Tapping an open chip closes it.
            if isOpen {
                isOpen = false
            } else {
                openRequest += 1
            }
        } label: {
            // Every heart is always there; closed, all but the first sit in one frame of no width. So
            // opening and closing only moves the chip's edge, which uncovers or covers the hearts as
            // it goes, instead of the hearts fading on their own while the chip resizes.
            HStack(spacing: 0) {
                Image(systemName: isOpen && remaining == 0 ? "heart" : "heart.fill")
                    .foregroundStyle(firstHeartStyle(isLost: remaining == 0))
                    .symbolEffect(.bounce, value: mistakes)
                HStack(spacing: 3) {
                    ForEach(1..<max(limit, 1), id: \.self) { index in
                        let isLost = index >= remaining
                        Image(systemName: isLost ? "heart" : "heart.fill")
                            .foregroundStyle(isLost ? AnyShapeStyle(.tertiary) : AnyShapeStyle(Color.red))
                    }
                }
                .padding(.leading, 3)
                .fixedSize()
                .frame(width: isOpen ? nil : 0, alignment: .leading)
                .clipped()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.fill.tertiary, in: .capsule)
            .clipShape(.capsule)
        }
        .buttonStyle(.pressable)
        .animation(.spring(duration: 0.35, bounce: 0.3), value: isOpen)
        .onChange(of: mistakes) { _, _ in
            openRequest += 1
        }
        .task(id: openRequest) {
            guard openRequest > 0 else { return }
            isOpen = true
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            isOpen = false
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Mistakes: \(mistakes)/\(limit)"))
        .accessibilityHint(Text("Shows the tries left"))
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
    model.showNextHintPage()
    model.showNextHintPage()
    return NavigationStack {
        GameView(model: model)
    }
}
