print("=================================")
print(" 🌐 LUAX SERVER v2.5")
print(" https://luax.axcora.com")
print("=================================\n")

local port = 8080
local dist = "dist"
local is_windows = package.config:sub(1,1) == "\\"

local function safe_popen(cmd)
    local ok, p = pcall(io.popen, cmd)
    if not ok or not p then return nil end
    return p
end

local function build()
    print("\n🔨 Rebuilding...")
    local ok = false
    if is_windows then
        ok = os.execute("lua build.lua >nul 2>&1")
        if not ok then ok = os.execute("luax build >nul 2>&1") end
    else
        ok = os.execute("lua build.lua > /dev/null 2>&1")
        if not ok then ok = os.execute("lua5.4 build.lua > /dev/null 2>&1") end
        if not ok then ok = os.execute("./luax.sh build > /dev/null 2>&1") end
    end
    if ok then
        print("✅ Built at ".. os.date("%H:%M:%S"))
        local f = io.open(dist.."/.reload", "w")
        if f then f:write(tostring(os.time()).."_"..math.random(100000)) f:close() end
    else
        print("❌ Build failed,try manual:")
        os.execute("lua build.lua")
    end
end

local function file_signature(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local content = f:read(4096)
    if not content then f:close() return nil end
    local full = f:read("*a")
    f:close()
    if full then content = content .. full:sub(1,100) end
    local sum = 0
    for i=1, math.min(#content, 2000) do sum = (sum + content:byte(i)) % 1000000 end
    return tostring(#content).."_"..tostring(sum)
end

local function scan_files()
    local files = {}
    if is_windows then
        -- WINDOWS
        local dirs = {"src", "templates", "data", "public"}
        for _, dir in ipairs(dirs) do
            local cmd = 'dir "'..dir..'" /b /s 2>nul'
            local p = safe_popen(cmd)
            if p then
                for line in p:lines() do
                    if line:match("%.md$") or line:match("%.lax$") or line:match("%.yaml$") or line:match("%.yml$") or line:match("%.json$") or line:match("%.css$") or line:match("%.js$") then
                        -- dir /b /s sudah full path
                        table.insert(files, line)
                    end
                end
                p:close()
            end
        end
        -- root files
        for _, f in ipairs({"metadata.yaml", "build.lua", "lax.lua", "yaml.lua"}) do
            local fh = io.open(f, "r")
            if fh then fh:close() table.insert(files, f) end
        end
    else
        -- LINUX / MAC
        local p = safe_popen('find src templates data public -type f \\( -name "*.md" -o -name "*.lax" -o -name "*.yaml" -o -name "*.yml" -o -name "*.json" -o -name "*.css" -o -name "*.js" \\) 2>/dev/null')
        if p then
            for line in p:lines() do table.insert(files, line) end
            p:close()
        end
        for _, f in ipairs({"metadata.yaml", "build.lua", "lax.lua", "yaml.lua"}) do
            local fh = io.open(f, "r")
            if fh then fh:close() table.insert(files, f) end
        end
    end
    return files
end

local function inject_livereload()
    local files = {}
    if is_windows then
        local p = safe_popen('dir "'..dist..'" /b /s 2>nul')
        if p then
            for line in p:lines() do
                if line:match("%.html$") then table.insert(files, line) end
            end
            p:close()
        end
    else
        local p = safe_popen('find "'..dist..'" -name "*.html" -type f 2>/dev/null')
        if p then
            for line in p:lines() do table.insert(files, line) end
            p:close()
        end
    end

    local script = [[
<script id="luax-livereload">
(function(){let last=0;console.log("🔥 LUAX Live Reload");setInterval(async()=>{try{let r=await fetch('/.reload?t='+Date.now(),{cache:'no-store'});let t=await r.text();if(last===0){last=t;return;}if(t!==last){location.reload();}}catch(e){}},500);})();
</script></body>]]

    for _, file in ipairs(files) do
        local f = io.open(file, "r")
        if f then
            local html = f:read("*a")
            f:close()
            if html then
                html = html:gsub('<script id="luax%-livereload">.-</script></body>', '</body>')
                html = html:gsub('<script id="livereload">.-</script></body>', '</body>')
                if not html:find('luax%-livereload') and html:find("</body>") then
                    html = html:gsub("</body>", script)
                    local out = io.open(file, "w")
                    if out then out:write(html) out:close() end
                end
            end
        end
    end
end

-- BUILD
build()
inject_livereload()

print("🚀 Server at http://localhost:"..port)
print("👀 Watching: src/, templates/, data/, public/")
print("⚡ Live Reload")
print("📁 Serving: "..dist.."/")
print("Press Ctrl+C to stop")
print("========================================\n")

-- open browser
if is_windows then
    os.execute('start http://localhost:'..port..' >nul 2>&1')
else
    local uname_p = safe_popen("uname 2>/dev/null")
    local is_mac = false
    if uname_p then
        local u = uname_p:read("*a")
        uname_p:close()
        if u:match("Darwin") then is_mac = true end
    end
    if is_mac then
        os.execute('open http://localhost:'..port..' > /dev/null 2>&1 &')
    else
        os.execute('xdg-open http://localhost:'..port..' > /dev/null 2>&1 &')
    end
end

-- START SERVER
local server_started = false
local has_router = io.open("router.php", "r")
if has_router then has_router:close() end

if is_windows then
    local php = safe_popen("php -v 2>nul")
    if php then
        local r = php:read("*a") php:close()
        if r:match("PHP") then
            if has_router then
                os.execute('start /B php -S localhost:'..port..' -t '..dist..' router.php >nul 2>&1')
            else
                os.execute('start /B php -S localhost:'..port..' -t '..dist..' >nul 2>&1')
            end
            print("🐘 PHP server started")
            server_started = true
        end
    end
    if not server_started then
        local py = safe_popen("python --version 2>nul")
        if py then
            local r = py:read("*a") py:close()
            if r:match("Python") then
                os.execute('start /B python -m http.server '..port..' --directory '..dist..' >nul 2>&1')
                print("🐍 Python http.server")
                server_started = true
            end
        end
    end
else
    local php = safe_popen("php -v 2>/dev/null")
    if php then
        local r = php:read("*a") php:close()
        if r:match("PHP") then
            if has_router then
                os.execute('php -S localhost:'..port..' -t '..dist..' router.php > /dev/null 2>&1 & echo $! > /tmp/luax_php.pid')
            else
                os.execute('php -S localhost:'..port..' -t '..dist..' > /dev/null 2>&1 & echo $! > /tmp/luax_php.pid')
            end
            print("🐘 PHP server started")
            server_started = true
        end
    end
    if not server_started then
        os.execute("python3 -m http.server "..port.." --directory "..dist.." > /dev/null 2>&1 & echo $! > /tmp/luax_py.pid")
        print("🐍 Python3 http.server")
        server_started = true
    end
end

if not server_started then
    print("❌ Install PHP atau Python dulu bro")
    os.exit(1)
end

local cache = {}
local initial = scan_files()
for _, file in ipairs(initial) do
    local sig = file_signature(file)
    if sig then cache[file] = sig end
end
local c=0 for _ in pairs(cache) do c=c+1 end
print("✅ Watching "..c.." files...\n")

while true do
    if is_windows then
        os.execute("timeout /t 1 /nobreak >nul 2>&1")
    else
        os.execute("sleep 0.5")
    end
    local changed = false
    local current = scan_files()
    local seen = {}
    for _, file in ipairs(current) do
        seen[file] = true
        local sig = file_signature(file)
        if sig then
            if cache[file] and cache[file] ~= sig then
                print("📝 Changed: "..file)
                changed = true
            end
            cache[file] = sig
        end
    end
    for old_file in pairs(cache) do
        if not seen[old_file] then
            cache[old_file] = nil
            changed = true
            print("🗑️ Deleted: "..old_file)
        end
    end
    if changed then
        build()
        inject_livereload()
        print("👀 Watching again...\n")
    end
end
