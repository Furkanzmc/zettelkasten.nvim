local M = {}
local api = vim.api
local log_levels = vim.log.levels
local log = require("zettelkasten.log")
local config = require("zettelkasten.config")

local s_zk_id_pattern = "%d+-%d+-%d+-%d+:%d+:%d+"
local s_zk_id_regexp = "[0-9]+-[0-9]+-[0-9]+-[0-9]+:[0-9]+:[0-9]+"
local s_zk_file_name_pattern = "%d+-%d+-%d+-%d+:%d+:%d+.md"

local function set_qflist(lines, action, bufnr, use_loclist, what)
    what = what or {}
    local _, local_efm = pcall(vim.api.nvim_buf_get_option, bufnr, "errorformat")
    what.efm = what.efm or local_efm
    if use_loclist then
        vim.fn.setloclist(bufnr, lines, action, what)
    else
        vim.fn.setqflist(lines, action, what)
    end
end

local function get_note_content(file_name)
    if vim.fn.filereadable(file_name) == 0 then
        log.notify("Cannot find the note.", log_levels.ERROR, { tag = true })
    end
    return vim.fn.readfile(file_name, "")
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
        tag_name = string.gsub(tag_name, "^:", "")
        local names = vim.split(tag_name, " ")
        if #names > 1 then
            for _, tn in ipairs(names) do
                table.insert(tags, { file_name = file_name, linenr = linenr, tag_name = tn })
            end
        else
            table.insert(tags, { file_name = file_name, linenr = linenr, tag_name = tag_name })
        end
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
            log.notify("Cannot find the ID.", log_levels.DEBUG, { tag = true })
            return {}
        end

        local file_name = string.match(word, s_zk_file_name_pattern)
        local context = string.match(word, "# " .. s_zk_id_pattern .. " .*")
        context = string.gsub(context, " " .. s_zk_id_pattern, "")
        if word ~= base then
            table.insert(words, { id = zk_id, context = context, file_name = file_name })
        end
    end

    return words
end

local function get_context(all_ids, note_id)
    for _, ref in ipairs(all_ids) do
        if ref.id == note_id then
            return ref.context
        end
    end

    return ""
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
    local zk_id = vim.fn.strftime("%d-%m-%y-%T")

    if not is_id_unique(zk_id) then
        log.notify("Duplicate note ID: " .. zk_id, log_levels.DEBUG, { tag = true })
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
        log.notify("There's already a note with the same ID.", log_levels.ERROR, { tag = true })
    end
end

function M.tagfunc(pattern, flags, info)
    local in_insert = string.match(flags, "i") ~= nil
    local pattern_provided = pattern ~= "\\<\\k\\k"
    local all_tags = {}
    if in_insert then
        all_tags = get_all_tags(nil)
    else
        all_tags = get_all_tags(pattern)
    end

    local tags = {}
    for _, tag in ipairs(all_tags) do
        if string.find(tag.tag_name, pattern, 1, true) or not pattern_provided then
            table.insert(tags, {
                name = tag.tag_name,
                filename = tag.file_name,
                cmd = tag.linenr,
                kind = "zettelkasten",
            })
        end
    end

    if not in_insert then
        local all_references = get_all_ids()
        for _, ref in ipairs(all_references) do
            if string.find(ref.id, pattern, 1, true) or not pattern_provided then
                table.insert(tags, {
                    name = ref.id,
                    filename = ref.file_name,
                    cmd = "1",
                    kind = "zettelkasten",
                })
            end
        end
    end

    if #tags > 0 then
        return tags
    end

    return nil
end

function M.keyword_expr(word, opts)
    if not word then
        return {}
    end

    opts = opts or {}
    opts.preview_note = opts.preview_note or false
    opts.return_lines = opts.return_lines or false

    local matching_ids = get_all_ids()
    local lines = {}
    for _, entry in ipairs(matching_ids) do
        if entry.id == word then
            if opts.preview_note and not opts.return_lines then
                vim.cmd(config.get().preview_command .. " " .. entry.file_name)
            elseif opts.preview_note and opts.return_lines then
                vim.list_extend(lines, get_note_content(entry.file_name))
            else
                table.insert(lines, entry.context)
            end
        end
    end

    return lines
end

function M.get_references(note_id)
    local references = vim.fn.systemlist(
        'rg -F "'
            .. "[["
            .. note_id
            .. "]]"
            .. '" --color never --no-heading --line-number --glob !'
            .. note_id
    )

    local all_ids = get_all_ids()
    local words = {}
    for _, word in ipairs(references) do
        local zk_id = string.match(word, s_zk_id_pattern)
        if zk_id == nil then
            log.notify("Cannot find the ID.", log_levels.DEBUG, { tag = true })
            return {}
        end

        local file_name = string.match(word, s_zk_file_name_pattern)
        local linenr = string.match(word, ":(%d+):", #file_name)
        linenr = string.gsub(linenr, ":", "")
        table.insert(words, {
            id = zk_id,
            linenr = linenr,
            context = get_context(all_ids, zk_id),
            file_name = file_name,
        })
    end

    return words
end

function M.show_references(cword, use_loclist)
    use_loclist = use_loclist or false
    local references = M.get_references(cword)
    local lines = {}
    for _, ref in ipairs(references) do
        local line = {}
        table.insert(line, ref.file_name)
        table.insert(line, ":")
        table.insert(line, ref.linenr)
        table.insert(line, ": ")
        table.insert(line, ref.context)

        table.insert(lines, table.concat(line, ""))
    end

    set_qflist(
        {},
        " ",
        vim.api.nvim_get_current_buf(),
        use_loclist,
        { title = "[[" .. cword .. "]] References", lines = lines }
    )
end

function M.setup(opts)
    opts = opts or {}
    opts.notes_path = opts.notes_path or ""

    config._set(opts)
end

return M
