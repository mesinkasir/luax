
local json = {}

function json.decode(str)
    local pos = 1
    local function skip()
        while pos <= #str and str:sub(pos,pos):match("%s") do pos = pos + 1 end
    end
    local function parse_value()
        skip()
        local c = str:sub(pos,pos)
        if c == "{" then
            pos = pos + 1
            local obj = {}
            skip()
            if str:sub(pos,pos) == "}" then pos = pos + 1 return obj end
            while true do
                skip()
                if str:sub(pos,pos) ~= '"' then error("expected key") end
                local key = parse_value()
                skip()
                if str:sub(pos,pos) ~= ":" then error("expected :") end
                pos = pos + 1
                local val = parse_value()
                obj[key] = val
                skip()
                local d = str:sub(pos,pos)
                if d == "}" then pos = pos + 1 break
                elseif d == "," then pos = pos + 1
                else error("expected , or } at "..pos) end
            end
            return obj
        elseif c == "[" then
            pos = pos + 1
            local arr = {}
            skip()
            if str:sub(pos,pos) == "]" then pos = pos + 1 return arr end
            while true do
                local val = parse_value()
                table.insert(arr, val)
                skip()
                local d = str:sub(pos,pos)
                if d == "]" then pos = pos + 1 break
                elseif d == "," then pos = pos + 1
                else error("expected , or ]") end
            end
            return arr
        elseif c == '"' then
            pos = pos + 1
            local s = ""
            while pos <= #str do
                local ch = str:sub(pos,pos)
                if ch == '"' then pos = pos + 1 break
                elseif ch == "\\" then
                    local esc = str:sub(pos+1,pos+1)
                    if esc == "n" then s = s .. "\n"
                    elseif esc == "r" then s = s .. "\r"
                    elseif esc == "t" then s = s .. "\t"
                    elseif esc == '"' then s = s .. '"'
                    elseif esc == "\\" then s = s .. "\\"
                    elseif esc == "/" then s = s .. "/"
                    else s = s .. esc end
                    pos = pos + 2
                else
                    s = s .. ch
                    pos = pos + 1
                end
            end
            return s
        elseif str:sub(pos,pos+3) == "true" then pos = pos + 4 return true
        elseif str:sub(pos,pos+4) == "false" then pos = pos + 5 return false
        elseif str:sub(pos,pos+3) == "null" then pos = pos + 4 return nil
        else
            local num = str:match("^-?%d+%.?%d*[eE]?[+-]?%d*", pos)
            if num and #num > 0 then pos = pos + #num return tonumber(num) end
            error("unexpected at "..pos.." char "..c)
        end
    end
    return parse_value()
end

return json
