function prefix(s)
    return "DestructiveBlueprints__" .. s
end

return {
    input = {
        force_place = prefix("input__force_place_blueprint")
    }
}
