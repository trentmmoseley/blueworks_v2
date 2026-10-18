local ProxyGrabSettings = {
    KEYBINDS = {
        {
            Enum.KeyCode.A,
            Color3.fromRGB(0, 128, 255),
            1,
        },
        {
            Enum.KeyCode.S,
            Color3.fromRGB(255, 0, 255),
            1,
        },
        {
            Enum.KeyCode.D,
            Color3.fromRGB(0, 0, 255),
            1,
        },
        {
            Enum.KeyCode.W,
            Color3.fromRGB(255, 255, 0),
            1,
        },
        {
            Enum.KeyCode.Space,
            Color3.fromRGB(255, 128, 0),
            3.5,
        },
    },

    INITIAL_PROGRESS = 50,
    DRAIN_RATE = 10,
    DRAIN_ACCELERATION = 1,
    GOOD_BONUS = 7.5,
    BAD_PENALTY = 5,
}

return ProxyGrabSettings
