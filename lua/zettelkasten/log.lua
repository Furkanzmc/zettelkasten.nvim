local M = {}
local log_levels = vim.log.levels
local s_log_level = log_levels.ERROR

function M.set_level(level)
    s_log_level = level
end

function M.notify(msg, level, opts)
    if level >= s_log_level then
        local tag = ""
        if opts.tag then
            tag = "[zettelkasten] "
        end
        vim.notify(tag .. msg, level, opts)
    end
end

return M
