local mathlib = require("__DestructiveBlueprints__.util.math")
local curvedRail = require("__DestructiveBlueprints__.util.curvedRail")

require("__DestructiveBlueprints__.util.misc")

local module = {}

-- Determine whether the blueprint contains rails and/or train stops.
function module.contains_rails(blueprint)
    for _, ent in pairs(blueprint.get_blueprint_entities() or {}) do
        if ent.name == "straight-rail" or ent.name == "curved-rail" or ent.name == "train-stop" then
            return true
        end
    end
    return false
end

local function rotate_box(x_left, x_right, y_top, y_bottom, direction)
    if direction == 0 or direction == 4 then
        return x_left, x_right, y_top, y_bottom
    elseif direction == 2 or direction == 6 then
        return y_top, y_bottom, x_left, x_right

        -- These are mainly designed for curved rails, will likely break for other 8-way entities
    elseif direction == 1 or direction == 5 then
        return x_left, x_right, y_top, y_bottom
    elseif direction == 3 or direction == 7 then
        return y_top, y_bottom, x_left, x_right

    else
        assert(direction < 8 and direction >= 0, "Unknown direction: " .. direction)
    end
end

-- Compute the bounding box for entities and tiles in the blueprint,
-- in the blueprint's internal coordinate frame.
function module.dimensions(blueprint, transform)
    local x_min = nil
    local x_max = nil
    local y_min = nil
    local y_max = nil

    for _, ent in pairs(blueprint.get_blueprint_entities() or {}) do
        local prots = game.get_filtered_entity_prototypes {{
            filter = "name",
            name = ent.name
        }}

        local box = prots[ent.name].secondary_collision_box or prots[ent.name].selection_box

        local x_left = box.left_top.x
        local x_right = box.right_bottom.x
        local y_top = box.left_top.y
        local y_bottom = box.right_bottom.y

        local rotation = ((ent.direction or 0) + transform.rotation) % 8
        x_left, x_right, y_top, y_bottom = rotate_box(x_left, x_right, y_top, y_bottom, rotation)

        local x_lo = ent.position.x + x_left
        local x_hi = ent.position.x + x_right
        local y_lo = ent.position.y + y_top
        local y_hi = ent.position.y + y_bottom

        x_min = math.min(x_lo, x_min or x_lo)
        x_max = math.max(x_hi, x_max or x_hi)
        y_min = math.min(y_lo, y_min or y_lo)
        y_max = math.max(y_hi, y_max or y_hi)
    end

    for _, ent in pairs(blueprint.get_blueprint_tiles() or {}) do
        local x_lo = ent.position.x
        local x_hi = ent.position.x + 1
        local y_lo = ent.position.y
        local y_hi = ent.position.y + 1

        x_min = math.min(x_lo, x_min or x_lo)
        x_max = math.max(x_hi, x_max or x_hi)
        y_min = math.min(y_lo, y_min or y_lo)
        y_max = math.max(y_hi, y_max or y_hi)
    end

    if module.contains_rails(blueprint) then
        x_min = mathlib.floor2(x_min)
        x_max = mathlib.ceil2(x_max)
        y_min = mathlib.floor2(y_min)
        y_max = mathlib.ceil2(y_max)
    else
        x_min = math.floor(x_min)
        x_max = math.ceil(x_max)
        y_min = math.floor(y_min)
        y_max = math.ceil(y_max)
    end

    -- x_min, x_max, y_min, y_max = rotate_box(x_min, x_max, y_min, y_max, transform.rotation)
    -- draw_box(x_min, y_min, x_max, y_max)

    return x_min, y_min, x_max - x_min, y_max - y_min
end

-- The blueprint center is the coordinate within the blueprint's internal coordinate frame
-- which the game attempts to keep as close as possible to the cursor
-- while placing the blueprint.
-- This may, in each axis,
-- be a half-number if the blueprint centers around a tile center,
-- or an integer if the blueprint centers around a tile edge.
-- If the blueprint contains rails or train stops, both coordinates will be integers.
function module.center(blueprint, transform)
    if blueprint.blueprint_snap_to_grid and blueprint.blueprint_absolute_snapping then
        if blueprint.blueprint_position_relative_to_grid then
            offset = blueprint.blueprint_position_relative_to_grid
        else
            offset = {
                x = 0,
                y = 0
            }
        end
        local x = blueprint.blueprint_snap_to_grid.x / 2
        local y = blueprint.blueprint_snap_to_grid.y / 2
        return {
            x = x,
            y = y
        }
    else
        local x_min, y_min, w, h = module.dimensions(blueprint, transform)
        local cx, cy = x_min + w / 2, y_min + h / 2
        if module.contains_rails(blueprint) then
            return {
                x = mathlib.round(cx),
                y = mathlib.round(cy)
            }
        else
            return {
                x = cx,
                y = cy
            }
        end
    end
end

-- Transform a world-coordinate into a coordinate relative to the absolute blueprint grid,
-- respecting blueprint rotation and/or flipping.
-- Undefined behaviour if blueprint has no grid size set.
function module.world_to_blueprint_frame(x, y, direction, flip_x, flip_y, blueprint)
    assert(blueprint.blueprint_snap_to_grid, "Blueprint must have grid size set.")

    local grid_x0 = (blueprint.blueprint_position_relative_to_grid or {
        x = 0
    }).x
    local grid_y0 = (blueprint.blueprint_position_relative_to_grid or {
        y = 0
    }).y

    local grid_w = blueprint.blueprint_snap_to_grid.x
    local grid_h = blueprint.blueprint_snap_to_grid.y

    local bx, by = 0, 0

    if direction == 0 then
        -- grid origin is top-left
        bx = (((x - grid_x0) % grid_w) + grid_w) % grid_w
        by = (((y - grid_y0) % grid_h) + grid_h) % grid_h

    elseif direction == 2 then
        -- grid origin is top-right
        bx = (((y - grid_y0) % grid_h) + grid_h) % grid_h
        by = (((grid_x0 - x) % grid_w) + grid_w) % grid_w

    elseif direction == 4 then
        -- grid origin is bottom-right
        bx = (((grid_x0 - x) % grid_w) + grid_w) % grid_w
        by = (((grid_y0 - y) % grid_h) + grid_h) % grid_h

    else
        -- grid origin is bottom-left
        bx = (((grid_y0 - y) % grid_h) + grid_h) % grid_h
        by = (((x - grid_x0) % grid_w) + grid_w) % grid_w
    end

    local swap_dims = direction == 2 or direction == 6
    if flip_x then
        bx = (swap_dims and grid_h or grid_w) - bx
    end
    if flip_y then
        by = (swap_dims and grid_w or grid_h) - by
    end

    return bx, by
end

local function is_valid_slot(slot, state)

    if not slot or not slot.valid_for_read then
        return false
    end

    -- if state then
    if state == "empty" then
        return not slot.is_blueprint_setup()
    elseif state == "setup" then
        return slot.is_blueprint_setup()
    end
    -- end
    return true
end

-- rotate bounding box 90° cw
local function rotate_box_90(box)
    return {
        left_top = {
            x = -box.right_bottom.y,
            y = box.left_top.x
        },
        right_bottom = {
            x = -box.left_top.y,
            y = box.right_bottom.x
        }
    }
end

-- local function rotate(positions, center, direction)
--     -- local rotatedPoints = {}
--     for _, pos in ipairs(positions) do
--         local offset_x = pos.x - center.x
--         local offset_y = pos.y - center.y

--         if rotation == 0 then
--             new_x = pos.x
--             new_y = pos.y
--         elseif rotation == 1 then
--             new_x = center.x - offset_y
--             new_y = center.y + offset_x
--         elseif rotation == 2 then
--             new_x = center.x - offset_x
--             new_y = center.y - offset_y
--         elseif rotation == 3 then
--             new_x = center.x + offset_y
--             new_y = center.y - offset_x
--         else
--             error("Invalid rotation value. Use 0, 1, 2, or 3.")
--         end

--         -- local newPos = rotate_point_90(pos, center, transform.rotation / 2)
--         positions[_].x = new_x
--         positions[_].y = new_y

--         -- table.insert(rotatedPoints, {
--         --     x = newPos.x,
--         --     y = newPos.y,
--         --     entity_number = pos.entity_number,
--         --     entity = pos.entity
--         -- })
--     end
--     return positions
--     -- positions = rotatedPoints
-- end

local function flip(positions, center, axies)
end

local flip_x_table = {
    [0] = 1,
    [1] = 0,
    [2] = 7,
    [3] = 6,
    [4] = 5,
    [5] = 4,
    [6] = 3,
    [7] = 2
}
local flip_y_table = {
    [0] = 5,
    [1] = 4,
    [2] = 3,
    [3] = 2,
    [4] = 1,
    [5] = 0,
    [6] = 7,
    [7] = 6
}
function module.transform(blueprint, center, transform)
    local entities = blueprint.get_blueprint_entities()
    -- local bp_copy = blueprint
    local bp_copy = {}
    local rotation = transform.rotation
    local flip_x = transform.flip_horizontal
    local flip_y = transform.flip_vertical

    for i, ent in ipairs(entities) do
        local pos = ent.position
        if transform.translate then
            pos.x = pos.x + transform.translate.x
            pos.y = pos.y + transform.translate.y
        end

        ent.direction = ent.direction or 0

        -- rotation
        local offset_x = pos.x - center.x
        local offset_y = pos.y - center.y
        if rotation == 0 then
            pos.x = pos.x
            pos.y = pos.y
        elseif rotation == 2 then
            pos.x = center.x - offset_y
            pos.y = center.y + offset_x
        elseif rotation == 4 then
            pos.x = center.x - offset_x
            pos.y = center.y - offset_y
        elseif rotation == 6 then
            pos.x = center.x + offset_y
            pos.y = center.y - offset_x
        end
        ent.direction = (ent.direction + rotation) % 8

        -- Flipping
        local offset_x = pos.x - center.x
        local offset_y = pos.y - center.y
        if flip_x then
            pos.x = center.x - offset_x
            if ent.name == 'straight-rail' and ent.direction % 2 == 1 then
                local amount = (ent.direction == 7 or ent.direction == 3) and 2 or -2
                ent.direction = ent.direction + amount
            elseif ent.name == 'curved-rail' then
                ent.direction = flip_x_table[ent.direction]
            elseif ent.direction == 2 or ent.direction == 6 then
                ent.direction = ent.direction + 4
            end
        end
        ent.direction = ent.direction % 8

        if flip_y then
            pos.y = center.y - offset_y
            if ent.name == 'straight-rail' and ent.direction % 2 == 1 then
                local amount = (ent.direction == 7 or ent.direction == 3) and -2 or 2
                ent.direction = amount + ent.direction
            elseif ent.name == 'curved-rail' then
                ent.direction = flip_y_table[ent.direction]
            elseif ent.direction == 0 or ent.direction == 4 then
                ent.direction = 4 + ent.direction
            end
        end
        ent.direction = ent.direction % 8

        ent.position = pos
        table.insert(bp_copy, ent)
        -- bp_copy[_] = ent
    end
    return bp_copy
end

function module.get_blueprint_on_cursor(player)

    local stack = player.cursor_stack
    if stack.valid_for_read then
        if (stack.type == "blueprint" and is_valid_slot(stack, 'setup')) then
            return stack
        elseif stack.type == "blueprint-book" then
            local recusive_safe = 10
            while stack.type == "blueprint-book" and recusive_safe > 0 do
                recusive_safe = recusive_safe - 1
                stack = stack.get_inventory(defines.inventory.item_main)[stack.active_index]
            end
            if recusive_safe == 0 then
                return false
            end

            -- local active =
            --     stack.get_inventory(defines.inventory.item_main)[stack.active_index]
            if is_valid_slot(stack, 'setup') then
                return stack
            end
        end
    else
        local entities = player.get_blueprint_entities()
        if not entities then
            return false
        end
        player.clear_cursor()
        stack.set_stack("blueprint")
        player.cursor_stack_temporary = true
        stack.set_blueprint_entities(entities)
        -- return stack
    end
    return false
end

function module.get_positions(blueprint)
    local entities = blueprint.get_blueprint_entities()

    local protos = {}
    local positions = {}
    local entityPositions = {}

    if not entities then
        return
    end

    for k = 1, #entities, 1 do
        local name = entities[k].name
        if protos[name] == nil then
            protos[name] = game.entity_prototypes[name]
            local proto_type = protos[name].type
        end
    end

    for i, ent in ipairs(entities) do
        local name = ent.name
        entityPositions[ent.entity_number] = ent.position
        if "curved-rail" ~= name then
            local box = protos[name].collision_box or protos[name].selection_box -- 
            local pos = ent.position

            if protos[ent.name].collision_mask["ground-tile"] == nil then

                if ent.direction ~= defines.direction.north and ent.direction ~= nil then
                    box = rotate_box_90(box)
                    if ent.direction == defines.direction.south or ent.direction == defines.direction.west then
                        box = rotate_box_90(box)
                        if ent.direction == defines.direction.west then
                            box = rotate_box_90(box)
                        end
                    end
                end

                local start_x = math.floor(pos.x + box.left_top.x)
                local start_y = math.floor(pos.y + box.left_top.y)
                local end_x = math.floor(pos.x + box.right_bottom.x)
                local end_y = math.floor(pos.y + box.right_bottom.y)

                for y = start_y, end_y, 1 do
                    for x = start_x, end_x, 1 do
                        table.insert(positions, {
                            x = x + 0.5,
                            y = y + 0.5,
                            entity_number = ent.entity_number,
                            entity = ent
                        })
                    end
                end
            end
        else
            local dir = ent.direction
            if dir == nil then
                dir = 8
            end
            local curveMask = getCurveMask(dir)
            local pos = ent.position
            for m = 1, #curveMask do
                local x = curveMask[m].x + pos.x
                local y = curveMask[m].y + pos.y
                table.insert(positions, {
                    x = x + 0.5,
                    y = y + 0.5,
                    entity_number = ent.entity_number,
                    entity = ent
                })

            end
        end
    end

    return positions, entityPositions
end

-- function module.translate(dx, dy, list, keepindex)
--     keepindex = keepindex or false
--     local newList = {}
--     for _, pos in pairs(list) do
--         if keepindex then
--             newList[_] = {
--                 x = pos.x + dx,
--                 y = pos.y + dy
--             }
--         else
--             table.insert(newList, {
--                 x = pos.x + dx,
--                 y = pos.y + dy,
--                 entity_number = pos.entity_number,
--                 entity = pos.entity
--             })
--         end
--     end
--     return newList
-- end

local non_flip_list = {
    ['train-stop'] = true,
    ['pumpjack'] = true,
    ['burner-mining-drill'] = true,
    ['oil-refinery'] = true,
    ['chemical-plant'] = true,
    ['rail-signal'] = true,
    ['rail-chain-signal'] = true
}
function module.can_be_flipped(blueprint)
    for _, ent in pairs(blueprint.get_blueprint_entities() or {}) do
        if non_flip_list[ent.name] then
            return false
        end
    end
    return true
end

return module
