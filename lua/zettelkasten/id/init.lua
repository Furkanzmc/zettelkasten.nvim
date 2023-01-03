local config = require("zettelkasten.config")

local luhmann = require("zettelkasten.id.luhmann")
local date = require("zettelkasten.id.date")

local M = {}

function M.sort_ids(ids)
    local id_scheme = config.get().id_scheme
    if id_scheme == config.DATE_TIME then
        return date.sort_ids(ids)
    elseif id_scheme == config.LUHMANN then
        return luhmann.sort_ids(ids)
    end
end

function M.generate_note_id(ids, parent_id)
    local id_scheme = config.get().id_scheme
    if id_scheme == config.DATE_TIME then
        return date.generate_note_id(ids, parent_id)
    elseif id_scheme == config.LUHMANN then
        return luhmann.generate_note_id(ids, parent_id)
    end
end

return M
