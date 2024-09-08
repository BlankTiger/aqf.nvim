local ok, telescope = pcall(require, "telescope")
if not ok then
    error("No telescope installed, please install telescope.nvim")
end

local actions = require("telescope.actions")
local make_entry = require("telescope.make_entry")
local finders = require("telescope.finders")
local pickers = require("telescope.pickers")
local sorters = require("telescope.sorters")
local state = require("telescope.actions.state")
local conf = require("telescope.config").values
local plenary = require("plenary")
local with = plenary.context_manager.with
local open = plenary.context_manager.open

local default_opts = {}

local function split(command)
    local cmd_split = {}
    local start = 1
    local in_quotes = false
    local curr_quotes = "\""
    for i = 1, #command do
        local c = command:sub(i, i)
        local next = ""

        if (c == "\"" or c == "'") and not in_quotes then
            in_quotes = true
            curr_quotes = c
            start = i
        elseif c == curr_quotes and in_quotes then
            in_quotes = false
            next = command:sub(start + 1, i - 1)
            start = i + 1
        end
        if in_quotes then
            goto continue
        end

        if c == " " then
            next = command:sub(start, i - 1)
            start = i + 1
        end

        if i == #command and next:len() == 0 then
            next = command:sub(start, i)
        end

        if next:len() > 0 then
            table.insert(cmd_split, next)
        end
        ::continue::
    end

    return cmd_split
end

local function by_name(opts)
    if not opts then
        opts = { fname_width = 200, path_display = { "absolute" } }
    end
    local filtered_qf = vim.g.filtered_qf
    local filtered_qf_str = ""
    for _, v in pairs(filtered_qf) do
        local filename = v:sub(1, v:find(":") - 1)
        if filtered_qf_str:find(filename) then
            goto continue
        end
        filtered_qf_str = filtered_qf_str .. filename .. "\n"
        ::continue::
    end

    -- local tmpfile = io.tmpfile()
    -- tmpfile:write(filtered_qf_str)
    local result = with(open("/tmp/aqftmpfilenames", "w"), function(reader)
        reader:write(filtered_qf_str)
    end)
    local live_grepper = finders.new_job(function(prompt)
        if not prompt or prompt == "" then
            return nil
        end
        local rg_args = split(prompt)
        table.insert(rg_args, "/tmp/aqftmpfilenames")
        return rg_args
    end, opts.entry_maker or make_entry.gen_from_file(opts))

    pickers
        .new(opts, {
            prompt_title = "Filter quickfix by filename",
            finder = live_grepper,
            -- sorter = sorters.get_generic_fuzzy_sorter(),
            sorter = sorters.highlighter_only(opts),
            default_text = "rg -N -I --no-heading --no-column ",
            -- attach_mappings = function(prompt_bufnr, _)
            --     actions.select_default:replace(function()
            --         actions.close(prompt_bufnr)
            --
            --         local selection = state.get_selected_entry()
            --         local link = codes[selection[1]]
            --
            --         vim.fn.jobstart(http_opts.open_url:format(link))
            --     end)
            --     return true
            -- end,
        })
        :find()
end

local function by_file_content(opts) end

return telescope.register_extension({
    setup = function(opts, _)
        opts = vim.tbl_extend("force", default_opts, opts)
    end,
    exports = {
        by_name = by_name,
        by_file_content = by_file_content,
    },
})
