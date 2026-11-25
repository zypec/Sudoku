#!/bin/zsh
# Extracts practice positions for every technique from Sudoku/Resources/PuzzleBank.json into
# Sudoku/Resources/TrainingPositions.json. Run after regenerating the bank.
#
# Usage: Tools/generate-training-positions.sh [positions per technique, default 25]
set -euo pipefail

root=${0:A:h:h}
limit=${1:-25}
build=$(mktemp -d)
trap 'rm -rf "$build"' EXIT

swiftc -O -swift-version 6 -o "$build/PuzzleBankGenerator" \
    $(find "$root/Sudoku/Engine" -name '*.swift') \
    "$root/Tools/PuzzleBankGenerator/main.swift" 2>&1 | grep -v "^$" || true

"$build/PuzzleBankGenerator" positions "$root/Sudoku/Resources/PuzzleBank.json" "$root/Sudoku/Resources/TrainingPositions.json" "$limit"
