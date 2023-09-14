require("util")
require("__DestructiveBlueprints__.util.misc")
local bluelib = require("__DestructiveBlueprints__.util.blueprint")
local mathlib = require("__DestructiveBlueprints__.util.math")
local mod_defines = require("__DestructiveBlueprints__.mod_defines")

local transformList = {}
local defaultTransform = {
    rotation = 0,
    flip_horizontal = false,
    flip_vertical = false,
    translate = {
        x = 0,
        y = 0
    }
}

-- compares 2 entities
local function equals(e1, e2)
    return (e1.name == e2.name) and
               ((e1.direction or 0) == (e2.direction or 0) and
                   (e1.position.x == e2.position.x and e1.position.y == e2.position.y))

end

script.on_event('rotate', function(event)
    local player = game.players[event.player_index]
    local blueprint = bluelib.get_blueprint_on_cursor(player)

    if not blueprint then
        return
    end

    local transform = transformList[blueprint.item_number] or table.deepcopy(defaultTransform)
    local current = transform.rotation or 0
    local next = (current + 2) % 8
    transform.rotation = next
    transform.flip_horizontal, transform.flip_vertical = transform.flip_vertical, transform.flip_horizontal
    transformList[blueprint.item_number] = transform
end)
script.on_event('reverse-rotate', function(event)
    local player = game.players[event.player_index]
    local blueprint = bluelib.get_blueprint_on_cursor(player)
    if not blueprint then
        return
    end

    local transform = transformList[blueprint.item_number] or table.deepcopy(defaultTransform)
    local current = transform.rotation or 0
    local next = (current - 2) % 8
    if next < 0 then
        next = 8 + next
    end
    transform.rotation = next
    transform.flip_horizontal, transform.flip_vertical = transform.flip_vertical, transform.flip_horizontal
    transformList[blueprint.item_number] = transform
end)
script.on_event('flip-blueprint-horizontal', function(event)
    local player = game.players[event.player_index]
    local blueprint = bluelib.get_blueprint_on_cursor(player)
    if not blueprint then
        return
    end
    if not bluelib.can_be_flipped(blueprint) then
        return
    end

    local transform = transformList[blueprint.item_number] or table.deepcopy(defaultTransform)
    local current = transform.flip_horizontal or false
    transform.flip_horizontal = not current

    transformList[blueprint.item_number] = transform
end)
script.on_event('flip-blueprint-vertical', function(event)
    local player = game.players[event.player_index]
    local blueprint = bluelib.get_blueprint_on_cursor(player)
    if not blueprint then
        return
    end
    if not bluelib.can_be_flipped(blueprint) then
        return
    end

    local transform = transformList[blueprint.item_number] or table.deepcopy(defaultTransform)
    local current = transform.flip_vertical or false
    transform.flip_vertical = not current

    transformList[blueprint.item_number] = transform
end)

-- script.on_event(defines.events.on_pre_build, function(event)
--     game.print(serializeTable(event.direction))
-- end)

-- script.on_event(defines.events.on_player_rotated_entity, function(event)
--     -- game.print(serializeTable(event.entity.item_requests))
--     game.print(serializeTable(event.entity.get_module_inventory().get_contents()))
-- end)

script.on_event(mod_defines.input.force_place, function(event)
    local player = game.players[event.player_index]
    local pos = event.cursor_position
    local blueprint = bluelib.get_blueprint_on_cursor(player)
    if not (blueprint) then
        return
    end
    local original_blueprint_entities = table.deepcopy(blueprint.get_blueprint_entities())

    local transform = table.deepcopy(transformList[blueprint.item_number]) or table.deepcopy(defaultTransform)
    local center = bluelib.center(blueprint, transform)

    local snapped_pos
    if blueprint.blueprint_snap_to_grid and blueprint.blueprint_absolute_snapping then
        local offset = {
            x = 0,
            y = 0
        }
        if blueprint.blueprint_position_relative_to_grid then
            offset = blueprint.blueprint_position_relative_to_grid
        end

        local grid_size = blueprint.blueprint_snap_to_grid

        snapped_pos = {
            x = pos.x - math.fmod(pos.x - offset.x, grid_size.x),
            y = pos.y - math.fmod(pos.y - offset.y, grid_size.y)
        }
        if pos.x - offset.x <= 0 then
            snapped_pos.x = snapped_pos.x - grid_size.x
        end
        if pos.y - offset.y <= 0 then
            snapped_pos.y = snapped_pos.y - grid_size.y
        end

        snapped_pos.x = snapped_pos.x + grid_size.x / 2
        snapped_pos.y = snapped_pos.y + grid_size.y / 2

    else
        local center_offset
        if bluelib.contains_rails(blueprint) then
            center_offset = {
                x = math.fmod(center.x, 2),
                y = math.fmod(center.y, 2)
            }

            snapped_pos = {
                x = pos.x - math.fmod(pos.x + 1 - center_offset.x, 2) + mathlib.sign(pos.x),
                y = pos.y - math.fmod(pos.y + 1 - center_offset.y, 2) + mathlib.sign(pos.y)
            }
        else
            center_offset = {
                x = math.abs(math.fmod(center.x, 1)),
                y = math.abs(math.fmod(center.y, 1))
            }
            snapped_pos = {
                x = math.floor(pos.x + center_offset.x - 0.5) + 1 - center_offset.x,
                y = math.floor(pos.y + center_offset.y - 0.5) + 1 - center_offset.y
            }
        end
    end
    local offset = {
        x = snapped_pos.x - center.x,
        y = snapped_pos.y - center.y
    }

    transform.translate = offset
    local transformed_blueprint_entities = bluelib.transform(blueprint, snapped_pos, transform)
    blueprint.set_blueprint_entities(transformed_blueprint_entities)

    local positions, entityPositions = bluelib.get_positions(blueprint)

    -- positions = bluelib.translate(offset.x, offset.y, positions)
    -- entityPositions = bluelib.translate(offset.x, offset.y, entityPositions, true)

    -- draw_circle(snapped_pos)
    -- draw_circle(center, {0, 1, 1})

    local surface = player.surface
    local force = player.force
    for _, pos in ipairs(positions) do
        local x = math.floor(pos.x)
        local y = math.floor(pos.y)
        local offsets = {{0, 0}, {0.5, 0.5}, {1, 0}, {0, 1}, {1, 1}}

        local blueEntity = pos.entity
        blueEntity.position = entityPositions[pos.entity_number]

        -- game.print(blueEntity.direction)
        -- do
        --     return
        -- end

        local entities = {}
        for _, offset in ipairs(offsets) do
            for _, e in ipairs(surface.find_entities_filtered {
                position = {
                    x = x + offset[1],
                    y = y + offset[2]
                }
            }) do
                if e and e.unit_number then
                    entities[e.unit_number] = e
                end
            end
        end

        for _, entity in pairs(entities) do
            if entity and entity.valid and not entity.is_registered_for_deconstruction(force) then
                if equals(entity, blueEntity) then
                    if not (pos.x == entity.position.x and pos.y == entity.position.y) or not blueEntity.items then
                        break
                    end

                    local request_proxy = surface.find_entity("item-request-proxy", entity.position)
                    if request_proxy then
                        request_proxy.destroy {
                            raise_destroy = true
                        }
                    end

                    local module_inventory = entity.get_module_inventory()
                    local request_items = blueEntity.items
                    if module_inventory then
                        local count = #module_inventory
                        if count == 0 then
                            break
                        end
                        local remove = {}
                        for i = 1, count do
                            local module_stack = module_inventory[i]
                            if module_stack and module_stack.valid_for_read then
                                if request_items[module_stack.name] then
                                    local new = request_items[module_stack.name] - 1
                                    if new == 0 then
                                        request_items = table.removekey(request_items, module_stack.name)
                                    else
                                        request_items[module_stack.name] = new
                                    end
                                else
                                    local spilled = surface.spill_item_stack(entity.bounding_box.left_top, module_stack,
                                        true, player.force, false)
                                    if spilled[1] then
                                        module_stack.clear()
                                    end
                                end
                            end
                        end
                    end

                    if type(request_items) == 'table' then
                        surface.create_entity {
                            name = "item-request-proxy",
                            target = entity,
                            modules = request_items,
                            position = entity.position,
                            force = entity.force
                        }
                    end
                else
                    entity.order_deconstruction(force, event.player_index)
                end
            end
        end
    end

    blueprint.build_blueprint {
        surface = surface,
        force = force,
        position = event.cursor_position,
        by_player = event.player_index
    }

    blueprint.set_blueprint_entities(original_blueprint_entities)
end)
