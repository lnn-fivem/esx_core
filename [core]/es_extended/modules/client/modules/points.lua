local points = {}

function ESX.CreatePointInternal(coords, distance, hidden, enter, leave)
    local point = {
        coords = coords,
        distance = distance,
        hidden = hidden,
        enter = enter,
        leave = leave,
    }
    local handle = tostring(point)
    points[handle] = point
    return handle
end

function ESX.RemovePointInternal(handle)
    local point = points[handle]
    if not point then
        return
    end
    points[handle] = nil
    if point.nearby then
        point.leave()
    end
end

function ESX.HidePointInternal(handle, hidden)
    local point = points[handle]
    if not point then
        return
    end
    point.hidden = hidden
    if hidden and point.nearby then
        point.nearby = false
        point.leave()
    end
end

CreateThread(function()
    while true do
        Wait(500)
        local coords = GetEntityCoords(ESX.PlayerData.ped)
        for _, point in pairs(points) do
            local inside = not point.hidden and #(coords - point.coords) <= point.distance
            if inside and not point.nearby then
                point.nearby = true
                point.enter()
            elseif not inside and point.nearby then
                point.nearby = false
                point.leave()
            end
        end
    end
end)

AddEventHandler("onResourceStop", function(resource)
    for handle, point in pairs(points) do
        if point.resource == resource then
            ESX.RemovePointInternal(handle)
        end
    end
end)
