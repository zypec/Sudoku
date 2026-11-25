# Sudoku

A smart Sudoku app for iPhone and iPad, developed with [Claude](https://claude.com) (Anthropic) using Claude Code.

What sets it apart is a solver that thinks like a person. Hints don't just say "put a 7 here": they show the next logical step an experienced player would take, name the technique, and walk through it on the board, including a visual explanation that tries each case of the technique one assumption at a time.

## Features

- **Human-like solver** with 32 techniques in five levels, from Full House and Hidden Single to X-Wing, Swordfish, Unique Rectangles, XY-Chains, AICs and ALS-XZ. It never guesses.
- **Difficulty by technique**, not by the number of givens: a puzzle's level is the hardest technique it needs. 1,500 puzzles are generated and graded ahead of time and shipped with the app, each shown in a fresh symmetry (relabeled digits, shuffled rows, columns and bands) so repeats look new.
- **Step-by-step hints**: where to look, how to spot the pattern, the reasoning, and the result. Hints check your notes first and, if you don't take notes, follow the logic on to a digit you can place.
- **Visual explanations** that play a technique's proof on the board, with links drawn between candidates.
- **Training**: a library of every technique with an animated example on a real position, and practice positions where the next step is exactly that technique.
- **Statistics and scores**: per difficulty, with an estimated solve time for every puzzle and points that reward speed and penalize mistakes and hints.
- Auto solve, pause, notes, undo and redo, configurable assists and mistake limit, light and dark mode, English and Turkish.

## Building

Requires Xcode with the iOS 27 SDK. Open `Sudoku.xcodeproj` and run the `Sudoku` scheme. Unit tests use Swift Testing:

```sh
xcodebuild test -project Sudoku.xcodeproj -scheme Sudoku -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:SudokuTests
```

The puzzle bank and the training positions are generated with the app's own engine, compiled for the Mac:

```sh
Tools/generate-puzzle-bank.sh        # Sudoku/Resources/PuzzleBank.json
Tools/generate-training-positions.sh # Sudoku/Resources/TrainingPositions.json
```

## Project structure

- `Sudoku/Engine`: pure Swift, no UI. Board representation, a brute-force solution counter, every technique, the logical solver, the generator, the solve time estimate and training positions.
- `Sudoku/Features`: the SwiftUI screens (home, game, hints, auto solve, training, statistics, settings).
- `Tools`: command-line generators for the bundled data.

## Acknowledgments

- [SudokuWiki.org](https://www.sudokuwiki.org) by Andrew Stuart, whose strategy pages helped shape the techniques and their explanations. Several of its example puzzles are used in the unit tests.
- The example puzzle from Wikipedia's [Sudoku](https://en.wikipedia.org/wiki/Sudoku) article and Arto Inkala's well-known hard puzzle are used as test puzzles.
- Built with SwiftUI, SwiftData and Swift Testing.

---

**Türkçe:** Claude ile geliştirilen, insan gibi düşünen bir çözücüye sahip akıllı bir Sudoku uygulaması. İpuçları bir sonraki mantıklı adımı yöntemiyle birlikte adım adım ve görsel olarak anlatır; eğitim modu her yöntemi gerçek pozisyonlarla öğretir. Uygulama Türkçe ve İngilizce destekler.
