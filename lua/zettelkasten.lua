local M = {}
local api = vim.api
local fn = vim.fn

local log_levels = vim.log.levels
local log = require("zettelkasten.log")
local config = require("zettelkasten.config")
local formatter = require("zettelkasten.formatter")
local browser = require("zettelkasten.browser")

local function _internal_execute_hover_cmd(args)
    if args ~= nil and type(args) == "string" then
        args = vim.split(args, " ", true)
    else
        args = {}
    end

    local cword = ""
    if #args == 1 then
        cword = fn.expand("<cword>")
    else
        cword = args[#args]
    end

    local lines = M.keyword_expr(cword, {
        preview_note = vim.tbl_contains(args, "-preview"),
        return_lines = vim.tbl_contains(args, "-return-lines"),
    })
    if #lines > 0 then
        log.notify(table.concat(lines, "\n"), log_levels.INFO, {})
    end
end

local function set_qflist(lines, action, bufnr, use_loclist, what)
    what = what or {}
    local _, local_efm = pcall(vim.api.nvim_buf_get_option, bufnr, "errorformat")
    what.efm = what.efm or local_efm
    if use_loclist then
        fn.setloclist(bufnr, lines, action, what)
    else
        fn.setqflist(lines, action, what)
    end
end

local function read_note(file_path, line_count)
    local file = io.open(file_path, "r")
    assert(file ~= nil)
    assert(file:read(0) ~= nil)

    if line_count == nil then
        line_count = 0
    end

    local lines = {}
    for line in io.lines(file_path) do
        line, _ = string.gsub(line, "\r", "")
        table.insert(lines, line)
        if line_count > 0 and #lines == line_count then
            break
        end
    end

    return lines
end

local function get_all_tags(lookup_tag)
    if lookup_tag ~= nil and #lookup_tag > 0 then
        lookup_tag = string.gsub(lookup_tag, "\\<", "")
        lookup_tag = string.gsub(lookup_tag, "\\>", "")
    end

    local tags = browser.get_tags()
    if lookup_tag ~= nil and #lookup_tag > 0 then
        tags = vim.tbl_filter(function(tag)
            return string.match(tag.name, lookup_tag) ~= nil
        end, tags)
    end

    return tags
end

local function generate_note_id(parent_id)
    local id_format = config.get().id_format
    local format_type = type(id_format)
    if format_type == "string" then
        return fn.strftime(id_format)
    elseif format_type == "function" then
        return id_format(parent_id)
    else
        log.notify("config.id_format is not a string or function.", log_levels.ERROR, {})
    end
end

function M.completefunc(find_start, base)
    if find_start == 1 and base == "" then
        local pos = api.nvim_win_get_cursor(0)
        local line = api.nvim_get_current_line()
        local line_to_cursor = line:sub(1, pos[2])
        return fn.match(line_to_cursor, "\\k*$")
    end

    local notes = vim.tbl_filter(function(note)
        return string.match(note.title, base)
    end, browser.get_notes())

    local words = {}
    for _, ref in ipairs(notes) do
        table.insert(words, {
            word = ref.id,
            abbr = ref.title,
            dup = 0,
            empty = 0,
            kind = "[zettelkasten]",
            icase = 1,
        })
    end

    return words
end

function M.set_note_id(bufnr, parent_id)
    local first_line = vim.api.nvim_buf_get_lines(bufnr, 0, 1, true)[1]
    local zk_id = generate_note_id(parent_id)
    if #zk_id > 0 then
        first_line, _ = string.gsub(first_line, "# ", "")
        api.nvim_buf_set_lines(bufnr, 0, 1, true, { "# " .. zk_id .. " " .. first_line })
        vim.cmd("file " .. zk_id .. ".md")
    else
        log.notify("There's already a note with the same ID.", log_levels.ERROR, {})
    end
end

function M.tagfunc(pattern, flags, info)
    local in_insert = string.match(flags, "i") ~= nil
    local pattern_provided = pattern ~= "\\<\\k\\k" or pattern == "*"
    local all_tags = {}
    if pattern_provided then
        all_tags = get_all_tags(pattern)
    else
        all_tags = get_all_tags()
    end

    local tags = {}
    for _, tag in ipairs(all_tags) do
        table.insert(tags, {
            name = string.gsub(tag.name, "#", ""),
            filename = tag.file_name,
            cmd = tostring(tag.linenr),
            kind = "zettelkasten",
        })
    end

    if not in_insert then
        local notes = browser.get_notes()
        for _, note in ipairs(notes) do
            if string.find(note.id, pattern, 1, true) or not pattern_provided then
                table.insert(tags, {
                    name = note.id,
                    filename = note.file_name,
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

    local note = browser.get_note(word)
    if note == nil then
        log.notify("Cannot find note.", log_levels.ERROR, {})
        return {}
    end

    local lines = {}
    if opts.preview_note and not opts.return_lines then
        vim.cmd(config.get().preview_command .. " " .. note.file_name)
    elseif opts.preview_note and opts.return_lines then
        vim.list_extend(lines, read_note(note.file_name))
    else
        table.insert(lines, note.title)
    end

    return lines
end

function M.get_back_references(note_id)
    local note = browser.get_note(note_id)
    if note == nil then
        return {}
    end

    local title_cache = {}
    local get_title = function(id)
        if title_cache[id] ~= nil then
            return title_cache[id]
        end

        title_cache[id] = browser.get_note(id).title
        return title_cache[id]
    end

    local references = {}
    for _, back_reference in ipairs(note.back_references) do
        table.insert(references, {
            id = back_reference.id,
            linenr = back_reference.linenr,
            title = back_reference.title,
            file_name = back_reference.file_name,
        })
    end

    return references
end

function M.show_back_references(cword, use_loclist)
    use_loclist = use_loclist or false
    local references = M.get_back_references(cword)
    if #references == 0 then
        log.notify("No back references found.", log_levels.ERROR, {})
        return
    end

    local lines = {}
    for _, ref in ipairs(references) do
        local line = {}
        table.insert(line, fn.fnamemodify(ref.file_name, ":."))
        table.insert(line, ":")
        table.insert(line, ref.linenr)
        table.insert(line, ": ")
        table.insert(line, ref.title)

        table.insert(lines, table.concat(line, ""))
    end

    set_qflist(
        {},
        " ",
        vim.api.nvim_get_current_buf(),
        use_loclist,
        { title = "[[" .. cword .. "]] References", lines = lines }
    )

    if use_loclist then
        vim.cmd([[botright lopen | wincmd p]])
    else
        vim.cmd([[botright copen | wincmd p]])
    end
end

function M.get_toc(note_id, format)
    format = format or "- [%h](%d)"
    local references = M.get_back_references(note_id)
    local lines = {}
    for _, note in ipairs(references) do
        table.insert(lines, {
            file_name = note.file_name,
            id = note.id,
            title = note.title,
        })
    end

    return formatter.format(lines, format)
end

function M.get_note_browser_content()
    if config.get().notes_path == "" then
        log.notify("'notes_path' option is required for note browsing.", log_levels.WARN, {})
        return {}
    end

    local all_notes = browser.get_notes()
    local lines = {}
    for _, note in ipairs(all_notes) do
        table.insert(lines, {
            file_name = note.file_name,
            id = note.id,
            references = note.references,
            back_references = note.back_references,
            tags = note.tags,
            title = note.title,
        })
    end

    return formatter.format(lines, config.get().browseformat)
end

function M.add_hover_command(bufnr)
    if fn.exists(":ZkHover") == 2 then
        return
    end

    api.nvim_buf_create_user_command(bufnr, "ZkHover", function(opts)
        _internal_execute_hover_cmd(opts.args)
    end, { nargs = "?" })
end

function M.contains(filename)
    local notes_path = config.get().notes_path
    if notes_path == "" then
        log.notify(
            "'notes_path' option is required for checking note location.",
            log_levels.WARN,
            {}
        )
        return false
    end
    local file_path = vim.fn.resolve(vim.fs.normalize(filename))
    notes_path = vim.fn.resolve(vim.fs.normalize(notes_path))

    for dir in vim.fs.parents(file_path) do
        if dir == notes_path then
            return true
        end
    end
    return false
end

function M.setup(opts)
    opts = opts or {}
    opts.notes_path = opts.notes_path or ""

    config._set(opts)
end

return M
