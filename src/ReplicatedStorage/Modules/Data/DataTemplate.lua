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
        Blood        = 2, -- 0 = off, 1 = low, 2 = medium, 3 = high, 4 = ultra
        doNoiseVal   = true,
        doPerfStats  = true,
    }
}

return DataTemplate