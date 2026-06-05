# sapling

A Neovim file explorer with a left sidebar tree, async git status markers, and optional `nvim-web-devicons` support.

## Features

- Left sidebar tree rooted at the current working directory
- Current file auto-reveal when it is inside the active root
- Background highlight for the selected row and the current edited file
- Vim-style movement with `j`/`k`, plus `gg` and `G`
- Mouse support for click-to-select and double-click to open or toggle directories
- Built-in help menu for active explorer keymaps
- Async git status markers for modified, untracked, and ignored files
- Right-aligned git markers with status-colored entry names
- Background polling while the sidebar is open so external git changes get picked up
- Gitignored files shown by default, with a runtime toggle that also controls configured hidden names
- Custom `nui.nvim` floating prompts for create, rename, move, and delete confirmation, positioned near the selected entry
- Optional editable buffer mode for file operations, applied on `:write`
- Configurable keymaps for explorer actions
- File and directory actions for open, create, rename, move, copy, cut, paste, delete, and refresh
- Optional file icons via [`nvim-tree/nvim-web-devicons`](https://github.com/nvim-tree/nvim-web-devicons)

## Install

### lazy.nvim

```lua
{
  dir = "/absolute/path/to/sapling",
  name = "sapling",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "MunifTanjim/nui.nvim",
    "nvim-tree/nvim-web-devicons",
  },
  opts = {},
}
```

`plenary.nvim` is required for async git integration. `nui.nvim` is required for floating prompts. `nvim-web-devicons` is optional. If devicons is not installed, `sapling` falls back to plain file rendering.

## Commands

- `:SaplingToggle`
- `:SaplingOpen`
- `:SaplingReveal`
- `:SaplingRefresh`
- `:SaplingToggleIgnored`

## Setup

```lua
require("sapling").setup({
  file_edit_mode = "prompt",
  window = {
    side = "left",
    width = 32,
  },
  root = {
    strategy = "cwd",
  },
  tree = {
    show_arrows = true,
    show_hidden = false,
    hidden_files = { ".git", "node_modules", ".env" },
  },
  follow_current_file = {
    enabled = true,
    focus = false,
  },
  icons = {
    enabled = true,
    provider = "nvim-web-devicons",
  },
  git = {
    enabled = true,
    show_ignored = true,
    refresh_interval_ms = 1500,
  },
  keymaps = {
    select = { "<LeftMouse>" },
    move_down = { "j" },
    move_up = { "k" },
    move_top = { "gg" },
    move_bottom = { "G" },
    open = { "<CR>", "o", "l" },
    open_mouse = { "<2-LeftMouse>" },
    collapse_or_parent = { "h" },
    edit_buffer = { "e" },
    create_file = { "a" },
    create_dir = { "A" },
    rename = { "r" },
    move = { "m" },
    copy = { "y" },
    copy_absolute_path = { "Y" },
    paste = { "p" },
    cut = { "c" },
    delete = { "d" },
    refresh = { "R" },
    reveal_current = { "." },
    toggle_ignored = { "H" },
    show_help = { "?" },
    close = { "q" },
  },
})
```

Set any action in `keymaps` to `false` to disable its default mapping.

## Default Keymaps

- `j`: move down
- `k`: move up
- `gg`: jump to the top of the explorer
- `G`: jump to the bottom of the explorer
- `<LeftMouse>`: select entry under the mouse
- `<CR>`, `o`, `l`: open file or expand directory
- `<2-LeftMouse>`: open file or toggle directory under the mouse
- `h`: collapse directory or move to its parent
- `e`: enter editable buffer mode when `file_edit_mode = "buffer"` or `"mixed"`
- `a`: create file
- `A`: create directory
- `r`: rename
- `m`: move
- `y`: copy
- `Y`: copy the selected entry's absolute path
- `p`: paste
- `c`: cut
- `d`: delete
- `R`: refresh
- `.`: reveal current file
- `H`: toggle visibility of gitignored files and configured hidden files
- `?`: toggle the help menu
- `q`: close the explorer

## Notes

- The explorer root follows Neovim's current working directory.
- Current-file reveal is ignored when the active file is outside the current working directory.
- Git markers use `~` for modified, `+` for untracked, and `!` for ignored.
- Directory git markers include the number of git-reported changed paths in that subtree, for example `[~3]`.
- Set `tree.show_arrows = false` to hide the expand/collapse arrows while keeping directory toggling behavior.
- Set `tree.hidden_files` to file or directory base names you want treated as hidden, and use `tree.show_hidden` to control their default visibility. `H` toggles both `tree.show_hidden` and gitignored visibility together.
- Git integration is active only when the current working directory is inside a Git repository.
- While the sidebar is open, git and directory state are refreshed on a timer. Set `git.refresh_interval_ms = 0` to disable polling.
- `file_edit_mode = "prompt"` keeps the existing popup flow for create, rename, move, and delete.
- `file_edit_mode = "buffer"` turns file-edit actions into an editable tree session. Edit the root-relative lines and use `:write` to confirm and apply creates, deletes, and moves.
- `file_edit_mode = "mixed"` keeps create, rename, move, and delete on the popup flow, while `edit_buffer` enters the editable tree session for bulk changes.
- In buffer edit mode, pressing `<CR>` on a directory line expands that directory into the editable manifest when there are no pending unsaved edits.
