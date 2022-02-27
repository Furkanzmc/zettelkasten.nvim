local api = vim.api
local s_config = require("zettelkasten.config")

api.nvim_add_user_command("ZkNew", function(_)
    vim.cmd([[new | setlocal filetype=markdown]])
    local config = s_config.get()
    if config.notes_path ~= "" then
        vim.cmd("lcd " .. config.notes_path)
    end

    vim.cmd("normal ggI# New Note")
    require("zettelkasten").set_note_id(vim.api.nvim_get_current_buf())
    vim.cmd("normal $")
end, {})

_G.zettelkasten = {
    tagfunc = require("zettelkasten").tagfunc,
    completefunc = require("zettelkasten").completefunc,
}
