package.path = package.path .. ";data/scripts/lib/?.lua"
require ("stringutility")

if onServer() then

package.path = package.path .. ";data/scripts/?.lua"

require ("galaxy")
--local PirateGenerator = require ("pirategenerator")
local ShipGenerator = require ("shipgenerator")
local ShipUtility = require ("shiputility")
local Rewards = require ("rewards")
local SectorSpecifics = require ("sectorspecifics")
local Xsotan = require("story/xsotan")

local target = nil
local generated = 0
local rewardsGiven = 0
local pirates = {}
local traders = {}
local timeSinceCall = 0
local player = nil

local faction

local convertedTrader1 = nil
local convertedTrader2 = nil

function getUpdateInterval()
    return 5
end

function secure()
    return {dummy = 1}
end

function restore(data)
    terminate()
end

function initialize(firstInitialization)
	print "initialize(1)"

    local specs = SectorSpecifics()
    local x, y = Sector():getCoordinates()
    local coords = specs.getShuffledCoordinates(random(), x, y, 7, 12)


	print "initialize(2)"
    target = nil

    for _, coord in pairs(coords) do

        local regular, offgrid, blocked, home = specs:determineContent(coord.x, coord.y, Server().seed)

        if not regular and not offgrid and not blocked and not home then
            target = {x=coord.x, y=coord.y}
            break
        end
    end

	print "initialize(3)"

    -- if no empty sector could be found, exit silently
    if not target then
        terminate()
        return
    end


    player = Player()
    player:registerCallback("onSectorEntered", "onSectorEntered")
    player:registerCallback("onSectorLeft", "onSectorLeft")

	print "initialize(4)"

    if firstInitialization then
        local messages =
        {
            "Mayday! Mayday! We are being pursued by automated vessels! Our position is \\s(%i:%i), someone help, please!"%_t,
            "Mayday! CHRRK ... CHRRK ... please ... CHRRK ... position \\s(%i:%i) ... no survivors!"%_t,
            "Please assist us, we are being attacked by aliens \\s(%i:%i) Help!"%_t,
			"Automated General Request for Assistance: \\s(%i:%i)"%_t,
            "This is a distress call! Our position is \\s(%i:%i) We are attack by an unknown race, please help!"%_t,
        }

        player:sendChatMessage("Unknown"%_t, 0, messages[random():getInt(1, #messages)], target.x, target.y)
        player:sendChatMessage("", 3, "You have received a distress signal by an unknown source."%_t)
    end
print "initialize(6)"
end

function piratePosition()
    local pos = random():getVector(-1000, 1000)
    return MatrixLookUpPosition(-pos, vec3(0, 1, 0), pos)
end

function updateServer(timeStep)

    local x, y = Sector():getCoordinates()
    if x == target.x and y == target.y then
        updatePresentShips()

        local piratesLeft = tablelength(pirates)
        local tradersLeft = tablelength(traders)

        if rewardsGiven == 0 and piratesLeft == 0 and tradersLeft > 0 then
            rewardsGiven = 1

            local traderFaction = Faction(table.first(traders).factionIndex)
            local money = tradersLeft * 200 * Balancing_GetSectorRichnessFactor(Sector():getCoordinates())

            for _, player in pairs({Sector():getPlayers()}) do
                Rewards.standard(player, traderFaction, "On behalf of our government, thank you for assisting our people", money, 5000, true, true)
            end

        end
    elseif generated == 0 then
        timeSinceCall = timeSinceCall + timeStep

        if timeSinceCall > 10 * 60 then
            terminate()
        end
    end



end

function updatePresentShips()
    for i, pirate in pairs(pirates) do
        if not valid(pirate) then
            pirates[i] = nil
        end
    end

    for i, trader in pairs(traders) do
        if not valid(trader) then
            traders[i] = nil
        end
    end
end

function onSectorLeft(player, x, y)
    -- only react when the player left the correct Sector
    if x ~= target.x or y ~= target.y then return end


--	print "before updatePresentShips"
    updatePresentShips()

    if tablelength(pirates) == 0 then
        -- all pirates were beaten, delete all traders on leave
        for _, trader in pairs(traders) do
            Sector():deleteEntity(trader)
        end
    end

	--	print "after updatePresentShips"

    if tablelength(pirates) == 0 or tablelength(traders) == 0 then
	 print "cleanup of xsotandistresssignal."
	 target = nil
	 generated = nil
	 rewardsGiven = nil
	 pirates = nil
	 traders = nil
	 timeSinceCall = nil
	 faction= nil
	 convertedTrader1 = nil
	 convertedTrader2 = nil


        terminate()
    end
end

function infectionChat1()
	Player():sendChatMessage(faction.name .. " ship with no lifesigns", ChatMessageType.Whisp, "General Distress: LifeSupport offline, command routines offline, atmospheric pressure lost"%_T)
end

function infectionChat2()
	Player():sendChatMessage(faction.name .. " Refugee", ChatMessageType.Whisp, "There are over 2000 passengers on that vessel, please help."%_T)
end

function infectionChat3()
	Player():sendChatMessage(faction.name .. " Refugee"%_t, 0,"Who is firing from that vessel? It appears to be unmanned? OPEN FIRE" , target.x, target.y)
end



function convertTraders()
	print "Convert traders deferred call"
	convertedTrader1:addScript("story/xsotanbehaviour.lua")
	convertedTrader2:addScript("story/xsotanbehaviour.lua")
	convertedTrader1:setValue("is_xsotan", 1)
	convertedTrader2:setValue("is_xsotan", 1)


	convertedTrader2.factionIndex =  Xsotan.getFaction().index
	convertedTrader1.factionIndex =  Xsotan.getFaction().index

	ShipUtility.addTurretsToCraft(convertedTrader1, CreateXsotanPlasmaTurret(x,y), 3)
	ShipUtility.addTurretsToCraft(convertedTrader1, CreateXsotanPlasmaTurret(x,y), 1)
	ShipUtility.addTurretsToCraft(convertedTrader2,CreateXsotanPlasmaTurret(x,y), 2)
	ShipUtility.addTurretsToCraft(convertedTrader2,CreateXsotanPlasmaTurret(x,y), 4)

	convertedTrader1.crew = convertedTrader1.minCrew;
	convertedTrader2.crew = convertedTrader2.minCrew;

	convertedTrader1.name = "Ship with no lifesigns"
	convertedTrader2.name = "Ship with no lifesigns"

	ShipAI(convertedTrader1.index):registerEnemyFaction(Player().index)
	ShipAI(convertedTrader2.index):registerEnemyFaction(Player().index)

	Player():sendChatMessage(faction.name .. " ship with no lifesigns", ChatMessageType.Whisp, "Command routines overwritten, initiating new protocol."%_T)

	ShipAI(convertedTrader1.index):setAggressive()
    ShipAI(convertedTrader2.index):setAggressive()

	Sector():broadcastChatMessage("Server"%_t, 2, "Two corrupted refugee ships have gone berserk!"%_t)


end


function onSectorEntered(player, x, y)

	if generated == 1 then
		print "Already generated the xsotan distress signal traders and xsotan attackers."
		return
	end  --Do not generate the event more than once.
    if x ~= target.x or y ~= target.y then return end

    generated = 1

    -- spawn 3 ships and 10 pirates
    faction = Galaxy():getNearestFaction(x, y)
    local volume = Balancing_GetSectorShipVolume(x, y) * 2

    local look = vec3(1, 0, 0)
    local up = vec3(0, 1, 0)

	Sector():broadcastChatMessage(faction.name .. " refugees", ChatMessageType.Normal, "Please help, we cannot outrun these.. machines!"%_T)


    table.insert(traders, ShipGenerator.createMiningShip(faction, MatrixLookUpPosition(look, up, vec3(100, 50, 50)), volume*0.8))
    table.insert(traders, ShipGenerator.createFreighterShip(faction, MatrixLookUpPosition(look, up, vec3(0, -50, 0)), volume))

    table.insert(traders, ShipGenerator.createTradingShip(faction, MatrixLookUpPosition(look, up, vec3(-200, 50, -50)), volume))
    table.insert(traders, ShipGenerator.createDefender(faction, MatrixLookUpPosition(look, up, vec3(-300, -50, 50)), volume))

	--Make one trader look like it's about to turn Xsotan; but it won't actually.
	local infectedTrader = ShipGenerator.createTradingShip(faction, MatrixLookUpPosition(look, up, vec3(-100, -50, -50)), volume)
	Xsotan.infectShip(infectedTrader)
	infectedTrader.name = "damaged trader"
    table.insert(traders,infectedTrader)

	--For additional horror, add converted trader vessels, and put them nearby, they will become hostile!
	convertedTrader1 = ShipGenerator.createFreighterShip(faction, MatrixLookUpPosition(look, up, vec3(-350, -50, 50)), volume*2)
    Xsotan.infectShip(convertedTrader1)

	convertedTrader2 = ShipGenerator.createDefender(faction, MatrixLookUpPosition(look, up, vec3(-1200, -50, 50)), volume*1.3)
	Xsotan.infectShip(convertedTrader2)

	convertedTrader1.name = "Damaged refugee"
	convertedTrader2.name = "Damaged refugee"


	print "Setting callback to make two ships hostile."
	--Set the two infected traders to convert and suddenly become hostile and xsotan.
	deferredCallback(27.0, "convertTraders")


	table.insert(pirates, convertedTrader1)
	table.insert(pirates, convertedTrader2)

	createEnemies({
		  {size=1, title="Xsotan pursuer"%_t},
		  {size=2, title="Xsotan attacker"%_t},
		  {size=3, title="Xsotan hunter"%_t},
		  {size=5, title="Xsotan Interceptor"%_t},
		  {size=3, title="Xsotan Ship"%_t},
		  {size=1, title="Small Xsotan pursuer"%_t}
		  },pirates)

	--Cannot seem to get a good reference to the faction index; it keeps being nil.
    for i, pirate in pairs(pirates) do
        if valid(pirate) then
			print("faction is " ..  tostring(Xsotan.getFaction().index))
            --ShipAI(Xsotan.getFaction().index):setAggressive()
        end
    end

    for _, trader in pairs(traders) do
        ShipAI(trader.index):setPassiveShooting(1)
    end



	deferredCallback(10.0, "infectionChat1")
	deferredCallback(19.0, "infectionChat2")
	deferredCallback(36.0, "infectionChat3")

	-- --Ensure Xsotan aggresive.
    -- local player = Player()
    -- local others = Galaxy():getNearestFaction(Sector():getCoordinates())
	-- Galaxy():changeFactionRelations(Xsotan.getFaction(), player, -200000)
    -- Galaxy():changeFactionRelations(Xsotan.getFaction(), others, -200000)


end

function CreateXsotanPlasmaTurret(x,y)
    TurretGenerator.initialize(Seed(151))

    local turret = TurretGenerator.generate(x, y, 2, Rarity(RarityType.Uncommon), WeaponType.PlasmaGun)
    local weapons = {turret:getWeapons()}
    turret:clearWeapons()
    for _, weapon in pairs(weapons) do
        weapon.reach = 600
        weapon.pmaximumTime = weapon.reach / weapon.pvelocity
        weapon.hullDamageMultiplicator = 0.35
        turret:addWeapon(weapon)
    end

    turret.turningSpeed = 2.0
    turret.crew = Crew()

    return turret
end

function createEnemies(volumes,pirateTable)

    local galaxy = Galaxy()

    local faction = Xsotan.getFaction()

    local player = Player()
    local others = Galaxy():getNearestFaction(Sector():getCoordinates())
    Galaxy():changeFactionRelations(faction, player, -200000)
    Galaxy():changeFactionRelations(faction, others, -200000)

    -- create the enemies
    local dir = normalize(vec3(getFloat(-1, 1), getFloat(-1, 1), getFloat(-1, 1)))
    local up = vec3(0, 1, 0)
    local right = normalize(cross(dir, up))
    local pos = dir * 1500

    local volume = Balancing_GetSectorShipVolume(faction:getHomeSectorCoordinates());

    for _, p in pairs(volumes) do

        local enemy = Xsotan.createShip(MatrixLookUpPosition(-dir, up, pos), p.size)
        enemy.title = p.title

        local distance = enemy:getBoundingSphere().radius + 20

        pos = pos + right * distance

        enemy.translation = dvec3(pos.x, pos.y, pos.z)

        pos = pos + right * distance + 20

		table.insert(pirateTable,enemy);

        ShipAI(enemy.index):setAggressive()
    end
end



function sendCoordinates()
    invokeClientFunction(Player(callingPlayer), "receiveCoordinates", target)
end

end

function abandon()
    if onClient() then
        invokeServerFunction("abandon")
        return
    end
    terminate()
end

if onClient() then

function initialize()
print 'initialize called'
    invokeServerFunction("sendCoordinates")
    target = {x=0, y=0}
end

function receiveCoordinates(target_in)
    target = target_in
end

function getMissionBrief()
    return "Distorted Distress Signal"%_t
end

function getMissionDescription()
    if not target then return "" end

    return string.format("You received a distress call from an unknown source. Their last reported position was (%i:%i)."%_t, target.x, target.y)
end

function getMissionLocation()
    if not target then return 0, 0 end

    return target.x, target.y
end

end
