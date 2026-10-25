return function(amount : number, singular : string, plural : string) : string
    return math.abs(amount) == 1 and singular or plural
end
