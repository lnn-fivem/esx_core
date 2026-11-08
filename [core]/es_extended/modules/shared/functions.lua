-- Seed RNG once at boot time (instead of calling math.randomseed(GetGameTimer()) per call)
math.randomseed(GetGameTimer())

local Charset = {}
for i = 48, 57 do
    Charset[#Charset + 1] = string.char(i)
end
for i = 65, 90 do
    Charset[#Charset + 1] = string.char(i)
end
for i = 97, 122 do
    Charset[#Charset + 1] = string.char(i)
end
local CharsetCount <const> = #Charset

local weaponsByName = {}
local weaponsByHash = {}

CreateThread(function()
    for index, weapon in pairs(Config.Weapons) do
        weaponsByName[weapon.name] = index
        weaponsByHash[joaat(weapon.name)] = weapon
    end
end)

---@param length number
---@return string
function ESX.GetRandomString(length)
    if length <= 0 then
        return ""
    end
    local buf = {}
    for i = 1, length do
        buf[i] = Charset[math.random(1, CharsetCount)]
    end
    return table.concat(buf)
end

function ESX.GetConfig(key)
    return key ~= nil and Config[key] or Config
end

function ESX.GetWeapon(weaponName)
    weaponName = string.upper(weaponName)

    assert(weaponsByName[weaponName], "Invalid weapon name!")

    local index = weaponsByName[weaponName]
    return index, Config.Weapons[index]
end

function ESX.GetWeaponFromHash(weaponHash)
    weaponHash = type(weaponHash) == "string" and joaat(weaponHash) or weaponHash

    return weaponsByHash[weaponHash]
end

function ESX.GetWeaponList(byHash)
    return byHash and weaponsByHash or Config.Weapons
end

function ESX.GetWeaponLabel(weaponName)
    weaponName = string.upper(weaponName)

    assert(weaponsByName[weaponName], "Invalid weapon name!")

    local index = weaponsByName[weaponName]
    return Config.Weapons[index].label or ""
end

function ESX.GetWeaponComponent(weaponName, weaponComponent)
    weaponName = string.upper(weaponName)

    assert(weaponsByName[weaponName], "Invalid weapon name!")
    local weapon = Config.Weapons[weaponsByName[weaponName]]

    for _, component in ipairs(weapon.components) do
        if component.name == weaponComponent then
            return component
        end
    end
end

function ESX.DumpTable(table, nb)
    if nb == nil then
        nb = 0
    end

    if type(table) == "table" then
        local s = ""
        for _ = 1, nb + 1, 1 do
            s = s .. "    "
        end

        s = "{\n"
        for k, v in pairs(table) do
            if type(k) ~= "number" then
                k = '"' .. k .. '"'
            end
            for _ = 1, nb, 1 do
                s = s .. "    "
            end
            s = s .. "[" .. k .. "] = " .. ESX.DumpTable(v, nb + 1) .. ",\n"
        end

        for _ = 1, nb, 1 do
            s = s .. "    "
        end

        return s .. "}"
    else
        return tostring(table)
    end
end

function ESX.Round(value, numDecimalPlaces)
    return ESX.Math.Round(value, numDecimalPlaces)
end

function ESX.ValidateType(value, ...)
    local types = { ... }
    if #types == 0 then
        return true
    end

    local mapType = {}
    for i = 1, #types, 1 do
        local validateType = types[i]
        assert(type(validateType) == "string", "bad argument types, only expected string")
        mapType[validateType] = true
    end

    local valueType = type(value)

    local matches = mapType[valueType] ~= nil

    if not matches then
        local requireTypes = table.concat(types, " or ")
        local errorMessage = ("bad value (%s expected, got %s)"):format(requireTypes, valueType)

        return false, errorMessage
    end

    return true
end

function ESX.AssertType(...)
    local matches, errorMessage = ESX.ValidateType(...)

    assert(matches, errorMessage)

    return matches
end

function ESX.IsFunctionReference(val)
    local typeVal = type(val)

    return typeVal == "function" or (typeVal == "table" and type(getmetatable(val)?.__call) == "function")
end

---@param conditionFunc function A function that is repeatedly called until it returns a truthy value or the timeout is exceeded.
---@param errorMessage? string Optional. If set, an error will be thrown with this message if the condition is not met within the timeout.
---@param timeoutMs? number Optional. The maximum time to wait (in milliseconds) for the condition to be met. Defaults to 1000ms.
---@return boolean, any: Returns true and the truthy returned value of conditionFunc if the condition was met, or false if the timeout was exceeded.
function ESX.Await(conditionFunc, errorMessage, timeoutMs)
    timeoutMs = timeoutMs or 1000

    if timeoutMs < 0 then
        error("Timeout should be a positive number.")
    end

    if not ESX.IsFunctionReference(conditionFunc) then
        error("Condition Function should be a function reference.")
    end

    -- since errorMessage is optional, we only validate it if the user provided it.
    if errorMessage then
        ESX.AssertType(errorMessage, "string", "errorMessage should be a string.")
    end

    local invokingResource = GetInvokingResource()
    local startTimeMs = GetGameTimer()
    while GetGameTimer() - startTimeMs < timeoutMs do
        local result = conditionFunc()

        if result then
            return true, result
        end

        Wait(0)
    end

    if errorMessage then
        error(("[%s] -> %s"):format(invokingResource or GetCurrentResourceName(), errorMessage))
    end

    return false
end

-- Hoisted tables (avoid allocating 3 tables per call)
local defaultAllowedRanges <const> = {
    { 0x0041, 0x005A }, -- Basic Latin uppercase (A-Z)
    { 0x0061, 0x007A }, -- Basic Latin lowercase (a-z)
    { 0x00C0, 0x00D6 }, -- Latin-1 Supplement (À-Ö)
    { 0x00D8, 0x00F6 }, -- Latin-1 Supplement (Ø-ö)
    { 0x00F8, 0x00FF }, -- Latin-1 Supplement (ø-ÿ)
    { 0x0100, 0x017F }, -- Latin Extended-A
    { 0x0180, 0x024F }, -- Latin Extended-B
    { 0x0370, 0x03FF }, -- Greek and Coptic
    { 0x0400, 0x04FF }, -- Cyrillic
    { 0x0500, 0x052F }, -- Cyrillic Supplement
    { 0x0590, 0x05FF }, -- Hebrew
    { 0x0600, 0x06FF }, -- Arabic
    { 0x0900, 0x097F }, -- Devanagari
    { 0x0E00, 0x0E7F }, -- Thai
    { 0x1100, 0x11FF }, -- Hangul Jamo
    { 0x1E00, 0x1EFF }, -- Latin Extended Additional
    { 0x2DE0, 0x2DFF }, -- Cyrillic Extended-A
    { 0x3040, 0x309F }, -- Hiragana
    { 0x30A0, 0x30FF }, -- Katakana
    { 0x3130, 0x318F }, -- Hangul Compatibility Jamo
    { 0x4E00, 0x9FFF }, -- CJK Unified Ideographs
    { 0xA640, 0xA69F }, -- Cyrillic Extended-B
    { 0xAC00, 0xD7AF }, -- Hangul Syllables
}
local digitsRange <const> = { 0x0030, 0x0039 }
local numRanges <const> = #defaultAllowedRanges

---@param str string
---@param allowDigits? boolean
---@return boolean
function ESX.IsValidLocaleString(str, allowDigits)
    if type(str) ~= "string" then
        return false
    end

    local ok, isValid = pcall(function()
        for _, code in utf8.codes(str) do
            local allowed = false

            for i = 1, numRanges do
                local range = defaultAllowedRanges[i]
                if code >= range[1] and code <= range[2] then
                    allowed = true
                    break
                end
            end

            if not allowed and allowDigits and code >= digitsRange[1] and code <= digitsRange[2] then
                allowed = true
            end

            if not allowed then
                return false
            end
        end

        return true
    end)

    return ok and isValid or false
end
