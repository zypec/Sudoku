<!--
  Everything Sudoku's front page says. Change it here and the page follows; nothing else needs touching.

  ## A heading             starts a section; ## Gallery {#gallery} gives it the id the links use
  A paragraph             with **bold**, *italic*, `code` and [a link](https://…)

  A block starts with "::: kind" and ends with ":::". Its fields come first, one a line, up to the first
  empty line; after that is what it says. A field can be given more than once, and a | splits it in parts.
  The kinds this page knows:

  hero      kicker, button: Words | address | primary (any number), note, technique: name | what it means,
            step (any number: what the hint beside the board says, one step after another); then the opening
            words. The name and the board are drawn by the page
  card      name, link, go (the words at its foot), until (said instead of go while link is empty),
            featured: yes (drawn as the one to pick); then what it says. Cards side by side form a row
  gallery   picture: file | caption (any number; a picture opens large when clicked)
  credits   the small print under the gallery
-->

::: hero
kicker: A Sudoku for iPhone and iPad
button: See the gallery | #gallery | primary
button: Read the source | https://github.com/zypec/Sudoku
note: On iOS 27, in English and Turkish. In development.
technique: X-Wing | Rectangle on two lines
step: In rows 1 and 5, **7** fits only in columns 5 and 7.
step: Suppose **7** is in row 1, column 5. Then row 5 has its **7** in column 7.
step: Suppose instead it is in row 1, column 7. Then row 5 has it in column 5.
step: Either way both columns get their **7** in these rows, so **7** goes from the rest of them.

A Sudoku that explains itself. Its hints don't say "put a 7 here": they name the technique a good player
would use next, show where to look and how to spot it, and play the reasoning on the board.
:::

::: card
name: Source code
link: https://github.com/zypec/Sudoku
go: Open on GitHub
featured: yes

The Swift engine with all 32 techniques and the tests that check them, the generator that grades every
puzzle, and the app.
:::

::: card
name: Get Sudoku
link:
go: Get it on the App Store
until: Coming soon

The engine, the hints and training are in; the daily puzzle and its streak come next.
:::

::: card
name: Built with Claude
link: https://claude.com/claude-code
go: About Claude Code

Developed with Claude, Anthropic's model, in Claude Code: the engine, the explanations, the app and this
page.
:::

## Gallery {#gallery}

Screens of the app, recorded on the iPhone simulator.

::: gallery
picture: gallery/hint.jpg | A hint played on the board: an X-Wing, one case after the other
picture: gallery/steps.jpg | A hint step by step: an alternating chain, link by link
picture: gallery/autosolve.jpg | Auto solve, a step at a time, with the cell it solves next marked
picture: gallery/home.jpg | The home screen: the daily puzzle, training and statistics
picture: gallery/library.jpg | Training: 32 techniques in five levels, from Full House to ALS-XZ
picture: gallery/training.jpg | Each technique with an animated example on a real position, then practice
picture: gallery/stats.jpg | Statistics per difficulty, and a score that rewards speed
picture: gallery/dark.jpg | Dark mode, and a hint's first step: where to look
:::

::: credits
The techniques and how they are explained draw on [SudokuWiki.org](https://www.sudokuwiki.org) by Andrew
Stuart, and several of its example puzzles test the solver, along with the example puzzle of Wikipedia's
[Sudoku](https://en.wikipedia.org/wiki/Sudoku) article and Arto Inkala's hard puzzle. The board at the top is
cut from the solution of Wikipedia's puzzle.
:::
