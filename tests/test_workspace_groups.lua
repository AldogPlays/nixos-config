-- Exercise actual grouping policy against a small in-memory compositor.
local monitors = {
    { name = "laptop", description = "Laptop" },
    { name = "bottom", description = "Bottom" },
    { name = "top", description = "Top" },
}
local workspaces, rules, events, timers, windows = {}, {}, {}, {}, {}
local persistence = {}
local focused, cursor, selected = monitors[1], { x = -100, y = 500 }, nil
local focus
local function workspace(id, monitor)
    if not workspaces[id] then workspaces[id] = { id = id, monitor = monitor } end
    return workspaces[id]
end
focus = function(id)
    local target = rules[id] or focused
    local ws = workspace(id, target)
    focused, target.active = ws.monitor, ws
    if events["workspace.active"] then events["workspace.active"](ws) end
end
hl = {
    get_monitors = function() return monitors end,
    get_active_monitor = function() return focused end,
    get_active_workspace = function(m) return (m or focused).active end,
    get_workspace = function(id) return workspaces[id] end,
    get_windows = function() return windows end,
    get_active_window = function() return selected end,
    get_cursor_pos = function() return cursor end,
    on = function(name, callback) events[name] = callback end,
    timer = function(callback) timers[#timers + 1] = callback end,
    workspace_rule = function(rule)
        persistence[tonumber(rule.workspace)] = rule.persistent
        for _, m in ipairs(monitors) do
            if m.name == rule.monitor then rules[tonumber(rule.workspace)] = m end
        end
    end,
    dispatch = function(callback) callback() end,
    dsp = {
        focus = function(options)
            return function()
                if options.workspace then focus(options.workspace)
                else focused = options.monitor end
            end
        end,
        cursor = { move = function(p) return function() cursor = p end end },
        window = { move = function(options)
            return function()
                local w = options.window
                w.workspace = workspace(options.workspace, rules[options.workspace] or focused)
                w.monitor = w.workspace.monitor
                if options.follow ~= false then focus(options.workspace) end
            end
        end },
        workspace = { move = function(options)
            return function()
                options.workspace.monitor = options.monitor
                for _, w in ipairs(windows) do
                    if w.workspace == options.workspace then w.monitor = options.monitor end
                end
            end
        end },
    },
}
local function flush()
    local pending = timers
    timers = {}
    for _, callback in ipairs(pending) do callback() end
end
monitors[1].active = workspace(3, monitors[1])
monitors[2].active = workspace(6, monitors[2])
monitors[3].active = workspace(7, monitors[3])
windows[1] = { monitor = monitors[3], workspace = monitors[3].active }
local groups = dofile(arg[1])({ Laptop = 0, Bottom = 1, Top = 2 })
flush()
assert(windows[1].workspace.id == 27 and windows[1].monitor == monitors[3], "adopt windows on their existing screen")
assert(monitors[1].active.id == 3 and monitors[2].active.id == 13 and monitors[3].active.id == 23)
assert(focused == monitors[1] and cursor.x == -100 and cursor.y == 500, "preserve keyboard screen and pointer")
groups.focus(8)
assert(monitors[1].active.id == 8 and monitors[2].active.id == 18 and monitors[3].active.id == 28)
focused = monitors[2]
focus(12) -- Native Waybar click or completed swipe on an external monitor.
flush()
assert(monitors[1].active.id == 2 and monitors[2].active.id == 12 and monitors[3].active.id == 22)
assert(focused == monitors[2], "external navigation must retain its initiating monitor")
groups.focus(10)
groups.step(1)
assert(monitors[2].active.id == 11, "wrap group 10 to 1")
groups.step(-1)
assert(monitors[2].active.id == 20, "wrap group 1 to 10")
events["workspace.active"]({ id = -99 })
assert(monitors[2].active.id == 20, "special workspaces stay independent")
selected = windows[1]
groups.moveWindow(4)
flush()
assert(windows[1].workspace.id == 24 and windows[1].monitor == monitors[3], "move targets the window's own monitor")
assert(monitors[1].active.id == 4 and monitors[2].active.id == 14, "following a moved window switches the group")
local laptop = monitors[1]
windows[1].monitor = laptop -- Native output removal migrates its windows first.
windows[1].workspace.monitor = laptop
monitors, focused = { laptop }, laptop
events["monitor.removed"]()
events["monitor.removed"]()
assert(#timers == 1, "coalesce hotplug events")
flush()
assert(windows[1].workspace.id == 4 and windows[1].monitor == laptop, "undocked windows remain reachable by their group number")
for id = 1, 10 do assert(persistence[id] == true) end
for id = 11, 30 do assert(persistence[id] == false, "retire disconnected screens' persistent workspace buttons") end
for group = 1, 10 do
    groups.focus(group)
    assert(laptop.active.id == group, "every desktop stays reachable on the laptop alone")
end
-- A Waybar click uses the same native workspace dispatch when undocked.
focus(4)
flush()
assert(laptop.active.id == 4)
local bottom = { name = "new-dock-port", description = "Bottom", active = workspace(15, laptop) }
monitors[2] = bottom
events["monitor.added"]()
flush()
assert(bottom.active.id == 14 and bottom.active.monitor == bottom, "dock connector renumbering retains the description's slot")
for id = 11, 20 do assert(persistence[id] == true, "redocking restores persistence on the new port") end
assert(windows[1].monitor == laptop, "redocking does not scatter merged windows")
print("PASS: synchronized navigation, focus, cursor, moves, wrap, special workspaces, undocking and redocking")
