local vehicleBeingEntered = nil
local hijackedVehicles = {}
local attemptedVehicles = {}
local authorizedVehicles = {}
local readyToStartVehicles = {}

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        local ped = PlayerPedId()

        HandleVehicleEntryAttempt(ped)
        HandleKeyPresses(ped)
        CheckVehicleAuthorization(ped)
        StartVehicleWithW(ped)
    end
end)

function HandleVehicleEntryAttempt(ped)
    if IsPedTryingToEnterALockedVehicle(ped) or IsPedJacking(ped) then
        local vehicle = GetVehiclePedIsTryingToEnter(ped)
        local speed = GetEntitySpeed(vehicle)
        
        -- Speed threshold to consider the vehicle as parked, might need adjustment
        local parkedSpeedThreshold = 0.1 -- Adjust based on testing
        
        if speed <= parkedSpeedThreshold then
            -- Vehicle is considered parked, trigger interaction attempt
            TriggerVehicleInteractionAttempt(vehicle, "enter")
        else
            -- Vehicle is considered moving, allow immediate hijack without needing keys
            -- You might want to add logic here to directly allow entry or to flag the vehicle as authorized temporarily
            authorizedVehicles[vehicle] = true
            ESX.ShowNotification("~g~Vehicle hijacked. Press 'W' to drive.")
        end
    end
end

function HandleKeyPresses(ped)
    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle ~= 0 then
        if IsControlJustReleased(0, 47) and not attemptedVehicles[vehicle] then
            SearchForKeys(vehicle)
        elseif IsControlJustReleased(0, 74) and not attemptedVehicles[vehicle] then
            HotwireVehicle(vehicle)
        end
    end
end

function CheckVehicleAuthorization(ped)
    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle ~= 0 and GetIsVehicleEngineRunning(vehicle) then
        -- Check for hijacked status or authorization
        if hijackedVehicles[vehicle] or authorizedVehicles[vehicle] then
            -- The vehicle is either hijacked or the player is authorized; no action needed
            -- Optionally, provide feedback for a hijacked vehicle
            if hijackedVehicles[vehicle] then
                -- This notification could become annoying if shown repeatedly
                -- Consider showing it only once when the hijack is first recognized
                ESX.ShowNotification("~g~You are driving a hijacked vehicle.")
            end
        else
            -- The player is not authorized and the vehicle is not marked as hijacked
            SetVehicleEngineOn(vehicle, false, false, true)
            TriggerEvent('esx:showNotification', "~r~You don't have the keys to this vehicle.")
        end
    end
end


function SearchForKeys(vehicle)
    attemptedVehicles[vehicle] = true
    local playerPed = PlayerPedId()
    local currentVehicle = vehicle

    exports["esx_progressbar"]:Progressbar("Searching Vehicle", 5000, {
        FreezePlayer = true,
        animation = {
            type = "anim",
            dict = "mini@repair",
            lib = "fixing_a_ped"
        },
        onStart = function()
            Citizen.CreateThread(function()
                while true do
                    Citizen.Wait(500) -- Check every half second
                    if not IsPedInVehicle(playerPed, currentVehicle, false) then
                        exports["esx_progressbar"]:CloseUI() -- Close the progress bar if the player is pulled out
                        return -- Exit the thread
                    end
                end
            end)
        end,
        onFinish = function()
            if IsPedInVehicle(playerPed, currentVehicle, false) then -- Check again to ensure player is still in vehicle
                if math.random(2) == 1 then
                    ESX.ShowNotification("~g~You found the keys! Press 'W' to start the vehicle.")
                    authorizedVehicles[vehicle] = true
                    readyToStartVehicles[vehicle] = true
                else
                    ESX.ShowNotification("~r~No keys found in the vehicle.")
                end
            end
        end
    })
end


function HotwireVehicle(vehicle)
    attemptedVehicles[vehicle] = true
    local playerPed = PlayerPedId()
    local currentVehicle = vehicle

    exports["esx_progressbar"]:Progressbar("Hotwiring Vehicle", 10000, {
        FreezePlayer = true,
        animation = {
            type = "anim",
            dict = "mini@repair",
            lib = "fixing_a_ped"
        },
        onStart = function()
            Citizen.CreateThread(function()
                while true do
                    Citizen.Wait(500) -- Check every half second
                    if not IsPedInVehicle(playerPed, currentVehicle, false) then
                        exports["esx_progressbar"]:CloseUI() -- Close the progress bar if the player is pulled out
                        return -- Exit the thread
                    end
                end
            end)
        end,
        onFinish = function()
            if IsPedInVehicle(playerPed, currentVehicle, false) then -- Check again to ensure player is still in vehicle
                if math.random(2) == 1 then
                    ESX.ShowNotification("~g~Hotwire successful! Press 'W' to start the vehicle.")
                    authorizedVehicles[vehicle] = true
                    readyToStartVehicles[vehicle] = true
                else
                    ESX.ShowNotification("~r~Hotwire failed. The vehicle cannot be started.")
                end
            end
        end
    })
end


function TriggerVehicleInteractionAttempt(vehicle, action)
    local vehicleId = NetworkGetNetworkIdFromEntity(vehicle)
    TriggerServerEvent('vehicle:attemptSteal', vehicleId, action)
    SetVehicleNeedsToBeHotwired(vehicle, true)
    ESX.ShowNotification("~b~Attempting to " .. action .. " vehicle...")
end

function StartVehicleWithW(ped)
    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle ~= 0 and readyToStartVehicles[vehicle] and IsControlJustPressed(0, 71) then
        if not GetIsVehicleEngineRunning(vehicle) then
            SetVehicleEngineOn(vehicle, true, false, false)
            ESX.ShowNotification("~g~Vehicle started successfully.")
            readyToStartVehicles[vehicle] = nil
        end
    end
end