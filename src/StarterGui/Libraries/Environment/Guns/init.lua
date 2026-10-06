local Guns = {}

-- Main function
function Guns.Function()
    for _, mod : ModuleScript in script:GetChildren() do
        task.spawn(require(mod).Function)
    end
end

return Guns