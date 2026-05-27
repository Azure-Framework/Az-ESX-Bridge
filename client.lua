local callbacks = {}
local nextRequestId = 0

local ESX = {
  PlayerData = {},
  PlayerLoaded = false,
  Game = {},
  Math = {},
  Streaming = {},
}

local function clone(value, seen)
  if type(value) ~= "table" then return value end
  seen = seen or {}
  if seen[value] then return seen[value] end

  local out = {}
  seen[value] = out
  for k, v in pairs(value) do
    out[clone(k, seen)] = clone(v, seen)
  end
  return out
end

local function refreshPlayerData()
  local snapshot = exports["Az-Framework"]:GetBridgeClientSnapshot()
  if type(snapshot) ~= "table" then return ESX.PlayerData end

  local job = snapshot.jobInfo or {}
  ESX.PlayerData = {
    identifier = tostring(snapshot.identifier or ""),
    name = tostring(snapshot.name or ""),
    job = {
      name = tostring(job.name or snapshot.job or "unemployed"),
      label = tostring(job.label or job.name or snapshot.job or "Unemployed"),
      grade = tonumber(job.rank) or 0,
      grade_name = tostring(job.rankName or "member"),
      grade_label = tostring(job.rankName or "Member"),
      onDuty = job.onduty == true,
    },
    accounts = {
      money = { name = "money", money = tonumber(snapshot.cash) or 0 },
      bank = { name = "bank", money = tonumber(snapshot.bank) or 0 },
    },
    metadata = clone(snapshot.metadata or {}),
  }
  return ESX.PlayerData
end

function ESX.IsPlayerLoaded()
  return ESX.PlayerLoaded == true
end

function ESX.GetPlayerData()
  return clone(refreshPlayerData())
end

function ESX.SetPlayerData(key, value)
  ESX.PlayerData[tostring(key or "")] = value
end

function ESX.TriggerServerCallback(name, cb, ...)
  nextRequestId = nextRequestId + 1
  local requestId = nextRequestId
  callbacks[requestId] = cb
  TriggerServerEvent("esx:triggerServerCallback", name, requestId, ...)
end

function ESX.ShowNotification(message, ntype, length)
  TriggerEvent("ox_lib:notify", {
    title = "Notification",
    description = tostring(message or ""),
    type = tostring(ntype or "inform"),
    duration = tonumber(length) or 5000,
  })
end

function ESX.ShowHelpNotification(message)
  BeginTextCommandDisplayHelp("STRING")
  AddTextComponentSubstringPlayerName(tostring(message or ""))
  EndTextCommandDisplayHelp(0, false, true, -1)
end

function ESX.Game.GetPlayers()
  return GetActivePlayers()
end

function ESX.Game.GetClosestPlayer(coords)
  coords = coords or GetEntityCoords(PlayerPedId())
  local closestPlayer, closestDistance = -1, -1
  for _, player in ipairs(GetActivePlayers()) do
    if player ~= PlayerId() then
      local dist = #(coords - GetEntityCoords(GetPlayerPed(player)))
      if closestDistance == -1 or dist < closestDistance then
        closestPlayer = player
        closestDistance = dist
      end
    end
  end
  return closestPlayer, closestDistance
end

function ESX.Game.GetClosestVehicle(coords)
  coords = coords or GetEntityCoords(PlayerPedId())
  local closestVehicle, closestDistance = 0, -1
  for _, vehicle in ipairs(GetGamePool and GetGamePool("CVehicle") or {}) do
    local dist = #(coords - GetEntityCoords(vehicle))
    if closestDistance == -1 or dist < closestDistance then
      closestVehicle = vehicle
      closestDistance = dist
    end
  end
  return closestVehicle, closestDistance
end

RegisterNetEvent("esx:serverCallback", function(requestId, ...)
  local cb = callbacks[tonumber(requestId)]
  callbacks[tonumber(requestId)] = nil
  if type(cb) == "function" then cb(...) end
end)

RegisterNetEvent("esx:getSharedObject", function(cb)
  if type(cb) == "function" then cb(ESX) end
end)

RegisterNetEvent("esx:playerLoaded", function(playerData)
  ESX.PlayerLoaded = true
  if type(playerData) == "table" then
    ESX.PlayerData = clone(playerData)
  else
    refreshPlayerData()
  end
end)

RegisterNetEvent("esx:setJob", function(job)
  ESX.PlayerData.job = clone(job or {})
end)

RegisterNetEvent("Az-Framework:Bridge:Snapshot", refreshPlayerData)
RegisterNetEvent("Az-Framework:Bridge:MetadataUpdated", refreshPlayerData)
RegisterNetEvent("hud:setDepartment", refreshPlayerData)
RegisterNetEvent("updateCashHUD", refreshPlayerData)

AddEventHandler("onClientResourceStart", function(resourceName)
  if resourceName ~= GetCurrentResourceName() then return end
  SetTimeout(500, function()
    refreshPlayerData()
    ESX.PlayerLoaded = true
  end)
end)

exports("getSharedObject", function()
  return ESX
end)
