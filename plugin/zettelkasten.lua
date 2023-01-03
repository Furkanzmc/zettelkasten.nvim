local api = vim.api
local s_config = require("zettelkasten.config")

if vim.fn.exists(":ZkNew") == 0 then
    vim.cmd([[command -nargs=? ZkNew :lua _G.zettelkasten.zknew(<q-args>)]])
end

if vim.fn.exists(":ZkBrowse") == 0 then
    vim.cmd([[command ZkBrowse :lua _G.zettelkasten.zkbrowse()]])
end

vim.api.nvim_create_autocmd({ "BufReadCmd" }, {
    pattern = "zk://browser",
    group = vim.api.nvim_create_augroup("zettelkasten_browser_events", { clear = true }),
    callback = function(opts)
        vim.opt_local.syntax = ""
        vim.api.nvim_buf_set_lines(
            0,
            vim.fn.line("$") - 1,
            -1,
            true,
            require("zettelkasten").get_note_browser_content()
        )
        vim.opt_local.syntax = "zkbrowser"
        vim.opt_local.filetype = "zkbrowser"
    end,
})

_G.zettelkasten = {
    tagfunc = require("zettelkasten").tagfunc,
    completefunc = require("zettelkasten").completefunc,
    zknew = function(parent_id)
        vim.cmd([[new | setlocal filetype=markdown]])
        local config = s_config.get()
        if config.notes_path ~= "" then
            vim.cmd("lcd " .. config.notes_path)
        end

        vim.cmd("normal ggI# New Note")
        require("zettelkasten").set_note_id(vim.api.nvim_get_current_buf(), parent_id)
        vim.cmd("normal $")
    end,
    zkbrowse = function()
        vim.cmd("edit zk://browser")
    end,
    contains = require("zettelkasten").contains,
}
