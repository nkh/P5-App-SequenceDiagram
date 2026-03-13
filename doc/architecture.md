# App::SequenceDiagram — Architecture

## Overview

The tool processes a plain text sequence diagram source file through a classic pipeline: tokenize, parse, lint, render. Each stage is a separate module with a narrow interface. Configuration and defaults are isolated in their own namespace so no module hard-codes colors, characters, or severity levels.

```
source text
    |
    v
Lexer         tokenizes into a flat token stream
    |
    v
Parser        builds a typed AST
    |
    v
Linter        checks the AST for semantic problems (optional)
    |
    v
Renderer      two-pass layout and drawing
    |
    v
Canvas        character grid, ANSI coloring, final output
```

---

## Modules

### script/rsd

Entry point. Parses command-line options, wires together the pipeline, and writes the final output. Owns no logic beyond option handling and error reporting.

Key decisions:
- `--config FILE` loads a merged color, character, linter, and SVG configuration. If absent, the script auto-discovers a config file by checking `./rsd.rc`, `~/.config/rsd/rsd.rc`, and `~/.rsd.rc` in that order before falling back to built-in defaults from `Config::Defaults`.
- `--color` enables ANSI escape codes. Without this flag no color codes are emitted, ensuring clean output in scripts or piped contexts.
- `--unicode` switches the character set to Unicode box-drawing characters. The two modes can be mixed freely via the config file.
- `--svg` routes output through `SVGRenderer` instead of `Renderer` and `Canvas`.
- `--markdown` wraps the ASCII output in a fenced code block, suitable for embedding in GitHub or GitLab documentation.
- `--theme NAME` applies a built-in SVG color theme (`light`, `dark`, `monochrome`, `solarized`) before any user config is loaded, so individual keys in the config file can still override the theme.
- Linter severity is taken from the config so it is also user-overridable.

---

### SequenceDiagram::Lexer

Converts raw source text into a flat array of typed tokens. The lexer is regex-driven and stateless. Each token carries its type, value, and source position (line, column).

Reserved words are recognized as keywords. A reserved word enclosed in double quotes is emitted as a plain `WORD` token, allowing keywords to be used as participant names.

---

### SequenceDiagram::Parser

Consumes the token stream and builds a typed AST. Each statement type produces a node hash with a `type` key and type-specific fields. Source position is preserved on every node for later use by the linter.

Key decisions:
- Recursive descent, one method per construct.
- `AltBlock` is a distinct node type from `Block` because it carries multiple labeled branches, each of which is itself a list of statements.
- `create` nodes have a `deferred` flag so the renderer knows not to draw the header box at the top of the diagram.
- The parser does not resolve aliases; that is left to the renderer and linter so each can reason about names independently.

---

### SequenceDiagram::AST

Provides constructor functions for every AST node type. Keeps node shape definitions in one place so the parser and any future transforms do not need to know the internal structure of nodes.

---

### SequenceDiagram::Linter

Two-pass semantic checker.

Pass 1 (`pre_scan`) collects all activate targets, all message labels, and the presence of `ignore`/`consider` statements. This gives the second pass the full picture before it begins issuing warnings.

Pass 2 (`scan`) walks the AST and checks:
- Participant lifecycle: duplicate declarations, create after declare, destroy without declare, destroy of already destroyed participant.
- Activation balance: activate/deactivate pairing, double activate, deactivate with no matching activate anywhere in the diagram.
- Interaction validity: implicit participants, post-destroy interaction, interaction with conditionally destroyed participant, self-interaction.
- Block structure: empty blocks, missing labels on `loop` and `critical`, nested `critical`, `break` outside `loop`, single-branch `alt`.
- Filter consistency: `ignore` and `consider` cannot coexist; filtered messages must appear somewhere in the diagram.

After the walk, `check_end_state` emits warnings for participants still active at end of diagram and participants declared but never used.

Every check has a named key in the severity table loaded from `Config::Defaults`. The user can promote warnings to errors or demote errors to warnings via the config file.

---

### SequenceDiagram::Renderer

Two-pass layout and drawing engine.

**Pass 1 — measurement**

`collect_participants` registers all participants by walking the full statement tree. `create` nodes mark their participant as `deferred` so no header box is drawn at the top.

`compute_layout` assigns an x coordinate to each participant. It starts from a minimum spacing derived from box widths, then widens each gap to accommodate the longest label of any arrow that crosses that gap. Aliases are resolved before index lookup so aliased participants contribute correctly to spacing.

`count_rows` computes total canvas height by counting the row cost of every statement type.

`measure_statements` records the y position of every `create`, `destroy`, and `activate`/`deactivate` event. This builds the activation span list and the create/destroy position maps used in the drawing pass.

A `depth` counter tracks whether a `Destroy` node is inside a block. A destroy inside a block is recorded as `cond_destroy_y` and does not clip the lifeline.

**Pass 2 — drawing**

Drawing order is intentional: lifelines first (background), activation bars second (overwrite lifelines), header boxes third (overwrite lifeline tops), content last (arrows, labels, annotations overwrite everything).

The constructor arrow for `create` nodes is drawn as a dashed arrow from the nearest left non-deferred participant to the left edge of the new participant's box.

Box centering: `box_half` is `int(width / 2)`, not `int((width + 1) / 2)`. This places the lifeline at the true visual centre of the box for all label lengths.

All draw calls accept an optional color string. When `--color` is active the renderer passes the participant's assigned color for each element; otherwise it passes `undef` and no escape codes are emitted.

All characters (box corners, lifeline, arrows, activation bar, destroy marker) are taken from the character set loaded from `Config::Defaults` or overridden by the user config. This makes ASCII and Unicode output use identical code paths.

---

### SequenceDiagram::Canvas

A fixed-size character grid. Stores characters and colors in parallel arrays of the same dimensions.

Drawing primitives: `draw_vertical_line`, `draw_horizontal_line`, `draw_horizontal_arrow`, `draw_box`, `draw_actor_box`, `write_text`. All accept an optional color argument.

`draw_horizontal_arrow` uses `Array::Iterator::Circular` to alternate characters for dashed style (`-` space in ASCII, `─╌` in Unicode).

`render($colorize)` converts the grid to a string. When colorize is true it groups adjacent cells of the same color and wraps each group in `Term::ANSIColor::colored`. Trailing whitespace and trailing blank lines are stripped.

---

### SequenceDiagram::SVGRenderer

SVG output renderer. Inherits all layout and measurement methods from `Renderer` (participant registration, layout, row counting, activation measurement). Overrides `render()` to produce an SVG string instead of a `Canvas` object, and adds `svg_process_statements()` which walks the AST and emits SVG elements.

Drawing is organized into three layers emitted in document order so that z-order is correct without any post-processing:

- `bg` — block rectangles (`opt`, `loop`, `alt` branches, etc.), rendered with low opacity so lifelines show through
- `mid` — lifelines, activation bars, participant boxes
- `fg` — arrows, labels, annotations, destroy markers

All geometry, typography, and color values are taken from the `[svg]` section of the config file, falling back to `Config::Defaults::svg()`. This covers font families, sizes, row height, column width, arrowhead size, lifeline stroke width and dash pattern, and all 12 element colors. No color or size is hardcoded in the module.

The `geometry()` method returns the merged config hashref directly. All drawing methods unpack the keys they need by name, so adding new config keys requires no changes to method signatures.

Built-in color themes (`light`, `dark`, `monochrome`, `solarized`) are defined in `Config::Defaults::themes()` and applied by `script/rsd` before any user config is loaded, so the user config file always takes precedence over the theme.

Does not depend on `Canvas` or `Term::ANSIColor`.

---

### SequenceDiagram::Config::Defaults

Single source of truth for all built-in defaults. Single source of truth for all built-in defaults. Exports seven functions:

- `colors()` — arrayref of 8 color slot hashrefs (color, lifeline, activebar, annotations, arrow, destroy)
- `blocks()` — hashref of block operator to color
- `ascii()` — hashref of character role to ASCII character
- `unicode()` — hashref of character role to Unicode character
- `severity()` — hashref of linter check name to `'error'` or `'warning'`
- `svg()` — hashref of all SVG defaults: geometry, typography, lifeline appearance, and the 12 element colors
- `themes()` — hashref of built-in theme name to a partial SVG hashref that overrides the color keys; available themes are `light`, `dark`, `monochrome`, `solarized`

No other module hard-codes any of these values.

---

### SequenceDiagram::Config::Parser

Reads the `rsd.rc` config file format and merges user values over the defaults.

Section types:
- `[participant]` — array-valued color slots; multiple sections allowed
- `[participant Name]` — single-participant color override; applied regardless of position
- `[blocks]` — per-operator block colors
- `[chars]` — character overrides for any character role
- `[linter]` — severity overrides per check name
- `[svg]` — SVG geometry, typography, lifeline appearance, and color overrides; all 25 keys from `Config::Defaults::svg()` are accepted, including the 12 CSS color keys

Values may be quoted to include background color specs (`"bright_white on_blue"`). Unquoted values use commas as separators. Missing fields within a slot inherit from `color` in the same slot.

Exposes `color_for($name, $index, $field)` and `block_color($operator)` to the renderer, `severity()` to the linter, and `svg()` to `SVGRenderer`, all via `script/rsd`.

---

## Character Defaults

| Element | ASCII | Unicode |
| :--- | :--- | :--- |
| Participant box | `+---+` / `\| \|` / `+---+` | `╭───╮` / `│ │` / `╰───╯` |
| Actor box | `.---.` / `\| \|` / `'---'` | `╭───╮` / `│ │` / `╰───╯` |
| Lifeline | `\|` | `│` |
| Activation bar | `#` | `▐` |
| Arrow solid line | `-` | `─` |
| Arrow dashed line | `- ` (alternating) | `╌` |
| Arrow right head | `>` | `→` |
| Arrow left head | `<` | `←` |
| Destroy marker | `\X/` / `/X\` | `\X/` / `/X\` |

All characters are overridable individually in the `[chars]` section of the config file, so ASCII and Unicode can be mixed freely.

---

## Design Decisions

**Why a two-pass renderer?**
The first pass measures the diagram before drawing begins. This is necessary to know activation bar extents (which depend on future `deactivate` positions), to know where to clip lifelines for unconditional destroys, and to compute the correct canvas height before allocating the grid.

**Why is `deferred` on the participant and not on the node?**
Multiple parts of the renderer need to know whether a participant was introduced via `create` or via `participant`/`actor`. Storing it on the participant record avoids threading the original node through every call.

**Why is depth tracked in `measure_statements` and `scan`?**
A `destroy` inside a block may or may not execute at runtime. Clipping the lifeline at that point would produce incorrect diagrams. Depth tracking lets the renderer distinguish an unconditional destroy (depth 0) from a conditional one (depth > 0) and only clips in the unconditional case.

**Why merge color and character config into one file?**
Both are presentation concerns. Keeping them in one place means one option, one file to version-control, and one example to distribute.

**Why are colors off by default?**
ANSI escape codes corrupt output in piped contexts, log files, and terminals that do not support them. Opt-in with `--color` is the safe default.

**Why does `--theme` apply before `--config`?**
A theme is a baseline. The user config file is a refinement. Applying the theme first means individual keys in the config file always win, which is the least surprising behaviour.

**Why is config auto-discovery ordered `./rsd.rc` first?**
Project-level config takes precedence over user-level config. A diagram embedded in a repository can ship its own `rsd.rc` that controls its appearance without affecting the user's other diagrams.

**Why does `--markdown` strip ANSI codes regardless of `--color`?**
Markdown fenced code blocks are plain text. ANSI escape codes would appear as literal garbage in rendered output. Color is therefore always disabled in markdown mode.
