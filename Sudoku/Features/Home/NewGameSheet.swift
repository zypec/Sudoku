//
//  NewGameSheet.swift
//  Sudoku
//

import SwiftUI

/// Difficulty picker shown as a Liquid Glass sheet that zooms out of the New Game button.
struct NewGameSheet: View {
    /// Whether starting a game will replace a saved one.
    let replacesGameInProgress: Bool
    /// Generates the puzzle and opens it; the sheet shows progress until it returns.
    let start: (Difficulty) async -> Void
    /// Opens the puzzle a pasted code stands for; `false` when the code makes no puzzle.
    var startWithCode: (String) async -> Bool = { _ in false }

    @Environment(\.dismiss) private var dismiss
    @State private var preparingDifficulty: Difficulty?
    @State private var code = ""
    @State private var isOpeningCode = false
    @State private var isCodeInvalid = false
    /// Measured height of the cards, so the sheet opens exactly tall enough for them.
    @State private var contentHeight: CGFloat = 420

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 10) {
                    GlassEffectContainer(spacing: 10) {
                        VStack(spacing: 10) {
                            ForEach(Difficulty.allCases) { difficulty in
                                DifficultyCard(
                                    difficulty: difficulty,
                                    isPreparing: preparingDifficulty == difficulty
                                ) {
                                    Task { await select(difficulty) }
                                }
                                .disabled(!difficulty.isAvailable || preparingDifficulty != nil)
                            }
                        }
                    }

                    codeField
                        .padding(.top, 8)

                    if replacesGameInProgress {
                        Label("Starting a new game counts the game in progress as lost.", systemImage: "info.circle")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 6)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom)
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.size.height
                } action: { height in
                    contentHeight = height
                }
            }
            .navigationTitle("New Game")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Button(role: .close) {
                    dismiss()
                }
            }
        }
        // Cards plus room for the navigation bar; grows with Dynamic Type and can still expand.
        .presentationDetents([.height(contentHeight + 76), .large])
        .interactiveDismissDisabled(preparingDifficulty != nil || isOpeningCode)
    }

    /// A puzzle code copied from a game, pasted in to play that puzzle again.
    private var codeField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Start with Code")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.leading, 4)
            // Above the field, so the keyboard never covers what it says.
            Group {
                if isCodeInvalid {
                    Text("This code doesn't make a puzzle with a single solution.")
                        .foregroundStyle(.red)
                } else {
                    Text("Paste a puzzle code copied from a game.")
                        .foregroundStyle(.secondary)
                }
            }
            .font(.footnote)
            .padding(.leading, 4)
            HStack(spacing: 8) {
                TextField(text: $code) {
                    Text(verbatim: "H7K-2M4-Q9X")
                }
                .font(.body.monospaced())
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.go)
                .onSubmit { Task { await openCode() } }
                .onChange(of: code) { isCodeInvalid = false }

                if isOpeningCode {
                    ProgressView()
                        .padding(.horizontal, 12)
                } else {
                    Button("Start") {
                        Task { await openCode() }
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .disabled(code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(.leading, 18)
            .padding(.trailing, 8)
            .frame(minHeight: 56)
            .background(.fill.tertiary, in: .rect(cornerRadius: 22))
        }
        .disabled(preparingDifficulty != nil)
    }

    private func openCode() async {
        guard !isOpeningCode, !code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        isOpeningCode = true
        isCodeInvalid = !(await startWithCode(code))
        isOpeningCode = false
    }

    private func select(_ difficulty: Difficulty) async {
        preparingDifficulty = difficulty
        await start(difficulty)
        preparingDifficulty = nil
    }
}

/// One difficulty: a level meter, name, and what kind of techniques to expect.
private struct DifficultyCard: View {
    let difficulty: Difficulty
    let isPreparing: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                DifficultyMeter(difficulty: difficulty)

                VStack(alignment: .leading, spacing: 2) {
                    Text(difficulty.title)
                        .font(.headline)
                    Text(difficulty.summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                trailing
            }
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity, minHeight: 68)
            .contentShape(.rect)
            .opacity(difficulty.isAvailable ? 1 : 0.45)
        }
        .buttonStyle(.plain)
        .glassEffect(
            .regular.tint(difficulty.isAvailable ? difficulty.color.opacity(0.18) : nil).interactive(),
            in: .rect(cornerRadius: 22)
        )
        .accessibilityValue(difficulty.isAvailable ? Text(verbatim: "") : Text("Coming soon"))
    }

    @ViewBuilder
    private var trailing: some View {
        if isPreparing {
            ProgressView()
                .accessibilityLabel(Text("Preparing puzzle…"))
        } else if difficulty.isAvailable {
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        } else {
            Text("Soon")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(.fill.tertiary, in: .capsule)
        }
    }
}

/// Five rising bars, filled up to the difficulty's level.
struct DifficultyMeter: View {
    let difficulty: Difficulty

    var body: some View {
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(1..<6) { level in
                Capsule()
                    .fill(level <= difficulty.level ? AnyShapeStyle(difficulty.color) : AnyShapeStyle(.fill.secondary))
                    .frame(width: 5, height: CGFloat(8 + level * 4))
            }
        }
        .frame(height: 28, alignment: .bottom)
        .accessibilityHidden(true)
    }
}

#Preview {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            NewGameSheet(replacesGameInProgress: true) { _ in }
        }
}
