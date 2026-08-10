local yaml = {}

function yaml.parse(content)
    content = content:gsub("^%z", "")
    content = content:gsub("\r\n", "\n")
    local data = {}
    local stack = { data }
    local indent_stack = { -1 }

    local lines = {}
    for line in content:gmatch("[^\n]+") do
        if not line:match("^%s*#") and line:match("%S") then
            table.insert(lines, line)
        end
    end

    local i = 1
    while i <= #lines do
        local line = lines[i]
        local indent = #(line:match("^%s*") or "")
        local stripped = line:gsub("^%s*", ""):gsub("%s*$", "")

        while #stack > 1 and indent <= indent_stack[#indent_stack] do
            table.remove(stack)
            table.remove(indent_stack)
        end

        if stripped:match("^- ") then
            local value = stripped:gsub("^- ", "")
            value = value:gsub('^"', ''):gsub('"$', '')
            value = value:gsub("^'", ''):gsub("'$", '')

            local target = stack[#stack]
            if not target._list then
                target._list = {}
            end

            local k, v = value:match("^(.-):%s*(.+)$")
            if k and v then
                local item = {}
                k = k:gsub("^%s*(.-)%s*$", "%1")
                v = v:gsub('"', ''):gsub("'", "")
                v = v:gsub("^%s*(.-)%s*$", "%1")
                item[k] = v

                if i + 1 <= #lines then
                    local next_line = lines[i + 1]
                    local next_indent = #(next_line:match("^%s*") or "")
                    if next_indent > indent then
                        table.insert(stack, item)
                        table.insert(indent_stack, indent)
                    end
                end

                table.insert(target._list, item)
            else
                local sub_k = value:match("^(.-):%s*$")
                if sub_k then
                    local item = {}
                    local inner = {}
                    sub_k = sub_k:gsub("^%s*(.-)%s*$", "%1")
                    item[sub_k] = inner
                    table.insert(target._list, item)
                    table.insert(stack, item)
                    table.insert(indent_stack, indent)
                    table.insert(stack, inner)
                    table.insert(indent_stack, indent + 1)
                else
                    table.insert(target._list, value)
                end
            end

            i = i + 1
            goto continue
        end

                local key, value = stripped:match("^([^:]+):%s*(.*)$")
        if key then
            key = key:gsub("^%s*(.-)%s*$", "%1")
            value = value:gsub('^"', ''):gsub('"$', '')
            value = value:gsub("^'", ''):gsub("'$", '')

            local target = stack[#stack]

            if i + 1 <= #lines then
                local next_line = lines[i + 1]
                local next_indent = #(next_line:match("^%s*") or "")
                if next_indent > indent then
                    local new_table = {}
                    target[key] = new_table
                    table.insert(stack, new_table)
                    table.insert(indent_stack, indent)
                else
                    target[key] = value
                end
            else
                target[key] = value
            end

            i = i + 1
            goto continue
        end

        i = i + 1
        ::continue::
    end

    local function convert(t)
        if type(t) ~= "table" then return t end

        if t._list then
            for _, it in ipairs(t._list) do
                convert(it)
            end
        end

        for k, v in pairs(t) do
            if k ~= "_list" and type(v) == "table" then
                convert(v)
                if v._list then
                    local arr = {}
                    for _, item in ipairs(v._list) do
                        table.insert(arr, item)
                    end
                    t[k] = arr
                end
            end
        end

        if t._list and not t._is_list_checked then
        end

        return t
    end

    local function finalize(t)
        if type(t) ~= "table" then return t end
        if t._list then
            local arr = {}
            for _, item in ipairs(t._list) do
                table.insert(arr, finalize(item))
            end
            return arr
        end
        local out = {}
        for k, v in pairs(t) do
            if k ~= "_list" and k ~= "_is_list_checked" then
                out[k] = finalize(v)
            end
        end
        return out
    end

    convert(data)
    return finalize(data)
end

return yaml