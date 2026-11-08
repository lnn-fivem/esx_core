---@class xVehicle
---@field entity number
---@field netId number
---@field owner string?
---@field group string?
---@field script string
---@field plate string
---@field model string|number
---@field modelHash number
---@field variables table
---@field set fun(key: string, value: any)
---@field get fun(key?: string): any
---@field delete fun(removeFromDb?: boolean)
---@field setCoords fun(coords: vector3|vector4|table)
---@field getCoords fun(vector?: boolean): vector4|table
---@field setOwner fun(owner?: string)
---@field setGroup fun(group?: string)
---@field setPlate fun(plate: string)

AddEventHandler("entityRemoved", function(entity)
    local xVehicle = Core.vehicles[entity]
    if not xVehicle then
        return
    end

    TriggerEvent("esx:vehicleRemoved", xVehicle.entity, xVehicle.netId, xVehicle)
    Core.vehicles[entity] = nil
end)

---@param entity number
---@param netId number
---@param model string|number
---@param modelHash number
---@param coords vector4
---@param script string
---@return xVehicle
function CreateExtendedVehicle(entity, netId, model, modelHash, coords, script)
    local self = {}

    self.entity = entity
    self.netId = netId
    self.owner = nil
    self.group = nil
    self.script = script
    self.plate = ESX.Math.Trim(GetVehicleNumberPlateText(self.entity))
    self.model = model
    self.modelHash = modelHash
    self.coords = coords
    self.variables = {}

    local stateBag = Entity(self.entity).state
    stateBag:set("model", self.model, false)
    stateBag:set("plate", self.plate, false)

    function self.set(key, value)
        self.variables[key] = value
        stateBag:set(key, value, false)
    end

    function self.get(key)
        if not key then
            return self.variables
        end
        return self.variables[key]
    end

    function self.delete(removeFromDb)
        if DoesEntityExist(self.entity) then
            DeleteEntity(self.entity)
        end

        if removeFromDb then
            MySQL.prepare("DELETE FROM `owned_vehicles` WHERE `plate` = ?", { self.plate })
        end
    end

    function self.setCoords(coordinates)
        local ped <const> = self.entity
        if not DoesEntityExist(ped) then
            return
        end

        local vector = type(coordinates) == "vector4" and coordinates
            or type(coordinates) == "vector3" and vector4(coordinates, 0.0)
            or vec(coordinates.x, coordinates.y, coordinates.z, coordinates.heading or 0.0)
        SetEntityCoords(ped, vector.xyz, false, false, false, false)
        SetEntityHeading(ped, vector.w)
    end

    function self.getCoords(vector)
        if DoesEntityExist(self.entity) then
            local coordinates = GetEntityCoords(self.entity)
            local heading = GetEntityHeading(self.entity)
            self.coords = { x = coordinates.x, y = coordinates.y, z = coordinates.z, heading = heading }
        end

        if vector then
            return vector4(self.coords.x, self.coords.y, self.coords.z, self.coords.heading)
        end

        return self.coords
    end

    function self.setOwner(owner)
        self.owner = owner
        stateBag:set("owner", self.owner, true)
    end

    function self.setGroup(group)
        self.group = group
        stateBag:set("group", self.group, true)
    end

    function self.setPlate(plate)
        self.plate = ("% -8s"):format(plate)
        SetVehicleNumberPlateText(self.entity, self.plate)
        stateBag:set("plate", self.plate, false)
    end

    TriggerEvent("esx:vehicleCreated", self.entity, self.netId, self)

    return self
end
