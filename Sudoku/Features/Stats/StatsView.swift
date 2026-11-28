//
//  StatsView.swift
//  Sudoku
//

import Charts
import SwiftData
import SwiftUI

/// Statistics, one difficulty at a time: a summary, solve times, how the player does with each
/// technique and the most recent games. Everything is computed from the stored `GameRecord`s.
///
/// The difficulties are always there. Only those with a game played can be chosen, and the easiest
/// of them is shown first; with no games at all the picker asks for a difficulty and every one is
/// locked, while the summary shows what it will hold.
struct StatsView: View {
    @Query(sort: \GameRecord.finishedAt, order: .reverse) private var records: [GameRecord]
    @Environment(\.modelContext) private var modelContext
    /// The difficulty picked; `nil` (or one whose games were reset) falls back to the easiest played.
    @State private var selection: Difficulty?
    @State private var isConfirmingReset = false

    var body: some View {
        let all = records.map(\.result)
        let played = Difficulty.allCases.filter { difficulty in all.contains { $0.difficulty == difficulty } }
        let shown = selection.flatMap { played.contains($0) ? $0 : nil } ?? played.first
        let results = shown.map { difficulty in all.filter { $0.difficulty == difficulty } } ?? []
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                DifficultyPicker(selection: shown, played: played) { selection = $0 }
                SummaryGrid(summary: StatsSummary(results: results))
                if results.isEmpty {
                    Text("Finish a game to see your statistics here.")
                        .font(.app(.subheadline))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                } else {
                    SolveTimeChart(results: results)
                    TechniqueSection(stats: TechniqueStat.all(from: results))
                    RecentGames(results: Array(results.prefix(10)))
                }
                DailyStreakSection()
            }
            .padding()
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .animation(.panel, value: shown)
        .navigationTitle("Statistics")
        .toolbar {
            Menu("More", systemImage: "ellipsis") {
                Button("Reset Statistics", systemImage: "trash", role: .destructive) {
                    isConfirmingReset = true
                }
                .disabled(shown == nil)
            }
        }
        .confirmationDialog(
            shown.map(resetTitle) ?? Text(verbatim: ""),
            isPresented: $isConfirmingReset,
            titleVisibility: .visible
        ) {
            Button("Reset", role: .destructive) {
                if let shown { reset(shown) }
            }
        } message: {
            if let shown {
                Text("Every \(shown.title) game is removed from your statistics. This can't be undone.")
            }
        }
    }

    private func resetTitle(_ difficulty: Difficulty) -> Text {
        Text("Reset \(String(localized: difficulty.title)) statistics?")
    }

    /// Deletes every recorded game of one difficulty.
    private func reset(_ difficulty: Difficulty) {
        for record in records where record.difficultyRaw == difficulty.rawValue {
            modelContext.delete(record)
        }
        try? modelContext.save()
        selection = nil
    }
}

// MARK: Picker

/// The difficulty shown, as a button in its color that opens the list of difficulties. Those without
/// a game played are locked and say so.
private struct DifficultyPicker: View {
    let selection: Difficulty?
    let played: [Difficulty]
    let choose: (Difficulty) -> Void

    var body: some View {
        Menu {
            ForEach(Difficulty.allCases) { difficulty in
                let isPlayed = played.contains(difficulty)
                Button {
                    choose(difficulty)
                } label: {
                    if difficulty == selection {
                        Label(difficulty.title, systemImage: "checkmark")
                    } else if isPlayed {
                        Text(difficulty.title)
                    } else {
                        // A menu row's second text is its subtitle.
                        Text(difficulty.title)
                        Text("No games played yet")
                        Image(systemName: "lock.fill")
                    }
                }
                .disabled(!isPlayed)
            }
        } label: {
            HStack(spacing: 8) {
                if let selection {
                    DifficultyMeter(difficulty: selection)
                        .scaleEffect(0.8)
                    Text(selection.title)
                } else {
                    Text("Choose a Difficulty")
                }
                Image(systemName: "chevron.up.chevron.down")
                    .font(.app(.caption, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .font(.app(.headline))
            .foregroundStyle(.primary)
            .padding(.leading, selection == nil ? 16 : 12)
            .padding(.trailing, 14)
            .frame(minHeight: 44)
            .background((selection?.color ?? .secondary).opacity(0.16), in: .capsule)
        }
        .accessibilityLabel(Text("Difficulty"))
        .accessibilityValue(selection.map { Text($0.title) } ?? Text("Choose a Difficulty"))
    }
}

// MARK: Summary

private struct SummaryGrid: View {
    let summary: StatsSummary

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            StatTile(title: "Total Score", systemImage: "star") {
                Text(summary.totalScore, format: .number)
            }
            StatTile(title: "Best Score", systemImage: "star.circle") {
                if let best = summary.bestScore {
                    Text(best, format: .number)
                } else {
                    Text("None")
                }
            }
            StatTile(title: "Played", systemImage: "square.grid.3x3") {
                Text(verbatim: "\(summary.played)")
            }
            StatTile(title: "Win Rate", systemImage: "trophy") {
                if let rate = summary.winRate {
                    Text(rate, format: .percent.precision(.fractionLength(0)))
                } else {
                    Text("None")
                }
            } detail: {
                Text("\(summary.wins) of \(summary.played) won")
            }
            StatTile(title: "Best Time", systemImage: "bolt") {
                time(summary.bestSeconds)
            }
            StatTile(title: "Average Time", systemImage: "stopwatch") {
                time(summary.averageSeconds)
            }
            StatTile(title: "Current Streak", systemImage: "flame") {
                Text(verbatim: "\(summary.currentStreak)")
            }
            StatTile(title: "Best Streak", systemImage: "medal") {
                Text(verbatim: "\(summary.bestStreak)")
            }
            StatTile(title: "Hints per Game", systemImage: "lightbulb") {
                if let hints = summary.hintsPerGame {
                    Text(hints, format: .number.precision(.fractionLength(0...1)))
                } else {
                    Text("None")
                }
            }
        }
    }

    @ViewBuilder
    private func time(_ seconds: Int?) -> some View {
        if let seconds {
            Text(verbatim: GameStatusView.formattedTime(seconds))
        } else {
            Text("None")
        }
    }
}

private struct StatTile<Value: View, Detail: View>: View {
    let title: LocalizedStringKey
    let systemImage: String
    @ViewBuilder let value: Value
    @ViewBuilder let detail: Detail

    init(title: LocalizedStringKey, systemImage: String, @ViewBuilder value: () -> Value, @ViewBuilder detail: () -> Detail = { EmptyView() }) {
        self.title = title
        self.systemImage = systemImage
        self.value = value()
        self.detail = detail()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: systemImage)
                .font(.app(.subheadline))
                .foregroundStyle(.secondary)
            value
                .font(.app(.title, weight: .bold))
                .monospacedDigit()
                .contentTransition(.numericText())
            detail
                .font(.app(.caption))
                .foregroundStyle(.secondary)
        }
        // Fill the row so tiles side by side have the same height.
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(16)
        .background(.fill.quaternary, in: .rect(cornerRadius: 20))
        .accessibilityElement(children: .combine)
    }
}

// MARK: Solve times

/// The time of the last 20 wins in order, with the average as a reference line. One series, so no
/// legend; touching a point shows its exact time.
private struct SolveTimeChart: View {
    let results: [GameResult]

    @State private var selectedIndex: Int?

    private struct Point: Identifiable {
        let index: Int
        let minutes: Double
        let result: GameResult
        var id: Int { index }
    }

    private var points: [Point] {
        let wins = results.filter(\.isWin).sorted { $0.finishedAt < $1.finishedAt }.suffix(20)
        return wins.enumerated().map { Point(index: $0.offset + 1, minutes: Double($0.element.elapsedSeconds) / 60, result: $0.element) }
    }

    var body: some View {
        let points = points
        if points.count >= 2 {
            let average = points.map(\.minutes).reduce(0, +) / Double(points.count)
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle("Solve Times")
                Chart {
                    ForEach(points) { point in
                        LineMark(x: .value("Game", point.index), y: .value("Minutes", point.minutes))
                            .lineStyle(StrokeStyle(lineWidth: 2))
                            .interpolationMethod(.monotone)
                        PointMark(x: .value("Game", point.index), y: .value("Minutes", point.minutes))
                            .symbolSize(point.index == selectedIndex ? 120 : 50)
                    }
                    RuleMark(y: .value("Average", average))
                        .foregroundStyle(.secondary)
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        .annotation(position: .top, alignment: .leading) {
                            Text("Average")
                                .font(.app(.caption2))
                                .foregroundStyle(.secondary)
                        }
                    if let selectedIndex, let point = points.first(where: { $0.index == selectedIndex }) {
                        RuleMark(x: .value("Game", point.index))
                            .foregroundStyle(.quaternary)
                            .annotation(position: .top, overflowResolution: .init(x: .fit, y: .disabled)) {
                                VStack(spacing: 2) {
                                    Text(verbatim: GameStatusView.formattedTime(point.result.elapsedSeconds))
                                        .font(.app(.caption, weight: .semibold))
                                        .monospacedDigit()
                                    Text(point.result.finishedAt, format: .dateTime.day().month())
                                        .font(.app(.caption2))
                                        .foregroundStyle(.secondary)
                                }
                                .padding(6)
                                .background(.background, in: .rect(cornerRadius: 8))
                                .shadow(radius: 2)
                            }
                    }
                }
                .foregroundStyle(Color.accentColor)
                .chartXAxis(.hidden)
                .chartYAxisLabel { Text("Minutes") }
                .chartXSelection(value: $selectedIndex)
                .frame(height: 180)
                .accessibilityLabel(Text("Solve Times"))
            }
        }
    }
}

// MARK: Techniques

private struct TechniqueSection: View {
    let stats: [TechniqueStat]

    var body: some View {
        if !stats.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle("Techniques")
                VStack(spacing: 14) {
                    ForEach(stats) { stat in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(verbatim: stat.technique.title)
                                    .font(.app(.subheadline, weight: .semibold))
                                Spacer()
                                Text("\(stat.solvedAlone) of \(stat.needed) on your own")
                                    .font(.app(.caption))
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                            ProgressView(value: stat.successRate)
                                .tint(Color.accentColor)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
                .padding(16)
                .background(.fill.quaternary, in: .rect(cornerRadius: 20))
            }
        }
    }
}

// MARK: Recent games

private struct RecentGames: View {
    let results: [GameResult]

    var body: some View {
        if !results.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle("Recent Games")
                VStack(spacing: 0) {
                    ForEach(Array(results.enumerated()), id: \.offset) { index, result in
                        if index > 0 {
                            Divider()
                        }
                        row(result)
                    }
                }
                .padding(.horizontal, 16)
                .background(.fill.quaternary, in: .rect(cornerRadius: 20))
            }
        }
    }

    private func row(_ result: GameResult) -> some View {
        HStack(spacing: 12) {
            outcomeIcon(result)
            VStack(alignment: .leading, spacing: 2) {
                Text(result.difficulty.title)
                    .font(.app(.subheadline, weight: .semibold))
                Text(result.finishedAt, format: .relative(presentation: .named))
                    .font(.app(.caption))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(verbatim: GameStatusView.formattedTime(result.elapsedSeconds))
                    .font(.app(.subheadline, weight: .semibold))
                    .monospacedDigit()
                if result.isWin {
                    Text("+\(result.score.total.formatted(.number)) points")
                        .font(.app(.caption, weight: .semibold))
                        .foregroundStyle(.tint)
                }
                if result.isWin, let estimate = result.estimatedSeconds {
                    let share = SolveTimeEstimate.shareOfSlowerPlayers(than: result.elapsedSeconds, estimate: estimate)
                    Text("Faster than \(share.formatted(.percent.precision(.fractionLength(0))))")
                        .font(.app(.caption))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }

    /// Outcome as an icon with its own label, so it never rests on color alone.
    private func outcomeIcon(_ result: GameResult) -> some View {
        let (symbol, color, label): (String, Color, LocalizedStringKey) = if result.isWin {
            ("checkmark.circle.fill", .green, "Solved")
        } else if result.isSolved {
            ("wand.and.stars", .purple, "Auto Solved")
        } else {
            ("xmark.circle.fill", .red, "Lost")
        }
        return Image(systemName: symbol)
            .font(.app(.title2))
            .foregroundStyle(color)
            .accessibilityLabel(Text(label))
    }
}

// MARK: Daily

/// The daily streak, now and at its best, and the way to the calendar.
private struct DailyStreakSection: View {
    @Query(filter: #Predicate<GameRecord> { $0.isDaily }) private var records: [GameRecord]

    var body: some View {
        let daily = DailyRecords(records)
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle("Daily Streak")
            HStack(spacing: 12) {
                StreakTile(title: "Current Streak", value: daily.streak.current(today: DailyCalendar.today()), systemImage: "flame.fill", tint: .orange)
                StreakTile(title: "Best Streak", value: daily.streak.best, systemImage: "medal.fill", tint: .yellow)
            }
            NavigationLink {
                DailyCalendarView()
            } label: {
                Label("Calendar", systemImage: "calendar")
                    .font(.app(.subheadline, weight: .semibold))
            }
        }
    }
}

private struct SectionTitle: View {
    let title: LocalizedStringKey

    init(_ title: LocalizedStringKey) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.app(.title3, weight: .bold))
            .accessibilityAddTraits(.isHeader)
    }
}
