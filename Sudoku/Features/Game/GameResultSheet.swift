//
//  GameResultSheet.swift
//  Sudoku
//

import SwiftUI

/// How a game ended, as shown on the result sheet.
enum GameOutcome: Identifiable {
    case solved
    /// Auto solve did some of the work: no points, not a win.
    case autoSolved
    case lost

    var id: Self { self }

    init(game: SudokuGame) {
        if game.isSolved {
            self = game.usedAutoSolve ? .autoSolved : .solved
        } else {
            self = .lost
        }
    }
}

/// Shown when a game ends: the score with its breakdown, the time and how it compares, and the
/// way to the next game.
struct GameResultSheet: View {
    let model: GameModel
    let outcome: GameOutcome
    let onNewGame: () -> Void
    let onHome: () -> Void
    /// After a loss: take back the last mistake and play on.
    var onTakeBack: () -> Void = {}
    /// After a loss: the same puzzle from the start.
    var onPlayAgain: () -> Void = {}

    private var result: GameResult {
        GameResult(game: model.game)
    }

    var body: some View {
        let score = result.score
        VStack(spacing: 20) {
            VStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 44))
                    .foregroundStyle(color)
                Text(title)
                    .font(.system(.title, design: .rounded, weight: .bold))
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 24)

            if outcome == .solved {
                VStack(spacing: 2) {
                    Text(score.total, format: .number)
                        .font(.system(size: 56, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text("points")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                VStack(spacing: 0) {
                    ForEach(Array(score.lines.enumerated()), id: \.offset) { index, line in
                        if index > 0 {
                            Divider()
                        }
                        HStack {
                            Text(label(for: line))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(verbatim: signed(line.points, isBase: line.kind == .base))
                                .fontWeight(.semibold)
                                .monospacedDigit()
                                .foregroundStyle(line.points < 0 ? AnyShapeStyle(Color.red) : AnyShapeStyle(.primary))
                        }
                        .font(.subheadline)
                        .padding(.vertical, 9)
                    }
                }
                .padding(.horizontal, 16)
                .background(.fill.quaternary, in: .rect(cornerRadius: 18))
            }

            Spacer(minLength: 0)

            if outcome == .lost {
                lostActions
            } else {
                VStack(spacing: 10) {
                    Button(action: onNewGame) {
                        Label("New Game", systemImage: "plus")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .glassProminentButton()
                    Button(action: onHome) {
                        Text("Home")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .glassButton()
                }
                .controlSize(.large)
            }
        }
        .padding()
        .frame(maxWidth: 480)
        .presentationDetents([.large])
    }

    /// A loss is a way back in first: the last mistake taken back, or the same puzzle again. A new
    /// game and the way home are still there, quieter.
    private var lostActions: some View {
        VStack(spacing: 10) {
            Button(action: onTakeBack) {
                Label("Undo Last Mistake", systemImage: "arrow.uturn.backward")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .glassProminentButton()
            Button(action: onPlayAgain) {
                Label("Play Again", systemImage: "arrow.clockwise")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .glassButton()
            HStack(spacing: 32) {
                Button("New Game", action: onNewGame)
                Button("Home", action: onHome)
            }
            .buttonStyle(.borderless)
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.top, 4)
        }
        .controlSize(.large)
    }

    private var symbol: String {
        switch outcome {
        case .solved: "checkmark.seal.fill"
        case .autoSolved: "wand.and.stars"
        case .lost: "heart.slash.fill"
        }
    }

    private var color: Color {
        switch outcome {
        case .solved: .green
        case .autoSolved: .purple
        case .lost: .red
        }
    }

    private var title: LocalizedStringKey {
        switch outcome {
        case .solved: "Puzzle Solved!"
        case .autoSolved: "Solved by Auto Solve"
        case .lost: "Game Over"
        }
    }

    private var message: String {
        let time = GameStatusView.formattedTime(model.elapsedSeconds)
        switch outcome {
        case .solved:
            if let share = model.shareOfSlowerPlayers {
                return String(localized: "You solved it in \(time), faster than an estimated \(share.formatted(.percent.precision(.fractionLength(0)))) of players.")
            }
            return String(localized: "You solved it in \(time).")
        case .autoSolved:
            return String(localized: "Games finished by auto solve don't earn points or count as wins.")
        case .lost:
            return String(localized: "You reached the mistake limit.")
        }
    }

    private func label(for line: GameScore.Line) -> LocalizedStringKey {
        switch line.kind {
        case .base: "\(Text(model.game.puzzle.difficulty.title)) puzzle"
        case .speed: "Speed"
        case .mistakes: "Mistakes (\(line.count))"
        case .hints: "Hints (\(line.count))"
        case .reveals: "Revealed cells (\(line.count))"
        case .flawless: "Flawless"
        }
    }

    private func signed(_ points: Int, isBase: Bool) -> String {
        let number = abs(points).formatted(.number)
        if isBase {
            return number
        }
        return points < 0 ? "\u{2212}\(number)" : "+\(number)"
    }
}
