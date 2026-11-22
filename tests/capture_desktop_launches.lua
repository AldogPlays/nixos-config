-- Load the complete generated compositor configuration at the Hyprland boundary.
local bindings, rules = {}, {}
local function noop() end
local dispatchers = setmetatable({}, {__index = function() return noop end})
hl = setmetatable({
    bind = function(key, action) bindings[key] = action end,
    window_rule = function(rule) rules[#rules + 1] = rule end,
    dsp = setmetatable({exec_cmd = function(command) return command end,
        window = dispatchers, cursor = dispatchers}, {__index = function() return noop end}),
    plugin = {load = noop},
    get_monitors = function() return {} end,
    get_windows = function() return {} end,
    timer = noop,
}, {__index = function() return noop end})
dofile(arg[1])
local output = assert(io.open(arg[2], 'w'))
for _, key in ipairs({'SUPER + SHIFT + N', 'SUPER + SHIFT + B', 'SUPER + SHIFT + A', 'SUPER + Escape', 'SUPER + T'}) do
    output:write(key, '\t', assert(bindings[key]), '\n')
end
for _, rule in ipairs(rules) do
    if rule.name == 'float-system-controls' then output:write('float\t', rule.match.class, '\n') end
end
output:close()
