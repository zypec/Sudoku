<!--
  Everything Sudoku's front page says. Change it here and the page follows; nothing else needs touching.
  The page is laid out as an app's store page: the app, its screens, what it is, what is new, and the facts.

  ## A heading             starts a section; ## Preview {#gallery} gives it the id the links use
  A paragraph             with **bold**, *italic*, `code` and [a link](https://…)

  A block starts with "::: kind" and ends with ":::". Its fields come first, one a line, up to the first
  empty line; after that is what it says. A field can be given more than once, and a | splits it in parts.
  The kinds this page knows:

  app       name, subtitle, developer: name | address, button: Words | address (the one button),
            soon (said beside it, dotted: what is not out yet), fact: label | value | under it (any number,
            the strip under the app)
  shots     demo: headline | technique | what it means (the first card: the live hint on the board),
            step (any number: what the demo's hint says, one step after another),
            shot: file | headline (any number); cards side by side share one background
  about     what the app is; it opens in full with More
  new       version, date; then what changed
  info      row: label | value (any number)
  credits   the small print at the end
-->

::: app
name: Sudoku
subtitle: Hints that teach you to solve
developer: zypec | https://github.com/zypec
button: Source code | https://github.com/zypec/Sudoku
soon: Coming to the App Store
fact: Techniques | 32 | In five levels
fact: Puzzles | 1,500 | Graded by logic
fact: Training | 31 | Techniques to practice
fact: Languages | EN | And Turkish
fact: Developer | zypec | With Claude
:::

## Preview {#gallery}

::: shots
demo: Hints that teach | X-Wing | Rectangle on two lines
step: In rows 1 and 5, **7** fits only in columns 5 and 7.
step: Suppose **7** is in row 1, column 5. Then row 5 has its **7** in column 7.
step: Suppose instead it is in row 1, column 7. Then row 5 has it in column 5.
step: Either way both columns get their **7** in these rows, so **7** goes from the rest of them.
shot: gallery/hint.jpg | See the proof, case by case
shot: gallery/steps.jpg | Every step explained
shot: gallery/autosolve.jpg | Watch it solve, one step at a time
shot: gallery/library.jpg | 32 techniques to learn
shot: gallery/training.jpg | Practice on real positions
shot: gallery/stats.jpg | Follow your progress
shot: gallery/home.jpg | Pick up where you left off
shot: gallery/dark.jpg | Light and dark
:::

## About

::: about
Sudoku for iPhone and iPad, made for getting better at it.

Stuck? Ask for a hint and you get the next logical step, not the answer: the technique it takes, where to
look, how to spot it, and why it works. Hard techniques are played on the board, one case after the other.
If one of your notes is wrong, the hint says so first.

Training covers the techniques one by one, from Hidden Single to X-Wings, Unique Rectangles and chains. Each
has an animated example and practice positions where the next step is exactly that technique.

Puzzles are graded by the hardest technique they need, not by how many digits they give, so a hard puzzle is
hard for the right reason. Your statistics, streaks and scores are kept per difficulty.

Other things you may like: notes with automatic cleanup, undo and redo, a mistake limit and a hint limit
of your choice, auto solve to watch a puzzle solved step by step, puzzle codes to share a puzzle, and light
and dark mode.
:::

## What's New

::: new
version: In development
date: November 2026

- Puzzle codes: copy one from a game, start it again from New Game.
- After a loss, take back the last mistake and play on, or play the same puzzle again.
- A hint limit, and hints that pick out the cells and digits they talk about.
- Practice positions for 31 techniques.
:::

## Information

::: info
row: Developer | [zypec](https://github.com/zypec)
row: Category | Games, Puzzle
row: Compatibility | iPhone and iPad
row: Languages | English and Turkish
row: Built with | Swift and SwiftUI, with [Claude](https://claude.com) in Claude Code
row: Source code | [github.com/zypec/Sudoku](https://github.com/zypec/Sudoku)
:::

::: credits
The techniques and how they are explained draw on [SudokuWiki.org](https://www.sudokuwiki.org) by Andrew
Stuart, and several of its example puzzles test the solver, along with the example puzzle of Wikipedia's
[Sudoku](https://en.wikipedia.org/wiki/Sudoku) article and Arto Inkala's hard puzzle. The board in the first
card is cut from the solution of Wikipedia's puzzle.
:::
