-- Exercise the real Lua policy with fake outputs and a temporary manifest.
local runtime = assert(os.getenv("TMPDIR"))
local originalGetenv = os.getenv
os.getenv = function(name) return name == "XDG_RUNTIME_DIR" and runtime or originalGetenv(name) end
local monitors = { {name="laptop"}, {name="lower"}, {name="upper"} }
local focused = monitors[1]
local layers, windows, events, timers, commands = {}, {}, {}, {}, {}
for index, monitor in ipairs(monitors) do
    monitor.workspace = {id=(index - 1) * 10 + 3}
    layers[index] = {namespace="waybar", mapped=true, monitor=monitor, layer=2}
end
local function addWindow(monitor, properties)
    local w = {monitor=monitor, workspace=monitor.workspace, mapped=true, hidden=false}
    for key, value in pairs(properties or {}) do w[key] = value end
    windows[#windows + 1] = w
    return w
end
hl = {
    get_active_monitor = function() return focused end,
    get_monitors = function() return monitors end,
    get_active_workspace = function(m) return m.workspace end,
    get_active_special_workspace = function(m) return m.special end,
    get_windows = function(options)
        local result = {}
        for _, w in ipairs(windows) do
            if w.monitor == options.monitor then result[#result + 1] = w end
        end
        return result
    end,
    get_layers = function() return layers end,
    on = function(name, callback) events[name] = callback end,
    timer = function(callback) timers[#timers + 1] = callback end,
    dsp = {exec_cmd=function(command) return command end},
    dispatch = function(command)
        commands[#commands + 1] = command
        if not command:find("SIGRTMIN+10", 1, true) then
            assert(command:find("SIGRTMIN+8", 1, true) or command:find("SIGRTMIN+9", 1, true))
            return
        end
        local file = assert(io.open(runtime .. "/waybar-output-visibility.json"))
        local value = file:read("*a")
        file:close()
        for _, layer in ipairs(layers) do
            layer.layer = value:find('"' .. layer.monitor.name .. '":true', 1, true) and 2 or 0
        end
    end,
}
local function flush()
    local remaining = 10
    while #timers > 0 do
        assert(remaining > 0, "must settle without polling")
        remaining = remaining - 1
        local pending = timers
        timers = {}
        for _, callback in ipairs(pending) do callback() end
    end
end
local laptop = addWindow(monitors[1])
local upper = addWindow(monitors[3], {floating=true})
local policy = dofile(arg[1])("systemctl")
flush()
assert(layers[1].layer == 2 and layers[2].layer == 0 and layers[3].layer == 2,
    "bars follow their own windows, including floating windows")
assert(#commands == 1)
events["monitor.focused"](monitors[2])
flush()
assert(#commands == 1, "focus alone must not change visibility")
upper.mapped = false
events["window.close"](upper)
flush()
assert(layers[1].layer == 2 and layers[3].layer == 0)
local lower = addWindow(monitors[2], {hidden=true})
events["window.open"](lower)
flush()
assert(layers[2].layer == 0, "hidden windows do not count")
lower.hidden, lower.workspace = false, {id=12}
events["window.update_rules"](lower)
flush()
assert(layers[2].layer == 0, "inactive workspaces do not count")
lower.pinned = true
events["window.pin"](lower)
flush()
assert(layers[2].layer == 2, "pinned windows count")
lower.pinned = false
monitors[2].special = {id=-99}
lower.workspace = monitors[2].special
events["workspace.active"](monitors[2].special)
flush()
assert(layers[2].layer == 2, "special workspace windows count")
laptop.mapped, lower.mapped = false, false
events["window.close"](laptop)
events["window.close"](lower)
assert(#timers == 1, "simultaneous changes coalesce")
flush()
assert(layers[1].layer == 0 and layers[2].layer == 0 and layers[3].layer == 0)
layers[#layers + 1] = {namespace="rofi", mapped=true, monitor=monitors[1], layer=2}
events["layer.opened"](layers[#layers])
flush()
assert(layers[1].layer == 0, "Rofi alone does not reveal an empty screen's bar")
-- Monitor removal can leave a closing layer surface alive for one more frame.
local laptopMonitor = monitors[1]
monitors = {laptopMonitor}
laptop.mapped = true
events["monitor.removed"]()
flush()
assert(layers[1].layer == 2, "undocked laptop retains its own dynamic bar")
local signals = #commands
events["monitor.removed"]()
flush()
assert(#commands == signals, "stale dock layers must not cause repeated visibility signals")
local returning = {name="new-dock-port", workspace={id=13}}
monitors[2] = returning
layers = {layers[1], {namespace="waybar", mapped=true, monitor=returning, layer=2}}
events["monitor.added"]()
flush()
assert(layers[1].layer == 2 and layers[2].layer == 0, "new empty dock output remains hidden independently")
print("PASS: per-output visibility, floating/pinned/special windows, focus and coalescing")

-- Tray actions use the same public interface as the keyboard binding.
focused = returning
policy.toggleTray()
assert(commands[#commands]:find("SIGRTMIN+8", 1, true), "drawer opens immediately, before visibility is scheduled")
flush()
assert(layers[2].layer == 2, "pin reveals the focused empty output")
policy.toggleTray()
assert(commands[#commands]:find("SIGRTMIN+9", 1, true))
flush()
assert(layers[2].layer == 0, "unpin restores window-based visibility")
policy.toggleTray()
flush()
focused = laptopMonitor
laptop.mapped = false
policy.toggleTray()
assert(commands[#commands]:find("SIGRTMIN+8", 1, true), "moving the pin keeps the process-wide drawer open")
flush()
assert(layers[1].layer == 2 and layers[2].layer == 0, "pin moves to the focused output")
focused = nil
local before = #commands
policy.toggleTray()
flush()
assert(#commands == before, "no active monitor leaves the tray unchanged")
focused = laptopMonitor
policy.toggleTray()
flush()
assert(layers[1].layer == 0)

-- An event arriving after publication must be reconciled when the signal settles.
laptop.mapped = true
events["window.open"](laptop)
local pending = timers
timers = {}
for _, callback in ipairs(pending) do callback() end
assert(layers[1].layer == 2)
laptop.mapped = false
events["window.close"](laptop)
policy.toggleTray()
focused = returning
policy.toggleTray()
flush()
assert(layers[1].layer == 0 and layers[2].layer == 2,
    "window and tray changes during a pending signal reach the final manifest")
-- The compositor can disagree with the last requested state: always observe it.
layers[2].layer = 0
events["layer.opened"](layers[2])
flush()
assert(layers[2].layer == 2, "actual surface state is reconciled")
print("PASS: tray pin/unpin, moving pin, absent focus and pending-signal changes")
