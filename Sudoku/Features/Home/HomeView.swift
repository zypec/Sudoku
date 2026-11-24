//
//  HomeView.swift
//  Sudoku
//

import SwiftUI

/// Home screen: continue the saved game or start a new one. New Game and Settings open as
/// Liquid Glass sheets that zoom out of the buttons that present them.
struct HomeView: View {
    @Environment(AppSettings.self) private var settings
    @Namespace private var namespace

    @State private var activeGame: GameModel?
    @State private var savedGame: SudokuGame?
    @State private var isShowingNewGame = false
    @State private var isShowingSettings = false
    /// A game generated from the New Game sheet, opened once the sheet has finished closing.
    @State private var pendingGame: GameModel?

    private let store = GameStore.shared

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Spacer()
                Text("Sudoku")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                Spacer()
                GlassEffectContainer(spacing: 12) {
                    VStack(spacing: 12) {
                        if let savedGame {
                            continueButton(for: savedGame)
                        }
                        newGameButton
                    }
                }
            }
            .padding()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Settings", systemImage: "gearshape") {
                        isShowingSettings = true
                    }
                }
                .matchedTransitionSource(id: TransitionID.settings, in: namespace)
            }
            .navigationDestination(item: $activeGame) { model in
                GameView(model: model)
            }
            .sheet(isPresented: $isShowingNewGame, onDismiss: openPendingGame) {
                NewGameSheet(replacesGameInProgress: savedGame != nil) { difficulty in
                    await startGame(difficulty)
                }
                .navigationTransition(.zoom(sourceID: TransitionID.newGame, in: namespace))
            }
            .sheet(isPresented: $isShowingSettings) {
                SettingsView()
                    .navigationTransition(.zoom(sourceID: TransitionID.settings, in: namespace))
            }
            .task {
                savedGame = store.load()
            }
            .onChange(of: activeGame) { _, game in
                // Returning from a game: show its latest saved state (or none if it finished).
                if game == nil {
                    savedGame = store.load()
                }
            }
        }
    }

    private func continueButton(for game: SudokuGame) -> some View {
        Button {
            activeGame = GameModel(game: game, settings: settings, store: store)
        } label: {
            VStack(spacing: 2) {
                Text("Continue")
                    .font(.headline)
                Text("\(Text(game.puzzle.difficulty.title)) · \(GameStatusView.formattedTime(game.elapsedSeconds))")
                    .font(.caption)
                    .opacity(0.8)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.glassProminent)
        .controlSize(.large)
    }

    @ViewBuilder
    private var newGameButton: some View {
        let label = Text("New Game")
            .font(.headline)
            .frame(maxWidth: .infinity, minHeight: 44)
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

    private func startGame(_ difficulty: Difficulty) async {
        let model = await GameModel.make(difficulty: difficulty, settings: settings, store: store)
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
        static let settings = "settings"
    }
}

#Preview {
    HomeView()
        .environment(AppSettings())
}
