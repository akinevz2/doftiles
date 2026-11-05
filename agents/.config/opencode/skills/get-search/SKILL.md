---
name: get-search
description: Search files/folders for content or filenames using the `get` command (backed by ~/.local/bin/got). Use when you need to locate files by name or grep files/directories from the shell quickly.
---

# Get Search

`get` is the repo's universal view/search command. The logic lives in
`~/.local/bin/got` (POSIX sh); the `get` shell function is defined in
`~/.shellx.rc` (sourced by both bash and zsh) and additionally `cd`s into a
leading directory argument or `-` (previous directory) before calling got.

## Modes (first matching rule wins)

| Command | Effect |
|---|---|
| `get` or `get @` | `ls -al` the current directory |
| `get @<file\|dir>` | open it (plus any further args) in `$EDITOR` |
| `get <dir> [names...]` | cd into dir, `ls -al`, then `find` each name beneath it |
| `get <file...>` | cat/bat display — only when EVERY arg is an existing path |
| `get <queries...> <file>` | grep each query in the file, with `file:line:` prefixes |
| `get <queries...> <dir>` | find filenames matching the queries under the dir and pick one via `fzf`, opening it in `$EDITOR` |
| `get <queries...> -- <file\|dir>...` | same search, but the `--` separator makes the queries/targets split explicit (queries left of `--`, targets right of it) |

Without `--`, classification is automatic: an argument that exists as a
file/directory is a target, anything else is a query. Use `--` when a query
word happens to collide with an existing path, or to name targets that do not
exist yet.

## Typical agent usage

```sh
# grep content with line numbers, several files at once
get TODO -- src/*.py

# grep a word in one file
get "def parse" src/parser.py

# find + fzf filenames under a tree, then open the pick in $EDITOR
get autocomplete src/

# locate by basename (dir-first mode, ls + find, no fzf)
get . "got" "*.rc"

# mixed targets: files grep'ed, directories searched recursively
get TODO -- src/ README.md docs/

# display files (no queries → cat/bat)
get README.md docs/analysis.md
```

Notes:

- Grep of directories is recursive (`grep -rnH -e <query> -- <dir>`); files
  use `grep -nH`.
- `fzf` is only used in the folder+queries mode; without fzf installed it
  prints the `find` results instead.
- Non-interactive shells may not have `fzf` output attached to a terminal —
  prefer `--` file targets or the dir-first find mode for scripting.
- When editing repo configs, edit `~/dots/shell/.local/bin/got` (via the
  `shell` stow package), never `~/.local/bin/got` directly.
