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
        
        -- Chat
        ToggleRadio  = {
            Keyboard = "LeftAlt",
        },
        ChatToggle   = {
            Keyboard = "Slash",
        },
    },

    Client           = {
        doPerfStats  = true,
    }
}

return DataTemplate