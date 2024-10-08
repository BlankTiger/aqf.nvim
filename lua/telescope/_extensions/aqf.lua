local ok, telescope = pcall(require, "telescope")
if not ok then
    error("No telescope installed, please install telescope.nvim")
end

local actions = require("telescope.actions")
local make_entry = require("telescope.make_entry")
local finders = require("telescope.finders")
local pickers = require("telescope.pickers")
local sorters = require("telescope.sorters")
local utils = require("telescope.actions.utils")
local conf = require("telescope.config").values
local fs = require("aqf.fs")

local default_opts = {}
local _data_path = vim.fn.stdpath("data")
local data_path = _data_path .. "/aqf"
fs.mkdir(data_path)

local aqf_tmp_filenames_path = data_path .. "/aqf_tmp_filenames"
local aqf_tmp_matches_path = data_path .. "/aqf_tmp_matches"
fs.write(aqf_tmp_filenames_path, "", "w")
fs.write(aqf_tmp_matches_path, "", "w")

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
    local filtered_qf = vim.g.__aqf_file_lines
    local filtered_qf_str = ""
    for _, v in pairs(filtered_qf) do
        local filename = v:sub(1, v:find(":") - 1)
        if filtered_qf_str:find(filename) then
            goto continue
        end
        filtered_qf_str = filtered_qf_str .. filename .. "\n"
        ::continue::
    end

    fs.write(aqf_tmp_filenames_path, filtered_qf_str, "w")
    local live_grepper = finders.new_job(function(prompt)
        if not prompt or prompt == "" then
            return nil
        end
        local rg_args = split(prompt)
        table.insert(rg_args, "")
        table.insert(rg_args, aqf_tmp_filenames_path)
        return rg_args
    end, opts.entry_maker or make_entry.gen_from_file(opts))

    vim.g.__aqf_filter_by_name_results = nil
    pickers
        .new(opts, {
            prompt_title = "Filter quickfix by filename, <cr> to apply filter",
            finder = live_grepper,
            sorter = sorters.get_generic_fuzzy_sorter(),
            default_text = "rg -N -I --no-heading --no-column ",
        })
        :find()

    local prompt_bufnr = vim.api.nvim_get_current_buf()
    vim.keymap.set("i", "<cr>", function()
        local results = {}
        utils.map_entries(prompt_bufnr, function(entry, index, row)
            table.insert(results, entry.value)
        end)
        vim.g.__aqf_filter_by_name_results = results
        actions.close(prompt_bufnr)
    end, { remap = true, buffer = prompt_bufnr })
end

local function _deduplicate(list)
    local res = {}
    local seen = {}
    for i, v in pairs(list) do
        if not seen[v] then
            seen[v] = i
            table.insert(res, v)
        end
    end
    return res
end

local function _filenames_from_qf_lines(list)
    local res = {}
    for _, qf_line in pairs(list) do
        local filename = qf_line:sub(1, qf_line:find(":") - 1)
        table.insert(res, filename)
    end
    return res
end

local function by_file_content(opts)
    if not opts then
        opts = { fname_width = 200, path_display = { "absolute" } }
    end

    local live_grepper = finders.new_job(function(prompt)
        if not prompt or prompt == "" then
            return nil
        end
        local rg_args = split(prompt)

        local filenames = _filenames_from_qf_lines(vim.g.__aqf_file_lines)
        local unique_filenames = _deduplicate(filenames)
        for _, name in pairs(unique_filenames) do
            table.insert(rg_args, name)
        end

        return rg_args
    end, opts.entry_maker or make_entry.gen_from_vimgrep(opts))

    vim.g.__aqf_filter_by_file_content_results = nil
    pickers
        .new(opts, {
            prompt_title = "Filter quickfix by file content, <cr> to apply filter",
            finder = live_grepper,
            previewer = conf.grep_previewer(opts),
            sorter = sorters.get_generic_fuzzy_sorter(),
            default_text = "rg --vimgrep ",
        })
        :find()

    local prompt_bufnr = vim.api.nvim_get_current_buf()
    vim.keymap.set("i", "<cr>", function()
        local results = {}
        utils.map_entries(prompt_bufnr, function(entry, index, row)
            table.insert(results, entry.value)
        end)
        vim.g.__aqf_filter_by_file_content_results = results
        actions.close(prompt_bufnr)
    end, { remap = true, buffer = prompt_bufnr })
end

function string.cutn(s, search, n)
    local c = 0
    local txt = s
    local idx = 1
    while c < n do
        idx = txt:find(search)
        if not idx then
            return nil
        end
        txt = txt:sub(idx + 1, -1)
        c = c + 1
    end
    return txt
end

local function by_match_content(opts)
    if not opts then
        opts = { fname_width = 200, path_display = { "absolute" } }
    end
    local filtered_qf = vim.g.__aqf_file_lines
    local filtered_qf_str = ""
    for _, v in pairs(filtered_qf) do
        local match_text = string.cutn(v, ":", 3)
        -- TODO: think if deduplicating is worth it here
        -- if filtered_qf_str:find(match_text) then
        --     goto continue
        -- end
        filtered_qf_str = filtered_qf_str .. match_text .. "\n"
        -- ::continue::
    end

    fs.write(aqf_tmp_matches_path, filtered_qf_str, "w")
    local live_grepper = finders.new_job(function(prompt)
        if not prompt or prompt == "" then
            return nil
        end
        local rg_args = split(prompt)
        table.insert(rg_args, "")
        table.insert(rg_args, aqf_tmp_matches_path)
        return rg_args
    end, opts.entry_maker or make_entry.gen_from_string(opts))

    vim.g.__aqf_filter_by_match_content_results = nil
    pickers
        .new(opts, {
            prompt_title = "Filter quickfix by match content, <cr> to apply filter",
            finder = live_grepper,
            sorter = sorters.get_generic_fuzzy_sorter(),
            default_text = "rg -N -I --no-heading --no-column ",
        })
        :find()

    local prompt_bufnr = vim.api.nvim_get_current_buf()
    vim.keymap.set("i", "<cr>", function()
        local results = {}
        utils.map_entries(prompt_bufnr, function(entry, index, row)
            table.insert(results, entry.value)
        end)
        vim.g.__aqf_filter_by_match_content_results = results
        actions.close(prompt_bufnr)
    end, { remap = true, buffer = prompt_bufnr })
end

return telescope.register_extension({
    setup = function(opts, _)
        opts = vim.tbl_extend("force", default_opts, opts)
    end,
    exports = {
        by_name = by_name,
        by_file_content = by_file_content,
        by_match_content = by_match_content,
    },
})
