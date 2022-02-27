local M = {}
local api = vim.api
local log_levels = vim.log.levels
local log = require("zettelkasten.log")
local config = require("zettelkasten.config")

local s_zk_id_pattern = "%d+-%d+-%d+-%d+:%d+:%d+"
local s_zk_id_regexp = "[0-9]+-[0-9]+-[0-9]+-[0-9]+:[0-9]+:[0-9]+"
if vim.fn.has('linux') == 0 then
  -- The colon is an illegal character in file names on Windows & Mac.
  local s_zk_id_pattern = "%d+-%d+-%d+--%d+-%d+-%d+"
  local s_zk_id_regexp = "[0-9]+-[0-9]+-[0-9]+--[0-9]+-[0-9]+-[0-9]+"
end

local function get_all_tags(base)
    if base == nil or #base == 0 then
        base = "\\w.*"
    end

    local references = vim.fn.systemlist(
        'rg "(#' .. base .. ')" --color never --no-heading --line-number'
    )
    local tags = {}

    for _, word in ipairs(references) do
        local file_name = string.match(word, ".*%a:")
        file_name = string.gsub(file_name, ":$", "")
        local linenr = string.match(word, ":(%d+):")
        linenr = string.gsub(linenr, ":", "")
        local regex = vim.regex("#\\k.*")
        local tag_name = word:sub(regex:match_str(word))
        table.insert(tags, { file_name = file_name, linenr = linenr, tag_name = tag_name })
    end

    return tags
end

local function get_all_ids(base)
    if base and #base > 0 then
        base = s_zk_id_regexp .. " " .. base
    else
        base = s_zk_id_regexp
    end

    local references = vim.fn.systemlist(
        'rg "# ' .. base .. '" --color never --no-heading --no-line-number'
    )

    local words = {}
    for _, word in ipairs(references) do
        local zk_id = string.match(word, s_zk_id_pattern)
        if zk_id == nil then
            log.notify("Cannot find the ID.", log_levels.DEBUG, {})
            return {}
        end

        local context = string.match(word, "# " .. s_zk_id_pattern .. " .*")
        context = string.gsub(context, " " .. s_zk_id_pattern, "")
        if word ~= base then
            table.insert(words, { id = zk_id, context = context })
        end
    end

    return words
end

local function is_id_unique(zk_id)
    local all_ids = get_all_ids()
    for _, entry in ipairs(all_ids) do
        if entry.id == zk_id then
            return false
        end
    end

    return true
end

local function generate_note_id()
    local format = "%d-%m-%y-%T"
    if vim.fn.has('linux') == 0 then
      format = "%d-%m-%y--%H-%M-%S"
    end
    local zk_id = vim.fn.strftime(format)

    if not is_id_unique(zk_id) then
        log.notify("[zettelkasten] Duplicate note ID: " .. zk_id, log_levels.DEBUG)
        return ""
    end

    return zk_id
end

function M.completefunc(find_start, base)
    if find_start == 1 and base == "" then
        local pos = api.nvim_win_get_cursor(0)
        local line = api.nvim_get_current_line()
        local line_to_cursor = line:sub(1, pos[2])
        return vim.fn.match(line_to_cursor, "\\k*$")
    end

    local all_references = get_all_ids(base)

    local words = {}
    for _, ref in ipairs(all_references) do
        if ref.word ~= base then
            table.insert(words, {
                word = ref.id,
                abbr = ref.context,
                dup = 0,
                empty = 0,
                kind = "[zettelkasten]",
                icase = 1,
            })
        end
    end

    return words
end

function M.set_note_id(bufnr)
    local first_line = vim.api.nvim_buf_get_lines(bufnr, 0, 1, true)[1]
    local zk_id = generate_note_id()
    if #zk_id > 0 then
        first_line, _ = string.gsub(first_line, "# ", "")
        api.nvim_buf_set_lines(bufnr, 0, 1, true, { "# " .. zk_id .. " " .. first_line })
        vim.cmd("file " .. zk_id .. ".md")
    else
        log.notify("[zettelkasten] There's already a note with the same ID.", log_levels.ERROR)
    end
end

function M.tagfunc(pattern, flags, info)
    local in_insert = string.match(flags, "i") ~= nil
    local all_tags = {}
    if in_insert then
        all_tags = get_all_tags(nil)
    else
        all_tags = get_all_tags(pattern)
    end

    local tags = {}
    for _, tag in ipairs(all_tags) do
        table.insert(tags, {
            name = tag.tag_name,
            filename = tag.file_name,
            cmd = tag.linenr,
            kind = "zettelkasten",
        })
    end

    return tags
end

function M.keyword_expr(word)
    if not word then
        return {}
    end

    local matching_ids = get_all_ids()
    local lines = {}
    for _, entry in ipairs(matching_ids) do
        if entry.id == word then
            table.insert(lines, entry.context)
        end
    end

    return lines
end

function M.setup(opts)
    opts = opts or {}
    opts.notes_path = opts.notes_path or ""

    config._set(opts)
end

return M
