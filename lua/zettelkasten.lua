local M = {}
local api = vim.api
local log_levels = vim.log.levels
local log = require("zettelkasten.log")
local config = require("zettelkasten.config")
local formatter = require("zettelkasten.formatter")

local s_zk_id_pattern = "%d+-%d+-%d+-%d+-%d+-%d+"
local s_zk_id_regexp = "[0-9]+-[0-9]+-[0-9]+-[0-9]+-[0-9]+-[0-9]+"
local s_zk_file_name_pattern = "%d+-%d+-%d+-%d+-%d+-%d+.md"

local function get_grepprg()
    local grepprg = vim.opt_local.grepprg:get()
    if #grepprg == 0 then
        grepprg = vim.opt.grepprg:get()
    end

    local cmd = vim.split(grepprg, " ")

    -- We want to control what parameters are passed in.
    if #cmd > 1 then
        grepprg = cmd[1]
    end

    return grepprg
end

local function get_rg_cmd(search_pattern, search_file)
    local cmd = {
        "rg",
        search_pattern,
        "--line-number",
        "--color",
        "never",
        "--no-heading",
        "--sort",
        "path",
    }

    if search_file and #search_file > 0 then
        table.insert(cmd, search_file)
    end

    return cmd
end

local function get_grep_cmd(search_pattern, search_file)
    local grepprg = get_grepprg()
    if grepprg == "rg" then
        return get_rg_cmd(search_pattern, search_file)
    end

    local cmd = {
        grepprg,
        "-E",
        search_pattern,
    }

    if search_file and #search_file > 0 then
        table.insert(cmd, search_file)
    else
        table.insert(cmd, "./")
        table.insert(cmd, "-R")
    end

    table.insert(cmd, "--line-number")
    table.insert(cmd, "-I")
    table.insert(cmd, "--exclude-dir")
    table.insert(cmd, ".git")

    return cmd
end

local function run_grep(search_pattern, search_file, extra_args)
    extra_args = extra_args or {}
    local args = get_grep_cmd(search_pattern, search_file)
    if extra_args then
        for _, arg in pairs(extra_args) do
            table.insert(args, arg)
        end
    end

    local output = {}
    local job_id = vim.fn.jobstart(args, {
        on_exit = function(job_id, exit_code, _)
            if exit_code ~= 0 then
                output = {}
            end
        end,
        clear_env = true,
        stdout_buffered = true,
        -- FIXME: See issue #9
        pty = args[1] ~= "grep",
        on_stdout = function(job_id, data)
            output = vim.tbl_filter(function(item)
                return item ~= ""
            end, data)
            output = vim.tbl_map(function(item)
                return string.gsub(item, "\r", "")
            end, output)
        end,
    })
    vim.fn.jobwait({ job_id }, 5000)

    return output
end

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

local function get_all_tags(lookup_tag, search_file)
    search_file = search_file or ""
    if lookup_tag == nil or #lookup_tag == 0 or lookup_tag == "*" then
        lookup_tag = "\\w.*"
    else
        lookup_tag = string.gsub(lookup_tag, "\\<", "")
        lookup_tag = string.gsub(lookup_tag, "\\>", "")
    end

    local references = run_grep("#" .. lookup_tag, search_file)
    local tags = {}

    for _, word in ipairs(references) do
        local linenr_pattern = ":(%d+):"
        local file_name = ""
        if #search_file > 0 then
            file_name = search_file
            linenr_pattern = "(%d+):"
        else
            file_name = string.match(word, ".*%a:")
            file_name = string.gsub(file_name, ":$", "")
        end

        local linenr = string.match(word, linenr_pattern)
        linenr = string.gsub(linenr, ":", "")
        local regex = vim.regex("#\\k.*")
        local names = vim.split(word, " ")
        for _, tn in ipairs(names) do
            local match = regex:match_str(tn)
            if match then
                local tag_name = tn:sub(regex:match_str(tn))
                if tag_name then
                    tag_name = string.gsub(tag_name, "^:", "")
                    table.insert(tags, {
                        file_name = file_name,
                        linenr = linenr,
                        tag_name = tag_name,
                    })
                end
            end
        end
    end

    return tags
end

local function get_all_ids(base)
    local search_str = ""
    if base and #base > 0 then
        if #base >= 1 and tonumber(string.sub(base, 1, 2)) ~= nil then
            search_str = base
        else
            search_str = s_zk_id_regexp .. " " .. base
        end
    else
        search_str = s_zk_id_regexp
    end

    local references = run_grep("# " .. search_str)

    local words = {}
    for _, word in ipairs(references) do
        local zk_id = string.match(word, s_zk_id_pattern)
        if zk_id == nil then
            log.notify("Cannot find the ID.", log_levels.DEBUG, { tag = true })
        else
            local file_name = string.match(word, s_zk_file_name_pattern)
            local context = string.match(word, "# " .. s_zk_id_pattern .. " .*")
            context = string.gsub(context, " " .. s_zk_id_pattern, "")
            if word ~= base then
                table.insert(words, { id = zk_id, context = context, file_name = file_name })
            end
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

local function generate_note_id()
    return vim.fn.strftime("%Y-%m-%d-%H-%M-%S")
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
    local pattern_provided = pattern ~= "\\<\\k\\k" or pattern == "*"
    local all_tags = {}
    if pattern_provided then
        all_tags = get_all_tags(pattern)
    else
        all_tags = get_all_tags(nil)
    end

    local tags = {}
    for _, tag in ipairs(all_tags) do
        table.insert(tags, {
            name = string.gsub(tag.tag_name, "#", ""),
            filename = tag.file_name,
            cmd = tag.linenr,
            kind = "zettelkasten",
        })
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

function M.get_references(note_id, all_ids)
    local references = run_grep("[[" .. note_id .. "]]", nil, { "-F" })

    local words = {}
    for _, word in ipairs(references) do
        local zk_id = string.match(word, s_zk_id_pattern)
        if zk_id == nil then
            log.notify("Cannot find the ID.", log_levels.DEBUG, { tag = true })
        else
            local file_name = string.match(word, s_zk_file_name_pattern)
            if file_name == nil then
                log.notify(
                    "Cannot capture the file name: " .. word,
                    log_levels.DEBUG,
                    { tag = true }
                )
            else
                local linenr = string.match(word, ":(%d+):", #file_name)
                linenr = string.gsub(linenr, ":", "")
                table.insert(words, {
                    id = zk_id,
                    linenr = linenr,
                    context = get_context(all_ids, zk_id),
                    file_name = file_name,
                })
            end
        end
    end

    return words
end

function M.show_references(cword, use_loclist)
    use_loclist = use_loclist or false
    local all_ids = get_all_ids()
    local references = M.get_references(cword, all_ids)
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

function M.get_note_browser_content()
    local all_ids = get_all_ids()
    local lines = {}
    for _, note in ipairs(all_ids) do
        table.insert(lines, {
            file_name = note.file_name,
            references = M.get_references(note.id, all_ids),
            tags = get_all_tags("*", note.file_name),
            title = note.context,
        })
    end

    return formatter.format(lines, config.get().browseformat)
end

function M.add_hover_command(bufnr)
    vim.api.nvim_buf_add_user_command(bufnr, "ZkHover", function(opts)
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

        local lines = M.keyword_expr(cword, {
            preview_note = vim.tbl_contains(args, "-preview"),
            return_lines = vim.tbl_contains(args, "-return-lines"),
        })
        vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO, {})
    end, {
        nargs = "+",
    })
end

function M.setup(opts)
    opts = opts or {}
    opts.notes_path = opts.notes_path or ""

    config._set(opts)
end

return M
