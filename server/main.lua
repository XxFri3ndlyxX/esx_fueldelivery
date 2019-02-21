ESX = nil
TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)

RegisterServerEvent('esx_fueldelivery:pay')
AddEventHandler('esx_fueldelivery:pay', function(amount)
	local _source = source
	local xPlayer = ESX.GetPlayerFromId(_source)
	xPlayer.addMoney(tonumber(amount))
end)

RegisterServerEvent('esx_fueldelivery:truckpay')
AddEventHandler('esx_fueldelivery:truckpay', function(amount)
	local _source = source
	local xPlayer = ESX.GetPlayerFromId(_source)
	xPlayer.removeMoney(Config.TruckRental)
end)

RegisterServerEvent('esx_fueldelivery:truckpayback')
AddEventHandler('esx_fueldelivery:truckpayback', function(amount)
	local _source = source
	local xPlayer = ESX.GetPlayerFromId(_source)
	xPlayer.addMoney(Config.TruckRental)
end)
