local NOTE_ID_STRFTIME_FORMAT = "%Y-%m-%d-%H-%M-%S"

local M = {}

function M.generate_note_id(ids, parent_id)
    return vim.fn.strftime(NOTE_ID_STRFTIME_FORMAT)
end

function M.sort_ids(ids)
    table.sort(ids)
    return ids
end

return M
