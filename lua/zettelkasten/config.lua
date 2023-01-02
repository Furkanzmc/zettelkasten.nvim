local log_levels = vim.log.levels
local log = require("zettelkasten.log")

local M = {}
local s_config = {
    notes_path = "",
    preview_command = "pedit",
    browseformat = "%f - %h [%r Refs] [%b B-Refs] %t",
    id_inference_location = 0,
    id_pattern = "%d+-%d+-%d+-%d+-%d+-%d+",
    filename_pattern = "%d+-%d+-%d+-%d+-%d+-%d+.md",
    title_pattern = "# %d+-%d+-%d+-%d+-%d+-%d+ .+",
}

M.get = function()
    return s_config
end

M._set = function(new_config)
    for k, _ in pairs(new_config) do
        if s_config[k] == nil then
            log.notify('Key "' .. k .. '" ignored in user config.', log_levels.WARN, {})
        end
    end

    s_config = vim.tbl_extend("force", s_config, new_config)
end

return M
