if vim.b.current_syntax == "zkbrowser" then
    return
end

vim.cmd([[syntax match ZkFileName '[0-9]\+-[0-9]\+-[0-9]\+-[0-9]\+-[0-9]\+-[0-9]\+\.md']])
vim.cmd([[syntax match ZkRefCount '\[[0-9]\+ .*\]']])
vim.cmd([[syntax match ZkTag '#\<\k\+\>']])

vim.api.nvim_set_hl(0, "ZkFileName", { link = "Label", default = true })
vim.api.nvim_set_hl(0, "ZkRefCount", { link = "Link", default = true })
vim.api.nvim_set_hl(0, "ZkTag", { link = "Tag", default = true })

vim.b.current_syntax = "zkbrowser"
