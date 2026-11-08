Core = {}
Core.Input = {}
Core.Events = {}

ESX.PlayerData = {}
ESX.PlayerLoaded = false

ESX.UI = {}
ESX.UI.Menu = {}
ESX.UI.Menu.RegisteredTypes = {}
ESX.UI.Menu.Opened = {}

ESX.Game = {}
ESX.Game.Utils = {}

ESX.Items = {}
for name, v in pairs(Config.Items or {}) do
    ESX.Items[name] = {
        name = name,
        label = v.label or name,
        weight = tonumber(v.weight) or 0,
        limit = tonumber(v.limit) or -1,
        rare = v.rare == true or v.rare == 1,
        canRemove = v.canRemove == nil and true or (v.canRemove == true or v.canRemove == 1),
    }
end

CreateThread(function()
    while not Config.Multichar do
        Wait(100)

        if NetworkIsPlayerActive(PlayerId()) then
            ESX.DisableSpawnManager()
            DoScreenFadeOut(0)
            Wait(500)
            TriggerServerEvent("esx:onPlayerJoined")
            break
        end
    end
end)
