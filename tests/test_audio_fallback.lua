-- Execute the pinned WirePlumber default-selection hooks with device fixtures.
local scripts = assert(arg[1])
local hooks, configured = {}, {}
Log = {open_topic=function() return {} end}
Constraint = function(value) return value end
EventInterest = function(value) return value end
SimpleEventHook = function(hook)
    hook.register = function(self) hooks[self.name] = self.execute end
    return hook
end
package.preload["node-utils"] = function()
    return {
        get_session_priority=function(props) return props["priority.session"] or 0 end,
        get_route_priority=function(props) return props["route.priority"] or 0 end,
    }
end
Json = {Raw=function(name) return {parse=function() return {name=name} end} end}
dofile(scripts .. "/default-nodes/find-selected-default-node.lua")
dofile(scripts .. "/default-nodes/find-best-default-node.lua")
local sinkName = "alsa_output.usb-RODE_Microphones_RODE_AI-1_13164FAA-00.analog-stereo"
local sourceName = "alsa_input.usb-RODE_Microphones_RODE_AI-1_13164FAA-00.mono-fallback"
configured["audio.sink"], configured["audio.source"] = sinkName, sourceName
local speaker = { ["node.name"]="laptop-speakers", ["media.class"]="Audio/Sink", ["priority.session"]=1000 }
local mic = { ["node.name"]="laptop-microphone", ["media.class"]="Audio/Source", ["priority.session"]=2000 }
local rodeSink = { ["node.name"]=sinkName, ["media.class"]="Audio/Sink", ["priority.session"]=1450 }
local rodeSource = { ["node.name"]=sourceName, ["media.class"]="Audio/Source", ["priority.session"]=2450 }
local metadata = {find=function(_, _, key) return configured[key:gsub("default.configured.", "", 1)] end}
local manager = {lookup=function() return metadata end}
local owner = {call=function() return manager end}
local function selectDefault(kind, available)
    local data = {["available-nodes"]={parse=function() return available end}}
    local event = {
        get_data=function(_, key) return data[key] end,
        set_data=function(_, key, value) data[key] = value end,
        get_source=function() return owner end,
        get_properties=function() return {["default-node.type"]=kind} end,
    }
    hooks["default-nodes/find-selected-default-node"](event)
    hooks["default-nodes/find-best-default-node"](event)
    return data["selected-node"]
end
for _ = 1, 3 do
    assert(selectDefault("audio.sink", {speaker, rodeSink}) == sinkName, "prefer attached RODE output")
    assert(selectDefault("audio.source", {mic, rodeSource}) == sourceName, "prefer attached RODE input")
    assert(selectDefault("audio.sink", {speaker}) == "laptop-speakers", "missing saved USB output must fall back")
    assert(selectDefault("audio.source", {mic}) == "laptop-microphone", "missing saved USB input must fall back")
end
assert(selectDefault("audio.source", {speaker, mic}) == "laptop-microphone", "speaker monitor must not replace the real microphone")
configured["audio.sink"] = "laptop-speakers"
assert(selectDefault("audio.sink", {speaker, rodeSink}) == "laptop-speakers", "preserve a later deliberate user choice")
print("PASS: pinned audio policy falls back on undock, returns on redock and respects manual choices")
