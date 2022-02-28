local M = {}
local s_formatters = {
    ["%r"] = function(line)
        return #line.references
    end,
    ["%f"] = function(line)
        return line.file_name
    end,
    ["%h"] = function(line)
        return line.title
    end,
    ["%t"] = function(line)
        local tags = {}
        for _, tag in ipairs(line.tags) do
            table.insert(tags, tag.tag_name)
        end

        return table.concat(tags, " ")
    end,
}

local function get_format_keys(format)
    local matches = {}
    for w in string.gmatch(format, "%%%a") do
        table.insert(matches, w)
    end

    return matches
end

function M.format(lines, format)
    local formatted_lines = {}
    local modifiers = get_format_keys(format)
    for _, line in ipairs(lines) do
        local cmps = format
        for _, modifier in ipairs(modifiers) do
            cmps = string.gsub(cmps, "%" .. modifier, s_formatters[modifier](line))
        end

        table.insert(formatted_lines, cmps)
    end

    return formatted_lines
end

return M
