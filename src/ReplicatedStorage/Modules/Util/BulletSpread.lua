return function(iteminfo : {}, mmt : string, aiming : boolean, leaning : boolean) : number
    return iteminfo.BulletSpread[mmt] * (aiming == true and (1 - _G.CurrentI2.AimModifier) or 1) * (leaning == true and 5 or 1)
end