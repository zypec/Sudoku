<!--
  Everything Sudoku's page says. Change it here, save, and reload the page.

  ## A heading             starts a section
  A paragraph             with **bold**, *italic* and [a link](https://…)
  - an item               a list

  A block starts with "::: kind" and ends with ":::". Its fields come first, one a line, up to the first
  empty line; after that is what it says. A field can be given more than once, and a | splits it in parts.
  The kinds this page knows:

  hero        kicker, title, badge, link: Words | address (any number); then the opening words
  board       the board beside the hero, drawn by the page: caption
  feature     a card in the grid of what it does: label, name; then what it says
  shots       the screens of the app: image, caption
-->

::: hero
kicker: An iPhone and iPad app, in development
title: Sudoku
badge: Built with Claude
link: Source code | https://github.com/zypec/Sudoku

A Sudoku that explains itself. Its solver thinks like a person: a hint names the technique an experienced
player would use next, shows where to look and how to spot it, and plays the reasoning on the board, case by
case, until the answer is plain.
:::

::: board
caption: An X-Wing on 7. Rows 1 and 5 hold it only in columns 5 and 7, so whichever diagonal is right, both columns get their 7 here and lose it everywhere else.
:::

## What it does

::: feature
label: Hints
name: The next step, not the answer

Not "put a 7 here", but the step a good player would take next: where to look, how to spot it, why it
works, and then the result to apply. Hints check your notes first and point out the ones that can't be right.
:::

::: feature
label: Visual
name: Proofs played on the board

Each technique is tried case by case. An assumed digit appears in green, what it rules out is struck in red,
and the links between candidates are drawn, so the reasoning is seen rather than read.
:::

::: feature
label: Training
name: Every technique, practiced

A library of 32 techniques, from Hidden Single to AICs and ALS-XZ, each with an animated example on a real
position and practice where the next step is exactly that technique.
:::

::: feature
label: Puzzles
name: Graded by logic

Difficulty comes from the hardest technique a puzzle needs, not from how many digits it gives. 1,500
puzzles are generated and graded ahead of time and come in a fresh symmetry every time.
:::

::: feature
label: Progress
name: Statistics and scores

Wins, streaks, best and average times per difficulty, how you do with each technique, and points that reward
speed against each puzzle's estimated time.
:::

::: feature
label: Details
name: Made for iPhone

Liquid Glass controls, a board that stays flat and legible, auto solve, pause, light and dark, English and
Turkish.
:::

::: shots
image: gallery/screens.jpg
caption: The home screen, a hint's visual explanation of an X-Wing, and the X-Wing's page in training.
:::

## How it was made

Sudoku is developed with [Claude](https://claude.com), Anthropic's model, working in Claude Code: the engine
and every technique in it, the step-by-step and visual explanations, the app, and this page. The whole history
is on [GitHub](https://github.com/zypec/Sudoku).

## Credits

- [SudokuWiki.org](https://www.sudokuwiki.org) by Andrew Stuart, whose strategy pages helped shape the
  techniques and how they are explained. Several of its example puzzles are used to test the solver.
- The example puzzle from Wikipedia's [Sudoku](https://en.wikipedia.org/wiki/Sudoku) article and Arto
  Inkala's well-known hard puzzle are used as test puzzles; the board above is drawn from Wikipedia's.
