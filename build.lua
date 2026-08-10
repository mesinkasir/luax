local c = {
    reset = "\27[0m",
    bold = "\27[1m",
    green = "\27[32m",
    blue = "\27[34m",
    cyan = "\27[36m",
    dim = "\27[2m",
    magenta = "\27[35m",
    yellow = "\27[33m",
    red = "\27[31m"
}

print(c.bold..c.magenta.."🚀 LUAX SSG v1.2.7 FIXED"..c.reset)
print(c.dim.."▶ LAX + Eleventy Style Collections Anywhere"..c.reset.."\n")

local Lax = dofile("lax.lua")
local yaml = dofile("yaml.lua")

local function read_file(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local content = f:read("*all")
    f:close()
    return content
end

local function write_file(path, content)
    if not path or path == "" then return end
    if not content then return end
    local f = io.open(path, "w")
    if not f then return end
    f:write(content)
    f:close()
end

local function list_files(dir)
    local files = {}
    local is_win = package.config:sub(1,1) == "\\"
    local cmd
    if is_win then
        local d = dir:gsub("/", "\\")
        cmd = 'dir "'..d..'" /b /a 2>nul'
    else
        cmd = 'ls -1 "'..dir..'" 2>/dev/null'
    end
    local handle = io.popen(cmd)
    if handle then
        for file in handle:lines() do table.insert(files, file) end
        handle:close()
    end
    return files
end

local function is_dir(path)
    local is_win = package.config:sub(1,1) == "\\"
    local p = path:gsub("/", "\\")
    local cmd = is_win and 'if exist "'..p..'\\*" (echo 1) else (echo 0)' or 'test -d "'..path..'" && echo 1 || echo 0'
    local handle = io.popen(cmd)
    if handle then
        local result = handle:read("*all"):gsub("\n", ""):gsub("\r","")
        handle:close()
        return result:find("1") ~= nil
    end
    return false
end

local function mkdir_p(path)
    if package.config:sub(1,1) == "\\" then
        os.execute('mkdir "'..path:gsub("/", "\\")..'" 2>nul')
    else
        os.execute('mkdir -p "'..path..'" 2>/dev/null')
    end
end

local function copy_public()
    local public_dir = "public"
    if not is_dir(public_dir) then return end
    if package.config:sub(1,1) == "\\" then
        os.execute('xcopy "'..public_dir..'" "dist\\" /E /I /Y >nul 2>nul')
    else
        os.execute('cp -r "'..public_dir..'"/* "dist/" 2>/dev/null')
    end
    print(c.green.."✔"..c.reset.." Public assets copied")
end

local function load_yaml_file(path)
    local content = read_file(path)
    if not content then return nil end
    return yaml.parse(content)
end

local function is_array(t)
    if type(t) ~= "table" then return false end
    if #t > 0 then return true end
    for k,_ in pairs(t) do
        if type(k) == "number" then return true end
    end
    return false
end

local function load_data_folder()
    local all = {}
    local files = list_files("data")
    if not files then return all end
    for _, f in ipairs(files) do
        if f:match("%.yaml$") or f:match("%.yml$") or f:match("%.json$") then
            local name = f:gsub("%.yaml$",""):gsub("%.yml$",""):gsub("%.json$","")
            local data = load_yaml_file("data/"..f)
            if data then
                all[name] = data
                local function flatten(t, prefix)
                    for k, v in pairs(t) do
                        local key = prefix and (prefix.."."..k) or k
                        if type(v) == "table" and not is_array(v) then
                            flatten(v, key)
                        else
                            all[key] = v
                        end
                    end
                end
                flatten(data, name)
                
                if name == "metadata" or name == "home" or name == "index" or name == "site" then
                    all.metadata = data
                    all.site = data
                    for k, v in pairs(data) do
                        all[k] = v
                        if type(v) == "table" and not is_array(v) then
                            flatten(v, k)
                        else
                            all[k] = v
                        end
                    end
                end
                
                for k,v in pairs(data) do
                    if all[k] == nil then
                        all[k] = v
                    end
                
                    if type(v) == "table" and not is_array(v) then
                        flatten(v, k)
                    end
                end
            end
        end
    end
    return all
end

local function parse_tags(tags)
    if not tags then return {} end
    if type(tags) == "table" then
        local r = {}
        for _, t in ipairs(tags) do
            if type(t) == "string" then
                local c = t:gsub("^%s*(.-)%s*$","%1"):gsub('^["\'](.*)["\']$','%1')
                if c ~= "" then table.insert(r, c) end
            end
        end
        if #r==0 then for _,v in pairs(tags) do if type(v)=="string" and v~="" then table.insert(r,v) end end end
        return r
    end
    if type(tags) == "string" then
        local s = tags:gsub("^%[",""):gsub("%]$","")
        local r = {}
        for part in s:gmatch("[^,\n]+") do
            local c = part:gsub("^%s*(.-)%s*$","%1"):gsub("^%-%s*",""):gsub('^["\'](.*)["\']$','%1'):gsub("^%s*(.-)%s*$","%1")
            if c~="" then table.insert(r,c) end
        end
        return r
    end
    return {}
end

local function parse_markdown(content)
    local html = content
    local frontmatter = {}
    local lines = {}
    local toc = {}
    local footnotes = {}
    local footnote_order = {}

    for line in html:gmatch("[^\n]+") do
        table.insert(lines, line)
    end

    if #lines > 0 and lines[1] == "---" then
        local end_idx = nil
        for i = 2, #lines do
            if lines[i] == "---" then
                end_idx = i
                break
            end
        end
        if end_idx then
            local fm_raw = table.concat(lines, "\n", 2, end_idx-1)
            frontmatter = yaml.parse(fm_raw) or {}
            local new_lines = {}
            for i = end_idx + 1, #lines do
                table.insert(new_lines, lines[i])
            end
            html = table.concat(new_lines, "\n")
        end
    end

    if frontmatter.tags then
        frontmatter.tags = parse_tags(frontmatter.tags)
    end

    local content_lines = {}
    for line in html:gmatch("[^\n]*") do
        local id, text = line:match("^%[%^([^%]]+)%]:%s*(.+)$")
        if id then
            footnotes[id] = text
        else
            table.insert(content_lines, line)
        end
    end
    html = table.concat(content_lines, "\n")

    local result = {}
    local in_code = false
    local in_pre = false 
    local code_block = {}
    local in_list = false
    local list_items = {}
    local in_table = false
    local table_rows = {}

    local function slugify(str)
        return str:lower():gsub("<[^>]+>", ""):gsub("[^%w%s-]", ""):gsub("%s+", "-"):gsub("^-+", ""):gsub("-+$", "")
    end

    local function process_footnote_refs(text)
        return text:gsub("%[%^([^%]]+)%]", function(id)
            if footnotes[id] then
                if not footnote_order[id] then
                    footnote_order[id] = #footnote_order + 1
                end
                return '<sup id="fnref:'..id..'"><a href="#fn:'..id..'" class="footnote-ref">['..id..']</a></sup>'
            end
            return "[^"..id.."]"
        end)
    end

        local in_pre = false
    for line in html:gmatch("[^\n]*") do
        local trimmed_l = line:lower()
        if trimmed_l:find("<pre") then in_pre = true end

        if in_pre then
            table.insert(result, line)
            if trimmed_l:find("</pre>") then in_pre = false end
            goto continue
        end

        local trimmed = line:gsub("^%s*", ""):gsub("%s*$", "")
        if trimmed == "" then
            if in_table and #table_rows > 0 then
                local table_html = "<div class='table-responsive'><table class='table'>\n"
                for r_idx, row in ipairs(table_rows) do
                    if r_idx == 1 then
                        table_html = table_html.. "<thead><tr>"
                        for _, cell in ipairs(row) do
                            table_html = table_html.. "<th>"..cell.."</th>"
                        end
                        table_html = table_html.. "</tr></thead>\n<tbody>\n"
                    else
                        if not (row[1] and row[1]:match("^%-+$")) then
                            table_html = table_html.. "<tr>"
                            for _, cell in ipairs(row) do table_html = table_html.. "<td>"..cell.."</td>" end
                            table_html = table_html.. "</tr>\n"
                        end
                    end
                end
                table_html = table_html.. "</tbody></table></div>"
                table.insert(result, table_html)
                table_rows = {}
                in_table = false
            end
            if in_list and #list_items > 0 then
                table.insert(result, "<ul>"..table.concat(list_items, "\n").."</ul>")
                list_items = {}
                in_list = false
            end
            goto continue
        end

        if trimmed:match("^|.*|$") then
            in_table = true
            local cells = {}
            local inner = trimmed:gsub("^|", ""):gsub("|$", "")
            for cell in inner:gmatch("[^|]+") do
                local c = cell:gsub("^%s*(.-)%s*$","%1")
                c = c:gsub("%*%*(.-)%*%*", "<strong>%1</strong>")
                c = c:gsub("%*(.-)%*", "<em>%1</em>")
                c = c:gsub("`(.-)`", "<code>%1</code>")
                c = process_footnote_refs(c)
                table.insert(cells, c)
            end
            table.insert(table_rows, cells)
            goto continue
        else
            if in_table and #table_rows > 0 then
                local table_html = "<div class='table-responsive'><table class='table'>\n"
                for r_idx, row in ipairs(table_rows) do
                    if r_idx == 1 then
                        table_html = table_html.. "<thead><tr>"
                        for _, cell in ipairs(row) do table_html = table_html.. "<th>"..cell.."</th>" end
                        table_html = table_html.. "</tr></thead>\n<tbody>\n"
                    else
                        if not (row[1] and row[1]:match("^%-+$")) then
                            table_html = table_html.. "<tr>"
                            for _, cell in ipairs(row) do table_html = table_html.. "<td>"..cell.."</td>" end
                            table_html = table_html.. "</tr>\n"
                        end
                    end
                end
                table_html = table_html.. "</tbody></table></div>"
                table.insert(result, table_html)
                table_rows = {}
                in_table = false
            end
        end

        if trimmed:match("^---$") or trimmed:match("^%*%*%*$") or trimmed:match("^___$") then
            if in_list and #list_items > 0 then
                table.insert(result, "<ul>"..table.concat(list_items, "\n").."</ul>")
                list_items = {}
                in_list = false
            end
            table.insert(result, "<hr>")
            goto continue
        end

        if trimmed:match("^```") then
            if not in_code then
                in_code = true
                code_block = {}
            else
                in_code = false
                local code_content = table.concat(code_block, "\n"):gsub("\n$", "")
                table.insert(result, "<pre><code>"..code_content.."</code></pre>")
                code_block = {}
            end
            goto continue
        end

        if in_code then
            table.insert(code_block, line)
            goto continue
        end

        if trimmed:match("^#+%s+") then
            if in_list and #list_items > 0 then
                table.insert(result, "<ul>"..table.concat(list_items, "\n").."</ul>")
                list_items = {}
                in_list = false
            end
            local level = 0
            for char in trimmed:gmatch(".") do if char == "#" then level = level + 1 else break end end
            local text = trimmed:gsub("^#+%s+", "")
            text = process_footnote_refs(text)
            local id = slugify(text)
            table.insert(toc, {level=level, text=text:gsub("<[^>]+>",""), id=id})
            table.insert(result, "<h"..level.." id='"..id.."'>"..text.."</h"..level..">")
            goto continue
        end

        if trimmed:match("^- ") then
            local text = trimmed:gsub("^- ", "")
            text = text:gsub("%*%*(.-)%*%*", "<strong>%1</strong>")
            text = text:gsub("%*(.-)%*", "<em>%1</em>")
            text = text:gsub("`(.-)`", "<code>%1</code>")
            text = text:gsub("%[(.-)%]%((.-)%)", '<a href="%2">%1</a>')
            text = process_footnote_refs(text)
            table.insert(list_items, "<li>"..text.."</li>")
            in_list = true
            goto continue
        end

        if in_list and #list_items > 0 then
            table.insert(result, "<ul>"..table.concat(list_items, "\n").."</ul>")
            list_items = {}
            in_list = false
        end

        local text = trimmed
        text = text:gsub("%*%*(.-)%*%*", "<strong>%1</strong>")
        text = text:gsub("%*(.-)%*", "<em>%1</em>")
        text = text:gsub("`(.-)`", "<code>%1</code>")
        text = text:gsub("%[(.-)%]%((.-)%)", '<a href="%2">%1</a>')
        text = process_footnote_refs(text)
        table.insert(result, "<p>"..text.."</p>")

        ::continue::
    end

    if in_table and #table_rows > 0 then
        local table_html = "<div class='table-responsive'><table class='table'>\n"
        for r_idx, row in ipairs(table_rows) do
            if r_idx == 1 then
                table_html = table_html.. "<thead><tr>"
                for _, cell in ipairs(row) do table_html = table_html.. "<th>"..cell.."</th>" end
                table_html = table_html.. "</tr></thead>\n<tbody>\n"
            else
                if not (row[1] and row[1]:match("^%-+$")) then
                    table_html = table_html.. "<tr>"
                    for _, cell in ipairs(row) do table_html = table_html.. "<td>"..cell.."</td>" end
                    table_html = table_html.. "</tr>\n"
                end
            end
        end
        table_html = table_html.. "</tbody></table></div>"
        table.insert(result, table_html)
    end

    if in_list and #list_items > 0 then
        table.insert(result, "<ul>"..table.concat(list_items, "\n").."</ul>")
    end

    if next(footnotes) ~= nil then
        local fn_html = "<div class='footnotes'><hr><ol>"
        local sorted = {}
        for id,_ in pairs(footnotes) do table.insert(sorted, id) end
        table.sort(sorted, function(a,b)
            return (footnote_order[a] or 999) < (footnote_order[b] or 999)
        end)
        for _, id in ipairs(sorted) do
            local txt = footnotes[id]
            txt = txt:gsub("%*%*(.-)%*%*", "<strong>%1</strong>")
            fn_html = fn_html.. "<li id='fn:"..id.."'>"..txt.." <a href='#fnref:"..id.."' class='footnote-backref'>↩</a></li>"
        end
        fn_html = fn_html.. "</ol></div>"
        table.insert(result, fn_html)
    end

    local final_html = table.concat(result, "\n")

    if frontmatter.toc and #toc > 0 then
        local toc_html = "<div class='toc'><h4>Table of Contents</h4>"
        local last_level = 0
        for _, h in ipairs(toc) do
            local level = h.level
            if level > last_level then
                for i = last_level+1, level do
                    if i > 2 then
                        toc_html = toc_html.. "<ul class='toc-ul-"..i.."'>"
                    else
                        if i==2 then toc_html = toc_html.. "<ul class='toc-root'>" end
                        if i>2 then toc_html = toc_html.. "<ul>" end
                    end
                end
            elseif level < last_level then
                for i = level+1, last_level do
                    toc_html = toc_html.. "</li></ul>"
                end
                toc_html = toc_html.. "</li>"
            else
                if last_level > 0 then toc_html = toc_html.. "</li>" end
            end
            toc_html = toc_html.. "<li class='toc-l"..level.."'><a href='#"..h.id.."'>"..h.text.."</a>"
            last_level = level
        end
        for i=2, last_level do
            toc_html = toc_html.. "</li></ul>"
        end
        toc_html = toc_html.. "</div>"
        frontmatter.toc_html = toc_html
        frontmatter.toc_items = toc
    end

    return final_html, frontmatter
end

local function scan_content()
    local all_items = {}
    local collections = {}
    local controllers = {}
    local global_data = load_data_folder()

    local src_files = list_files("src")
    if not src_files then return all_items, collections, controllers, global_data end

    for _, item in ipairs(src_files) do
        local item_path = "src/"..item

        if is_dir(item_path) then
            local collection_name = item
            collections[collection_name] = {}

            local controller_path = "src/"..collection_name..".md"
            local controller_content = read_file(controller_path)

            if controller_content then
                local c_html, fm = parse_markdown(controller_content)
                controllers[collection_name] = {
                    layout = (fm and fm.layout) or "collection.lax",
                    title = (fm and fm.title) or collection_name,
                    description = (fm and fm.description) or "",
                    pagination = tonumber((fm and fm.pagination) or 6) or 6,
                    collection = (fm and fm.collection) or collection_name,
                    frontmatter = fm or {},
                    content = c_html or ""
                }
                if fm then
                    for k, v in pairs(fm) do
                        controllers[collection_name][k] = v
                    end
                end
            else
                controllers[collection_name] = {
                    layout = "collection.lax",
                    title = collection_name,
                    description = "Posts in "..collection_name,
                    pagination = 6,
                    collection = collection_name,
                    frontmatter = {}
                }
            end

            local function scan_folder(folder_path, current_path)
                local full_path = "src/"..folder_path
                local files = list_files(full_path)
                if not files then return end

                for _, file in ipairs(files) do
                    local file_full = full_path.."/"..file

                    if is_dir(file_full) then
                        local sub_path = current_path and (current_path.."/"..file) or file
                        scan_folder(folder_path.."/"..file, sub_path)
                    elseif file:match("%.md$") then
                        local content = read_file(file_full)
                        if content then
                            local html, fm = parse_markdown(content)
                            local slug = file:gsub("%.md$", "")

                            local url_path
                            if slug == "index" then
                                if current_path then
                                    url_path = "/"..collection_name.."/"..current_path.."/"
                                else
                                    url_path = "/"..collection_name.."/"
                                end
                            else
                                if current_path then
                                    url_path = "/"..collection_name.."/"..current_path.."/"..slug.."/"
                                else
                                    url_path = "/"..collection_name.."/"..slug.."/"
                                end
                            end

                            local auto_title = slug:gsub("-", " "):gsub("^%l", string.upper)

                            local item_data = {
                                title = (fm and fm.title) or auto_title,
                                date = (fm and fm.date) or os.date("%Y-%m-%d"),
                                slug = slug,
                                excerpt = (fm and fm.excerpt) or "",
                                description = (fm and fm.description) or "",
                                tags = (fm and fm.tags) or {},
                                author = (fm and fm.author) or (global_data.author or "LUAX Team"),
                                content = html,
                                url = url_path,
                                image = (fm and fm.image) or global_data.image or "",
                                layout = (fm and fm.layout) or "post.lax",
                                collection = collection_name,
                                sub_collection = current_path,
                                frontmatter = fm or {}
                            }

                            if item_data.excerpt == "" then
                                local text = html:gsub("<[^>]+>", "")
                                item_data.excerpt = text:sub(1, 150).."..."
                            end

                            table.insert(all_items, item_data)
                            table.insert(collections[collection_name], item_data)
                        end
                    end
                end
            end

            scan_folder(item, nil)

        elseif item:match("%.md$") then
            local content = read_file("src/"..item)
            if content then
                local html, fm = parse_markdown(content)
                local slug = item:gsub("%.md$", "")

                if slug == "index" then
                    local page = {
                        title = (fm and fm.title) or global_data.title or "Home",
                        date = (fm and fm.date) or os.date("%Y-%m-%d"),
                        slug = "index",
                        excerpt = (fm and fm.excerpt) or "",
                        description = (fm and fm.description) or global_data.description or "",
                        tags = (fm and fm.tags) or {},
                        author = (fm and fm.author) or (global_data.author or "LUAX Team"),
                        content = html,
                        url = "/",
                        image = (fm and fm.image) or global_data.image or "",
                        layout = (fm and fm.layout) or "index.lax",
                        collection = "root",
                        is_home = true,
                        frontmatter = fm or {}
                    }

                    if page.excerpt == "" then
                        local text = html:gsub("<[^>]+>", "")
                        page.excerpt = text:sub(1, 150).."..."
                    end

                    table.insert(all_items, page)
                else
                    local auto_title = slug:gsub("-", " "):gsub("^%l", string.upper)

                    local page = {
                        title = (fm and fm.title) or auto_title,
                        date = (fm and fm.date) or os.date("%Y-%m-%d"),
                        slug = slug,
                        excerpt = (fm and fm.excerpt) or "",
                        description = (fm and fm.description) or "",
                        tags = (fm and fm.tags) or {},
                        author = (fm and fm.author) or (global_data.author or "LUAX Team"),
                        content = html,
                        url = "/"..slug.."/",
                        image = (fm and fm.image) or global_data.image or "",
                        layout = (fm and fm.layout) or "page.lax",
                        collection = "root",
                        is_home = false,
                        frontmatter = fm or {}
                    }

                    if page.excerpt == "" then
                        local text = html:gsub("<[^>]+>", "")
                        page.excerpt = text:sub(1, 150).."..."
                    end

                    table.insert(all_items, page)
                end
            end
        end
    end

    table.sort(all_items, function(a, b) return a.date > b.date end)

    for i, post in ipairs(all_items) do
        if post.collection == "root" then
            if i > 1 then
                for j=i-1,1,-1 do if all_items[j].collection=="root" then post.prev_post = all_items[j] break end end
            end
            if i < #all_items then
                for j=i+1,#all_items do if all_items[j].collection=="root" then post.next_post = all_items[j] break end end
            end
        end
    end

    for collection_name, collection_posts in pairs(collections) do
        table.sort(collection_posts, function(a, b) return a.date > b.date end)
        for i, post in ipairs(collection_posts) do
            post.collection_index = i
            post.collection_total = #collection_posts
            if i > 1 then
                post.collection_prev = collection_posts[i-1]
                post.prev_post = collection_posts[i-1]
            end
            if i < #collection_posts then
                post.collection_next = collection_posts[i+1]
                post.next_post = collection_posts[i+1]
            end
        end
    end

    return all_items, collections, controllers, global_data
end

local function load_partials()
    local partials = {}
    local is_win = package.config:sub(1,1) == "\\"
    local cmd
    if is_win then
        
        cmd = 'dir /s /b "templates\\partials\\*.lax" 2>nul'
    else
        
        cmd = 'find templates -type f -iname "*.lax" -path "*partials*" 2>/dev/null'
    end

    local handle = io.popen(cmd)
    if not handle then
        print("WARN: partials handle fail")
        return partials
    end

    for full_path in handle:lines() do
        local content = read_file(full_path)
        if content then
            
            local name = full_path:gsub(".*templates[/\\]partials[/\\]",""):gsub("%.lax$",""):gsub("\\","/")
            partials[name] = content
            print(" + partial: "..name)
        end
    end
    handle:close()

    local count = 0
    for _ in pairs(partials) do count = count + 1 end
    print("Partials loaded: "..count)
    if count == 0 then
        print("ERROR: No partials found! Check git ls-files")
    end
    return partials
end

local function render_template(template_name, context, partials, global_data)
    local paths = {
        "templates/layouts/"..template_name,
        "templates/layouts/"..template_name..".lax",
        "templates/"..template_name,
        "templates/"..template_name..".lax",
    }

    local template = nil
    for _, path in ipairs(paths) do
        template = read_file(path)
        if template then break end
    end

    if not template then
        print(c.red.."ERROR: Template not found: "..template_name..c.reset)
        return ""
    end

    local engine = Lax.new(template)

    if global_data then
        engine:set("luax", global_data)
        for k, v in pairs(global_data) do
            engine:set(k, v)
        end
    end

    if global_data and global_data.metadata then
        engine:set("metadata", global_data.metadata)
        engine:set("site", global_data.metadata)
    end

    for k, v in pairs(context) do
        engine:set(k, v)
    end

    for name, content in pairs(partials) do
        engine:partial(name, content)
    end

    return engine:render()
end

local function build_collection(collection_name, collection_posts, controller, global_data, partials, all_collections)
    if #collection_posts == 0 then return end
    local per_page = controller.pagination or 6
    local total = #collection_posts
    local total_pages = math.max(1, math.ceil(total / per_page))
    mkdir_p("dist/"..collection_name)
    mkdir_p("dist/"..collection_name.."/page")
    for page_num = 1, total_pages do
        local start_idx = (page_num - 1) * per_page + 1
        local end_idx = math.min(page_num * per_page, total)
        local page_items = {}
        for i = start_idx, end_idx do table.insert(page_items, collection_posts[i]) end
        local pagination = {items=page_items, current_page=page_num, total_pages=total_pages, total_items=total, per_page=per_page}
        if page_num > 1 then pagination.prev_url = page_num == 2 and "/"..collection_name.."/" or "/"..collection_name.."/page/"..(page_num-1).."/" end
        if page_num < total_pages then pagination.next_url = "/"..collection_name.."/page/"..(page_num+1).."/" end
        local output_dir = page_num == 1 and "dist/"..collection_name or "dist/"..collection_name.."/page/"..page_num
        mkdir_p(output_dir)
        local current_url = page_num == 1 and "/"..collection_name.."/" or "/"..collection_name.."/page/"..page_num.."/"

        local rendered_content = controller.content or ""
        if rendered_content:find("@for") or rendered_content:find("@if") then
            local tmpEngine = Lax.new(rendered_content)
            if global_data then for k,v in pairs(global_data) do 
                tmpEngine:set(k,v) end end
            tmpEngine:set("posts", page_items)
            tmpEngine:set("collections", all_collections)
            tmpEngine:set("_collections", all_collections)
            tmpEngine:set("all_posts", all_collections.all or page_items)
            tmpEngine:set("current_url", current_url)
            for n,pc in pairs(partials) do tmpEngine:partial(n,pc) end
            rendered_content = tmpEngine:render()
        end

        local context = {
            title = controller.title or collection_name,
            description = controller.description or "",
            content = rendered_content,
            posts = page_items,
            all_posts = all_collections.all or page_items,
            pagination = pagination,
            collection = collection_name,
            collections = all_collections,
            _collections = all_collections,
            current_url = current_url,
            base_url = "../",
            og_type = "website",
        }
        for k, v in pairs(controller.frontmatter or {}) do if context[k]==nil then context[k]=v end end
        local html = render_template(controller.layout, context, partials, global_data)
        write_file(output_dir.."/index.html", html)
        print(" "..c.green.."✔"..c.reset.." "..c.dim..current_url.." (page "..page_num.."/"..total_pages..")"..c.reset)
    end
end

local function build_tags(all_items, global_data, partials, all_collections)
    local all_tags = {}

    for _, item in ipairs(all_items) do
        if item.tags and #item.tags > 0 then
            for _, tag in ipairs(item.tags) do
                local slug = tag:lower():gsub(" ", "-"):gsub("[^%w-]", "")
                if not all_tags[slug] then
                    all_tags[slug] = {name = tag, slug = slug, items = {}}
                end
                table.insert(all_tags[slug].items, item)
            end
        end
    end

    if not next(all_tags) then
        print(" "..c.yellow.."⚠ No tags found"..c.reset)
        return
    end

    mkdir_p("dist/tags")

    local tag_list = {}
    for slug, data in pairs(all_tags) do
        table.insert(tag_list, {
            name = data.name,
            slug = slug,
            url = "/tags/"..slug.."/",
            count = #data.items
        })
    end
    table.sort(tag_list, function(a, b) return a.name < b.name end)

    local context = {
        title = "Tags",
        description = "All tags",
        tags = tag_list,
        collections = all_collections,
        _collections = all_collections,
        current_url = "/tags/",
        base_url = "",
        metadata = global_data.metadata or global_data,
        site = global_data.metadata or global_data
    }

    local html = render_template("tags.lax", context, partials, global_data)
    write_file("dist/tags/index.html", html)
    print(" "..c.green.."✔"..c.reset.." "..c.dim.."/tags/ ("..#tag_list.." tags)"..c.reset)

    for slug, data in pairs(all_tags) do
        mkdir_p("dist/tags/"..slug)

        local items = data.items
        table.sort(items, function(a, b) return a.date > b.date end)

        local context = {
            title = data.name,
            description = "Posts tagged with "..data.name,
            tag = data.name,
            tag_slug = slug,
            posts = items,
            count = #items,
            collections = all_collections,
            _collections = all_collections,
            current_url = "/tags/"..slug.."/",
            base_url = "..",
            metadata = global_data.metadata or global_data,
            site = global_data.metadata or global_data
        }

        local html = render_template("tag.lax", context, partials, global_data)
        write_file("dist/tags/"..slug.."/index.html", html)
        print(" "..c.green.."✔"..c.reset.." "..c.dim.."/tags/"..slug.."/ ("..#items.." posts)"..c.reset)
    end
end

local function build_index(all_items, global_data, partials, all_collections)
    table.sort(all_items, function(a,b)
        return (a.date or "") > (b.date or "")
    end)

    local home_item = nil
    for _, item in ipairs(all_items) do
        if item.is_home or item.slug == "index" then
            home_item = item
            break
        end
    end

    local only_posts = {}
    if all_collections and all_collections.posts then
        only_posts = all_collections.posts
    else
        for _, it in ipairs(all_items) do
            if it.collection ~= "root" and not it.is_home then
                table.insert(only_posts, it)
            end
        end
    end
    table.sort(only_posts, function(a,b) return (a.date or "") > (b.date or "") end)

    local context = {
        site = global_data.site or global_data.metadata or {},
        site_title = global_data.title or "LUAX SSG",
        site_description = global_data.description or "",
        title = home_item and home_item.title or global_data.title or "LUAX",
        content = home_item and home_item.content or "",
        posts = only_posts,
        collections = all_collections,
        _collections = all_collections,
        all_posts = only_posts,
        current_url = "/",
        base_url = "",
        metadata = global_data.metadata or global_data,
        site = global_data.metadata or global_data
    }

    if home_item then
        if home_item.frontmatter then
            for k, v in pairs(home_item.frontmatter) do
                context[k] = v
            end
        end
        context.content = home_item.content
        context.home_title = home_item.title or context.site_title
        context.home_description = home_item.description or context.site_description
    end

    if global_data.home then
        for k, v in pairs(global_data.home) do
            if context[k] == nil then
                context[k] = v
            end
        end
    end

    local layout = (home_item and home_item.layout) or "index.lax"

    local html = render_template(layout, context, partials, global_data)
    if html and html ~= "" then
        write_file("dist/index.html", html)
        print(" "..c.green.."✔"..c.reset.." "..c.dim.."/ (home)"..c.reset)
    else
        print(c.red.."ERROR: Failed to render index"..c.reset)
    end
end

local function generate_feeds(all_items, global_data)
    local site_url = global_data.url or "https://example.com"

    local sitemap = '<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n'
    sitemap = sitemap..' <url>\n <loc>'..site_url..'</loc>\n <lastmod>'..os.date("%Y-%m-%d")..'</lastmod>\n <changefreq>daily</changefreq>\n <priority>1.0</priority>\n </url>\n'

    for _, item in ipairs(all_items) do
        sitemap = sitemap..' <url>\n <loc>'..site_url..item.url..'</loc>\n <lastmod>'..item.date..'</lastmod>\n <changefreq>monthly</changefreq>\n <priority>0.8</priority>\n </url>\n'
    end
    sitemap = sitemap..'</urlset>\n'
    write_file("dist/sitemap.xml", sitemap)

    local rss = '<?xml version="1.0" encoding="UTF-8"?>\n<rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom">\n'
    rss = rss..' <channel>\n <title>'..(global_data.title or "LUAX SSG")..'</title>\n <link>'..site_url..'</link>\n'
    rss = rss..' <description>'..(global_data.description or "")..'</description>\n'
    rss = rss..' <language>en-us</language>\n <lastBuildDate>'..os.date("%a, %d %b %Y %H:%M:%S +0000")..'</lastBuildDate>\n'
    rss = rss..' <atom:link href="'..site_url..'feed.xml" rel="self" type="application/rss+xml" />\n'

    for _, item in ipairs(all_items) do
        if not item.is_home and item.slug ~= "index" then
            rss = rss..' <item>\n <title>'..item.title..'</title>\n <link>'..site_url..item.url..'</link>\n'
            rss = rss..' <description><![CDATA['..(item.excerpt or item.description or "")..']]></description>\n'
            rss = rss..' <pubDate>'..item.date..'</pubDate>\n <guid>'..site_url..item.url..'</guid>\n </item>\n'
        end
    end
    rss = rss..' </channel>\n</rss>\n'
    write_file("dist/feed.xml", rss)
    write_file("dist/rss.xml", rss)

    write_file("dist/robots.txt", 'User-agent: *\nAllow: /\nSitemap: '..site_url..'sitemap.xml\n')
    write_file("dist/humans.txt", '/* TEAM */\n Architect: AXCORA\n Website: '..site_url..'\n Labs: axcora.com\n/* SITE */\n Generator: LUAX SSG\n Built: '..os.date("%Y-%m-%d %H:%M:%S")..'\n Powered by: Lua + LAX Template\n')

    print(" "..c.green.."✔"..c.reset.." "..c.dim.."Feeds generated"..c.reset)
end

local start_time = os.clock()

local global_data = load_data_folder()
print(c.cyan.."▶"..c.reset.." Loaded data")

if global_data.title then
    print(" "..c.dim.." Site: "..global_data.title..c.reset)
end

mkdir_p("dist")
mkdir_p("dist/img")
mkdir_p("dist/tags")
copy_public()

local partials = load_partials()

local all_items, collections, controllers = scan_content()
print("\n"..c.cyan.."▶"..c.reset.." Found "..c.bold..#all_items..c.reset.." content items")
local col_count = 0 for _ in pairs(collections) do col_count=col_count+1 end
print(" "..c.dim.." - "..col_count.." collections"..c.reset)

print("\n"..c.cyan.."▶"..c.reset.." Building content")
for _, item in ipairs(all_items) do
    local output_dir = "dist"..item.url:gsub("/$", "")
    mkdir_p(output_dir)

    local tag_data = {}
    if item.tags and #item.tags > 0 then
        for _, tag in ipairs(item.tags) do
            local slug = tag:lower():gsub(" ", "-"):gsub("[^%w-]", "")
            table.insert(tag_data, {
                name = tag,
                slug = slug,
                url = "/tags/"..slug.."/"
            })
        end
    end

    local only_posts_global = {}
    if collections and collections.posts then
        only_posts_global = collections.posts
    else
        for _, it in ipairs(all_items) do
            if it.collection ~= "root" and not it.is_home then
                table.insert(only_posts_global, it)
            end
        end
    end
    table.sort(only_posts_global, function(a,b) return (a.date or "") > (b.date or "") end)

    local context = {
        title = item.title,
        description = (item.description ~= "" and item.description) and item.description or item.excerpt,
        excerpt = item.excerpt,
        content = item.content,
        date = item.date,
        post = item,
        prev_post = item.prev_post,
        next_post = item.next_post,
        tags = tag_data,
        has_tags = #tag_data > 0,
        current_url = item.url,
        collection = item.collection,
        posts = only_posts_global,
        all_posts = only_posts_global,
        collections = collections,
        _collections = collections,
        base_url = "..",
        metadata = global_data.metadata or global_data,
        site = global_data.metadata or global_data
    }

    if item.frontmatter then
        for k, v in pairs(item.frontmatter) do
            if context[k] == nil then
                context[k] = v
            end
        end
    end

    local raw_content = context.content or item.content or ""
    if raw_content:find("@for") or raw_content:find("@if") then
    local cEngine = Lax.new(raw_content)
    for k,v in pairs(context) do cEngine:set(k,v) end
    if global_data then
        cEngine:set("luax", global_data)
        for k,v in pairs(global_data) do cEngine:set(k,v) end
        if global_data.metadata then
            cEngine:set("metadata", global_data.metadata)
            cEngine:set("site", global_data.metadata)
        end
    end
    for name, pc in pairs(partials) do cEngine:partial(name, pc) end
    context.content = cEngine:render()
end

    local layout = item.layout or "page.lax"
    local html = render_template(layout, context, partials, global_data)
    write_file(output_dir.."/index.html", html)
    print(" "..c.green.."✔"..c.reset.." "..c.dim..item.url..c.reset)
end

print("\n"..c.cyan.."▶"..c.reset.." Building collections")
for collection_name, collection_posts in pairs(collections) do
    table.sort(collection_posts, function(a, b) return a.date > b.date end)
    for i, post in ipairs(collection_posts) do
        post.collection_index = i
        post.collection_total = #collection_posts
        if i > 1 then
            post.collection_prev = collection_posts[i-1]
            post.prev_post = collection_posts[i-1]
        end
        if i < #collection_posts then
            post.collection_next = collection_posts[i+1]
            post.next_post = collection_posts[i+1]
        end
    end
    local controller = controllers[collection_name]
    if controller then
        build_collection(collection_name, collection_posts, controller, global_data, partials, collections)
    end
end

print("\n"..c.cyan.."▶"..c.reset.." Building tags")
build_tags(all_items, global_data, partials, collections)

print("\n"..c.cyan.."▶"..c.reset.." Building index")
build_index(all_items, global_data, partials, collections)

print("\n"..c.cyan.."▶"..c.reset.." Generating feeds")
generate_feeds(all_items, global_data)

local build_time = os.clock() - start_time
print("\n"..c.green..c.bold.."▶ BUILD COMPLETE v1.2.7 FIXED"..c.reset)
print(c.dim.." Items: "..c.reset..c.bold..#all_items..c.reset)
print(c.dim.." Collections: "..c.reset..c.bold..col_count..c.reset)
print(c.dim.." Time: "..c.reset..string.format("%.3f", build_time).."s")
print(c.dim.." Dir: "..c.reset.."dist/\n")
print(c.green..c.bold.."LUAX BY AXCORA v1.2.7"..c.reset)
print(c.dim.." Docs: LUAX.AXCORA.COM"..c.reset)
