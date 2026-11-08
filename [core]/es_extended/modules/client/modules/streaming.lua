ESX.Streaming = {}

function ESX.Streaming.RequestModel(modelHash, cb)
    modelHash = (type(modelHash) == "number" and modelHash or joaat(modelHash))

    if not IsModelInCdimage(modelHash) then
        return
    end

    RequestModel(modelHash)
    while not HasModelLoaded(modelHash) do
        Wait(0)
    end

    if cb ~= nil then
        cb()
    end
end

function ESX.Streaming.RequestStreamedTextureDict(textureDict, cb)
    RequestStreamedTextureDict(textureDict)

    while not HasStreamedTextureDictLoaded(textureDict) do
        Wait(0)
    end

    if cb ~= nil then
        cb()
    end
end

function ESX.Streaming.RequestNamedPtfxAsset(assetName, cb)
    RequestNamedPtfxAsset(assetName)

    while not HasNamedPtfxAssetLoaded(assetName) do
        Wait(0)
    end

    if cb ~= nil then
        cb()
    end
end

function ESX.Streaming.RequestAnimSet(animSet, cb)
    RequestAnimSet(animSet)

    while not HasAnimSetLoaded(animSet) do
        Wait(0)
    end

    if cb ~= nil then
        cb()
    end
end

function ESX.Streaming.RequestAnimDict(animDict, cb)
    RequestAnimDict(animDict)

    while not HasAnimDictLoaded(animDict) do
        Wait(0)
    end

    if cb ~= nil then
        cb()
    end
end

function ESX.Streaming.RequestWeaponAsset(weaponHash, cb)
    RequestWeaponAsset(weaponHash)

    while not HasWeaponAssetLoaded(weaponHash) do
        Wait(0)
    end

    if cb ~= nil then
        cb()
    end
end
