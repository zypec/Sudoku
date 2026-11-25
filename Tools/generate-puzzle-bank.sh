#!/bin/zsh
# Regenerates Sudoku/Resources/PuzzleBank.json with the app's engine, compiled and optimized for the
# Mac. The result is deterministic: the same engine and count always give the same file.
#
# Usage: Tools/generate-puzzle-bank.sh [puzzles per difficulty, default 300]
set -euo pipefail

root=${0:A:h:h}
count=${1:-300}
build=$(mktemp -d)
trap 'rm -rf "$build"' EXIT

swiftc -O -swift-version 6 -o "$build/PuzzleBankGenerator" \
    $(find "$root/Sudoku/Engine" -name '*.swift') \
    "$root/Tools/PuzzleBankGenerator/main.swift" 2>&1 | grep -v "^$" || true

"$build/PuzzleBankGenerator" "$root/Sudoku/Resources/PuzzleBank.json" "$count"
