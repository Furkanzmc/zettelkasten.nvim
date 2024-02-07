local api = vim.api
local fn = vim.fn

if fn.exists(":ZkNew") == 0 then
    api.nvim_create_user_command("ZkNew", function(opts)
        vim.cmd([[new | setlocal filetype=markdown]])
        local config = require("zettelkasten.config").get()
        if fn.isdirectory(config.notes_path) == 1 then
            vim.cmd("lcd " .. config.notes_path)
        end

        vim.cmd("normal ggI# New Note")
        require("zettelkasten").set_note_id(api.nvim_get_current_buf(), opts.args)
        vim.cmd("normal $")
    end, { nargs = "?", bar = true })
end

if fn.exists(":ZkBrowse") == 0 then
    api.nvim_create_user_command("ZkBrowse", function(opts)
        vim.cmd("edit zk://browser")
    end, {})
end

api.nvim_create_autocmd({ "BufReadCmd" }, {
    pattern = "zk://browser",
    group = api.nvim_create_augroup("zettelkasten_browser_events", { clear = true }),
    callback = function(opts)
        vim.opt_local.syntax = ""
        api.nvim_buf_set_lines(
            0,
            fn.line("$") - 1,
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
}
