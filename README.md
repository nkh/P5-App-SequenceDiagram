# App::SequenceDiagram

A command-line tool and reusable module set that parses plain text sequence diagram descriptions and renders them as ASCII art, Unicode art, or SVG.

The input language is the Extended Common Sequence Diagram Specification (ECSDS), a human-friendly text format covering the full UML sequence diagram feature set including all combined fragment operators (`alt`, `opt`, `loop`, `par`, `critical`, `break`, `assert`, `neg`, `seq`, `strict`).

```text
    .------.                 .---------.                .------.                  .-----.
    | User |                 | Browser |                | Auth |                  | API |
    '------'                 '---------'                '------'                  '-----'
        |                         |                         |                        |
        |      click login        |                         |                        |
        |------------------------>|                         |                        |
        |                         |     GET /authorize      |                        |
        |                         |------------------------>|                        |
        |                         |       login form        |                        |
        |                         |<- - - - - - - - - - - - |                        |
        |   submit credentials    |                         |                        |
        |------------------------>|                         |                        |
        |                         |      POST /login        |                        |
        |                         |------------------------>|                        |
        |                         |    redirect + code      |                        |
        |                         |<- - - - - - - - - - - - #                        |
        |                         |   POST /token (code)    #                        |
        |                         |------------------------>|                        |
        |                         |      access_token       |                        |
        |                         |<- - - - - - - - - - - - #                        |
        |                         |            GET /data (Bearer token)              |
        |                         |------------------------------------------------->|
        |                         |                         |   introspect token     |
        |                         |                         |<-----------------------#
        |                         |                         |   valid, user=alice    #
        |                         |                         |- - - - - - - - - - - ->#
        |                         |                  200 JSON data                   #
        |                         |<- - - - - - - - - - - - - - - - - - - - - - - - -#
        |                         |                         |                        #
        |                         |                         |                        |
        |                         |                         |                        |
```

## Usage

```
rsd [options] <input_file>
```

| Option                   | Description                                                                   |
| :---                     | :---                                                                          |
| `--help`                 | show this help                                                                |
| `--lint`                 | report warnings after parsing                                                 |
| `--no-canvas`            | skip rendering                                                                |
| `--color`                | enable ANSI color output, colors ASCII, Unicode, and SVG                      |
| `--config FILE`          | load color, character, and SVG configuration from FILE                        |
| `--unicode`              | use Unicode box-drawing and arrow characters                                  |
| `--svg`                  | emit SVG to stdout instead of ASCII                                           |
| `--markdown`             | wrap ASCII output in a fenced code block                                      |
| `--theme NAME`           | apply a built-in SVG color theme (`light`, `dark`, `monochrome`, `solarized`) |
| `--debug tokenizer`      | print each token as it is produced                                            |
| `--debug parser`         | print each AST node as it is built                                            |
| `--debug parser_details` | add per-field lines under each parser node                                    |
| `--debug ast`            | dump the full AST after parsing                                               |
| `--debug canvas`         | print each canvas drawing operation                                           |

Multiple debug flags may be combined:

```
rsd --debug tokenizer,parser,ast --lint diagram.ecsds
```

## Installation

```
perl Build.PL
./Build
./Build test
./Build install
```

## Configuration

The tool auto-discovers a config file by checking the following locations in order, stopping at the first one found:

1. `./rsd.rc` — project-level config alongside the diagram file
2. `~/.config/rsd/rsd.rc` — user config in XDG location
3. `~/.rsd.rc` — user config in home directory

Pass `--config FILE` to override auto-discovery and load a specific file.

The config file controls:

- per-participant color cycle (box, lifeline, activation bar, arrows, annotations, destroy marker)
- named participant color overrides
- per-operator block header colors
- every drawn character (ASCII and Unicode, individually overridable)
- linter check severity (`error` or `warning` per check)
- SVG geometry and typography (font family, font size, row height, column width, arrowhead size, lifeline width and dash)
- SVG element colors (participant boxes, lifelines, arrows, labels, blocks, annotations, destroy markers)

See `rsd.rc` for a fully commented example with all default values shown.

### Unicode output with colors

![Unicode]( https://github.com/nkh/P5-App-SequenceDiagram/blob/main/screenshots/gallery02_unicode.png)

### SVG output

![SVG](https://github.com/nkh/P5-App-SequenceDiagram/blob/main/screenshots/gallery02.svg)

```
rsd --svg diagram.ecsds > diagram.svg
rsd --svg --theme dark diagram.ecsds > diagram.svg
rsd --svg --config my.rc diagram.ecsds > diagram.svg
```

`--theme NAME` applies a built-in color palette before any user config is loaded, so individual keys in the config file still take precedence. Available themes: `light`, `dark`, `monochrome`, `solarized`.

SVG colors and geometry are configured in the `[svg]` section of the config file:

```ini
[svg]
font_size        = 30
lifeline_color   = #4a5568
lifeline_width   = 2
lifeline_dash    = 8,5
participant_fill = #f7fafc
arrow            = #2d3748
block_fill       = #edf2f7
```

### Markdown export

```
rsd --markdown diagram.ecsds > diagram.md
rsd --markdown diagram.ecsds >> README.md
```

Wraps the ASCII diagram in a fenced code block. ANSI color codes are never emitted in this mode.

## Character Defaults

| Element | ASCII | Unicode (`--unicode`) |
| :---              | :---                        | :---                      |
| Participant box   | `+---+` / `\| \|` / `+---+` | `╭───╮` / `│ │` / `╰───╯` |
| Actor box         | `.---.` / `\| \|` / `'---'` | `╭───╮` / `│ │` / `╰───╯` |
| Lifeline          | `\|`                        | `│`                       |
| Activation bar    | `#`                         | `▐`                       |
| Arrow solid line  | `-`                         | `─`                       |
| Arrow dashed line | `- ` (alternating)          | `╌`                       |
| Arrow right head  | `>`                         | `→`                       |
| Arrow left head   | `<`                         | `←`                       |

All characters are overridable in the `[chars]` section of the config file.

## Dependencies

- `Data::TreeDumper`
- `Getopt::Long` (core)
- `List::Util` (core)
- `Array::Iterator::Circular`
- `Term::ANSIColor` (core, used only when `--color` is active)

## Documentation

- `ecsds.md` — full language reference including all options
- `ecsds.ebnf` — formal EBNF grammar
- `ecsds_tests.ecsds` — annotated language feature examples
- `doc/architecture.md` — module architecture and design decisions
- `examples/` — domain-specific gallery examples

## Examples

| File                 | Scenario                                        |
| :---                 | :---                                            |
| `examples/gallery01` | HTTP request/response with DNS and CDN          |
| `examples/gallery02` | OAuth2 authorization code flow                  |
| `examples/gallery03` | E-commerce checkout with payment and inventory  |
| `examples/gallery04` | Microservice saga pattern with compensation     |
| `examples/gallery05` | Hospital patient admission                      |
| `examples/gallery06` | CI/CD pipeline with rolling deploy              |
| `examples/gallery07` | WebSocket chat session with presence service    |
| `examples/gallery08` | Database connection pool with overflow handling |

## Architecture

```
Lexer.pm                tokenizes source text
Parser.pm               builds a typed AST
AST.pm                  node constructors
Linter.pm               post-parse semantic checks
Renderer.pm             two-pass layout and drawing engine (ASCII/Unicode)
SVGRenderer.pm          SVG output renderer, inherits layout from Renderer
Canvas.pm               character grid with ANSI color support
Config/Defaults.pm      all built-in default values including SVG themes
Config/Parser.pm        rsd.rc config file reader
```

See `doc/architecture.md` for a detailed description of each module and the design decisions behind them.

## License

This software is copyright (c) 2026 by Nadim Khemir.

This is free software; you can redistribute it and/or modify it under the same terms as the Perl 5 programming language system itself.

## Author


    Khemir Nadim ibn Hamouda
    https://github.com/nkh
    CPAN ID: NKH
