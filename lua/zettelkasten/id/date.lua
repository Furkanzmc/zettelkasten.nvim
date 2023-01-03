local NOTE_ID_STRFTIME_FORMAT = "%Y-%m-%d-%H-%M-%S"

local M = {}

function M.generate_note_id(names, parent_name)
    return vim.fn.strftime(NOTE_ID_STRFTIME_FORMAT)
end

function M.sort_ids(names)
    table.sort(names)
    return names
end

return M
