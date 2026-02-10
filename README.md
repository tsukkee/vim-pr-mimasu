# vim-pr-mimasu

A Vim plugin for reviewing GitHub Pull Requests with a 3-pane diff layout. The current file is opened as a real file, so LSP features (go-to-definition, completion, diagnostics) remain fully active.

## Requirements

- Vim 8.0+ with `+job` and `+channel`
- [gh CLI](https://cli.github.com/) installed and authenticated
- Git repository with an open pull request

## Installation

With [minpac](https://github.com/k-takata/minpac):

```vim
call minpac#add('tsukkee/vim-pr-mimasu')
```

With [vim-plug](https://github.com/junegunn/vim-plug):

```vim
Plug 'tsukkee/vim-pr-mimasu'
```

## Usage

```vim
:Mimasu          " Open PR review tree (toggle)
:MimasuClose     " Close tree and diff windows
```

### Layout

```
┌──────────┬──────────────┬──────────────┐
│  Tree    │  Base file   │ Current file │
│          │  (read-only) │ (real file)  │
│          │  :diffthis   │ :diffthis    │
└──────────┴──────────────┴──────────────┘
```

### Key Mappings

In the tree buffer:

| Key | Action |
|-----|--------|
| `<CR>` / `o` | Open file diff or toggle directory |
| `q` | Close all |
| `R` | Refresh PR info |

In diff buffers:

| Key | Action |
|-----|--------|
| `<Leader>c` | Add review comment (Normal / Visual) |
| `<Leader>x` | Open PR in browser |

In the comment buffer:

| Key | Action |
|-----|--------|
| `:w` | Submit comment (pending review) |
| `q` | Cancel |

### Review Workflow

1. Run `:Mimasu` on a branch with an open PR
2. Select files from the tree to view diffs
3. Press `<Leader>c` to add review comments (added as pending)
4. Press `<Leader>x` to open the PR in browser and submit the review (Approve / Comment / Request changes)

## Options

```vim
let g:mimasu_sidebar_width = 40              " Tree sidebar width
let g:mimasu_sidebar_position = 'topleft vertical'  " Sidebar position
let g:mimasu_fold_icons = ['▾', '▸']         " Directory fold icons
```

## License

MIT
