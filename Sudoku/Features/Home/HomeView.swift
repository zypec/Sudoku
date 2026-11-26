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

    @State private var isShowingStats = false
    @State private var isShowingTraining = false
    @State private var isShowingRace = false
    @State private var isShowingCalendar = false
    @State private var isShowingDailyGame = false
    /// The day whose daily puzzle opens.
    @State private var dailyGameDay = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    DailyCard {
                        dailyGameDay = DailyCalendar.today()
                        isShowingDailyGame = true
                    } onCalendar: {
                        isShowingCalendar = true
                    }
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
                    FeatureTile(
                        title: "Race a Friend",
                        subtitle: "Same puzzle, first to finish wins",
                        systemImage: "flag.checkered",
                        tint: .orange,
                        isWide: true
                    ) {
                        isShowingRace = true
                    }
                }
                .padding()
                // A comfortable reading width on iPad.
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
            .safeAreaInset(edge: .bottom) {
                GlassGroup(spacing: 12) {
                    VStack(spacing: 12) {
                        if let savedGame {
                            continueButton(for: savedGame)
                        }
                        newGameButton
                    }
                }
                .frame(maxWidth: 440)
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            // The screen draws its own title and hides the bar, but the back button's long-press menu
            // lists screens by their navigation title: without one, Home was an empty row there.
            .navigationTitle("Sudoku")
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(item: $activeGame) { model in
                GameView(model: model)
            }
            .navigationDestination(isPresented: $isShowingStats) {
                StatsView()
            }
            .navigationDestination(isPresented: $isShowingTraining) {
                TrainingView()
            }
            .navigationDestination(isPresented: $isShowingRace) {
                RaceListView()
            }
            .navigationDestination(isPresented: $isShowingCalendar) {
                DailyCalendarView()
            }
            .navigationDestination(isPresented: $isShowingDailyGame) {
                DailyGameView(day: dailyGameDay)
            }
            .sheet(isPresented: $isShowingNewGame, onDismiss: openPendingGame) {
                NewGameSheet(replacesGameInProgress: savedGame?.hasProgress == true) { difficulty in
                    await startGame(difficulty)
                } startWithCode: { code in
                    await startGame(code: code)
                }
                .zoomTransition(sourceID: TransitionID.newGame, in: namespace)
            }
            // A standard sheet: the zoom out of the toolbar button stuttered on the first open.
            .sheet(isPresented: $isShowingSettings) {
                SettingsView()
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

    /// The date and the name at the very top, as Apple's own apps open, with Settings beside the name
    /// instead of in a bar of its own above it.
    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                Text(Date.now, format: .dateTime.weekday(.wide).day().month(.wide))
                    .font(.app(.subheadline, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Text("Sudoku")
                    .font(.app(.largeTitle, weight: .bold))
                    .accessibilityAddTraits(.isHeader)
            }
            Spacer(minLength: 12)
            Button {
                isShowingSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 19, weight: .medium))
                    .foregroundStyle(.primary)
                    .frame(width: 44, height: 44)
                    .glassOrMaterial(in: .circle, interactive: true)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Settings"))
        }
        .padding(.top, 8)
    }

    private var recorder: GameRecorder {
        GameRecorder(context: modelContext)
    }

    private func continueButton(for game: SudokuGame) -> some View {
        Button {
            activeGame = GameModel(game: game, settings: settings, store: store, recorder: recorder)
        } label: {
            // One line: the action on the left, the saved game's difficulty and time on the right.
            HStack(spacing: 8) {
                Label("Continue", systemImage: "play.fill")
                    .font(.app(.headline))
                Spacer(minLength: 8)
                Text(game.puzzle.difficulty.title)
                Text(verbatim: GameStatusView.formattedTime(game.elapsedSeconds))
                    .monospacedDigit()
            }
            .font(.app(.subheadline))
            .frame(maxWidth: .infinity)
        }
        .glassProminentButton()
        .controlSize(.large)
    }

    @ViewBuilder
    private var newGameButton: some View {
        let label = HStack {
            Label("New Game", systemImage: "plus")
                .font(.app(.headline))
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        // The primary action is the most prominent button: Continue when there's a saved game.
        Group {
            if savedGame == nil {
                Button { isShowingNewGame = true } label: { label }
                    .glassProminentButton()
            } else {
                Button { isShowingNewGame = true } label: { label }
                    .glassButton()
            }
        }
        .controlSize(.large)
        .zoomSource(id: TransitionID.newGame, in: namespace)
    }

    /// A game left unfinished and replaced counts as lost, once the player had started it.
    private func recordAbandonedGame() {
        if let abandoned = savedGame, !abandoned.isFinished, abandoned.hasProgress {
            recorder.record(abandoned)
        }
    }

    /// Opens the puzzle a code stands for, graded off the main actor; `false` when the code makes no
    /// puzzle. Like a new game, it opens once the sheet has closed.
    private func startGame(code: String) async -> Bool {
        guard let puzzle = await Task.detached(priority: .userInitiated, operation: { PuzzleCode.puzzle(from: code) }).value else {
            return false
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
        pendingGame = model
        isShowingNewGame = false
        return true
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
/// Today's puzzle and the streak: the days of the week solved on their day, and a way into today's
/// game. The title opens the calendar.
private struct DailyCard: View {
    let onPlay: () -> Void
    let onCalendar: () -> Void

    @Query(filter: #Predicate<GameRecord> { $0.isDaily }) private var records: [GameRecord]

    var body: some View {
        let daily = DailyRecords(records)
        let today = DailyCalendar.today()
        let streak = daily.streak.current(today: today)
        let solvedToday = daily.solvedDays.contains(today)
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Button(action: onCalendar) {
                    HStack(spacing: 6) {
                        Label("Daily Sudoku", systemImage: "calendar")
                            .font(.app(.headline))
                        Image(systemName: "chevron.right")
                            .font(.app(.footnote, weight: .semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(.orange)
                    Text("\(streak) day streak")
                        .monospacedDigit()
                }
                .font(.app(.subheadline, weight: .semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.orange.opacity(0.15), in: .capsule)
            }

            WeekStrip(solvedDays: daily.streak.solvedDays)

            // Secondary: the screen's one prominent action is Continue or New Game at the bottom.
            Button(action: onPlay) {
                HStack {
                    if solvedToday {
                        Label("Solved Today", systemImage: "checkmark")
                    } else if DailyRecords.store(forDay: today).load() != nil {
                        Label("Continue Today's Puzzle", systemImage: "play.fill")
                    } else {
                        Label("Play Today's Puzzle", systemImage: "play.fill")
                    }
                    Spacer(minLength: 8)
                    Text(DailyPuzzle.difficulty(forDay: today).title)
                        .font(.app(.subheadline))
                        .foregroundStyle(.secondary)
                }
                .font(.app(.headline))
                .frame(maxWidth: .infinity)
            }
            .glassButton()
            .controlSize(.large)
            .disabled(solvedToday)
        }
        .padding(18)
        .background(.fill.quaternary, in: .rect(cornerRadius: 24))
    }
}

/// The current week, one circle per day, with today ringed. Days follow the user's calendar
/// (first weekday and names).
private struct WeekStrip: View {
    /// Days solved on their own day, filled in.
    let solvedDays: Set<Int>

    private var days: [Date] {
        let calendar = Calendar.current
        guard let week = calendar.dateInterval(of: .weekOfYear, for: .now) else { return [] }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: week.start) }
    }

    var body: some View {
        HStack {
            ForEach(days, id: \.self) { day in
                let isToday = Calendar.current.isDateInToday(day)
                let isSolved = solvedDays.contains(DailyCalendar.day(of: day))
                VStack(spacing: 6) {
                    Text(day, format: .dateTime.weekday(.narrow))
                        .font(.app(.caption, weight: .semibold))
                        .foregroundStyle(isToday ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                    Text(day, format: .dateTime.day())
                        .font(.app(.subheadline, weight: isToday || isSolved ? .bold : .regular))
                        .monospacedDigit()
                        .foregroundStyle(isSolved ? AnyShapeStyle(Color.white) : AnyShapeStyle(.primary))
                        .frame(width: 34, height: 34)
                        .background {
                            if isSolved {
                                Circle().fill(Color.orange.gradient)
                            }
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
    /// A full-width tile in one row: the icon beside the words, so it stays short.
    var isWide = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            if isWide {
                HStack(spacing: 14) {
                    icon
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.app(.headline))
                            .foregroundStyle(.primary)
                        Text(subtitle)
                            .font(.app(.caption))
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.app(.footnote, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(14)
                .background(.fill.quaternary, in: .rect(cornerRadius: 24))
                .contentShape(.rect(cornerRadius: 24))
            } else {
                tall
            }
        }
        .buttonStyle(.pressable)
    }

    private var icon: some View {
        Image(systemName: systemImage)
            .font(.app(.title2))
            .foregroundStyle(.white)
            .frame(width: 44, height: 44)
            .background(tint.gradient, in: .rect(cornerRadius: 12))
    }

    private var tall: some View {
        VStack(alignment: .leading, spacing: 10) {
            icon
            Spacer(minLength: 0)
            Text(title)
                .font(.app(.headline))
                .foregroundStyle(.primary)
            Text(subtitle)
                .font(.app(.caption))
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, minHeight: 130, alignment: .leading)
        .padding(16)
        .background(.fill.quaternary, in: .rect(cornerRadius: 24))
        .contentShape(.rect(cornerRadius: 24))
    }
}
