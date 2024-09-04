local M = {}

--- @param opts table
function M.setup(opts) end

function M.edit_qf() end

function M.save_qf()
    local curr_qflist = vim.fn.getqflist()
    vim.g.prev_qflist = curr_qflist
end

function M.prev_qf()
    local curr_qflist = vim.fn.getqflist()
    vim.fn.setqflist(vim.g.prev_qflist)
    vim.g.prev_qflist = curr_qflist
end

---@param by_prev_search boolean
function M.filter_qf_by_query(by_prev_search)
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
    vim.g.prev_qflist = curr_qflist
    vim.fn.setqflist(matching_files)
    vim.api.nvim_command("buf " .. curr_buf)
end

function M.show_saved_qf_lists() end

return M
