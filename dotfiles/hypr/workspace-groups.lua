-- One numbered desktop across all outputs, using native per-output workspaces.
return function(preferredSlots)
    local groups, slots, used = {}, {}, {}
    local changing, queued, focusQueued = false, false, false
    local current = 1
    for description, slot in pairs(preferredSlots) do
        slots[description], used[slot] = slot, true
    end

    local function number(id) return (id - 1) % 10 + 1 end
    local function slotFor(monitor)
        local key = monitor.description
        if slots[key] == nil then
            local slot = 0
            while used[slot] do slot = slot + 1 end
            slots[key], used[slot] = slot, true
        end
        return slots[key]
    end
    local function workspaceFor(monitor, group)
        return slotFor(monitor) * 10 + group
    end

    function groups.focus(group)
        if changing then return end
        local focused = hl.get_active_monitor()
        if not focused then return end
        changing, current = true, group
        -- Changing monitor/workspace focus can warp the pointer. Restore it once.
        local cursor = hl.get_cursor_pos()
        for _, monitor in ipairs(hl.get_monitors()) do
            local id = workspaceFor(monitor, group)
            local active = hl.get_active_workspace(monitor)
            if not active or active.id ~= id then
                hl.dispatch(hl.dsp.focus({ workspace = id }))
            end
        end
        hl.dispatch(hl.dsp.focus({ monitor = focused }))
        hl.dispatch(hl.dsp.cursor.move({ x = cursor.x, y = cursor.y }))
        changing = false
    end

    function groups.step(delta)
        groups.focus((current - 1 + delta) % 10 + 1)
    end

    function groups.moveWindow(group)
        local window = hl.get_active_window()
        if not window or not window.monitor then return end
        hl.dispatch(hl.dsp.window.move({
            workspace = workspaceFor(window.monitor, group), window = window,
        }))
    end

    local function reconcile()
        queued, changing = false, true
        local monitors = hl.get_monitors()
        if #monitors == 0 then changing = false; return end
        local active = hl.get_active_workspace()
        if active and active.id > 0 then current = number(active.id) end
        local activeSlots = {}
        for _, monitor in ipairs(monitors) do activeSlots[slotFor(monitor)] = true end
        -- Retire the disconnected screens' empty persistent workspaces. Their
        -- windows are merged below before native workspace cleanup runs.
        for slot in pairs(used) do
            if not activeSlots[slot] then
                for group = 1, 10 do
                    hl.workspace_rule({ workspace = tostring(slot * 10 + group), persistent = false })
                end
            end
        end
        -- Adopt pre-existing workspaces and keep undocked windows reachable in
        -- the same numbered desktop on their surviving monitor.
        for _, window in ipairs(hl.get_windows()) do
            local workspace, monitor = window.workspace, window.monitor
            if workspace and workspace.id > 0 and monitor then
                local target = workspaceFor(monitor, number(workspace.id))
                if workspace.id ~= target then
                    hl.dispatch(hl.dsp.window.move({ workspace = target, window = window, follow = false }))
                end
            end
        end
        for _, monitor in ipairs(monitors) do
            for group = 1, 10 do
                local id = workspaceFor(monitor, group)
                hl.workspace_rule({ workspace = tostring(id), monitor = monitor.name, persistent = true })
                local workspace = hl.get_workspace(id)
                if workspace and workspace.monitor ~= monitor then
                    hl.dispatch(hl.dsp.workspace.move({ workspace = workspace, monitor = monitor }))
                end
            end
        end
        changing = false
        groups.focus(current)
    end
    local function scheduleReconcile()
        if queued then return end
        queued = true
        hl.timer(reconcile, { timeout = 50, type = "oneshot" })
    end
    hl.on("workspace.active", function(workspace)
        if changing or queued or not workspace or workspace.id <= 0 then return end
        current = number(workspace.id)
        if focusQueued then return end
        focusQueued = true
        -- Native dispatch is still processing the Waybar click/swipe here.
        -- Synchronize after it finishes rather than re-entering that operation.
        hl.timer(function()
            focusQueued = false
            if not queued then groups.focus(current) end
        end, { timeout = 1, type = "oneshot" })
    end)
    for _, event in ipairs({ "monitor.added", "monitor.removed", "config.reloaded" }) do
        hl.on(event, scheduleReconcile)
    end
    scheduleReconcile()
    return groups
end
