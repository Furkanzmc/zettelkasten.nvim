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

vim.api.nvim_buf_add_user_command(0, "ZkHover", function(_)
    local lines = zk.keyword_expr(vim.fn.expand("<cword>"))
    vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO, {})
end, {
    nargs = 1,
})

if vim.opt_local.keywordprg:get() == "" then
    vim.opt_local.keywordprg = ":ZkHover"
end
