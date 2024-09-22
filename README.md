# <p align="center">📋 aqf.nvim ✨</p>

**Table of Contents**

* [🔭 Overview](#-overview)
* [☑️ Requirements](#️-requirements)
* [🧰 Installation](#-installation)
* [⚙️ Configuration](#️-configuration)
* [🗒️ Available commands](#️-available-commands)

# 🔭 Overview

Advanced QuickFix (aqf) - store, edit, swap, filter and keep histories of quickfix lists like a pro. With this plugin you can perform all the mentioned actions in a workflow inspired by [oil.nvim](https://github.com/stevearc/oil.nvim), which means that the main feature of this plugin is being able to edit quickfix lists in a buffer as plain text.

Additionally, with help of [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) you can filter currently edited quickfix list in various ways:
- by file name,
- by match content,
- by file content.

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
        require("aqf.nvim").setup({})
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
        require("aqf.nvim").setup({})
    end,
    dependencies = {}
}
```

# ⚙️ Configuration

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

-- Save and swap current quickfix list with the newest one found in history.
aqf.prev_qf()
```
