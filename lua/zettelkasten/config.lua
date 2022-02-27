local M = {}
local s_config = { notes_path = "" }

M.get = function()
    return s_config
end

M._set = function(new_config)
    s_config = vim.tbl_extend("force", s_config, new_config)
end

return M
