local zk = require("zettelkasten")

if vim.opt_local.tagfunc:get() == "" then
    vim.opt_local.tagfunc = "v:lua.zettelkasten.tagfunc"
end

if vim.opt_local.completefunc:get() == "" then
    vim.opt_local.completefunc = "v:lua.zettelkasten.completefunc"
end

vim.opt_local.isfname:append(":")
vim.opt_local.isfname:append("-")
vim.opt_local.iskeyword:append(":")
vim.opt_local.iskeyword:append("-")
vim.opt_local.suffixesadd:append(".md")

if vim.opt_local.keywordprg:get() == "" then
    vim.opt_local.keywordprg = ":ZkHover"
end

vim.api.nvim_buf_add_user_command(0, "ZkHover", function(opts)
    local args = {}
    if opts.args ~= nil then
        args = vim.split(opts.args, " ", true)
    end

    local cword = ""
    if #args == 1 then
        cword = vim.fn.expand("<cword>")
    else
        cword = args[#args]
    end

    local lines = zk.keyword_expr(cword, {
        preview_note = vim.tbl_contains(args, "-preview"),
        return_lines = vim.tbl_contains(args, "-return-lines"),
    })
    vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO, {})
end, {
    nargs = "+",
})
