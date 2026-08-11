
local Lax = {}
Lax.__index = Lax

local function read_file(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local c = f:read("*all")
    f:close()
    return c
end

local function find_end(str, from)
    local depth = 1
    local pos = from
    while depth > 0 do
        local s_if = str:find("@if%s+", pos)
        local s_for = str:find("@for%s+", pos)
        local s_end = str:find("@end", pos)
        if not s_end then return nil end
        local s_open = s_if and s_for and math.min(s_if, s_for) or s_if or s_for
        if s_open and s_open < s_end then
            depth = depth + 1
            pos = s_open + 1
        else
            depth = depth - 1
            if depth == 0 then return s_end end
            pos = s_end + 4
        end
    end
end

local function split_if_else(inner)
    local depth = 0
    local pos = 1
    while pos <= #inner do
        local s_if = inner:find("@if%s+", pos)
        local s_for = inner:find("@for%s+", pos)
        local s_else = inner:find("@else", pos)
        local s_end = inner:find("@end", pos)
        if not s_else then return nil end
        local min_pos, token = nil, nil
        if s_if and (not min_pos or s_if < min_pos) then min_pos = s_if token = "open" end
        if s_for and (not min_pos or s_for < min_pos) then min_pos = s_for token = "open" end
        if s_else and (not min_pos or s_else < min_pos) then min_pos = s_else token = "else" end
        if s_end and (not min_pos or s_end < min_pos) then min_pos = s_end token = "close" end
        if token == "open" then depth = depth + 1 pos = min_pos + 1
        elseif token == "close" then
            if depth == 0 then return nil end
            depth = depth - 1 pos = min_pos + 4
        elseif token == "else" then
            if depth == 0 then return min_pos end
            pos = min_pos + 5
        else break end
    end
    return nil
end

function Lax.new(template)
    return setmetatable({ template = template or "", context = {}, partials = {} }, Lax)
end
function Lax:set(k, v) self.context[k] = v return self end
function Lax:partial(n, c) self.partials[n] = c return self end
function Lax:resolve_var(path)
    if not path or path == "" then return nil end
    local val = self.context
    for p in path:gmatch("[^%.]+") do
        if type(val) == "table" then val = val[p] else return nil end
    end
    return val
end

function Lax:render()
    local output = self.template or ""
    local layout_name = nil
    output = output:gsub("@layout%((.-)%)", function(n) layout_name = n:gsub('"',''):gsub("'",""):gsub("^%s*(.-)%s*$","%1") return "" end)
    output = output:gsub("@include%((.-)%)", function(n) 
        local name = n:gsub('"',''):gsub("'",""):gsub("^%s*(.-)%s*$","%1") 
        return self.partials[name] or "" 
    end)

    local function render_vars(str, item)
        local s = str
        s = s:gsub("@@", "__AT__ESCAPED__")
        local saved = {}
        local c = 0
        s = s:gsub("<pre>(.-)</pre>", function(inner) c=c+1 local k="__SAVE"..c.."__" saved[k]=inner return "<pre>"..k.."</pre>" end)
        s = s:gsub("<code>(.-)</code>", function(inner) c=c+1 local k="__SAVE"..c.."__" saved[k]=inner return "<code>"..k.."</code>" end)
        local function get_from_item(prop)
            if not item then return nil end
            if type(item) == "table" then
                if prop == "item" then return item.name or item.title or item.slug or item.url or item.item end
                if item[prop] ~= nil and type(item[prop]) ~= "table" then return item[prop] end
                local v = item
                for p in prop:gmatch("[^%.]+") do if type(v) == "table" then v = v[p] else v = nil break end end
                if v ~= nil and type(v) ~= "table" then return v end
            else
                if prop == "item" or prop == "name" or prop == "title" or prop == "slug" or prop == "url" then return tostring(item) end
            end
            return nil
        end
        s = s:gsub("{{%s*([%w_%.]+)%s*}}", function(prop)
            local from_item = get_from_item(prop)
            if from_item ~= nil then return tostring(from_item) end
            local val = self:resolve_var(prop)
            if val ~= nil and type(val) ~= "table" then return tostring(val) end
            return ""
        end)
        s = s:gsub("@([%w_%.]+)", function(prop)
            if prop == "os.date" then return os.date("%Y") end
            local from_item = get_from_item(prop)
            if from_item ~= nil then return tostring(from_item) end
            local val = self:resolve_var(prop)
            if val ~= nil and type(val) ~= "table" then return tostring(val) end
            return ""
        end)
        for k,v in pairs(saved) do s = s:gsub(k, function() return v end) end
        s = s:gsub("__AT__ESCAPED__", "@")
        return s
    end

    local function process(str, parent_item)
        local out = str
        while true do
            local s_if = out:find("@if%s+")
            local s_for = out:find("@for%s+")
            if not s_if and not s_for then break end
            
            local is_if = s_if and (not s_for or s_if < s_for)
            local start_pos = is_if and s_if or s_for
            local line_end = out:find("\n", start_pos) or #out
            local line = out:sub(start_pos, line_end)
            local end_pos = find_end(out, line_end + 1)
            if not end_pos then break end
            local inner = out:sub(line_end + 1, end_pos - 1)
            local repl = ""

            local function get_val(name)
                if not name then return nil end
                name = name:gsub("^%s*(.-)%s*$","%1")
                if parent_item and type(parent_item) == "table" and parent_item[name] ~= nil then return parent_item[name] end
                local val = self:resolve_var(name)
                if val ~= nil then return val end
                if parent_item and type(parent_item) == "table" then
                    local v = parent_item
                    for p in name:gmatch("[^%.]+") do if type(v) == "table" then v = v[p] else v = nil break end end
                    if v ~= nil then return v end
                end
                return nil
            end

            local function is_truthy(v)
                if v == nil or v == "" or v == false then return false end
                if type(v) == "table" then return (#v > 0 or next(v) ~= nil) end
                return true
            end

            local function check_if(cond_raw)
                cond_raw = cond_raw:gsub("@if%s+",""):gsub("\r",""):gsub("^%s*(.-)%s*$","%1")
                if cond_raw == "" then return false end
                if cond_raw:find("%s+or%s+") then
                    for raw in (cond_raw.." or "):gmatch("(.-)%s+or%s+") do
                        local part = raw:gsub("^%s*(.-)%s*$","%1")
                        if part ~= "" then
                            local is_not = part:match("^not%s+")
                            local nm = is_not and part:gsub("^not%s+",""):gsub("^%s*(.-)%s*$","%1") or part
                            local v = get_val(nm)
                            local ok = is_truthy(v)
                            if is_not then ok = not ok end
                            if ok then return true end
                        end
                    end
                    return false
                end
                if cond_raw:find("%s+and%s+") then
                    for raw in (cond_raw.." and "):gmatch("(.-)%s+and%s+") do
                        local part = raw:gsub("^%s*(.-)%s*$","%1")
                        if part ~= "" then
                            local is_not = part:match("^not%s+")
                            local nm = is_not and part:gsub("^not%s+",""):gsub("^%s*(.-)%s*$","%1") or part
                            local v = get_val(nm)
                            local ok = is_truthy(v)
                            if is_not then ok = not ok end
                            if not ok then return false end
                        end
                    end
                    return true
                end
                local is_not = cond_raw:match("^not%s+")
                local nm = is_not and cond_raw:gsub("^not%s+",""):gsub("^%s*(.-)%s*$","%1") or cond_raw
                local v = get_val(nm)
                local ok = is_truthy(v)
                if is_not then ok = not ok end
                return ok
            end

            if is_if then
                local else_pos = split_if_else(inner)
                local if_branch, else_branch
                if else_pos then
                    if_branch = inner:sub(1, else_pos - 1)
                    else_branch = inner:sub(else_pos + 5)
                else
                    if_branch = inner
                    else_branch = ""
                end
                if check_if(line) then repl = process(if_branch, parent_item)
                else repl = process(else_branch, parent_item) end
            else
                local clean = line:gsub("\r",""):gsub("@for%s+",""):gsub("^%s*(.-)%s*$","%1")
                                local limit = tonumber(clean:match("limit%s*[:=]?%s*(%d+)"))
                local without_filter = clean:gsub("%s*|.*$","")
                local without_limit = without_filter:gsub("%s+limit%s*[:=]?%s*%d+.*$",""):gsub("^%s*(.-)%s*$","%1")
                local list_name = without_limit:match(" in ([%w_%.%-]+)") or without_limit:match("^([%w_%.%-]+)")
                if list_name then list_name = list_name:gsub("^%s*(.-)%s*$","%1") end

                local list = nil
                if list_name and list_name ~= "" then
                    list = self:resolve_var(list_name)
                    if list == nil and parent_item and type(parent_item) == "table" then
                        local v = parent_item
                        local ok = true
                        for p in list_name:gmatch("[^%.]+") do
                            if type(v) == "table" and v[p] ~= nil then v = v[p] else ok = false break end
                        end
                        if ok then list = v end
                    end
                end

                if type(list) == "table" then
                    local function is_array(t)
                        if #t > 0 then return true end
                        for k,_ in pairs(t) do if type(k)=="number" then return true end end
                        return false
                    end
                    local arr = {}
                    if is_array(list) then
                        arr = list
                    else
                        -- single map object like mission.card -> treat as 1 item
                        arr = { list }
                    end
                    local max = limit and math.min(limit, #arr) or #arr
                    for idx=1,max do
                        if arr[idx] then
                            repl = repl.. process(inner, arr[idx])
                        end
                    end
                end
            end
            out = out:sub(1, start_pos - 1).. repl.. out:sub(end_pos + 4)
        end
        return render_vars(out, parent_item)
    end

    output = process(output, nil)
    if layout_name then
        local paths = { "templates/layouts/"..layout_name, "templates/layouts/"..layout_name..".lax" }
        local layout = nil
        for _, p in ipairs(paths) do layout = read_file(p) if layout then break end end
        if layout then
            local eng = Lax.new(layout)
            for k, v in pairs(self.context) do eng:set(k, v) end
            eng:set("content", output)
            for n, c in pairs(self.partials) do eng:partial(n, c) end
            return eng:render()
        end
    end
    return output
end
return Lax
