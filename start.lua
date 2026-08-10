print("========================================")
print(" 🌐 LUAX SERVER STARTED !! v1.2 FIX")
print("========================================\n")

local port = 8080
local dist = "dist"
local is_windows = package.config:sub(1,1) == "\\"

local function build()
    print("\n🔨 Rebuilding...")
    local ok = os.execute("luax build")
    if not ok then ok = os.execute("lua build.lua") end
    if ok then
        print("✅ Built at ".. os.date("%H:%M:%S"))
        local f = io.open(dist.."/.reload", "w")
        if f then f:write(tostring(os.time())) f:close() end
    else
        print("❌ Build failed")
    end
end

local function scan_files_win()
    local files = {}
    local dirs = {"src", "templates", "data"}
    for _, dir in ipairs(dirs) do
        local cmd = 'dir /b /s "'..dir..'" 2>nul'
        local p = io.popen(cmd)
        if p then
            for line in p:lines() do
                if line:match("%.md$") or line:match("%.lax$") or line:match("%.yaml$") or line:match("%.yml$") or line:match("%.json$") then
                    table.insert(files, line)
                end
            end
            p:close()
        end
    end
    return files
end

local function scan_files_unix()
    local files = {}
    for _, dir in ipairs({"src","templates","data"}) do
        local p = io.popen('find "'..dir..'" -type f 2>/dev/null')
        if p then
            for file in p:lines() do table.insert(files, file) end
            p:close()
        end
    end
    return files
end

local function scan_files()
    if is_windows then return scan_files_win() else return scan_files_unix() end
end

local function get_mtime_win(path)
    local cmd = 'powershell -Command "(Get-Item \\"'..path..'\\").LastWriteTime.ToFileTimeUtc()" 2>nul'
    local p = io.popen(cmd)
    if not p then return 0 end
    local t = p:read("*a")
    p:close()
    return tonumber(t) or 0
end

local function get_mtime_unix(path)
    local f = io.popen('stat -f %m "'..path..'" 2>/dev/null || stat -c %Y "'..path..'" 2>/dev/null')
    if not f then return 0 end
    local t = f:read("*a")
    f:close()
    return tonumber(t) or 0
end

local function get_mtime(path)
    if is_windows then return get_mtime_win(path) else return get_mtime_unix(path) end
end

local function inject_livereload()
    local cmd = is_windows and 'dir /b /s "'..dist..'\\*.html" 2>nul' or 'find "'..dist..'" -name "*.html" 2>/dev/null'
    local p = io.popen(cmd)
    if not p then return end
    for file in p:lines() do
        local f = io.open(file, "r")
        if f then
            local html = f:read("*a")
            f:close()
            if not html:find("livereload") then
                local injected = html:gsub("</body>", [[
<script id="livereload">
let last=0;setInterval(async()=>{
 try{let r=await fetch('/.reload?t='+Date.now());let t=await r.text();if(last==0)last=t;if(t!=last)location.reload();}catch(e){}
},800);
</script></body>]])
                local out = io.open(file, "w")
                if out then out:write(injected) out:close() end
            end
        end
    end
    p:close()
end

-- BUILD
build()
inject_livereload()

print("🚀 Server at http://localhost:"..port)
print("👀 Watching: src/, templates/, data/")
print("📁 Serving: "..dist.."/")
print("Press Ctrl+C to stop")
print("========================================\n")

if is_windows then
    os.execute('start http://localhost:'..port)
else
    os.execute("open http://localhost:"..port.." 2>/dev/null || xdg-open http://localhost:"..port.." 2>/dev/null")
end

local server_started = false

local php = io.popen("php -v 2>&1")
if php then
    local r = php:read("*a") php:close()
    if r:match("PHP") then
        if is_windows then
            os.execute('start /B php -S localhost:'..port..' -t '..dist..' router.php >nul 2>&1')
        else
            os.execute('php -S localhost:'..port..' -t '..dist..' router.php > /dev/null 2>&1 &')
        end
        print("🐘 Using PHP + router.php (pretty URL FIX for v0.3)")
        server_started = true
    end
end

if not server_started then
    if not is_windows then
        os.execute("python3 -m http.server "..port.." --directory "..dist.." > /dev/null 2>&1 &")
        server_started = true
        print("🐍 Using Python (may have issue with v0.3)")
    else
        local py = io.popen("python --version 2>&1")
        if py then
            local r = py:read("*a") py:close()
            if r:match("Python") then
                os.execute('start /B python -m http.server '..port..' --directory '..dist..' >nul 2>&1')
                print("🐍 Using Python (may have issue with v0.3)")
                server_started = true
            end
        end
    end
end

if not server_started then
    print("❌ Install PHP dulu bro (recommended) atau Python")
    os.exit(1)
end

local file_cache = {}
for _, file in ipairs(scan_files()) do
    file_cache[file] = get_mtime(file)
end

while true do
    if is_windows then os.execute("timeout /t 1 /nobreak >nul") else os.execute("sleep 1") end
    local changed = false
    local current_files = scan_files()
    for _, file in ipairs(current_files) do
        local mt = get_mtime(file)
        if file_cache[file] and file_cache[file] ~= mt and mt ~= 0 then
            print("📝 Changed: "..file)
            changed = true
        end
        file_cache[file] = mt
    end
    if changed then
        build()
        inject_livereload()
    end
end
