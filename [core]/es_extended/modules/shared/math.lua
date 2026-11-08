ESX.Math = {}

function ESX.Math.Round(value, numDecimalPlaces)
    if numDecimalPlaces then
        local power = 10 ^ numDecimalPlaces
        return math.floor((value * power) + 0.5) / power
    else
        return math.floor(value + 0.5)
    end
end

-- Memoize locale digit grouping symbol (avoid _U() lookup on every GroupDigits call)
local groupingSymbol

-- credit http://richard.warburton.it
function ESX.Math.GroupDigits(value)
    local left, num, right = string.match(value, "^([^%d]*%d)(%d*)(.-)$")
    if not groupingSymbol then
        groupingSymbol = _U("locale_digit_grouping_symbol")
    end

    return left .. (num:reverse():gsub("(%d%d%d)", "%1" .. groupingSymbol):reverse()) .. right
end

function ESX.Math.Trim(value)
    if value then
        return (string.gsub(value, "^%s*(.-)%s*$", "%1"))
    else
        return nil
    end
end

function ESX.Math.Random(minRange, maxRange)
    return math.random(minRange or 1, maxRange or 10)
end

function ESX.Math.GetHeadingFromCoords(origin, target)
    return (math.deg(math.atan(target.y - origin.y, target.x - origin.x)) + 270) % 360
end
