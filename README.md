# telescope-git-file-history.nvim

Telescope extension which lets you open and preview the current file at any previous commit, without detaching HEAD (i.e., without using `git checkout`). The file can be opened in the current buffer, new split, new tab or in your web browser. The file is opened as a `fugitive-object`, so all [`vim-fugitive`](https://github.com/tpope/vim-fugitive) mappings can be used.

## Demo
https://github.com/isak102/telescope-git-file-history.nvim/assets/90389894/9a4b5d2f-4dce-4dcb-816e-3cb8b132f7b9

## What is the difference between this plugin and `:Telescope git_bcommits`?

There are a few key differences between this plugin and `:Telescope git_bcommits`:
- **Purpose**: The purpose of this plugin is to open the current file at a previous version, without affecting the rest of your git workflow. By default, `git_bcommits` checks out the entire repository on selection, which affects everything you are currently doing. If you have unstaged changes the checkout will also fail.
- **Moved files**: This plugin handles moved/renamed files. For example, if the current file used to be called `foo.lua` at a specific commit but is now called `bar/baz.lua`, the preview will still be shown. This is not the case for `git_bcommits`. The actions will also work as expected.
- **Previewer**: The previewer in this plugin shows how the file looked at that commit, which is useful for quickly seeing how the file has changed. The previewer for `git_bcommits` shows the diff.

## Dependencies
- [tpope/vim-fugitive](https://github.com/tpope/vim-fugitive) (for opening file at previous commit without moving HEAD)
- git
- awk

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)
Add this plugin as a dependency to `telescope.nvim`, like this:
```lua
{
    "nvim-telescope/telescope.nvim"
    dependencies = {
        {
            "isak102/telescope-git-file-history.nvim",
            dependencies = { "tpope/vim-fugitive" }
        }
    }
}
```

## Setup

Call `require("telescope").load_extension("git_file_history")` somewhere after your telescope setup:

```lua
require("telescope").setup({
    -- Your telescope config here
})

require("telescope").load_extension("git_file_history")
```

## Configuration
Configure this plugin by using the `extensions.git_file_history` table in your telescope configuration. This plugin comes with the following defaults:

```lua
local gfh_actions = require("telescope").extensions.git_file_history.actions

require("telescope").setup({
    -- The rest of your telescope config here

    extensions = {
        git_file_history = {
            -- Keymaps inside the picker
            mappings = {
                i = {
                    ["<C-g>"] = gfh_actions.open_in_browser,
                },
                n = {
                    ["<C-g>"] = gfh_actions.open_in_browser,
                },
            },

            -- The command to use for opening the browser (nil or string)
            -- If nil, it will check if xdg-open, open, start, wslview are available, in that order.
            browser_command = nil,
        },
    },
})
```

## Usage

Run `:Telescope git_file_history` or use:
```lua
require("telescope").extensions.git_file_history.git_file_history()
```

## Keymaps

| Mappings | Action                                                                        |
| -------- | ----------------------------------------------------------------------------- |
| `<C-g>`  | Open current file at commit in web browser                                    |
| `select` (Telescope default: `<CR>`)  | Open current file at commit in current buffer                                    |
| `select_vertical` (Telescope default: `<C-v>`) | Open current file at commit in vertical split                                    |
| `select_horizontal` (Telescope default: `<C-x>`) | Open current file at commit in horizontal split                                    |
| `select_tab` (Telescope default: `<C-t>`) | Open current file at commit in new tab                                    |

The `select`, `select_vertical`, `select_horizontal` and `select_tab` keymaps are configured by telescope.

## Inspiration

- [`Telescope git_bcommits`](https://github.com/nvim-telescope/telescope.nvim/blob/master/lua/telescope/builtin/__git.lua)
