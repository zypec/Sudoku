//
//  DailyViews.swift
//  Sudoku
//

import SwiftData
import SwiftUI

/// Daily games as the statistics keep them: which days were solved on their own day, and which were
/// solved at all (a past day played later counts for the calendar, never for the streak).
struct DailyRecords {
    let streak: DailyStreak
    /// Days whose puzzle was solved, on its day or later.
    let solvedDays: Set<Int>

    init(_ records: [GameRecord], calendar: Calendar = .current) {
        let solved = records.filter { $0.isDaily && $0.result.isWin }.compactMap { record in
            record.dailyDay.map { (puzzleDay: $0, solvedOn: DailyCalendar.day(of: record.finishedAt, calendar: calendar)) }
        }
        streak = DailyStreak(solved: solved)
        solvedDays = Set(solved.map(\.puzzleDay))
    }

    /// Where a day's game in progress is saved.
    @MainActor
    static func store(forDay day: Int) -> GameStore {
        GameStore(url: URL.applicationSupportDirectory.appending(path: "Daily/\(day).json"))
    }
}

// MARK: Game

/// A day's puzzle as a game, saved apart from the main game and recorded with its day.
struct DailyGameView: View {
    let day: Int

    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var modelContext
    @State private var model: GameModel?

    var body: some View {
        Group {
            if let model {
                GameView(model: model, returnTitle: "Done")
            } else {
                ProgressView()
            }
        }
        .task {
            guard model == nil, let puzzle = DailyPuzzle.puzzle(forDay: day) else { return }
            let store = DailyRecords.store(forDay: day)
            let game = store.load() ?? SudokuGame(puzzle: puzzle, mistakeLimit: settings.mistakeLimitSetting)
            let model = GameModel(game: game, settings: settings, store: store, recorder: GameRecorder(context: modelContext))
            model.isFixedPuzzle = true
            model.dailyDay = day
            model.save()
            self.model = model
        }
    }
}

// MARK: Calendar

/// A month of daily puzzles: the days solved on their day, those solved later, and today. Any day up
/// to today can be played; only its own day counts toward the streak.
struct DailyCalendarView: View {
    @Environment(\.modelContext) private var modelContext
    /// Read when the calendar shows up (and again on coming back from a day's game), not kept live: a
    /// live query here and the home screen's daily card set each other off and drew without end.
    @State private var daily = DailyRecords([])
    @State private var month = Calendar.current.dateInterval(of: .month, for: .now)?.start ?? .now

    private let calendar = Calendar.current

    var body: some View {
        let today = DailyCalendar.today()
        ScrollView {
            VStack(spacing: 24) {
                HStack(spacing: 12) {
                    StreakTile(title: "Current Streak", value: daily.streak.current(today: today), systemImage: "flame.fill", tint: .orange)
                    StreakTile(title: "Best Streak", value: daily.streak.best, systemImage: "medal.fill", tint: .yellow)
                }

                VStack(spacing: 12) {
                    HStack {
                        Button("Previous Month", systemImage: "chevron.left") { shift(-1) }
                            .labelStyle(.iconOnly)
                        Spacer()
                        Text(month, format: .dateTime.month(.wide).year())
                            .font(.app(.headline))
                        Spacer()
                        Button("Next Month", systemImage: "chevron.right") { shift(1) }
                            .labelStyle(.iconOnly)
                            .disabled(calendar.isDate(month, equalTo: .now, toGranularity: .month))
                    }
                    .font(.app(.title3))

                    // The weekday names in a row of their own: in the grid their places (0 to 6) were
                    // the same ids as the first days', and the grid laid itself out again forever.
                    // By place, not by name, since the narrow names repeat (T, T, S, S).
                    HStack(spacing: 6) {
                        ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                            Text(symbol)
                                .font(.app(.caption, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 8) {
                        ForEach(Array(cells.enumerated()), id: \.offset) { _, date in
                            if let date {
                                let day = DailyCalendar.day(of: date)
                                DayCell(date: date, day: day, today: today,
                                        onDay: daily.streak.solvedDays.contains(day), solved: daily.solvedDays.contains(day))
                            } else {
                                Color.clear.frame(height: 40)
                            }
                        }
                    }
                }
                .padding(16)
                .background(.fill.quaternary, in: .rect(cornerRadius: 24))

                Label("A day's puzzle counts toward your streak only when it's solved that day.", systemImage: "info.circle")
                    .font(.app(.footnote))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Daily Sudoku")
        .onAppear(perform: reload)
    }

    private func reload() {
        let records = (try? modelContext.fetch(FetchDescriptor<GameRecord>(predicate: #Predicate { $0.isDaily }))) ?? []
        daily = DailyRecords(records)
    }

    private func shift(_ months: Int) {
        if let next = calendar.date(byAdding: .month, value: months, to: month) {
            month = next
        }
    }

    /// Narrow weekday names, starting at the calendar's first weekday.
    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let first = calendar.firstWeekday - 1
        return Array(symbols[first...] + symbols[..<first])
    }

    /// The month's dates, with empty places before the first so it starts under its weekday.
    private var cells: [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: month) else { return [] }
        let lead = (calendar.component(.weekday, from: month) - calendar.firstWeekday + 7) % 7
        let dates = range.compactMap { calendar.date(byAdding: .day, value: $0 - 1, to: month) }
        return Array(repeating: nil, count: lead) + dates
    }
}

private struct DayCell: View {
    let date: Date
    let day: Int
    let today: Int
    /// Solved on its own day, so part of a streak.
    let onDay: Bool
    /// Solved at all.
    let solved: Bool

    var body: some View {
        let isToday = day == today
        let label = Text(date, format: .dateTime.day())
            .font(.app(.subheadline, weight: isToday || onDay ? .bold : .regular))
            .monospacedDigit()
            .frame(maxWidth: .infinity, minHeight: 40)
            .foregroundStyle(onDay ? AnyShapeStyle(Color.white) : day > today ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.primary))
            .background {
                Circle()
                    .fill(onDay ? AnyShapeStyle(Color.orange.gradient) : AnyShapeStyle(Color.clear))
                    .overlay {
                        Circle().strokeBorder(isToday ? AnyShapeStyle(.tint) : solved && !onDay ? AnyShapeStyle(Color.orange) : AnyShapeStyle(Color.clear), lineWidth: 2)
                    }
                    .frame(width: 38, height: 38)
            }
        if day <= today {
            NavigationLink {
                DailyGameView(day: day)
            } label: {
                label
            }
            .buttonStyle(.plain)
            .accessibilityValue(onDay ? Text("Solved on the day") : solved ? Text("Solved later") : Text(verbatim: ""))
        } else {
            label
        }
    }
}

struct StreakTile: View {
    let title: LocalizedStringKey
    let value: Int
    let systemImage: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: systemImage)
                .font(.app(.subheadline))
                .foregroundStyle(.secondary)
                .symbolRenderingMode(.multicolor)
            Text(value, format: .number)
                .font(.app(.title, weight: .bold))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(tint.opacity(0.12), in: .rect(cornerRadius: 20))
    }
}
