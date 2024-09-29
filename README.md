# <p align="center">📋 aqf.nvim ✨</p>

**Table of Contents**

* [🔭 Overview](#-overview)
* [☑️ Requirements](#️-requirements)
* [🧰 Installation](#-installation)
* [⚙️ Configuration options](#️-configuration-options)
* [🗒️ Available commands](#️-available-commands)

# 🔭 Overview

Advanced QuickFix (aqf) - store, edit, swap, filter and keep histories of quickfix lists like a pro. With this plugin you can perform all the mentioned actions in a workflow inspired by [oil.nvim](https://github.com/stevearc/oil.nvim), which means that the main feature of this plugin is being able to edit quickfix lists in a buffer as plain text.

Additionally, with help of [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) you can filter currently edited quickfix list in various ways:
- by file name,
- by match content,
- by file content.

https://github.com/user-attachments/assets/0e79c371-5fee-4b8d-b9ae-1083d33ceea1

# ☑️ Requirements

- If you want to only use the 'edit quickfix as a buffer' workflow, then you don't have to install any additional things.
- If you want to use all the additional filtering features, then you have to have the following conditions met:
    + [ripgrep](https://github.com/BurntSushi/ripgrep) installed,
    + [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) installed,
    + [plenary.nvim](https://github.com/nvim-lua/plenary.nvim) installed.

# 🧰 Installation

> [!NOTE]
> All instructions assume you are using [lazy.nvim](https://github.com/folke/lazy.nvim).

If you only want the 'edit quickfix as a buffer' workflow:

```lua
{
    "blanktiger/aqf.nvim",
    config = function()
        require("aqf").setup()
    end,
}
```

If you want all filtering features:

1. Install [ripgrep](https://github.com/BurntSushi/ripgrep) on your system.
2. Use the following [lazy.nvim](https://github.com/folke/lazy.nvim) plugin config:
```lua
{
    "blanktiger/aqf.nvim",
    config = function()
        require("aqf").setup()
        local telescope = require("telescope")
        telescope.load_extension("aqf")
    end,
    dependencies = {
        "nvim-lua/plenary.nvim",
        "nvim-telescope/telescope.nvim",
    }
}
```

# ⚙️ Configuration options

Following is the default configuration:

```lua
-- you can call setup function with the following options in a lua table:
local opts = {
    -- if set to true, then aqf will create floating windows, if not it will create UIs in new tabs
    windowed = false,
    -- quit editing buffer for currently edited quickfix after saving it
    quit_after_apply = false,
    -- selecting from history saves current quickfix list to history as the most recent entry
    save_when_selecting_from_history = true,
    -- amount of quickfix windows kept in quickfix history
    prev_qflists_limit = 9,
    -- height of a window if `windowed = true`
    win_height = 50,
    -- width of a window if `windowed = true`
    win_width = 180,
    -- set some keymaps and possibly some other stuff for debug/development
    debug = false,
    -- function that is executed during setup if `debug = true`
    on_debug = function()
        vim.keymap.set("n", "<leader>P", M.show_saved_qf_lists, { noremap = true })
        vim.keymap.set("n", "<leader>E", M.edit_curr_qf, { noremap = true })
        vim.keymap.set("n", "<leader>S", M.show_saved_qf_lists, { noremap = true })
        vim.keymap.set("n", "<leader>R", function()
            vim.cmd([[
Lazy reload aqf.nvim
Lazy reload telescope.nvim
Lazy reload aqf.nvim
Lazy reload telescope.nvim
    ]])
        end, { noremap = true })
    end,
}
```

# 🗒️ Available commands

```lua
local aqf = require("aqf")

-- Filter current quickfix by previous search query stored in / reg, by entering a search query in input field,
-- or by providing the `query` param.
---@param query string | nil
---@param by_prev_search boolean
aqf.filter_qf_by_query(by_prev_search, query)

-- Edit current quickfix list in a buffer.
aqf.edit_curr_qf()

-- Show history of quickfix lists.
aqf.show_saved_qf_lists()

-- Save current quickfix list to history of quickfix lists.
aqf.save_qf()

-- Save current quickfix to history (if jumping back in history for the first time)
-- and go back in history of quickfix lists by 1. 
-- NOTE: Creating a new entry in history moves counter over to the newest entry.
aqf.prev_qf()

-- Go forward in history of quickfix lists by 1.
-- NOTE: Creating a new entry in history moves counter over to the newest entry.
aqf.next_qf()

-- Go to arbitrary quickfix in history by index starting from the most recent one (index = 1).
---@param index integer
aqf.goto_qf(index)
```
