-- Exercise the real generated Lua fast path without contacting the desktop.
local input = assert(io.open(arg[1], "r"))
local config = input:read("*a")
input:close()
local policy = assert(config:match("(%-%- One renderer.-)\nhl%.curve"))
local now, workspace, imagePresent = 9000, 1, true
local commands, timers, events = {}, {}, {}
local images = { [1] = "/images/a 'quoted' image.png", [2] = "/images/second.png" }
local cacheEpoch = 10

os.time = function() return now end
io.open = function(path)
    local id = tonumber(path:match("/workspace%-wallpapers/6544502d31/(%-?%d+)$"))
    if id and images[id] then
        local line = 0
        return {
            read = function(_, mode)
                if mode == "*l" then
                    line = line + 1
                    return line == 1 and tostring(cacheEpoch) or images[id]
                end
                return images[id]
            end,
            close = function() end,
        }
    end
    if imagePresent and (path == images[1] or path == images[2]) then
        return { close = function() end }
    end
end
hl = {
    get_monitors = function()
        return { { name = "eDP-1", active_workspace = { id = workspace } } }
    end,
    on = function(name, callback) events[name] = callback end,
    timer = function(callback, options)
        timers[#timers + 1] = { callback = callback, timeout = options.timeout }
    end,
    dsp = { exec_cmd = function(command) return command end },
    dispatch = function(command) commands[#commands + 1] = command end,
}
local function flush()
    local pending = timers
    timers = {}
    for _, timer in ipairs(pending) do
        if timer.timeout == 1 then timer.callback()
        else timers[#timers + 1] = timer end
    end
end
local function isWallpaper(command)
    return command:find("/awww img --transition-type none --resize no", 1, true)
end
assert(load(policy))()
flush()
assert(#commands == 1 and isWallpaper(commands[1]), "cache hit must bypass helper")
assert(commands[1]:find("'\\''", 1, true), "quoted filename must be shell escaped")
assert(#timers == 1 and timers[1].timeout == 900100, "quarter-hour timer required")
events["workspace.active"]()
flush()
assert(#commands == 1, "unchanged wallpaper must not be reapplied")
workspace = 2
events["workspace.active"]()
events["workspace.active"]()
flush()
assert(#commands == 2 and isWallpaper(commands[2]), "switch must use cached image")
workspace = 1
events["workspace.active"]()
flush()
assert(#commands == 3 and isWallpaper(commands[3]), "return must restore cached image")
now = 9900
events["workspace.active"]()
flush()
assert(#commands == 4 and not isWallpaper(commands[4]), "expired cache must reconcile")
cacheEpoch = 11
imagePresent = false
events["workspace.active"]()
flush()
assert(#commands == 5 and not isWallpaper(commands[5]), "missing image must reconcile")
events["config.reloaded"]()
assert(#commands == 6 and not isWallpaper(commands[6]), "reload must reconcile backend")
imagePresent = true
cacheEpoch = 10
workspace = 2
events["workspace.active"]()
flush()
assert(#commands == 8 and isWallpaper(commands[7]) and not isWallpaper(commands[8]),
    "expired cache must switch with its ready image while requesting a new cycle")
print("PASS: Lua fast path, quoting, coalescing, timer, expiry, missing image and reload")
