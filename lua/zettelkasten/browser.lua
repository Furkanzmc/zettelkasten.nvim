local M = {}
local fn = vim.fn

local config = require("zettelkasten.config")

local s_note_cache_with_file_path = {}
local s_note_cache_with_id = {}

local function get_files(folder, filename_pattern)
    local files = fn.split(fn.globpath(folder, "*.md"), "\\n")
    files = vim.tbl_filter(function(file)
        return string.match(file, filename_pattern) ~= nil
    end, files)

    return files
end

--- @param line string
--- @param file_path string
--- @param title_pattern string
--- @param id_pattern string
--- @param id_inference_location number
--- @return table
local function extract_id_and_title(
    line,
    file_path,
    title_pattern,
    id_pattern,
    id_inference_location
)
    local title = nil
    local note_id = nil
    if id_inference_location == config.TITLE then
        local zk_id = string.match(line, title_pattern)
        zk_id = string.gsub(zk_id, "# ", "")

        note_id = string.match(zk_id, id_pattern)
        title = vim.trim(string.gsub(zk_id, id_pattern, ""))
    elseif id_inference_location == config.FILENAME then
        note_id = string.match(vim.fn.fnamemodify(file_path, ":t:r"), id_pattern)
        title = vim.trim(string.gsub(line, "# ", ""))
    end

    return { id = note_id, title = string.gsub(title, "\r", "") }
end

local function extract_references(line, linenr, id_pattern)
    assert(line ~= nil)

    local references = {}
    for ref in string.gmatch(line, "(%[%[" .. id_pattern .. "%]%])") do
        ref = string.gsub(ref, "%[%[", "")
        ref = string.gsub(ref, "%]%]", "")
        table.insert(references, { id = ref, linenr = linenr })
    end

    return references
end

local function extract_back_references(notes, note_id)
    assert(note_id ~= nil)

    local back_references = {}
    for _, note in ipairs(notes) do
        if note.id == note_id then
            goto continue
        end

        local references = note.references
        for _, ref in ipairs(references) do
            if ref.id == note_id then
                table.insert(back_references, {
                    id = note.id,
                    title = note.title,
                    file_name = note.file_name,
                    linenr = ref.linenr,
                })

                break
            end
        end

        ::continue::
    end

    return back_references
end

local function extract_tags(line, linenr)
    assert(line ~= nil)

    local tags = {}
    for tag in string.gmatch(line, "(%#%a[%w-_]+)") do
        local start_pos, _ = string.find(line, tag, 1, true)
        local previous_char = string.sub(line, start_pos - 1, start_pos - 1)
        if previous_char == "" or previous_char == " " then
            table.insert(tags, { linenr = linenr, name = tag })
        end
    end

    return tags
end

local function get_note_information(file_path, id_config)
    id_config = id_config or { title_pattern = "", id_pattern = "", id_inference_location = -1 }
    local last_modified = fn.strftime("%Y-%m-%d.%H:%M:%S", fn.getftime(file_path))
    if
        s_note_cache_with_file_path[file_path] ~= nil
        and s_note_cache_with_file_path[file_path].last_modified == last_modified
    then
        return s_note_cache_with_file_path[file_path]
    end

    local file = io.open(file_path, "r")
    if file:read(0) == nil then
        return nil
    end

    local info = {
        file_name = file_path,
        last_modified = last_modified,
        tags = {},
        references = {},
        back_references = {},
    }

    local linenr = 0
    while true do
        linenr = linenr + 1
        local line = file:read("*line")
        if line == nil then
            break
        end

        if line == "" then
            goto continue
        end

        if info.id == nil and string.starts_with(line, "#") then
            local id_title = extract_id_and_title(
                line,
                file_path,
                id_config.title_pattern,
                id_config.id_pattern,
                id_config.id_inference_location
            )
            if id_title then
                info = vim.tbl_extend("error", info, id_title)
                goto continue
            end
        end

        local refs = extract_references(line, linenr, id_config.id_pattern)
        if refs then
            vim.list_extend(info.references, refs)
        end

        local tags = extract_tags(line, linenr)
        if tags then
            vim.list_extend(info.tags, tags)
        end

        ::continue::
    end

    s_note_cache_with_file_path[file_path] = info
    s_note_cache_with_id[info.id] = info
    return info
end

function M.get_note(id)
    if s_note_cache_with_id[id] ~= nil then
        return s_note_cache_with_id[id]
    end

    local _ = M.get_notes()

    if s_note_cache_with_id[id] ~= nil then
        return s_note_cache_with_id[id]
    end

    return nil
end

function M.get_notes()
    local cfg = config.get()
    local folder = cfg.notes_path
    if fn.isdirectory(folder) == 0 then
        return {}
    end

    local files = get_files(folder, cfg.filename_pattern)
    local all_notes = {}
    for _, file in ipairs(files) do
        table.insert(
            all_notes,
            get_note_information(file, {
                id_pattern = cfg.id_pattern,
                title_pattern = cfg.title_pattern,
                id_inference_location = cfg.id_inference_location,
            })
        )
    end

    for _, note in ipairs(all_notes) do
        if note.id == nil then
            goto continue
        end

        local back_references = extract_back_references(all_notes, note.id)
        if back_references then
            -- When notes are cached, `back_references` field will have the references from before.
            -- Since the files that refer to this one might have changed, we'll overwrite it here.
            -- extract_back_references() already re-processes the references.
            note.back_references = back_references
        end

        ::continue::
    end

    return all_notes
end

function M.get_tags()
    local notes = M.get_notes()
    local tags = {}
    for _, note in ipairs(notes) do
        if #note.tags == 0 then
            goto continue
        end

        for _, tag in ipairs(note.tags) do
            table.insert(tags, {
                linenr = tag.linenr,
                name = tag.name,
                file_name = note.file_name,
            })
        end

        ::continue::
    end

    return tags
end

return M
