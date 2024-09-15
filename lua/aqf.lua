local M = { quit_after_apply = false, prev_qflists_limit = 9, win_height = 50, win_width = 180 }

function table.copy(t)
    local u = {}
    for k, v in pairs(t) do
        u[k] = v
    end
    return setmetatable(u, getmetatable(t))
end

--- @param opts table
function M.setup(opts)
    -- TODO: use vim.deepcopy or something like that to merge user config with defaults instead of manual work
    local quit_after_apply = opts["quit_after_apply"]
    local prev_qflists_limit = opts["prev_qflists_limit"]
    local win_height = opts["win_height"]
    local win_width = opts["win_width"]
    if quit_after_apply == true then
        M.quit_after_apply = true
    end
    if prev_qflists_limit then
        M.prev_qflists_limit = prev_qflists_limit
    end
    if win_height then
        M.win_height = win_height
    end
    if win_width then
        M.win_width = win_width
    end
    vim.g.prev_qflists = {}
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
end

local function _filter_by_bufnames(file_list, names)
    local res = {}
    for i, v in pairs(file_list) do
        local found = false
        for _, name in pairs(names) do
            if v.filename == name then
                found = true
                break
            end
        end
        if found then
            res[i] = v
        end
    end
    return res
end

local function _filter_by_match_content(file_list, matches)
    local res = {}
    for i, v in pairs(file_list) do
        local found = false
        for _, match in pairs(matches) do
            if v.text == match then
                found = true
                break
            end
        end
        if found then
            res[i] = v
        end
    end
    return res
end

local function _cushion_to_center(text, width)
    local len = text:len()
    local cushion = (width - len) / 2
    local new_text = string.rep(" ", cushion) .. text
    return new_text
end

local function _create_entry(filename, text, bufnr, col, line_num)
    return { filename = filename, text = text, bufnr = bufnr, col = col, lnum = line_num }
end

local function _create_buf_and_win()
    local bufnr = vim.api.nvim_create_buf(false, true)
    local ui = vim.api.nvim_list_uis()[1]
    local win = vim.api.nvim_open_win(bufnr, true, {
        width = M.win_width,
        height = M.win_height,
        style = "minimal",
        border = "rounded",
        relative = "editor",
        anchor = "NW",
        col = ui.width / 2 - M.win_width / 2,
        row = ui.height / 2 - M.win_height / 2,
    })
    return bufnr, win
end

local function _create_file_list(qf)
    local file_list = {}
    for _, v in pairs(qf) do
        local _bufnr = v["bufnr"]
        local _col = v["col"]
        local _lnum = v["lnum"]
        local text = v["text"]
        local filename = vim.api.nvim_buf_get_name(_bufnr)
        local entry = _create_entry(filename, text, _bufnr, _col, _lnum)
        table.insert(file_list, entry)
    end
    return file_list
end

local function _lineify_file_list(file_list, prefix)
    local lines = {}
    for _, v in pairs(file_list) do
        local entry = v["filename"] .. ":" .. v["lnum"] .. ":" .. v["col"] .. ":" .. v["text"]
        if prefix then
            entry = prefix .. entry
        end
        table.insert(lines, entry)
    end
    return lines
end

local function _get_cursor_pos()
    local winid = vim.api.nvim_get_current_win()
    local curpos = vim.fn.getcurpos(winid)
    return curpos[2], curpos[3]
end

local function _save_qf_from_current_editing_window(bufnr, sep_line)
    local buf_content = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local qflist = {}
    local found_sep_line = false
    for _, v in pairs(buf_content) do
        if v:find(sep_line, nil, true) then
            found_sep_line = true
            goto continue
        end
        if not found_sep_line then
            goto continue
        end

        table.insert(qflist, v)

        ::continue::
    end

    M.save_qf()

    local lnum, col = _get_cursor_pos()
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, qflist)
    vim.api.nvim_command("cexpr []")
    vim.api.nvim_command("caddbuffer")
    -- FIXME: think of a better way to remove the last entry from undolist
    -- to prevent user from seeing intermediate step
    vim.cmd.undo()
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, buf_content)
    vim.fn.cursor(lnum, col)
end

local function _apply_filter_by_name_results_via_autocmd(aqf_bufnr, file_list, prefix_lines)
    local prompt_bufnr = vim.api.nvim_get_current_buf()
    vim.api.nvim_create_autocmd("BufLeave", {
        buffer = prompt_bufnr,
        group = vim.api.nvim_create_augroup("telescope-aqf", {}),
        desc = "get selected entries from telescope aqf",
        callback = function()
            local names = vim.g.__aqf_filter_by_name_results
            if not names then
                return
            end

            local filtered = _filter_by_bufnames(file_list, names)
            local new_lines = table.copy(prefix_lines)
            local new_file_lines = _lineify_file_list(filtered, nil)
            vim.g.__aqf_file_lines = new_file_lines
            for _, v in pairs(new_file_lines) do
                table.insert(new_lines, v)
            end
            vim.api.nvim_buf_set_lines(aqf_bufnr, 0, -1, false, {})
            vim.api.nvim_buf_set_lines(aqf_bufnr, 1, -1, false, new_lines)
        end,
    })
end

local function _apply_filter_by_file_content_results_via_autocmd(aqf_bufnr, prefix_lines)
    local prompt_bufnr = vim.api.nvim_get_current_buf()
    vim.api.nvim_create_autocmd("BufLeave", {
        buffer = prompt_bufnr,
        group = vim.api.nvim_create_augroup("telescope-aqf", {}),
        desc = "get selected entries from telescope aqf",
        callback = function()
            local lines = vim.g.__aqf_filter_by_file_content_results
            if not lines then
                return
            end

            local new_lines = table.copy(prefix_lines)
            vim.g.__aqf_file_lines = lines
            for _, v in pairs(lines) do
                table.insert(new_lines, v)
            end
            vim.api.nvim_buf_set_lines(aqf_bufnr, 0, -1, false, {})
            vim.api.nvim_buf_set_lines(aqf_bufnr, 1, -1, false, new_lines)
        end,
    })
end

local function _apply_filter_by_match_content_results_via_autocmd(
    aqf_bufnr,
    file_list,
    prefix_lines
)
    local prompt_bufnr = vim.api.nvim_get_current_buf()
    vim.api.nvim_create_autocmd("BufLeave", {
        buffer = prompt_bufnr,
        group = vim.api.nvim_create_augroup("telescope-aqf", {}),
        desc = "get selected entries from telescope aqf",
        callback = function()
            local matches = vim.g.__aqf_filter_by_match_content_results
            if not matches then
                return
            end

            local filtered = _filter_by_match_content(file_list, matches)
            local new_lines = table.copy(prefix_lines)
            local new_file_lines = _lineify_file_list(filtered, nil)
            vim.g.__aqf_file_lines = new_file_lines
            for _, v in pairs(new_file_lines) do
                table.insert(new_lines, v)
            end
            vim.api.nvim_buf_set_lines(aqf_bufnr, 0, -1, false, {})
            vim.api.nvim_buf_set_lines(aqf_bufnr, 1, -1, false, new_lines)
        end,
    })
end

function filter_qf_by_query(by_prev_search)
    local query = ""
    if by_prev_search then
        vim.notify("Filtering using latest search pattern (/ reg)")
        query = vim.fn.getreg("/")
    else
        query = vim.fn.input("Search pattern: ")
    end

    if query == "" then
        vim.notify("No search pattern provided")
        return
    end

    local curr_buf = vim.fn.bufnr()
    local curr_qflist = vim.fn.getqflist()
    local matching_files = {}
    for _, v in ipairs(curr_qflist) do
        local bufnr = v["bufnr"]
        vim.api.nvim_command("buf " .. bufnr)
        local search_res = vim.fn.search(query)
        if search_res ~= 0 then
            table.insert(matching_files, v)
        end
    end
    M.save_qf()
    vim.fn.setqflist(matching_files)
    vim.api.nvim_command("buf " .. curr_buf)
end

local function _edit_qf(qf)
    local lines = {
        "<leader>n - filter by file names, <leader>c - filter by file content,",
        "<leader>m - filter by match content, <leader>s - filter by previous search query,",
        "<leader>r - refresh,",
        "<leader>a or <leader>w to apply changes, q - leave buffer",
        "",
        "You can also just edit the list under the separator",
        "",
        "Please don't remove/modify the separation line",
    }
    for i, inst in pairs(lines) do
        lines[i] = _cushion_to_center(inst, M.win_width)
    end
    local sep = "-"
    local sep_line = sep:rep(M.win_width)
    table.insert(lines, sep_line)

    local file_list = _create_file_list(qf)
    vim.g.__aqf_file_lines = _lineify_file_list(file_list, nil)
    local old_lines = table.copy(lines)
    for _, v in pairs(vim.g.__aqf_file_lines) do
        table.insert(lines, v)
    end

    local bufnr, win = _create_buf_and_win()
    vim.api.nvim_put(lines, "l", true, true)

    local keymap_opts = { noremap = true, buffer = bufnr, nowait = true }

    vim.keymap.set("n", "<leader>n", function()
        local telescope = require("telescope")
        telescope.extensions.aqf.by_name()
        _apply_filter_by_name_results_via_autocmd(bufnr, file_list, old_lines)
    end, keymap_opts)

    vim.keymap.set("n", "<leader>c", function()
        local telescope = require("telescope")
        telescope.extensions.aqf.by_file_content()
        _apply_filter_by_file_content_results_via_autocmd(bufnr, old_lines)
    end, keymap_opts)

    vim.keymap.set("n", "<leader>m", function()
        local telescope = require("telescope")
        telescope.extensions.aqf.by_match_content()
        _apply_filter_by_match_content_results_via_autocmd(bufnr, file_list, old_lines)
    end, keymap_opts)

    vim.keymap.set("n", "<leader>a", function()
        _save_qf_from_current_editing_window(bufnr, sep_line)
    end, keymap_opts)

    vim.keymap.set("n", "<leader>w", function()
        _save_qf_from_current_editing_window(bufnr, sep_line)
    end, keymap_opts)

    local function refresh()
        local lnum, col = _get_cursor_pos()
        vim.api.nvim_command("q")
        M.edit_curr_qf()
        vim.fn.cursor(lnum, col)
    end

    vim.keymap.set("n", "<leader>s", function()
        filter_qf_by_query(true)
        refresh()
        M.save_qf()
    end, keymap_opts)

    vim.keymap.set("n", "<leader>r", function()
        refresh()
    end, keymap_opts)

    vim.keymap.set("n", "q", "<cmd>q<cr>", { noremap = true, buffer = bufnr })
end

function M.edit_curr_qf()
    local qf = vim.fn.getqflist()
    _edit_qf(qf)
end

function M.save_qf()
    local curr_qflist = vim.fn.getqflist()
    local qflists = vim.g.prev_qflists
    local len_qfs = #qflists
    if len_qfs > M.prev_qflists_limit then
        table.remove(qflists, 1)
    end
    table.insert(qflists, curr_qflist)
    vim.g.prev_qflists = qflists
end

function M.prev_qf()
    local curr_qflist = vim.fn.getqflist()
    local len_prev_qflists = #vim.g.prev_qflists
    local prev_qflist = vim.g.prev_qflists[len_prev_qflists]
    local prev_qflists = vim.g.prev_qflists
    prev_qflists[len_prev_qflists] = curr_qflist
    vim.g.prev_qflists = prev_qflists
    vim.fn.setqflist(prev_qflist)
end

local function _summarize_qf(qf)
    local file_list = _create_file_list(qf)
    local file_lines = _lineify_file_list(file_list, "    ")
    return file_lines
end

function M.show_saved_qf_lists()
    local instructions = {
        "",
        "q - leave the buffer, <cr> - open quickfix list under cursor for editing",
        "<leader>s - set quickfix under cursor as current quickfix, <leader>r - refresh",
        "<leader>d - remove quickfix under cursor",
        "",
        "Please don't remove/modify the separation line",
    }
    for i, inst in pairs(instructions) do
        instructions[i] = _cushion_to_center(inst, M.win_width)
    end
    local sep = "-"
    table.insert(instructions, sep:rep(M.win_width))

    local qflists = vim.g.prev_qflists
    local bufnr, win = _create_buf_and_win()
    local qflists_strs = instructions
    local line_mapping = {}
    for i, qf in pairs(qflists) do
        table.insert(qflists_strs, i .. ": ")
        for _, line in pairs(_summarize_qf(qf)) do
            table.insert(qflists_strs, line)
            line_mapping[i] = #qflists_strs
        end
    end
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, qflists_strs)

    local function get_chosen_qf_idx()
        local lnum = vim.api.nvim__buf_stats(bufnr).current_lnum
        local chosen_qf = 1
        local prev_limit = 1
        -- FIXME: instructions arent taken into account while checking this,
        -- enter on instructions results in entering editing for first quickfix list
        for i, limit in pairs(line_mapping) do
            if i > 1 then
                prev_limit = line_mapping[i - 1]
            end
            if lnum > prev_limit and lnum <= limit then
                chosen_qf = i
                break
            end
        end
        return chosen_qf
    end

    local keymap_opts = { noremap = true, buffer = bufnr, nowait = true }
    vim.keymap.set("n", "<cr>", function()
        local chosen_qf = get_chosen_qf_idx()
        _edit_qf(qflists[chosen_qf])
    end, keymap_opts)

    local function refresh()
        local lnum, col = _get_cursor_pos()
        vim.api.nvim_command("q")
        M.show_saved_qf_lists()
        vim.fn.cursor(lnum, col)
    end

    vim.keymap.set("n", "<leader>s", function()
        local chosen_qf = get_chosen_qf_idx()
        M.save_qf()
        local qf = qflists[chosen_qf]
        vim.fn.setqflist(qf)
        refresh()
    end, keymap_opts)

    vim.keymap.set("n", "<leader>r", function()
        refresh()
    end, keymap_opts)

    vim.keymap.set("n", "<leader>d", function()
        local chosen_qf = get_chosen_qf_idx()
        table.remove(qflists, chosen_qf)
        vim.g.prev_qflists = qflists
        refresh()
    end, keymap_opts)

    vim.keymap.set("n", "q", "<cmd>q<cr>", { noremap = true, buffer = bufnr })
end

return M
