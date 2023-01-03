local config = require("zettelkasten.config")

local luhmann = require("zettelkasten.id.luhmann")
local date = require("zettelkasten.id.date")

local M = {}

function M.sort_ids(names)
    local name_scheme = config.get().name_scheme
    if name_scheme == config.DATE then
        return date.sort_ids(names)
    elseif name_scheme == config.LUHMANN then
        return luhmann.sort_ids(names)
    end
end

function M.generate_note_id(names, parent_name)
    local name_scheme = config.get().name_scheme
    if name_scheme == config.DATE then
        return date.generate_note_id(names, parent_name)
    elseif name_scheme == config.LUHMANN then
        return luhmann.generate_note_id(names, parent_name)
    end
end

return M
