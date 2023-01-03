local M = {}

local function split_id(id)
    id = string.gsub(id, "%..*", "")
    local parts = {}
    local i = 0
    local j = 0
    local k = 1
    local len = string.len(id)
    i, j = string.find(id, "%a+")
    while j ~= nil do
        if k <= i - 1 then
            table.insert(parts, string.sub(id, k, i - 1))
        end
        table.insert(parts, string.sub(id, i, j))
        k = j + 1
        i, j = string.find(id, "%a+", k)
    end
    if k <= len then
        table.insert(parts, string.sub(id, k))
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

local function compare_id_parts(id1_parts, id2_parts)
    local len1 = #id1_parts
    local len2 = #id2_parts
    local len_min = math.min(len1, len2)
    local comp = 0
    for i = 1, len_min do
        comp = compareParts(id1_parts[i], id2_parts[i])
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

local function split_and_sort_ids(ids)
    local id_parts = {}
    for _, id in pairs(ids) do
        table.insert(id_parts, split_id(id))
    end
    table.sort(id_parts, compare_id_parts)
    return id_parts
end

local function find_next_id(split_ids, id)
    local id_parts = split_id(id)
    local len = #id_parts

    if len == 0 or string.find(id_parts[len], "%a") ~= nil then
        table.insert(id_parts, "1")
    else
        table.insert(id_parts, "a")
    end

    for i = 1, #split_ids do
        local fparts = split_ids[i]
        local lengths_match = #fparts >= len + 1
        local parts_match = true
        for j = 1, (len + 1) do
            if fparts[j] ~= id_parts[j] then
                parts_match = false
                break
            end
        end
        if lengths_match and parts_match and fparts[len + 1] == id_parts[len + 1] then
            id_parts[len + 1] = incPart(id_parts[len + 1])
        end
    end

    return table.concat(id_parts, "")
end

function M.sort_ids(ids)
    local id_parts = split_and_sort_ids(ids)
    local new_ids = {}
    for _, id in pairs(id_parts) do
        table.insert(new_ids, table.concat(id, ""))
    end
    return new_ids
end

function M.generate_note_id(ids, parent_id)
    local split_ids = split_and_sort_ids(ids)
    return find_next_id(split_ids, parent_id)
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

    print("Begin ids")
    local ids = {
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
    print(vim.inspect(ids))

    print("Begin sort")
    local sorted_ids = M.sort_ids(ids)

    print(vim.inspect(sorted_ids))

    print("Begin next id")
    sorted_ids = { "1", "2", "3a", "3b", "3c", "4a1", "4a2", "4a3" }
    print(assert(M.generate_note_id(sorted_ids, ""), "5"))
    print(assert(M.generate_note_id(sorted_ids, "1"), "1a"))
    print(assert(M.generate_note_id(sorted_ids, "1a"), "1a1"))
    print(assert(M.generate_note_id(sorted_ids, "3"), "3d"))
    print(assert(M.generate_note_id(sorted_ids, "4"), "4b"))
    print(assert(M.generate_note_id(sorted_ids, "4a"), "4a4"))
    print(assert(M.generate_note_id(sorted_ids, "4a1"), "4a1a"))
end

return M
