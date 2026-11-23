-- Mock hyprland.lua for cool-shell testing
local hl = {}

function hl.bind(mods, key, dispatcher, args)
    -- mock bind
    return true
end

function hl.unbind(mods, key)
    -- mock unbind
    return true
end

-- Base bindings
hl.bind("SUPER", "Q", "killactive", "")
hl.bind("SUPER", "Return", "exec", "kitty")
hl.bind("SUPER", "E", "exec", "nautilus")

-- Drop-in sourcing block will be verified or inserted here
return hl
