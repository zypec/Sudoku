//
//  RaceViews.swift
//  Sudoku
//

import SwiftData
import SwiftUI

// MARK: List

/// The races this player started or joined, and the ways into a new one.
struct RaceListView: View {
    @State private var isStarting = false
    @State private var isJoining = false
    @State private var joinCode = ""
    @State private var joinError: RaceStore.JoinError?
    @State private var opened: Race?

    private var store: RaceStore {
        RaceStore.shared
    }

    var body: some View {
        List {
            Section {
                Button("Start a Race", systemImage: "flag.checkered") {
                    isStarting = true
                }
                Button("Join with Code", systemImage: "number") {
                    joinCode = ""
                    isJoining = true
                }
            } footer: {
                Text("Everyone plays the same puzzle. Whoever finishes first, before the race ends, wins. Share the race's code with your friends, and add the result codes they send you.")
            }

            if !store.races.isEmpty {
                Section("Races") {
                    ForEach(store.races) { race in
                        NavigationLink {
                            RaceDetailView(raceID: race.id)
                        } label: {
                            RaceRow(race: race)
                        }
                    }
                    .onDelete { offsets in
                        for race in offsets.map({ store.races[$0] }) {
                            store.remove(race)
                        }
                    }
                }
            }
        }
        .navigationTitle("Race")
        .sheet(isPresented: $isStarting) {
            NewRaceSheet { race in
                opened = race
            }
        }
        .alert("Join a Race", isPresented: $isJoining) {
            TextField(text: $joinCode) {
                Text(verbatim: "RXXX-XXXX-XXXX-XXXX")
            }
            .textInputAutocapitalization(.characters)
            .autocorrectionDisabled()
            Button("Join") {
                do throws(RaceStore.JoinError) {
                    opened = try store.join(joinCode)
                } catch {
                    joinError = error
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Paste the race code a friend shared.")
        }
        .alert("Couldn't Join", isPresented: Binding(get: { joinError != nil }, set: { if !$0 { joinError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            switch joinError {
            case .unknownPuzzle?: Text("This race's puzzle isn't in this version of the app.")
            default: Text("That isn't a race code.")
            }
        }
        .navigationDestination(item: $opened) { race in
            RaceDetailView(raceID: race.id)
        }
    }
}

private struct RaceRow: View {
    let race: Race

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 8) {
                DifficultyMeter(difficulty: race.puzzle.difficulty)
                    .scaleEffect(0.7, anchor: .leading)
                    .frame(width: 30, alignment: .leading)
                Text(race.puzzle.difficulty.title)
                    .font(.headline)
            }
            Group {
                if let winner = race.winner, race.isOver {
                    Text("Won by \(winner.name.isEmpty ? String(localized: "you") : winner.name)")
                } else if let mine = race.myResult {
                    Text("Your time: \(GameStatusView.formattedTime(mine.seconds))")
                } else if race.isOver {
                    Text("Ended")
                } else {
                    Text("Ends \(race.deadline, format: .relative(presentation: .named))")
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
    }
}

// MARK: New race

/// Picks the difficulty and how long the race runs, then starts it.
private struct NewRaceSheet: View {
    let opened: (Race) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var difficulty: Difficulty = .medium
    @State private var timeLimit = RaceStore.timeLimits[2]
    @State private var isStarting = false
    @State private var failed = false

    var body: some View {
        NavigationStack {
            Form {
                Picker("Difficulty", selection: $difficulty) {
                    ForEach(Difficulty.allCases.filter(\.isAvailable)) { difficulty in
                        Text(difficulty.title).tag(difficulty)
                    }
                }
                Picker("Time Limit", selection: $timeLimit) {
                    ForEach(RaceStore.timeLimits, id: \.self) { limit in
                        Text(Self.title(of: limit)).tag(limit)
                    }
                }
                Section {
                    Button {
                        Task { await start() }
                    } label: {
                        HStack {
                            Text("Start Race")
                            Spacer()
                            if isStarting {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isStarting)
                } footer: {
                    if failed {
                        Text("No puzzle of this difficulty could be prepared for a race.")
                            .foregroundStyle(.red)
                    } else {
                        Text("The race ends when its time is up, whether or not everyone has finished.")
                    }
                }
            }
            .navigationTitle("New Race")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                CloseButton {
                    dismiss()
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    static func title(of limit: TimeInterval) -> String {
        switch limit {
        case 3600: String(localized: "1 hour")
        case 6 * 3600: String(localized: "6 hours")
        case 86400: String(localized: "1 day")
        case 3 * 86400: String(localized: "3 days")
        default: String(localized: "1 week")
        }
    }

    private func start() async {
        isStarting = true
        defer { isStarting = false }
        guard let race = await RaceStore.shared.start(difficulty, timeLimit: timeLimit) else {
            failed = true
            return
        }
        dismiss()
        opened(race)
    }
}

// MARK: Detail

/// One race: its code to share, the game, this player's result and everyone's standings.
struct RaceDetailView: View {
    let raceID: String

    @Environment(AppSettings.self) private var settings
    @State private var resultCode = ""
    @State private var isResultInvalid = false
    @State private var isPlaying = false

    var body: some View {
        if let race = RaceStore.shared.race(raceID) {
            content(race)
        } else {
            ContentUnavailableView("This race was removed.", systemImage: "flag.slash")
        }
    }

    @ViewBuilder
    private func content(_ race: Race) -> some View {
        @Bindable var settings = settings
        List {
            Section {
                LabeledContent("Difficulty", value: String(localized: race.puzzle.difficulty.title))
                LabeledContent(race.isOver ? LocalizedStringKey("Ended") : LocalizedStringKey("Ends")) {
                    Text(race.deadline, format: .dateTime.weekday().day().month().hour().minute())
                }
                LabeledContent("Race Code") {
                    Text(verbatim: race.code)
                        .font(.body.monospaced())
                        .textSelection(.enabled)
                }
                ShareLink(item: String(localized: "Race me in Sudoku! Join with the code \(race.code) before \(race.deadline.formatted(date: .abbreviated, time: .shortened))."),
                          preview: SharePreview(Text("Sudoku Race"))) {
                    Label("Share Race", systemImage: "square.and.arrow.up")
                }
            }

            Section {
                if let mine = race.myResult {
                    LabeledContent("Your Time", value: GameStatusView.formattedTime(mine.seconds))
                    LabeledContent("Finished") {
                        Text(mine.finishedAt, format: .dateTime.weekday().day().month().hour().minute())
                    }
                    TextField("Your Name", text: $settings.playerName)
                        .autocorrectionDisabled()
                    let code = RaceCode.resultCode(raceID: race.id, name: settings.playerName, finishedAt: mine.finishedAt, seconds: mine.seconds)
                    ShareLink(item: String(localized: "I finished our Sudoku race in \(GameStatusView.formattedTime(mine.seconds)). Add my result: \(code)"),
                              preview: SharePreview(Text("Sudoku Race Result"))) {
                        Label("Share Your Result", systemImage: "square.and.arrow.up")
                    }
                    .disabled(settings.playerName.trimmingCharacters(in: .whitespaces).isEmpty)
                } else {
                    Button(RaceStore.shared.gameStore(for: race).load() == nil ? LocalizedStringKey("Play") : LocalizedStringKey("Continue"), systemImage: "play.fill") {
                        isPlaying = true
                    }
                    .font(.headline)
                }
            } header: {
                Text("You")
            } footer: {
                if race.myResult != nil, settings.playerName.trimmingCharacters(in: .whitespaces).isEmpty {
                    Text("Enter your name to share your result.")
                } else if race.myResult == nil, race.isOver {
                    Text("The race is over; a finish now comes in late.")
                }
            }

            Section {
                let standings = race.standings(myName: settings.playerName)
                if standings.isEmpty {
                    Text("No one has finished yet.")
                        .foregroundStyle(.secondary)
                }
                ForEach(Array(standings.enumerated()), id: \.offset) { place, entry in
                    StandingRow(place: place + 1, result: entry.result, isMe: entry.isMe, inTime: entry.inTime,
                                isWinner: entry.result == race.winner, myName: settings.playerName)
                }
                HStack {
                    TextField("Paste a result code", text: $resultCode)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.characters)
                        .onChange(of: resultCode) { isResultInvalid = false }
                    Button("Add") {
                        if RaceStore.shared.addResult(resultCode, to: race.id) {
                            resultCode = ""
                        } else {
                            isResultInvalid = true
                        }
                    }
                    .disabled(resultCode.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            } header: {
                Text("Standings")
            } footer: {
                if isResultInvalid {
                    Text("That isn't a result of this race.")
                        .foregroundStyle(.red)
                } else {
                    Text("Add the result codes your friends share with you.")
                }
            }
        }
        .navigationTitle("Race")
        .navigationDestination(isPresented: $isPlaying) {
            RaceGameView(race: race)
        }
    }
}

private struct StandingRow: View {
    let place: Int
    let result: RaceCode.Result
    let isMe: Bool
    let inTime: Bool
    let isWinner: Bool
    let myName: String

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if isWinner {
                    Image(systemName: "trophy.fill")
                        .foregroundStyle(.yellow)
                } else {
                    Text(verbatim: "\(place)")
                        .foregroundStyle(.secondary)
                }
            }
            .font(.headline)
            .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(isMe ? String(localized: "You") : (result.name.isEmpty ? String(localized: "Someone") : result.name))
                    .font(.headline)
                Text(result.finishedAt, format: .dateTime.weekday().day().month().hour().minute())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(verbatim: GameStatusView.formattedTime(result.seconds))
                    .font(.body.monospacedDigit())
                if !inTime {
                    Text("Late")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                }
            }
        }
    }
}

// MARK: Game

/// The race's puzzle as a game, saved apart from the main game. Solving it records the result.
private struct RaceGameView: View {
    let race: Race

    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var modelContext
    @State private var model: GameModel?

    var body: some View {
        Group {
            if let model {
                GameView(model: model, returnTitle: "Back to Race")
            }
        }
        .task {
            guard model == nil else { return }
            let store = RaceStore.shared.gameStore(for: race)
            let game = store.load() ?? SudokuGame(puzzle: race.puzzle, mistakeLimit: settings.mistakeLimitSetting)
            let model = GameModel(game: game, settings: settings, store: store, recorder: GameRecorder(context: modelContext))
            model.isFixedPuzzle = true
            let id = race.id
            model.onFinish = { game in
                RaceStore.shared.finish(id, game: game)
            }
            model.save()
            self.model = model
        }
    }
}
