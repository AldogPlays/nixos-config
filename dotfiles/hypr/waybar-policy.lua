-- Per-output visibility and tray pinning share one event-driven policy.
return function(systemctl)
    -- Each bar follows the windows visible on its own monitor, independent of focus.
    -- A runtime manifest plus an explicit signal avoids global toggle races.
    local waybarUpdateQueued = false
    local waybarSignalPending = false
    local waybarDirty = false
    local waybarTrayPinnedMonitor = nil
    local scheduleWaybarVisibility
    local function updateWaybarVisibility()
        local wanted, states, changed = {}, {}, false
        for _, monitor in ipairs(hl.get_monitors()) do
            local normal = hl.get_active_workspace(monitor)
            local special = hl.get_active_special_workspace(monitor)
            local show = waybarTrayPinnedMonitor == monitor.name
            for _, window in ipairs(hl.get_windows({ monitor = monitor })) do
                if window.mapped and not window.hidden and window.workspace and
                    (window.pinned or (normal and window.workspace.id == normal.id) or
                        (special and window.workspace.id == special.id)) then
                    show = true
                    break
                end
            end
            wanted[monitor.name] = show
            states[#states + 1] = string.format("%q:%s", monitor.name, tostring(show))
        end
        for _, layer in ipairs(hl.get_layers()) do
            if layer.mapped and layer.namespace == "waybar" and layer.monitor then
                local visible = layer.layer == 2 -- zwlr_layer_shell_v1 top
                if wanted[layer.monitor.name] ~= nil and wanted[layer.monitor.name] ~= visible then
                    changed = true
                end
            end
        end
        if not changed then return end
        local runtime = os.getenv("XDG_RUNTIME_DIR")
        if not runtime then return end
        local path = runtime .. "/waybar-output-visibility.json"
        local file = io.open(path .. ".tmp", "w")
        if not file then return end
        file:write("{" .. table.concat(states, ",") .. "}\n")
        file:close()
        if not os.rename(path .. ".tmp", path) then return end
        waybarSignalPending = true
        hl.dispatch(hl.dsp.exec_cmd(systemctl .. " --user kill --kill-whom=main --signal=SIGRTMIN+10 waybar.service"))
        hl.timer(function()
            waybarSignalPending = false
            if waybarDirty then
                waybarDirty = false
                scheduleWaybarVisibility()
            end
        end, { timeout = 100, type = "oneshot" })
    end
    scheduleWaybarVisibility = function()
        if waybarSignalPending then waybarDirty = true; return end
        if waybarUpdateQueued then return end
        waybarUpdateQueued = true
        hl.timer(function()
            waybarUpdateQueued = false
            updateWaybarVisibility()
        end, { timeout = 20, type = "oneshot" })
    end
    for _, event in ipairs({
        "window.open", "window.close", "window.destroy", "window.active",
        "window.move_to_workspace", "window.update_rules", "window.pin", "workspace.active",
        "monitor.focused", "monitor.added", "monitor.removed", "config.reloaded",
    }) do
        hl.on(event, scheduleWaybarVisibility)
    end
    for _, event in ipairs({ "layer.opened", "layer.closed" }) do
        hl.on(event, function(layer)
            if layer and layer.namespace == "waybar" then
                scheduleWaybarVisibility()
            end
        end)
    end
    scheduleWaybarVisibility()

    local function toggleTray()
        local monitor = hl.get_active_monitor()
        if not monitor then return end
        waybarTrayPinnedMonitor = waybarTrayPinnedMonitor ~= monitor.name and monitor.name or nil
        scheduleWaybarVisibility()
        local signal = waybarTrayPinnedMonitor and "SIGRTMIN+8" or "SIGRTMIN+9"
        hl.dispatch(hl.dsp.exec_cmd(systemctl .. " --user kill --kill-whom=main --signal=" .. signal .. " waybar.service"))
    end
    return { toggleTray = toggleTray }
end
