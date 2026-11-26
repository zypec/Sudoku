//
//  HomeView.swift
//  Sudoku
//

import SwiftData
import SwiftUI

/// Home screen: the daily puzzle with its streak, training and statistics, and at the bottom the
/// buttons to continue or start a game. New Game opens as a Liquid Glass sheet that zooms out of
/// its button; Settings opens as a standard sheet. Daily is a placeholder for now and says so when
/// tapped.
struct HomeView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var modelContext
    @Namespace private var namespace

    @State private var activeGame: GameModel?
    @State private var savedGame: SudokuGame?
    @State private var isShowingNewGame = false
    @State private var isShowingSettings = false
    /// A game generated from the New Game sheet, opened once the sheet has finished closing.
    @State private var pendingGame: GameModel?

    private let store = GameStore.shared

    @State private var isShowingComingSoon = false
    @State private var isShowingCodeEntry = false
    @State private var isShowingCodeError = false
    @State private var enteredCode = ""
    @State private var isShowingStats = false
    @State private var isShowingTraining = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    DailyCard(onPlay: showComingSoon)
                    HStack(spacing: 12) {
                        FeatureTile(
                            title: "Training",
                            subtitle: "Learn every technique",
                            systemImage: "graduationcap.fill",
                            tint: .purple
                        ) {
                            isShowingTraining = true
                        }
                        FeatureTile(
                            title: "Statistics",
                            subtitle: "Your progress",
                            systemImage: "chart.bar.fill",
                            tint: .teal
                        ) {
                            isShowingStats = true
                        }
                    }
                }
                .padding()
                // A comfortable reading width on iPad.
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
            .safeAreaInset(edge: .bottom) {
                GlassEffectContainer(spacing: 12) {
                    VStack(spacing: 12) {
                        if let savedGame {
                            continueButton(for: savedGame)
                        }
                        newGameButton
                        Button("Start with Code", systemImage: "number") {
                            enteredCode = ""
                            isShowingCodeEntry = true
                        }
                        .font(.subheadline.weight(.semibold))
                    }
                }
                .frame(maxWidth: 440)
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Settings", systemImage: "gearshape") {
                        isShowingSettings = true
                    }
                }
            }
            .navigationDestination(item: $activeGame) { model in
                GameView(model: model)
            }
            .navigationDestination(isPresented: $isShowingStats) {
                StatsView()
            }
            .navigationDestination(isPresented: $isShowingTraining) {
                TrainingView()
            }
            .sheet(isPresented: $isShowingNewGame, onDismiss: openPendingGame) {
                NewGameSheet(replacesGameInProgress: savedGame?.hasProgress == true) { difficulty in
                    await startGame(difficulty)
                }
                .navigationTransition(.zoom(sourceID: TransitionID.newGame, in: namespace))
            }
            // A standard sheet: the zoom out of the toolbar button stuttered on the first open.
            .sheet(isPresented: $isShowingSettings) {
                SettingsView()
            }
            .alert("Start with Code", isPresented: $isShowingCodeEntry) {
                TextField(text: $enteredCode) {
                    Text(verbatim: PuzzleCode.prefix)
                }
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                Button("Start") {
                    let code = enteredCode
                    Task { await startGame(code: code) }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Paste a puzzle code copied from a game.")
            }
            .alert("Not a Puzzle Code", isPresented: $isShowingCodeError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("This code doesn't make a puzzle with a single solution.")
            }
            .alert("Coming Soon", isPresented: $isShowingComingSoon) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("This part of the app isn't ready yet.")
            }
            .task {
                savedGame = store.load()
            }
            .task {
                // Decode the puzzle bank off the main actor now, so New Game doesn't wait for it.
                await Task.detached(priority: .utility) {
                    _ = PuzzleBank.bundled.count(of: .easy)
                }.value
            }
            .onChange(of: activeGame) { _, game in
                // Returning from a game: show its latest saved state (or none if it finished).
                if game == nil {
                    savedGame = store.load()
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(Date.now, format: .dateTime.weekday(.wide).day().month(.wide))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Text("Sudoku")
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
        }
    }

    private var recorder: GameRecorder {
        GameRecorder(context: modelContext)
    }

    private func showComingSoon() {
        isShowingComingSoon = true
    }

    private func continueButton(for game: SudokuGame) -> some View {
        Button {
            activeGame = GameModel(game: game, settings: settings, store: store, recorder: recorder)
        } label: {
            // One line: the action on the left, the saved game's difficulty and time on the right.
            HStack(spacing: 8) {
                Label("Continue", systemImage: "play.fill")
                    .font(.headline)
                Spacer(minLength: 8)
                Text(game.puzzle.difficulty.title)
                Text(verbatim: GameStatusView.formattedTime(game.elapsedSeconds))
                    .monospacedDigit()
            }
            .font(.subheadline)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.glassProminent)
        .controlSize(.large)
    }

    @ViewBuilder
    private var newGameButton: some View {
        let label = HStack {
            Label("New Game", systemImage: "plus")
                .font(.headline)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        // The primary action is the most prominent button: Continue when there's a saved game.
        Group {
            if savedGame == nil {
                Button { isShowingNewGame = true } label: { label }
                    .buttonStyle(.glassProminent)
            } else {
                Button { isShowingNewGame = true } label: { label }
                    .buttonStyle(.glass)
            }
        }
        .controlSize(.large)
        .matchedTransitionSource(id: TransitionID.newGame, in: namespace)
    }

    /// A game left unfinished and replaced counts as lost, once the player had started it.
    private func recordAbandonedGame() {
        if let abandoned = savedGame, !abandoned.isFinished, abandoned.hasProgress {
            recorder.record(abandoned)
        }
    }

    /// Opens the puzzle a code stands for, graded off the main actor.
    private func startGame(code: String) async {
        guard let puzzle = await Task.detached(priority: .userInitiated, operation: { PuzzleCode.puzzle(from: code) }).value else {
            isShowingCodeError = true
            return
        }
        recordAbandonedGame()
        let model = GameModel(
            game: SudokuGame(puzzle: puzzle, mistakeLimit: settings.mistakeLimitSetting),
            settings: settings,
            store: store,
            recorder: recorder
        )
        model.save()
        savedGame = model.game
        activeGame = model
    }

    private func startGame(_ difficulty: Difficulty) async {
        recordAbandonedGame()
        let model = await GameModel.make(difficulty: difficulty, settings: settings, store: store, recorder: recorder)
        savedGame = model.game
        if isShowingNewGame {
            pendingGame = model
            isShowingNewGame = false
        } else {
            activeGame = model
        }
    }

    private func openPendingGame() {
        guard let pendingGame else { return }
        activeGame = pendingGame
        self.pendingGame = nil
    }

    private enum TransitionID {
        static let newGame = "newGame"
    }
}

#Preview {
    HomeView()
        .environment(AppSettings())
}

/// The daily puzzle: today's date, the streak and this week's days. Placeholder until the daily
/// mode exists: the streak and week are empty.
private struct DailyCard: View {
    let onPlay: () -> Void

    private let streak = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("Daily Sudoku", systemImage: "calendar")
                    .font(.headline)
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(.orange)
                    Text("\(streak) day streak")
                        .monospacedDigit()
                }
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.orange.opacity(0.15), in: .capsule)
            }

            WeekStrip()

            // Secondary: the screen's one prominent action is Continue or New Game at the bottom.
            Button(action: onPlay) {
                Label("Play Today's Puzzle", systemImage: "play.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glass)
            .controlSize(.large)
        }
        .padding(18)
        .background(.fill.quaternary, in: .rect(cornerRadius: 24))
    }
}

/// The current week, one circle per day, with today ringed. Days follow the user's calendar
/// (first weekday and names).
private struct WeekStrip: View {
    private var days: [Date] {
        let calendar = Calendar.current
        guard let week = calendar.dateInterval(of: .weekOfYear, for: .now) else { return [] }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: week.start) }
    }

    var body: some View {
        HStack {
            ForEach(days, id: \.self) { day in
                let isToday = Calendar.current.isDateInToday(day)
                VStack(spacing: 6) {
                    Text(day, format: .dateTime.weekday(.narrow))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(isToday ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                    Text(day, format: .dateTime.day())
                        .font(.subheadline.weight(isToday ? .bold : .regular))
                        .monospacedDigit()
                        .frame(width: 34, height: 34)
                        .background {
                            Circle()
                                .strokeBorder(isToday ? AnyShapeStyle(.tint) : AnyShapeStyle(.quaternary), lineWidth: isToday ? 2 : 1)
                        }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("This week"))
    }
}

/// A square-ish entry point to a section of the app.
private struct FeatureTile: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    let systemImage: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: systemImage)
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(tint.gradient, in: .rect(cornerRadius: 12))
                Spacer(minLength: 0)
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, minHeight: 130, alignment: .leading)
            .padding(16)
            .background(.fill.quaternary, in: .rect(cornerRadius: 24))
            .contentShape(.rect(cornerRadius: 24))
        }
        .buttonStyle(.pressable)
    }
}
