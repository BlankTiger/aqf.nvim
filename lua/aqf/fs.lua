local M = {}

local uv = vim.loop

---@param path string
---@return boolean
function M.exists(path)
    return not vim.tbl_isempty(uv.fs_stat(path) or {})
end

---@param path string
---@return boolean
function M.mkdir(path)
    if M.exists(path) then
        return true
    end

    local mode = 448 -- decimal for 0700
    return uv.fs_mkdir(path, mode)
end

---@param path string
---@param content string
---@param flag "a" | "w"
---@param mode integer | nil
function M.write(path, content, flag, mode)
    assert(flag, [[write requires a flag! For example: 'w' or 'a']])
    mode = mode or 438 -- 0666 in oct
    local fd = assert(uv.fs_open(path, flag, mode))
    assert(uv.fs_write(fd, content, -1))
    assert(uv.fs_close(fd))
end

---@param path string
---@return string
function M.read(path)
    local fd = assert(uv.fs_open(path, "r", 438)) -- 0666 oct
    local stat = assert(uv.fs_fstat(fd))
    local data = assert(uv.fs_read(fd, stat.size, 0))
    assert(uv.fs_close(fd))

    return data
end

return M
