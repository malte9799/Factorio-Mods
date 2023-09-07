-- Blueprint Footprint
-- curvedRail.lua
local defaultCurve = {{0, 0, 0, 0, 0, 1, 0, 0}, {0, 0, 0, 0, 1, 1, 1, 0}, {0, 0, 0, 1, 1, 1, 0, 0},
                      {0, 0, 0, 1, 1, 1, 0, 0}, {0, 0, 1, 1, 1, 0, 0, 0}, {0, 0, 1, 1, 1, 0, 0, 0},
                      {0, 0, 1, 1, 0, 0, 0, 0}, {0, 0, 1, 1, 0, 0, 0, 0}}

local function flipLR(input)
    local out = table.deepcopy(input)
    for r = 1, 8 do
        for c = 1, 8 do
            out[r][c] = input[r][9 - c]
        end
    end
    return out
end

local function flipDiag(input)
    local out = table.deepcopy(input)
    for r = 1, 8 do
        for c = 1, 8 do
            out[r][c] = input[c][r]
        end
    end
    return out
end

curveMap = {}
curveMap[1] = defaultCurve
curveMap[6] = flipDiag(curveMap[1])
curveMap[3] = flipLR(curveMap[6])
curveMap[4] = flipDiag(curveMap[3])
curveMap[5] = flipLR(curveMap[4])
curveMap[2] = flipDiag(curveMap[5])
curveMap[7] = flipLR(curveMap[2])
curveMap[8] = flipDiag(curveMap[7])

function getCurveMask(dir)
    local out = {}
    local map = table.deepcopy(curveMap[dir])
    local index = 1
    for r = 1, 8 do
        for c = 1, 8 do
            if map[r][c] == 1 then
                out[index] = {
                    ["x"] = c - 5,
                    ["y"] = r - 5
                }
                index = index + 1
            end
        end
    end
    return out
end
