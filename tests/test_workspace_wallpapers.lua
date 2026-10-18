-- Exercise the real generated Lua scheduling policy without touching the desktop.
local input = assert(io.open(arg[1], "r"))
local config = input:read("*a")
input:close()
local policy = assert(config:match("(%-%- One renderer.-)\nhl%.curve"))
local commands, timers, events = {}, {}, {}
os.time = function() return 9000 end
hl = {
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
assert(load(policy))()
flush()
assert(#commands == 1, "startup must prepare assignments")
assert(#timers == 1 and timers[1].timeout == 900100, "quarter-hour boundary required")
for _ = 1, 3 do
    for number = 1, 10 do events["workspace.active"]({ id = number }) end
end
flush()
assert(#commands == 1, "ordinary switches must not launch a wallpaper process")
events["workspace.active"]({ id = -99 })
events["workspace.active"]({ id = 42 })
events["workspace.active"]({ id = 42 })
flush()
assert(#commands == 2, "new extra workspace must reconcile once; special IDs must not")
events["config.reloaded"]()
events["monitor.layout_changed"]()
flush()
assert(#commands == 3, "reload/output changes must coalesce")
assert(config:find('hl.plugin.load("', 1, true), "plugin must load declaratively")
assert(not config:find("/awww", 1, true), "no second wallpaper renderer")
assert(config:find('bezier = "workspaceSmooth"', 1, true), "workspace animation must remain enabled")
print("PASS: startup, process-free switching, extra IDs, coalescing, timer and plugin configuration")
