# Extended Common Sequence Diagram Specification (ECSDS)

A plain text language for describing sequence diagrams. No surrounding delimiters are required. Statements appear one per logical unit, top to bottom. Order is significant — it defines the chronological sequence of events in the rendered diagram. Blank lines and `#` comments are ignored.

## Usage

```
sequence_diagram.pl [--debug tokenizer,parser,parser_details,ast,canvas] [--ast] [--no-canvas] [--lint] <input_file>
```

| Option                   | Description                                                      |
| :---                     | :---                                                             |
| `--debug tokenizer`      | Print each token as it is produced                               |
| `--debug parser`         | Print each AST node as it is built, with position and key fields |
| `--debug parser_details` | Add per-field detail lines under each parser node                |
| `--debug ast`            | Dump the full AST after parsing                                  |
| `--debug canvas`         | Print each canvas operation with coordinates                     |
| `--no-canvas`            | Skip rendering, useful with `--debug ast`                        |
| `--lint`                 | Report warnings after parsing without affecting rendering        |

Multiple debug parameters may be combined: `--debug tokenizer,parser`.

## Lexical Rules

| Concept       | Definition                                                         |
| :---          | :---                                                               |
| NAME          | A letter or underscore followed by letters, digits, or underscores |
| QUOTED_STRING | Any text enclosed in double quotes                                 |
| WORD          | A NAME, a QUOTED_STRING, or a quoted reserved word                 |
| RESERVED      | Any keyword listed in this document                                |
| ARROW         | `->`, `-->`, or `->>`                                              |
| Comment       | `#` to end of line, ignored everywhere                             |

A reserved word enclosed in double quotes is treated as a plain WORD, not a keyword. Identifiers containing spaces must be quoted.

## Participants

Participants are the entities whose interactions the diagram describes. They appear as vertical lifelines. The left-to-right order follows the order of first declaration or first reference.

### participant / actor

Declares a participant. `participant` renders as a box, `actor` as a stick figure.

```
participant WORD [as WORD] [active] [data { text }]
actor       WORD [as WORD] [active] [data { text }]
```

| Clause          | Description                                                                    |
| :---            | :---                                                                           |
| `as WORD`       | Alias — a shorter name usable in place of the full name throughout the diagram |
| `active`        | Participant starts in an activated state from the beginning of the diagram     |
| `data { text }` | Free-form text block saved as-is in the AST; braces are balanced               |

The clauses `as`, `active`, and `data` may appear in any order.

### create

Introduces a new participant at a specific point in the sequence. The lifeline begins at this point rather than at the top of the diagram. Accepts the same clauses as `participant`.

```
create WORD [: WORD] [as WORD] [active] [data { text }]
```

The optional `: WORD` specifies a type or class name for the participant.

### destroy

Ends a participant's lifeline. The participant may not be referenced after this point — doing so is a parse error. The renderer marks the end of the lifeline with an X.

```
destroy WORD
```

## Lifeline Modifiers

### activate / deactivate

`activate` begins an activity period on a lifeline, rendered as a filled bar. `deactivate` ends the most recent one. Nesting is supported. Deactivating a participant that is not currently active is an error.

```
activate   WORD
deactivate WORD
```

## Interactions

An arrow between two participants carrying a label. Source and target may be the same participant.

```
WORD ARROW WORD : WORD
```

| Arrow | Style          | Meaning                      |
| :---  | :---           | :---                         |
| `->`  | Solid line     | Synchronous request          |
| `-->` | Dashed line    | Response or return value     |
| `->>` | Thin arrowhead | Asynchronous fire-and-forget |

## Annotations

### state

Annotates one or more lifelines with a state expression at a specific point. Purely informational.

```
state WORD [WORD ...] : WORD
```

### note

Attaches a free-text annotation to one or more lifelines. Rendered as a box or callout.

```
note WORD [WORD ...] : WORD
```

### ref

References an external diagram or named sub-sequence. Rendered as a box spanning the listed lifelines.

```
ref WORD [WORD ...] : WORD
```

Participant lists in `state`, `note`, and `ref` may be comma-separated or space-separated or a mix of both.

## Message Filters

Standalone statements that declare which messages are relevant in a given context. The message list may use commas or spaces or both as separators.

### ignore

Declares messages that may occur but are not shown.

```
ignore { WORD [, WORD ...] }
ignore : WORD [, WORD ...]
```

### consider

Declares the only messages that are relevant; all others are implicitly ignored.

```
consider { WORD [, WORD ...] }
consider : WORD [, WORD ...]
```

## Blocks

A block groups statements under a controlling operator, drawn as a labelled rectangle. The label is optional but recommended.

```
OPERATOR [WORD] { statement* }
```

| Operator   | Meaning                                               |
| :---       | :---                                                  |
| `alt`      | Alternatives — only one branch executes               |
| `opt`      | Optional — executes if condition holds                |
| `loop`     | Repeating sequence                                    |
| `par`      | Parallel execution                                    |
| `critical` | Atomic region — no interruption                       |
| `break`    | If this executes, the enclosing sequence is abandoned |
| `assert`   | This sequence always occurs exactly as shown          |
| `neg`      | This sequence is invalid or impossible                |
| `seq`      | Weak sequencing — default message ordering            |
| `strict`   | Strict sequencing — messages occur in exact order     |

### alt branches

`alt` supports one or more `else` branches. The final `else` may have no label, acting as a default catch-all.

```
alt [WORD] {
    statement*
}
else [WORD] {
    statement*
}
else {
    statement*
}
```

## Lint Warnings

Produced when `--lint` is passed. Rendering proceeds regardless.

| Warning                        | Condition                                                                                                |
| :---                           | :---                                                                                                     |
| Participant still active       | A participant is still activated at the end of the diagram                                               |
| Participant never used         | A participant is declared or created but never appears in an interaction                                 |
| Implicit declaration           | A participant is first introduced through an interaction rather than `participant`, `actor`, or `create` |
| Destroyed implicit participant | A participant that was only implicitly declared is destroyed                                             |
| Unresolved reference           | A `ref` label does not match any named sequence in the diagram                                           |
| Block without label            | A block operator has no label                                                                            |

## Example

```
participant "Large Filtering Unit" as LFU active
participant Client
create Session : DBSession

Client -> LFU : "filter request"
activate LFU

LFU -> Session : "query"
Session --> LFU : "results"

alt "results found" {
    LFU --> Client : "filtered data"
}
else {
    LFU --> Client : "empty response"
}

deactivate LFU
destroy Session
```

## Command-Line Options

```
rsd [options] <input_file>
```

| Option | Description |
| :--- | :--- |
| `--help` | show this help |
| `--lint` | report warnings after parsing |
| `--no-canvas` | skip rendering |
| `--color` | enable ANSI color output |
| `--config FILE` | load color and character configuration from FILE |
| `--unicode` | use Unicode box-drawing and arrow characters |
| `--debug tokenizer` | print each token as it is produced |
| `--debug parser` | print each AST node as it is built |
| `--debug parser_details` | add per-field lines under each parser node |
| `--debug ast` | dump the full AST after parsing |
| `--debug canvas` | print each canvas drawing operation |

## Color and Character Configuration

Pass a config file with `--config FILE`. If no file is given, built-in defaults are used. Copy `rsd.rc` as a starting point — it contains every possible key with its default value commented out.

Colors require `--color` to be active. Without that flag no ANSI escape codes are emitted regardless of the config.

`--unicode` switches the character set to Unicode box-drawing characters. Individual characters can be overridden in the `[chars]` section of the config, making it possible to mix ASCII and Unicode freely.

### Config file format

```ini
[participant]
color       = bright_blue, bright_green
lifeline    = blue,        green
activebar   = bright_cyan, bright_green
annotations = blue,        green
arrow       = bright_blue, bright_green
destroy     = bright_red,  bright_red

[participant Client]
color       = bright_yellow
lifeline    = yellow
activebar   = bright_yellow
arrow       = bright_yellow
destroy     = bright_red

[blocks]
loop     = cyan
alt      = magenta
critical = bright_red
default  = white

[chars]
lifeline   = |
activation = #

[linter]
unused_participant = error
```

Each `[participant]` section defines the color cycle. Participants are assigned slots in declaration order, cycling if there are more participants than slots. A `[participant Name]` section overrides the cycle for that specific participant regardless of its position.

Color values are `Term::ANSIColor` names. Quoted values may include a background: `"bright_white on_blue"`.

Missing fields within a slot inherit from `color` in that same slot.

### Character defaults

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
