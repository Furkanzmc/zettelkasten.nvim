local log_levels = vim.log.levels
local log = require("zettelkasten.log")

local M = {}

M.TITLE = 0
M.FILENAME = 1

local s_config = {
    notes_path = "",
    preview_command = "pedit",
    browseformat = "%f - %h [%r Refs] [%b B-Refs] %t",
    id_inference_location = M.TITLE,
    id_pattern = "%d+-%d+-%d+-%d+-%d+-%d+",
    filename_pattern = "%d+-%d+-%d+-%d+-%d+-%d+.md",
    title_pattern = "# %d+-%d+-%d+-%d+-%d+-%d+ .+",
    put_id_in_title = true,
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

    if
        s_config.id_inference_location ~= M.TITLE
        and s_config.id_inference_location ~= M.FILENAME
    then
        log.notify(
            "id_inference_location must be set to either TITLE or FILENAME.",
            log_levels.WARN,
            {}
        )
    end
end

return M
