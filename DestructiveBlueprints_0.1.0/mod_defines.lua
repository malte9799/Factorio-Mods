function prefix(s)
    return "DestructiveBlueprints__" .. s
end

return {
    sprite_path = function(path)
        return "__DestructiveBlueprints__/graphics/" .. path
    end,
    input = {
        force_place = prefix("input__force_place_blueprint")
    }
}
