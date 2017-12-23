function initialize()
    if onServer() then
        debugPrint(0,"Equiping "..Player().name.." with Febreze® space freshener.")
        --unregister events to clear things up.
        local unregisterOnSectorLeftValue = Player():unregisterCallback("onSectorLeft", "onSectorLeft")
        local unregisterOnSectorEnteredValue = Player():unregisterCallback("onSectorEntered", "onSectorEntered")
        local unregisterOnPlayerLogOffValue = Server():unregisterCallback("onPlayerLogOff", "onPlayerLogOff")

        debugPrint(3,"Event cleanup: "..tostring(unregisterOnSectorLeftValue).." | "..tostring(unregisterOnSectorEnteredValue).." | "..tostring(unregisterOnPlayerLogOffValue).." Expected: 0|0|0")

        playerIndex = Faction().index
        if playerIndex ~= nil and IGNOREVESIONCHECK == false then
            Player(): sendChatMessage("Sever", 2, "Waiting to receive version. Try not to Jump. This takes about 20 seconds!")
            deferredCallback(derefferedTimeout, "dCheck", playerIndex)
        end

        if playerIndex ~= nil and IGNOREVESIONCHECK == true then
            usesRightVersion = true
            registerPlayer(playerIndex)
        end

        --begin registering events for a fresh start
        Server():registerCallback("onPlayerLogOff", "onPlayerLogOff")

    else
        debugPrint(3, "client init")
    end

end


--sets a Timestamp when the last player leaves the Sector
function onSectorLeft(playerIndex, x, y)
    if Player(playerIndex).name ~= Player().name then            --wrong player called
        return
    end
    local numplayer = Sector().numPlayers
    local galaxyTickName = timeString

    if(numplayer <=1) then   -- we only need a new timestamp when a sector gets unloaded. The player is still in sector when the Hook calls, thus we check for mor remaining players
        local timestamp = Sector():getValue("oosTimestamp")
        if timestamp ~= nil then --update Timestamp
            timestamp = Server():getValue(timeString)
            Sector():setValue("oosTimestamp", timestamp)
            debugPrint(2, "timestamp: ".. timestamp .. " for Sector ".. x .. ":" .. y.." updated")
        else        --sector was never timestamped
            timestamp = Server():getValue(timeString)
            Sector():setValue("oosTimestamp", timestamp)
            debugPrint(2, "Sector get first timestamp: ".. timestamp .. " | ".. x .. ":" .. y)
        end
    end
end

--Is there a timestamp on which we can work?-Then do so.
function onSectorEntered(playerIndex, x, y)
    if Player(playerIndex).name ~= Player().name then            --wrong player called
        return
    end
    local timer = Timer()
    timer:start()
    sector = Sector()
    local stations = {sector:getEntitiesByType(EntityType.Station)}
    local ships = {sector:getEntitiesByType(EntityType.Ship)}
    if INCLUDEPLAYERS == false then
        for _,station in pairs(stations) do
            if station ~= nil and station.factionIndex ~= nil then
                if Faction(station.factionIndex).isPlayer then
                    debugPrint(3,"no OOSP update for Playersectors", nil, "Sector "..sector.name.." ("..x..":"..y..")Station: ", station.name, Player(station.factionIndex).name)
                    return
                end
            else
                debugPrint(2,"Found Factionless station", nil, station.name)
            end
        end

        for _,ship in pairs(ships) do
            if ship.factionIndex ~= nil then
                local faction = Faction(ship.factionIndex)
                if faction ~= nil then
                    if faction.isPlayer and ship.index ~= Player().craftIndex then
                        debugPrint(3,"no OOSP update for Playersectors", nil, "Sector "..sector.name.." ("..x..":"..y..") Ship: ", ship.name, Player(ship.factionIndex).name)
                        return
                    end
                else
                    debugPrint(2,"Found Factionless ship", nil, ship.name)
                end
            end
        end

        debugPrint(3, "Sector: "..x..":"..y.. " needed " ..(timer.microseconds/1000) .."ms for sorting out")
    end

    debugPrint(2, "Player: "..Player().name.." entered sector with: "..(Sector().numPlayers-1).." more player(s)")

    local timestamp = Sector():getValue("oosTimestamp")

    if timestamp ~= nil then
        if Sector().numPlayers <= 1 then
            debugPrint(2, "timestamp aquired: " .. timestamp)
            calculateOOSProductionForStations(Sector(),timestamp)
        else
            debugPrint(1, "Sector has been loaded already: "..Sector().numPlayers)
        end
    else
        debugPrint(1, "no timestamp - no production!")
    end
    timer:stop()
    debugPrint(3, "Sector: "..x..":"..y.. " needed " ..(timer.microseconds/1000) .."ms for Production catch-up")
end
