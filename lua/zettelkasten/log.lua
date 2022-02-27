local M = {}
local log_levels = vim.log.levels
local s_log_level = log_levels.ERROR

function M.set_level(level)
    s_log_level = level
end

function M.notify(msg, level, opts)
    if level >= s_log_level then
        vim.notify(msg, level, opts)
    end
end

return M
