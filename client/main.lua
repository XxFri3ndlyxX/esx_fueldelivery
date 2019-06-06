ESX = nil

Citizen.CreateThread(function()
	while ESX == nil do
		TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
		Citizen.Wait(0)
	end

	while ESX.GetPlayerData().job == nil do
		Citizen.Wait(10)
	end

	ESX.PlayerData = ESX.GetPlayerData()
end)
--------------------------------------------------------------------------------
-- NE RIEN MODIFIER
--------------------------------------------------------------------------------
local namezone = "Delivery"
local namezonenum = 0
local namezoneregion = 0
local MissionRegion = 0
local viemaxvehicule = 1000
local argentretire = 0
local livraisonTotalPaye = 0
local livraisonnombre = 0
local MissionRetourCamion = false
local MissionNum = 0
local MissionLivraison = false
local isInService = false
local GUI                     = {}
GUI.Time                      = 0
local hasAlreadyEnteredMarker = false
local lastZone                = nil
local Blips                   = {}

local plaquevehicule = ""
local plaquevehiculeactuel = ""
local CurrentAction           = nil
local CurrentActionMsg        = ''
local CurrentActionData       = {}
--------------------------------------------------------------------------------
RegisterNetEvent('esx:playerLoaded')
AddEventHandler('esx:playerLoaded', function(xPlayer)
	ESX.PlayerData = xPlayer
end)

RegisterNetEvent('esx:setJob')
AddEventHandler('esx:setJob', function(job)
	ESX.PlayerData.job = job
end)

-- MENUS
function MenuCloakRoom()
	ESX.UI.Menu.CloseAll()

	ESX.UI.Menu.Open(
		'default', GetCurrentResourceName(), 'cloakroom',
		{
			css      = 'vestiaire',
			title    = _U('cloakroom'),
			elements = {
				{label = _U('job_wear'), value = 'job_wear'},
				{label = _U('citizen_wear'), value = 'citizen_wear'}
			}
		},
		function(data, menu)
			if data.current.value == 'citizen_wear' then
				isInService = false
				ESX.TriggerServerCallback('esx_skin:getPlayerSkin', function(skin)
	    			TriggerEvent('skinchanger:loadSkin', skin)
				end)
			end
			if data.current.value == 'job_wear' then
				isInService = true
				ESX.TriggerServerCallback('esx_skin:getPlayerSkin', function(skin, jobSkin)
	    			if skin.sex == 0 then
	    				TriggerEvent('skinchanger:loadClothes', skin, jobSkin.skin_male)
					else
	    				TriggerEvent('skinchanger:loadClothes', skin, jobSkin.skin_female)
					end
				end)
			end
			menu.close()
		end,
		function(data, menu)
			menu.close()
		end
	)
end


function MenuVehicleSpawner()
	local elements = {}

	for i=1, #Config.Trucks, 1 do
		table.insert(elements, {label = GetLabelText(GetDisplayNameFromVehicleModel(Config.Trucks[i])), value = Config.Trucks[i]})
	end


	ESX.UI.Menu.CloseAll()

	ESX.UI.Menu.Open(
		'default', GetCurrentResourceName(), 'vehiclespawner',
		{
			css      = 'vehicle',
			title    = _U('vehiclespawner'),
			elements = elements
		},
		function(data, menu)
			ESX.Game.SpawnVehicle(data.current.value, Config.Zones.VehicleSpawnPoint.Pos, 352.0, function(vehicle)
				platenum = math.random(1, 9)
				SetVehicleNumberPlateText(vehicle, "RONFUEL"..platenum)  
                TriggerServerEvent("esx_fueldelivery:truckpay")	
                ESX.ShowNotification(_U('truck_deposit'))				
                MissionLivraisonSelect()
				plaquevehicule = "RONFUEL"..platenum
				exports["LegacyFuel"]:SetFuel(vehicle, 65) 
				if data.current.value == 'phantom3' then
					ESX.Game.SpawnVehicle("tanker", Config.Zones.VehicleSpawnPoint.Pos, 352.0, function(trailer)
					    AttachVehicleToTrailer(vehicle, trailer, 1.1)
					end)
				end				
				TaskWarpPedIntoVehicle(GetPlayerPed(-1), vehicle, -1)
			end)

			menu.close()
		end,
		function(data, menu)
			menu.close()
		end
	)
end

function IsATruck()
	local isATruck = false
	local playerPed = GetPlayerPed(-1)
	for i=1, #Config.Trucks, 1 do
		if IsVehicleModel(GetVehiclePedIsUsing(playerPed), Config.Trucks[i]) then
			isATruck = true
			break
		end
	end
	return isATruck
end

function IsJobfueldelivery()
	if ESX.PlayerData ~= nil then
		local IsJobfueldelivery = false
		if ESX.PlayerData.job and ESX.PlayerData.job.name == 'fueldelivery' then
			IsJobfueldelivery = true
		end
		return IsJobfueldelivery
	end
end

AddEventHandler('esx_fueldelivery:hasEnteredMarker', function(zone)

	local playerPed = GetPlayerPed(-1)

	if zone == 'CloakRoom' then
		MenuCloakRoom()
	end

	if zone == 'VehicleSpawner' then
		if isInService and IsJobfueldelivery() then
			if MissionRetourCamion or MissionLivraison then
				CurrentAction = 'hint'
                CurrentActionMsg  = _U('already_have_truck')
			else
				MenuVehicleSpawner()
			end
		end
	end

	if zone == namezone then
		if isInService and MissionLivraison and MissionNum == namezonenum and MissionRegion == namezoneregion and IsJobfueldelivery() then
			if IsPedSittingInAnyVehicle(playerPed) and IsATruck() then
				VerifPlaqueVehiculeActuel()
				
				if plaquevehicule == plaquevehiculeactuel then
					if Blips['delivery'] ~= nil then
						RemoveBlip(Blips['delivery'])
						Blips['delivery'] = nil
					end

					CurrentAction     = 'delivery'
                    CurrentActionMsg  = _U('delivery')
				else
					CurrentAction = 'hint'
                    CurrentActionMsg  = _U('not_your_truck')
				end
			else
				CurrentAction = 'hint'
                CurrentActionMsg  = _U('not_your_truck2')
			end
		end
	end

	if zone == 'AnnulerMission' then
		if isInService and MissionLivraison and IsJobfueldelivery() then
			if IsPedSittingInAnyVehicle(playerPed) and IsATruck() then
				VerifPlaqueVehiculeActuel()

                TriggerServerEvent('esx:clientLog', "3'" .. json.encode(plaquevehicule) .. "' '" .. json.encode(plaquevehiculeactuel) .. "'")
				
				if plaquevehicule == plaquevehiculeactuel then
                    CurrentAction     = 'retourcamionannulermission'
                    CurrentActionMsg  = _U('cancel_mission')
				else
					CurrentAction = 'hint'
                    CurrentActionMsg  = _U('not_your_truck')
				end
			else
                CurrentAction     = 'retourcamionperduannulermission'
			end
		end
	end

	if zone == 'RetourCamion' then
		if isInService and MissionRetourCamion and IsJobfueldelivery() then
			if IsPedSittingInAnyVehicle(playerPed) and IsATruck() then
				VerifPlaqueVehiculeActuel()

				if plaquevehicule == plaquevehiculeactuel then
                    CurrentAction     = 'retourcamion'
					CurrentActionMsg  = _U('return_truck')
				else
                    CurrentAction     = 'retourcamionannulermission'
                    CurrentActionMsg  = _U('not_your_truck')
				end
			else
                CurrentAction     = 'retourcamionperdu'
			end
		end
	end

end)
RegisterNetEvent('esx_fueldelivery:hasExitedMarker')
AddEventHandler('esx_fueldelivery:hasExitedMarker', function(zone)
	ESX.UI.Menu.CloseAll()    
    CurrentAction = nil
    CurrentActionMsg = ''
end)

function nouvelledestination()
	livraisonnombre = livraisonnombre+1
	livraisonTotalPaye = livraisonTotalPaye+destination.Paye

	if livraisonnombre >= Config.MaxDelivery then
		MissionLivraisonStopRetourDepot()
	else

		livraisonsuite = math.random(0, 100)
		
		if livraisonsuite <= 5 then
			MissionLivraisonStopRetourDepot()
		elseif livraisonsuite <= 99 then
			MissionLivraisonSelect()
		elseif livraisonsuite <= 100 then
			if MissionRegion == 1 then
				MissionRegion = 1
			end
			MissionLivraisonSelect()	
		end
	end
end

function retourcamion_oui()
	if Blips['delivery'] ~= nil then
		RemoveBlip(Blips['delivery'])
		Blips['delivery'] = nil
	end
	
	if Blips['annulermission'] ~= nil then
		RemoveBlip(Blips['annulermission'])
		Blips['annulermission'] = nil
	end
	
	MissionRetourCamion = false
	livraisonnombre = 0
	MissionRegion = 0
	
	donnerlapaye()
end

function retourcamion_non()
	
	if livraisonnombre >= Config.MaxDelivery then
		ESX.ShowNotification(_U('need_it'))
	else
		ESX.ShowNotification(_U('ok_work'))
		nouvelledestination()
	end
end

function retourcamionperdu_oui()
	if Blips['delivery'] ~= nil then
		RemoveBlip(Blips['delivery'])
		Blips['delivery'] = nil
	end
	
	if Blips['annulermission'] ~= nil then
		RemoveBlip(Blips['annulermission'])
		Blips['annulermission'] = nil
	end
	MissionRetourCamion = false
	livraisonnombre = 0
	MissionRegion = 0
	
	donnerlapayesanscamion()
end

function retourcamionperdu_non()
	ESX.ShowNotification(_U('scared_me'))
end

function retourcamionannulermission_oui()
	if Blips['delivery'] ~= nil then
		RemoveBlip(Blips['delivery'])
		Blips['delivery'] = nil
	end
	
	if Blips['annulermission'] ~= nil then
		RemoveBlip(Blips['annulermission'])
		Blips['annulermission'] = nil
	end
	
	MissionLivraison = false
	livraisonnombre = 0
	MissionRegion = 0
	
	donnerlapaye()
end

function retourcamionannulermission_non()	
	ESX.ShowNotification(_U('resume_delivery'))
end

function retourcamionperduannulermission_oui()
	if Blips['delivery'] ~= nil then
		RemoveBlip(Blips['delivery'])
		Blips['delivery'] = nil
	end
	
	if Blips['annulermission'] ~= nil then
		RemoveBlip(Blips['annulermission'])
		Blips['annulermission'] = nil
	end
	
	MissionLivraison = false
	livraisonnombre = 0
	MissionRegion = 0
	
	donnerlapayesanscamion()
end

function retourcamionperduannulermission_non()	
	ESX.ShowNotification(_U('resume_delivery'))
end

function round(num, numDecimalPlaces)
    local mult = 5^(numDecimalPlaces or 0)
    return math.floor(num * mult + 0.5) / mult
end

function donnerlapaye()
	ped = GetPlayerPed(-1)
	vehicle = GetVehiclePedIsIn(ped, false)
	vievehicule = GetVehicleEngineHealth(vehicle)
	calculargentretire = round(viemaxvehicule-vievehicule)
	
	if calculargentretire <= 0 then
		argentretire = 0
	else
		argentretire = calculargentretire
	end

    ESX.Game.DeleteVehicle(vehicle)
	TriggerServerEvent("esx_fueldelivery:truckpayback")
	ESX.ShowNotification(_U('truck_refund'))

	local amount = livraisonTotalPaye-argentretire
	
	if vievehicule >= 1 then
		if livraisonTotalPaye == 0 then
			ESX.ShowNotification(_U('not_delivery'))
			--ESX.ShowNotification(_U('pay_repair'))
			ESX.ShowNotification(_U('repair_minus')..argentretire)
			TriggerServerEvent("esx_fueldelivery:pay", amount)
			livraisonTotalPaye = 0
		else
			if argentretire <= 0 then
				ESX.ShowNotification(_U('shipments_plus')..livraisonTotalPaye)
				TriggerServerEvent("esx_fueldelivery:pay", amount)
				livraisonTotalPaye = 0
			else
				ESX.ShowNotification(_U('shipments_plus')..livraisonTotalPaye)
				ESX.ShowNotification(_U('repair_minus')..argentretire)
					TriggerServerEvent("esx_fueldelivery:pay", amount)
				livraisonTotalPaye = 0
			end
		end
	else
		if livraisonTotalPaye ~= 0 and amount <= 0 then
			ESX.ShowNotification(_U('truck_state'))
			livraisonTotalPaye = 0
		else
			if argentretire <= 0 then
				ESX.ShowNotification(_U('shipments_plus')..livraisonTotalPaye)
					TriggerServerEvent("esx_fueldelivery:pay", amount)
				livraisonTotalPaye = 0
			else
				ESX.ShowNotification(_U('shipments_plus')..livraisonTotalPaye)
				ESX.ShowNotification(_U('repair_minus')..argentretire)
				TriggerServerEvent("esx_fueldelivery:pay", amount)
				livraisonTotalPaye = 0
			end
		end
	end
end

function donnerlapayesanscamion()
	ped = GetPlayerPed(-1)
	argentretire = Config.TruckPrice
	
	-- donne paye
	local amount = livraisonTotalPaye-argentretire
	
	if livraisonTotalPaye == 0 then
		ESX.ShowNotification(_U('no_delivery_no_truck'))
		--ESX.ShowNotification(_U('truck_price')..argentretire)
					TriggerServerEvent("esx_fueldelivery:pay", amount)
		livraisonTotalPaye = 0
	else
		if amount >= 1 then
			ESX.ShowNotification(_U('shipments_plus')..livraisonTotalPaye)
			--ESX.ShowNotification(_U('truck_price')..argentretire)
					TriggerServerEvent("esx_fueldelivery:pay", amount)
			livraisonTotalPaye = 0
		else
			ESX.ShowNotification(_U('truck_state'))
			livraisonTotalPaye = 0
		end
	end
end

-- Key Controls
Citizen.CreateThread(function()
    while true do

        Citizen.Wait(0)

        if CurrentAction ~= nil then

        	SetTextComponentFormat('STRING')
        	AddTextComponentString(CurrentActionMsg)
       		DisplayHelpTextFromStringLabel(0, 0, 1, -1)

            if IsControlJustReleased(0, 26) and ESX.PlayerData.job and ESX.PlayerData.job.name == 'fueldelivery' then

                if CurrentAction == 'delivery' then
                    nouvelledestination()
                end

                if CurrentAction == 'retourcamion' then
                    retourcamion_oui()
                end

                if CurrentAction == 'retourcamionperdu' then
                    retourcamionperdu_oui()
                end

                if CurrentAction == 'retourcamionannulermission' then
                    retourcamionannulermission_oui()
                end

                if CurrentAction == 'retourcamionperduannulermission' then
                    retourcamionperduannulermission_oui()
                end

                CurrentAction = nil
            end

        end

    end
end)

-- DISPLAY MISSION MARKERS AND MARKERS
Citizen.CreateThread(function()
	while true do
		Wait(0)
		
		if MissionLivraison then
			DrawMarker(destination.Type, destination.Pos.x, destination.Pos.y, destination.Pos.z, 0.0, 0.0, 0.0, 0, 0.0, 0.0, destination.Size.x, destination.Size.y, destination.Size.z, destination.Color.r, destination.Color.g, destination.Color.b, 100, false, true, 2, false, false, false, false)
			DrawMarker(Config.Livraison.AnnulerMission.Type, Config.Livraison.AnnulerMission.Pos.x, Config.Livraison.AnnulerMission.Pos.y, Config.Livraison.AnnulerMission.Pos.z, 0.0, 0.0, 0.0, 0, 0.0, 0.0, Config.Livraison.AnnulerMission.Size.x, Config.Livraison.AnnulerMission.Size.y, Config.Livraison.AnnulerMission.Size.z, Config.Livraison.AnnulerMission.Color.r, Config.Livraison.AnnulerMission.Color.g, Config.Livraison.AnnulerMission.Color.b, 100, false, true, 2, false, false, false, false)
		elseif MissionRetourCamion then
			DrawMarker(destination.Type, destination.Pos.x, destination.Pos.y, destination.Pos.z, 0.0, 0.0, 0.0, 0, 0.0, 0.0, destination.Size.x, destination.Size.y, destination.Size.z, destination.Color.r, destination.Color.g, destination.Color.b, 100, false, true, 2, false, false, false, false)
		end

		local coords = GetEntityCoords(GetPlayerPed(-1))
		
		for k,v in pairs(Config.Zones) do

			if isInService and (IsJobfueldelivery() and v.Type ~= -1 and GetDistanceBetweenCoords(coords, v.Pos.x, v.Pos.y, v.Pos.z, true) < Config.DrawDistance) then
				DrawMarker(v.Type, v.Pos.x, v.Pos.y, v.Pos.z, 0.0, 0.0, 0.0, 0, 0.0, 0.0, v.Size.x, v.Size.y, v.Size.z, v.Color.r, v.Color.g, v.Color.b, 100, false, true, 2, false, false, false, false)
			end

		end

		for k,v in pairs(Config.Cloakroom) do

			if(IsJobfueldelivery() and v.Type ~= -1 and GetDistanceBetweenCoords(coords, v.Pos.x, v.Pos.y, v.Pos.z, true) < Config.DrawDistance) then
				DrawMarker(v.Type, v.Pos.x, v.Pos.y, v.Pos.z, 0.0, 0.0, 0.0, 0, 0.0, 0.0, v.Size.x, v.Size.y, v.Size.z, v.Color.r, v.Color.g, v.Color.b, 100, false, true, 2, false, false, false, false)
			end

		end
		
	end
end)

-- Activate menu when player is inside marker
Citizen.CreateThread(function()
	while true do
		
		Wait(0)
		
		if ESX.PlayerData.job and ESX.PlayerData.job.name == 'fueldelivery' then

			local coords      = GetEntityCoords(GetPlayerPed(-1))
			local isInMarker  = false
			local currentZone = nil

			for k,v in pairs(Config.Zones) do
				if(GetDistanceBetweenCoords(coords, v.Pos.x, v.Pos.y, v.Pos.z, true) < v.Size.x) then
					isInMarker  = true
					currentZone = k
				end
			end
			
			for k,v in pairs(Config.Cloakroom) do
				if(GetDistanceBetweenCoords(coords, v.Pos.x, v.Pos.y, v.Pos.z, true) < v.Size.x) then
					isInMarker  = true
					currentZone = k
				end
			end
			
			for k,v in pairs(Config.Livraison) do
				if(GetDistanceBetweenCoords(coords, v.Pos.x, v.Pos.y, v.Pos.z, true) < v.Size.x) then
					isInMarker  = true
					currentZone = k
				end
			end

			if isInMarker and not hasAlreadyEnteredMarker then
				hasAlreadyEnteredMarker = true
				lastZone                = currentZone
				TriggerEvent('esx_fueldelivery:hasEnteredMarker', currentZone)
			end

			if not isInMarker and hasAlreadyEnteredMarker then
				hasAlreadyEnteredMarker = false
				TriggerEvent('esx_fueldelivery:hasExitedMarker', lastZone)
			end

		end

	end
end)

-- CREATE BLIPS
Citizen.CreateThread(function()
	local blip = AddBlipForCoord(Config.Cloakroom.CloakRoom.Pos.x, Config.Cloakroom.CloakRoom.Pos.y, Config.Cloakroom.CloakRoom.Pos.z)
  
	SetBlipSprite (blip, 67)
	SetBlipDisplay(blip, 4)
	SetBlipScale  (blip, 1.2)
	SetBlipColour (blip, 5)
	SetBlipAsShortRange(blip, true)

	BeginTextCommandSetBlipName("STRING")
	AddTextComponentString(_U('blip_job'))
	EndTextCommandSetBlipName(blip)
end)

-------------------------------------------------
-- Fonctions
-------------------------------------------------
-- Fonction selection nouvelle mission livraison
function MissionLivraisonSelect()
    TriggerServerEvent('esx:clientLog', "MissionLivraisonSelect num")
    TriggerServerEvent('esx:clientLog', MissionRegion)
	if MissionRegion == 0 then

            TriggerServerEvent('esx:clientLog', "MissionLivraisonSelect 1")
		MissionRegion = math.random(1,1)
	end
	
	if MissionRegion == 1 then -- Los santos
            TriggerServerEvent('esx:clientLog', "MissionLivraisonSelect 2")
		MissionNum = math.random(1, 24)
	
		if MissionNum == 1 then destination = Config.Livraison.Delivery1LS namezone = "Delivery1LS" namezonenum = 1 namezoneregion = 1
		ESX.ShowNotification(_U('delivery_1'))
		elseif MissionNum == 2 then destination = Config.Livraison.Delivery2LS namezone = "Delivery2LS" namezonenum = 2 namezoneregion = 1
		ESX.ShowNotification(_U('delivery_2'))
		elseif MissionNum == 3 then destination = Config.Livraison.Delivery3LS namezone = "Delivery3LS" namezonenum = 3 namezoneregion = 1
		ESX.ShowNotification(_U('delivery_3'))
		elseif MissionNum == 4 then destination = Config.Livraison.Delivery4LS namezone = "Delivery4LS" namezonenum = 4 namezoneregion = 1
		ESX.ShowNotification(_U('delivery_4'))
		elseif MissionNum == 5 then destination = Config.Livraison.Delivery5LS namezone = "Delivery5LS" namezonenum = 5 namezoneregion = 1
		ESX.ShowNotification(_U('delivery_5'))
		elseif MissionNum == 6 then destination = Config.Livraison.Delivery6LS namezone = "Delivery6LS" namezonenum = 6 namezoneregion = 1
		ESX.ShowNotification(_U('delivery_6'))
		elseif MissionNum == 7 then destination = Config.Livraison.Delivery7LS namezone = "Delivery7LS" namezonenum = 7 namezoneregion = 1
		ESX.ShowNotification(_U('delivery_7'))
		elseif MissionNum == 8 then destination = Config.Livraison.Delivery8LS namezone = "Delivery8LS" namezonenum = 8 namezoneregion = 1
		ESX.ShowNotification(_U('delivery_8'))
		elseif MissionNum == 9 then destination = Config.Livraison.Delivery9LS namezone = "Delivery9LS" namezonenum = 9 namezoneregion = 1
		ESX.ShowNotification(_U('delivery_9'))
		elseif MissionNum == 10 then destination = Config.Livraison.Delivery10LS namezone = "Delivery10LS" namezonenum = 10 namezoneregion = 1
		ESX.ShowNotification(_U('delivery_10'))
		elseif MissionNum == 11 then destination = Config.Livraison.Delivery11LS namezone = "Delivery11LS" namezonenum = 11 namezoneregion = 1
		ESX.ShowNotification(_U('delivery_11'))
		elseif MissionNum == 12 then destination = Config.Livraison.Delivery12LS namezone = "Delivery12LS" namezonenum = 12 namezoneregion = 1
		ESX.ShowNotification(_U('delivery_12'))
		elseif MissionNum == 13 then destination = Config.Livraison.Delivery13LS namezone = "Delivery13LS" namezonenum = 13 namezoneregion = 1
		ESX.ShowNotification(_U('delivery_13'))
		elseif MissionNum == 14 then destination = Config.Livraison.Delivery14LS namezone = "Delivery14LS" namezonenum = 14 namezoneregion = 1
		ESX.ShowNotification(_U('delivery_14'))
		elseif MissionNum == 15 then destination = Config.Livraison.Delivery15LS namezone = "Delivery15LS" namezonenum = 15 namezoneregion = 1
		ESX.ShowNotification(_U('delivery_15'))
		elseif MissionNum == 16 then destination = Config.Livraison.Delivery16LS namezone = "Delivery16LS" namezonenum = 16 namezoneregion = 1
		ESX.ShowNotification(_U('delivery_16'))
		elseif MissionNum == 17 then destination = Config.Livraison.Delivery17LS namezone = "Delivery17LS" namezonenum = 17 namezoneregion = 1
		ESX.ShowNotification(_U('delivery_17'))
		elseif MissionNum == 18 then destination = Config.Livraison.Delivery18LS namezone = "Delivery18LS" namezonenum = 18 namezoneregion = 1
		ESX.ShowNotification(_U('delivery_18'))
		elseif MissionNum == 19 then destination = Config.Livraison.Delivery19LS namezone = "Delivery19LS" namezonenum = 19 namezoneregion = 1
		ESX.ShowNotification(_U('delivery_19'))
		elseif MissionNum == 20 then destination = Config.Livraison.Delivery20LS namezone = "Delivery20LS" namezonenum = 20 namezoneregion = 1
		ESX.ShowNotification(_U('delivery_20'))
		elseif MissionNum == 21 then destination = Config.Livraison.Delivery21LS namezone = "Delivery21LS" namezonenum = 21 namezoneregion = 1
		ESX.ShowNotification(_U('delivery_21'))
		elseif MissionNum == 22 then destination = Config.Livraison.Delivery22LS namezone = "Delivery22LS" namezonenum = 22 namezoneregion = 1
		ESX.ShowNotification(_U('delivery_22'))
		elseif MissionNum == 23 then destination = Config.Livraison.Delivery23LS namezone = "Delivery23LS" namezonenum = 23 namezoneregion = 1
		ESX.ShowNotification(_U('delivery_23'))
		elseif MissionNum == 24 then destination = Config.Livraison.Delivery24LS namezone = "Delivery24LS" namezonenum = 24 namezoneregion = 1
		ESX.ShowNotification(_U('delivery_24'))
		end
		
	end
	
	MissionLivraisonLetsGo()
end

-- Fonction active mission livraison
function MissionLivraisonLetsGo()
	if Blips['delivery'] ~= nil then
		RemoveBlip(Blips['delivery'])
		Blips['delivery'] = nil
	end
	
	if Blips['annulermission'] ~= nil then
		RemoveBlip(Blips['annulermission'])
		Blips['annulermission'] = nil
	end
	
	Blips['delivery'] = AddBlipForCoord(destination.Pos.x,  destination.Pos.y,  destination.Pos.z)
	SetBlipRoute(Blips['delivery'], true)
	BeginTextCommandSetBlipName("STRING")
	AddTextComponentString(_U('blip_delivery'))
	EndTextCommandSetBlipName(Blips['delivery'])
	
	Blips['annulermission'] = AddBlipForCoord(Config.Livraison.AnnulerMission.Pos.x,  Config.Livraison.AnnulerMission.Pos.y,  Config.Livraison.AnnulerMission.Pos.z)
	BeginTextCommandSetBlipName("STRING")
	AddTextComponentString(_U('blip_goal'))
	EndTextCommandSetBlipName(Blips['annulermission'])

	if MissionRegion == 1 then -- Los santos
		--ESX.ShowNotification(_U('meet_ls'))
	elseif MissionRegion == 0 then -- au cas ou
		ESX.ShowNotification(_U('meet_del'))
	end

	MissionLivraison = true
end

--Fonction retour au depot
function MissionLivraisonStopRetourDepot()
	destination = Config.Livraison.RetourCamion
	
	Blips['delivery'] = AddBlipForCoord(destination.Pos.x,  destination.Pos.y,  destination.Pos.z)
	SetBlipRoute(Blips['delivery'], true)
	BeginTextCommandSetBlipName("STRING")
	AddTextComponentString(_U('blip_depot'))
	EndTextCommandSetBlipName(Blips['delivery'])
	
	if Blips['annulermission'] ~= nil then
		RemoveBlip(Blips['annulermission'])
		Blips['annulermission'] = nil
	end

	ESX.ShowNotification(_U('return_depot'))
	
	MissionRegion = 0
	MissionLivraison = false
	MissionNum = 0
	MissionRetourCamion = true
end

function SavePlaqueVehicule()
	plaquevehicule = GetVehicleNumberPlateText(GetVehiclePedIsIn(GetPlayerPed(-1), false))
end

function VerifPlaqueVehiculeActuel()
	plaquevehiculeactuel = GetVehicleNumberPlateText(GetVehiclePedIsIn(GetPlayerPed(-1), false))
end
