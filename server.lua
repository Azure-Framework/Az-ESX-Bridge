local callbacks = {}
local lastJobBySource = {}
local useableItems = {}

local ESX = {
  Players = {},
  Shared = {},
  Jobs = {},
  Items = {},
}

local function bridge()
  return exports["Az-Framework"]
end

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

local function snapshot(src)
  return bridge():GetBridgePlayerSnapshot(tonumber(src) or 0)
end

local function jobFromSnapshot(data)
  local info = data and data.jobInfo or {}
  return {
    name = tostring(info.name or (data and data.job) or "unemployed"),
    label = tostring(info.label or info.name or (data and data.job) or "Unemployed"),
    grade = tonumber(info.rank) or 0,
    grade_name = tostring(info.rankName or "member"),
    grade_label = tostring(info.rankName or "Member"),
    onDuty = info.onduty == true,
  }
end

local function accountName(account)
  account = tostring(account or "money"):lower()
  if account == "cash" or account == "money" then return "money", "cash" end
  if account == "bank" then return "bank", "bank" end
  return account, nil
end

local function buildAccounts(src)
  return {
    money = {
      name = "money",
      label = "Cash",
      money = tonumber(bridge():GetBridgeMoney(src, "cash")) or 0,
    },
    bank = {
      name = "bank",
      label = "Bank",
      money = tonumber(bridge():GetBridgeMoney(src, "bank")) or 0,
    },
  }
end

local function buildXPlayer(src)
  local data = snapshot(src)
  if not data then
    ESX.Players[src] = nil
    return nil
  end

  local xPlayer = {
    source = src,
    identifier = tostring(data.identifier or ""),
    name = tostring(data.name or ""),
    job = jobFromSnapshot(data),
    variables = {},
    metadata = clone(data.metadata or {}),
  }

  function xPlayer.getIdentifier()
    return xPlayer.identifier
  end

  function xPlayer.getName()
    return tostring(snapshot(src) and snapshot(src).name or xPlayer.name or "")
  end

  function xPlayer.getJob()
    local current = snapshot(src)
    xPlayer.job = jobFromSnapshot(current or data)
    return clone(xPlayer.job)
  end

  function xPlayer.setJob(jobName, grade)
    return bridge():SetPlayerJob(src, jobName, grade) == true
  end

  function xPlayer.getMoney()
    return tonumber(bridge():GetBridgeMoney(src, "cash")) or 0
  end

  function xPlayer.addMoney(amount, reason)
    return bridge():AddBridgeMoney(src, "cash", amount, reason) == true
  end

  function xPlayer.removeMoney(amount, reason)
    return bridge():RemoveBridgeMoney(src, "cash", amount, reason) == true
  end

  function xPlayer.setMoney(amount, reason)
    return bridge():SetBridgeMoney(src, "cash", amount, reason) == true
  end

  function xPlayer.getAccount(account)
    local key, mapped = accountName(account)
    if not mapped then return nil end
    local accounts = buildAccounts(src)
    return clone(accounts[key])
  end

  function xPlayer.getAccounts()
    return clone(buildAccounts(src))
  end

  function xPlayer.addAccountMoney(account, amount, reason)
    local _, mapped = accountName(account)
    if not mapped then return false end
    return bridge():AddBridgeMoney(src, mapped, amount, reason) == true
  end

  function xPlayer.removeAccountMoney(account, amount, reason)
    local _, mapped = accountName(account)
    if not mapped then return false end
    return bridge():RemoveBridgeMoney(src, mapped, amount, reason) == true
  end

  function xPlayer.setAccountMoney(account, amount, reason)
    local _, mapped = accountName(account)
    if not mapped then return false end
    return bridge():SetBridgeMoney(src, mapped, amount, reason) == true
  end

  function xPlayer.getInventoryItem(item)
    local found = bridge():GetBridgeItem(src, item)
    if found ~= nil then return found end
    local count = tonumber(bridge():GetBridgeItemCount(src, item)) or 0
    return { name = tostring(item), count = count, amount = count }
  end

  function xPlayer.addInventoryItem(item, amount, metadata)
    return bridge():AddBridgeItem(src, item, amount, metadata) == true
  end

  function xPlayer.removeInventoryItem(item, amount, metadata)
    return bridge():RemoveBridgeItem(src, item, amount, metadata) == true
  end

  function xPlayer.canCarryItem()
    return true
  end

  function xPlayer.showNotification(message, ntype, length)
    return bridge():BridgeNotify(src, message, ntype, length)
  end

  function xPlayer.setMeta(key, value)
    return bridge():SetBridgeMetadata(src, key, value) == true
  end

  function xPlayer.getMeta(key)
    return bridge():GetBridgeMetadata(src, key)
  end

  function xPlayer.triggerEvent(eventName, ...)
    TriggerClientEvent(eventName, src, ...)
  end

  ESX.Players[src] = xPlayer
  return xPlayer
end

function ESX.GetPlayerFromId(src)
  src = tonumber(src or 0) or 0
  if src <= 0 then return nil end
  return buildXPlayer(src)
end

function ESX.GetExtendedPlayers(key, value)
  local players = {}
  for _, playerId in ipairs(GetPlayers() or {}) do
    local src = tonumber(playerId)
    local xPlayer = ESX.GetPlayerFromId(src)
    if xPlayer then
      local matches = true
      if key == "job" then
        matches = xPlayer.getJob().name == value
      elseif key ~= nil then
        matches = xPlayer[key] == value
      end
      if matches then players[#players + 1] = xPlayer end
    end
  end
  return players
end

function ESX.GetPlayers()
  local players = {}
  for _, playerId in ipairs(GetPlayers() or {}) do
    players[#players + 1] = tonumber(playerId)
  end
  return players
end

function ESX.RegisterServerCallback(name, cb)
  callbacks[tostring(name or "")] = cb
end

function ESX.RegisterUsableItem(itemName, cb)
  itemName = tostring(itemName or ""):lower()
  if itemName == "" or type(cb) ~= "function" then return false end
  useableItems[itemName] = cb
  return true
end

function ESX.UseItem(src, itemName, ...)
  local cb = useableItems[tostring(itemName or ""):lower()]
  if type(cb) ~= "function" then return false end
  cb(tonumber(src) or source, ...)
  return true
end

function ESX.GetConfig()
  return {
    CustomInventory = false,
    Accounts = { "money", "bank" },
  }
end

function ESX.TriggerClientCallback(playerId, name, cb, ...)
  TriggerClientEvent("esx:triggerClientCallback", playerId, name, cb, ...)
end

function ESX.DoesJobExist(jobName)
  jobName = tostring(jobName or ""):lower()
  for _, dept in ipairs(bridge():getConfiguredDepartments() or {}) do
    if tostring(dept.id or ""):lower() == jobName then return true end
  end
  return jobName == "unemployed"
end

function ESX.Trace(message)
  print(("[es_extended bridge] %s"):format(tostring(message or "")))
end

RegisterNetEvent("esx:triggerServerCallback", function(name, requestId, ...)
  local src = source
  local callback = callbacks[tostring(name or "")]
  if type(callback) ~= "function" then
    TriggerClientEvent("esx:serverCallback", src, requestId, nil)
    return
  end

  callback(src, function(...)
    TriggerClientEvent("esx:serverCallback", src, requestId, ...)
  end, ...)
end)

RegisterNetEvent("esx:getSharedObject", function(cb)
  if type(cb) == "function" then cb(ESX) end
end)

local function emitPlayerLoaded(src)
  local xPlayer = ESX.GetPlayerFromId(src)
  if not xPlayer then return end

  local job = xPlayer.getJob()
  lastJobBySource[src] = clone(job)
  TriggerEvent("esx:playerLoaded", src, xPlayer, false)
  TriggerClientEvent("esx:playerLoaded", src, {
    identifier = xPlayer.identifier,
    job = clone(job),
    accounts = buildAccounts(src),
  })
end

AddEventHandler("playerJoining", function()
  local src = source
  SetTimeout(2500, function()
    if GetPlayerPing(src) > 0 then emitPlayerLoaded(src) end
  end)
end)

RegisterNetEvent("az-fw-money:selectCharacter", function()
  local src = source
  SetTimeout(750, function()
    if GetPlayerPing(src) > 0 then emitPlayerLoaded(src) end
  end)
end)

AddEventHandler("Az-Framework:jobChanged", function(changedSrc)
  local src = tonumber(changedSrc) or tonumber(source)
  if not src or src <= 0 then return end

  local xPlayer = ESX.GetPlayerFromId(src)
  if not xPlayer then return end

  local newJob = xPlayer.getJob()
  local previousJob = lastJobBySource[src] or { name = "unemployed", label = "Unemployed", grade = 0 }
  lastJobBySource[src] = clone(newJob)
  TriggerEvent("esx:setJob", src, clone(newJob), clone(previousJob))
  TriggerClientEvent("esx:setJob", src, clone(newJob), clone(previousJob))
end)

AddEventHandler("playerDropped", function()
  ESX.Players[source] = nil
  lastJobBySource[source] = nil
end)

exports("getSharedObject", function()
  return ESX
end)
