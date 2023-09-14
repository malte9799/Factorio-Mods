local mod_defines = require("__DestructiveBlueprints__.mod_defines")

local force_place = {
    type = "custom-input",
    name = mod_defines.input.force_place,
    key_sequence = "CONTROL + mouse-button-1"
}

local rotate = {
    type = "custom-input",
    name = "rotate",
    key_sequence = "",
    linked_game_control = "rotate"
}
local reverse_rotate = {
    type = "custom-input",
    name = "reverse-rotate",
    key_sequence = "",
    linked_game_control = "reverse-rotate"
}
local flip_blueprint_horizontal = {
    type = "custom-input",
    name = "flip-blueprint-horizontal",
    key_sequence = "",
    linked_game_control = "flip-blueprint-horizontal"
}
local flip_blueprint_vertical = {
    type = "custom-input",
    name = "flip-blueprint-vertical",
    key_sequence = "",
    linked_game_control = "flip-blueprint-vertical"
}
data:extend{force_place, rotate, reverse_rotate, flip_blueprint_horizontal, flip_blueprint_vertical}
