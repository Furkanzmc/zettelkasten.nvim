local M = {}

local function split_name(name)
    name = string.gsub(name, "%..*", "")
    local parts = {}
    local i = 0
    local j = 0
    local k = 1
    local len = string.len(name)
    i, j = string.find(name, "%a+")
    while j ~= nil do
        if k <= i - 1 then
            table.insert(parts, string.sub(name, k, i - 1))
        end
        table.insert(parts, string.sub(name, i, j))
        k = j + 1
        i, j = string.find(name, "%a+", k)
    end
    if k <= len then
        table.insert(parts, string.sub(name, k))
    end
    return parts
end

local function incPart(part)
    local code = string.byte(part, -1)
    if code < 123 and code > 96 then
        local result = {}
        local len = string.len(part)
        local inc = true
        for j = 1, len do
            code = string.byte(part, -j)
            if inc then
                code = code + 1
            end
            if code == 123 then
                code = 97
                inc = true
            else
                inc = false
            end
            table.insert(result, string.char(code))
        end
        if inc then
            table.insert(result, "a")
        end
        return string.reverse(table.concat(result, ""))
    else
        return tostring(tonumber(part) + 1)
    end
end

local function compareParts(part1, part2)
    local len1 = string.len(part1)
    local len2 = string.len(part2)
    if len1 < len2 then
        return -1
    elseif len1 > len2 then
        return 1
    end
    for i = 1, len1 do
        if string.sub(part1, i, i) < string.sub(part2, i, i) then
            return -1
        elseif string.sub(part1, i, i) > string.sub(part2, i, i) then
            return 1
        end
    end
    return 0
end

local function compare_name_parts(name1_parts, name2_parts)
    local len1 = #name1_parts
    local len2 = #name2_parts
    local len_min = math.min(len1, len2)
    local comp = 0
    for i = 1, len_min do
        comp = compareParts(name1_parts[i], name2_parts[i])
        if comp < 0 then
            return true
        elseif comp > 0 then
            return false
        end
    end
    if len1 < len2 then
        return true
    elseif len1 > len2 then
        return false
    else
        return false
    end
end

local function split_and_sort_names(names)
    local name_parts = {}
    for _, name in pairs(names) do
        table.insert(name_parts, split_name(name))
    end
    table.sort(name_parts, compare_name_parts)
    return name_parts
end

local function find_next_name(split_names, name)
    local name_parts = split_name(name)
    local len = #name_parts

    if len == 0 or string.find(name_parts[len], "%a") ~= nil then
        table.insert(name_parts, "1")
    else
        table.insert(name_parts, "a")
    end

    for i = 1, #split_names do
        local fparts = split_names[i]
        local lengths_match = #fparts >= len + 1
        local parts_match = true
        for j = 1, (len + 1) do
            if fparts[j] ~= name_parts[j] then
                parts_match = false
                break
            end
        end
        if lengths_match and parts_match and fparts[len + 1] == name_parts[len + 1] then
            name_parts[len + 1] = incPart(name_parts[len + 1])
        end
    end

    return table.concat(name_parts, "")
end

function M.sort_ids(names)
    local name_parts = split_and_sort_names(names)
    local new_names = {}
    for _, name in pairs(name_parts) do
        table.insert(new_names, table.concat(name, ""))
    end
    return new_names
end

function M.generate_note_id(names, parent_name)
    local split_names = split_and_sort_names(names)
    return find_next_name(split_names, parent_name)
end

function M.test()
    print("Begin incs")
    print(incPart("1"))
    print(incPart("10"))
    print(incPart("9"))
    print(incPart("19"))
    print(incPart("99"))
    print(incPart("b"))
    print(incPart("bb"))
    print(incPart("z"))
    print(incPart("az"))
    print(incPart("zz"))

    print("Begin parse incs")

    print("Begin names")
    local names = {
        "bb",
        "ba",
        "b",
        "a",
        "aa",
        "ab",
        "1",
        "3",
        "2",
        "1a",
        "1b",
        "10",
        "10a",
        "10b",
        "1a2",
        "1a1",
    }
    print(vim.inspect(names))

    print("Begin sort")
    local sorted_names = M.sort_ids(names)

    print(vim.inspect(sorted_names))

    print("Begin next name")
    sorted_names = { "1", "2", "3a", "3b", "3c", "4a1", "4a2", "4a3" }
    print(assert(M.generate_note_id(sorted_names, ""), "5"))
    print(assert(M.generate_note_id(sorted_names, "1"), "1a"))
    print(assert(M.generate_note_id(sorted_names, "1a"), "1a1"))
    print(assert(M.generate_note_id(sorted_names, "3"), "3d"))
    print(assert(M.generate_note_id(sorted_names, "4"), "4b"))
    print(assert(M.generate_note_id(sorted_names, "4a"), "4a4"))
    print(assert(M.generate_note_id(sorted_names, "4a1"), "4a1a"))
end

return M
