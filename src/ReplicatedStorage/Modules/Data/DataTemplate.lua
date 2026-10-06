local DataTemplate   = {
    Keybinds         = {
        -- Movement
        Run          = {
            Keyboard = "LeftShift",
            Gamepad  = "ButtonL3"
        },
        Crouch       = {
            Keyboard = "C",
            Gamepad  = "ButtonB"
        },
        Crawl        = {
            Keyboard = "LeftControl",
            Gamepad  = "ButtonR3"
        },
        LeanRight    = {
            Keyboard = "E",
            Gamepad  = "DPadRight"
        },
        LeanLeft     = {
            Keyboard = "Q",
            Gamepad  = "DPadLeft"
        },

        -- Guns
        PointAim     = {
            Keyboard = "P",
            Gamepad  = "ButtonL1"
        },
        Reload       = {
            Keyboard = "R",
            Gamepad  = "ButtonX"
        },
        
        -- Chat
        ToggleRadio  = {
            Keyboard = "LeftAlt",
        },
        ChatToggle   = {
            Keyboard = "Slash",
        },

        -- Misc.
        Drop         = {
            Keyboard = "X",
        }
    },

    Client           = {
        doPerfStats  = true,
    }
}

return DataTemplate