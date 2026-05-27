




ESX = ESX or nil

local function resolveESX()
  if ESX then return ESX end

  local ok, obj = pcall(function()
    return exports['es_extended']:getSharedObject()
  end)

  if ok and obj then
    ESX = obj
    return ESX
  end

  
  TriggerEvent('esx:getSharedObject', function(obj)
    ESX = obj
  end)

  return ESX
end

resolveESX()

CreateThread(function()
  while not ESX do
    Wait(100)
    resolveESX()
  end
end)
