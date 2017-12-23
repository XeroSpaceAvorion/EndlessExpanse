-- Mod Name: Asteroid Composition Creation Extrusion and Spawn Simplification : ACCESS
-- Mod Author: Stalwart Pachyderm
-- Version .9 - needs testing

package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

require ("randomext")
require ("galaxy")
require ("utility")
require ("stringutility")
require ("defaultscripts")
require ("goods")
require ("merchantutility")
ShipGenerator = require ("shipgenerator")
PlanGenerator = require ("plangenerator")
ShipUtility = require ("shiputility")
GatesMap = require ("gatesmap")

local assert = assert
local SectorGenerator = {}

-- ACCESS START
-- Easily change all aspects of asteroids
-- Set to Avorion Defaults

----------------------------------
-- Advanced Mineral Spawn Start --
----------------------------------

-- Switch to per Material Spawn true 1/ false 0
local perMaterialSpawn = 1

-- Iron
local minIronSize = 0.0
local maxIronSize = 2.5
local minIronMulti = 1.5
local maxIronMulti = 2.3

-- Titanium
local minTitaniumSize = 0.0
local maxTitaniumSize = 2.5
local minTitaniumMulti = 1.5
local maxTitaniumMulti = 2.3

-- Naonite
local minNaoniteSize = 0.0
local maxNaoniteSize = 2.5
local minNaoniteMulti = 1.5
local maxNaoniteMulti = 2.3

-- Trinium
local minTriniumSize = 0.0
local maxTriniumSize = 2.5
local minTriniumMulti = 1.5
local maxTriniumMulti = 2.3

-- Xanion
local minXanionSize = 0.0
local maxXanionSize = 2.5
local minXanionMulti = 1.5
local maxXanionMulti = 2.3

-- Ogonite
local minOgoniteSize = 0.0
local maxOgoniteSize = 2.5
local minOgoniteMulti = 1.5
local maxOgoniteMulti = 2.3

-- Avorion
local minAvorionSize = 0.0
local maxAvorionSize = 2.5
local minAvorionMulti = 1.5
local maxAvorionMulti = 2.3

--------------------------------
-- END ADVANCED SPAWN-----------
--------------------------------

-------------------------------------------
-- Basic Material Spawn Start--------------
-- Ignore if using Advanced Mineral Spawn--
-------------------------------------------

-- Mineral Asteroids
local minMineralSize = 0.0
local maxMineralSize = 2.5
local minMineralMulti = 1.0
local maxMineralMulti = 1.0

--------------------------------------
-----END Basic Material Spawn---------
--------------------------------------

-- Regular Asteroids
local minRockSize = 0.0
local maxRockSize = 2.5
local minRockMulti = 1.0
local maxRockMulti = 1.0

-- Claimable Asteroids
local minClaimSize = 100
local maxClaimSize = 100
local minClaimMulti = 1
local maxClaimMulti = 1

-- Large Asteroids
-- Mineral
local minBigSize = 40
local maxBigSize = 60
local minBigMulti = 1
local maxBigMulti = 1

-- Non Mineral
local minBigRockSize = 40
local maxBigRockSize = 60
local minBigRockMulti = 1.0
local maxBigRockMulti = 1

-- Field Sizes
-- Mineral Fields
local denseAsteroidCount = 500
local maxDenseBeltVolume = 2800
local minDenseAsteroidCount = 5.0
local maxDenseAsteroidCount = 25.0
local minDenseFuzzy = 0.8
local maxDenseFuzzy = 1.25

local normalAsteroidCount = 300
local maxNormalBeltVolume = 2800
local minNormalAsteroidCount = 5.0
local maxNormalAsteroidCount = 25.0
local minNormalFuzzy = 0.5
local maxNormalFuzzy = 1.0

local smallAsteroidCount = 200
local maxSmallBeltVolume = 2800
local minSmallAsteroidCount = 5.0
local maxSmallAsteroidCount = 25.0
local minSmallFuzzy = 0.2
local maxSmallFuzzy = 0.5

-- Non Mineral Fields
local emptyAsteroidCount = 400
local maxEmptyBeltVolume = 2800
local minEmptyAsteroidCount = 5.0
local maxEmptyAsteroidCount = 25.0
local minEmptyFuzzy = 0.8
local maxEmptyFuzzy = 1.0

local emptySmallAsteroidCount = 200
local maxEmptySmallBeltVolume = 2800
local minEmptySmallAsteroidCount = 5.0
local maxEmptySmallAsteroidCount = 25.0
local minEmptySmallFuzzy = 0.2
local maxEmptySmallFuzzy = 0.4
-- ACCESS END

SectorGenerator.__index = SectorGenerator

local function new(x, y)
    assert(type(x) == "number" and type(y) == "number", "New SectorGenerator expects 2 numbers")

    return setmetatable({coordX = x, coordY = y}, SectorGenerator)
end

function SectorGenerator:getPositionInSector(maxDist)
    -- deliberately not [-1;1] to avoid round sectors
    -- see getUniformPositionInSector(maxDist) below
    local position = vec3(math.random(), math.random(), math.random());
    local dist = 0
    if maxDist == nil then
        dist = getFloat(-5000, 5000)
    else
        dist = getFloat(-maxDist, maxDist)
    end

    position = position * dist

    -- create a random up vector
    local up = vec3(math.random(), math.random(), math.random())

    -- create a random right vector
    local look = vec3(math.random(), math.random(), math.random())

    -- create the look vector from them
    local mat = MatrixLookUp(look, up)
    mat.pos = position

    return mat
end

function SectorGenerator:getUniformPositionInSector(maxDist)
    -- uniform version of getPositionInSector
    local position = random():getDirection()
    maxDist = maxDist or getFloat(-5000, 5000)
    position = position * maxDist

    local up = random():getDirection()
    local look = random():getDirection()

    local mat = MatrixLookUp(look, up)
    mat.pos = position
    return mat
end

function SectorGenerator:findStationPositionInSector(stationRadius)

    local stations = {Sector():getEntitiesByType(EntityType.Station)}
    local maxDist = 5000

    -- radius
    local radius = stationRadius * 1.75 -- keep some distance to other stations, otherwise the stations will be moved away from each other, which is not pretty

    while true do
        -- get a random position in the sector
        local mat = self:getPositionInSector(maxDist)
        local position = mat.pos

        -- check if it would intersect with another station
        local intersects = 0
        for i, station in pairs(stations) do

            -- get bounding sphere of station
            local sphere = station:getBoundingSphere();
            sphere.radius = sphere.radius * 1.75

            -- check if they intersect
            local distance = distance(position, sphere.center)
            if distance < radius + sphere.radius then
                intersects = 1;
                break;
            end

--          print("tested for intersection with " .. otherIndex .. " at position " .. tostring(otherPosition) .. ", distance: " .. distance .. ", intersecting: " .. intersects)

        end

        if intersects == 0 then
            -- doesn't intersect, great!
            return mat
        end

        -- increase distance so the search will eventually come to an end
        maxDist = maxDist + 50
    end
end

function SectorGenerator:createStash(worldMatrix, title)
    local plan = PlanGenerator.makeContainerPlan()

    local container = self:createContainer(plan, worldMatrix, 0)

    container.title = ""
    container:addScript("stash.lua")
    container.title = title or "Secret Stash"%_t

    return container
end

function SectorGenerator:createContainer(plan, worldMatrix, factionIndex)
    local desc = EntityDescriptor()
    desc:addComponents(
       ComponentType.Plan,
       ComponentType.BspTree,
       ComponentType.Intersection,
       ComponentType.Asleep,
       ComponentType.DamageContributors,
       ComponentType.BoundingSphere,
       ComponentType.BoundingBox,
       ComponentType.Velocity,
       ComponentType.Physics,
       ComponentType.Scripts,
       ComponentType.ScriptCallback,
       ComponentType.Title,
       ComponentType.Owner,
       ComponentType.FactionNotifier,
       ComponentType.WreckageCreator,
       ComponentType.Loot
       )

    desc.position = worldMatrix or self:getPositionInSector()
    desc:setPlan(plan)
    desc.title = "Container"%_t
    if factionIndex then desc.factionIndex = factionIndex end

    return Sector():createEntity(desc)
end

function SectorGenerator:createContainerField(sizeX, sizeY, circular, position, factionIndex)

    sizeX = sizeX or math.random(10, 30)
    sizeY = sizeY or math.random(10, 30)

    if circular == nil then
        circular = 0

        if math.random() < 0.2 then
            circular = 1
        end
    end

    position = position or self:getPositionInSector(maxDist)

    local space = 40.0

    local plan = PlanGenerator.makeContainerPlan()
    local basePosition = position.pos
    local up = position.up
    local look = position.look
    local right = position.right

    --local basePosition = vec3(15, 15, 15)

    for y = 1, sizeY do

        for x = 1, sizeX do

            local create = 1

            if circular == 1 then
                local radius

                if sizeX > sizeY then
                    radius = sizeY / 2
                else
                    radius = sizeX / 2
                end

                if distance(vec2(x, y), vec2(sizeX / 2, sizeY / 2)) > radius then
                    create = 0
                end
            end

            if create == 1 then
                local pos = basePosition + right * space * (x - sizeX / 2) + look * space * (y - sizeY / 2)


                local worldMatrix = Matrix();
                worldMatrix.pos = pos
                worldMatrix.up = up
                worldMatrix.look = look
                worldMatrix.right = right

                self:createContainer(plan, worldMatrix, factionIndex)
            end
        end
    end
end

function SectorGenerator:generateStationContainers(station, sizeX, sizeY, circular)

    sizeX = sizeX or math.random(8, 15)
    sizeY = sizeY or math.random(8, 15)

    if circular == nil then
        if math.random() < 0.5 then
            circular = 1
        else
            circular = 0
        end
    end

    local stationMatrix = station.position

    local box = station:getBoundingBox()

    local pos = stationMatrix:transformCoord(box.center)

    pos = pos + stationMatrix.right * (box.size.x * 0.5 + 600.0 + math.random() * 100.0)

    stationMatrix.pos = pos

    self:createContainerField(sizeX, sizeY, circular, stationMatrix, station.factionIndex)

end

-- returns an asteroid type, based on the sector's position in the galaxy
function SectorGenerator:getAsteroidType()
    local probabilities = Balancing_GetMaterialProbability(self.coordX, self.coordY)
    return Material(getValueFromDistribution(probabilities))
end

function SectorGenerator:createClaimableAsteroid(position)
    local desc = AsteroidDescriptor()
    desc:removeComponent(ComponentType.MineableMaterial)
    desc:addComponents(
       ComponentType.Owner,
       ComponentType.FactionNotifier
       )

    desc.position = position or self:getPositionInSector()
    desc:setMovePlan(PlanGenerator.makeBigAsteroidPlan(lerp(math.random(), 1, 1, minClaimSize * minClaimMulti, maxClaimSize * maxClaimMulti), 0, Material(0)))
    desc:addScript("claim.lua")

    return Sector():createEntity(desc)
end

-- creates an asteroid
function SectorGenerator:createSmallAsteroid(translation, size, resources, material)
    --acquire a random seed for the asteroid
    local plan = PlanGenerator.makeSmallAsteroidPlan(size, resources, material)
    plan.accumulatingHealth = false

    local position = MatrixLookUp(vec3(math.random(), math.random(), math.random()), vec3(math.random(), math.random(), math.random()))
    position.pos = translation

    local asteroid = Sector():createAsteroid(plan, resources, position)
    return asteroid
end

-- create an asteroid field. this field is already placed randomly in the sector.
function SectorGenerator:createAsteroidFieldEx(numAsteroids, fieldSize, minAsteroidSize, maxAsteroidSize, hasResources, probability)

    probability = probability or 0.05

    local asteroidsWithResources = numAsteroids * probability
    if hasResources == 0 then asteroidsWithResources = 0 end

    local mat = self:getPositionInSector()

    for i = 1, numAsteroids do
        local resources = 0
        if asteroidsWithResources > 0 then
            resources = 1
            asteroidsWithResources = asteroidsWithResources - 1
        end

        -- create asteroid size from those min/max values and the actual value
        local size;
		

        if math.random() < 0.15 then
			--size = lerp(math.random(), 0, 1.0, minAsteroidSize, maxAsteroidSize);
            if resources == 1 then
                resources = 0
                asteroidsWithResources = asteroidsWithResources + 1
            end
        else
            --size = lerp(math.random(), 0, 2.5, minAsteroidSize, maxAsteroidSize);
        end

        -- create the local position in the field
        local angle = getFloat(0, math.pi * 2.0)
        local height = getFloat(-fieldSize / 5, fieldSize / 5)

        local distFromCenter = getFloat(0, fieldSize * 0.75)
        local asteroidPosition = vec3(math.sin(angle) * distFromCenter, height, math.cos(angle) * distFromCenter)

        asteroidPosition = mat:transformCoord(asteroidPosition)

        local material = self:getAsteroidType()
		if resources == 1 then
			if perMaterialSpawn == 1 then
				if material.value == 0 then
					self:createSmallAsteroid(asteroidPosition, lerp(math.random(), minIronSize, maxIronSize, minAsteroidSize * minIronMulti, maxAsteroidSize * maxIronMulti), resources, material)
				elseif material.value == 1 then
					self:createSmallAsteroid(asteroidPosition, lerp(math.random(), minTitaniumSize, maxTitaniumSize, minAsteroidSize * minTitaniumMulti, maxAsteroidSize * maxTitaniumMulti), resources, material)
				elseif material.value == 2 then
					self:createSmallAsteroid(asteroidPosition, lerp(math.random(), minNaoniteSize, maxNaoniteSize, minAsteroidSize * minNaoniteMulti, maxAsteroidSize * maxNaoniteMulti), resources, material)
				elseif material.value == 3 then
					self:createSmallAsteroid(asteroidPosition, lerp(math.random(), minTriniumSize, maxTriniumSize, minAsteroidSize * minTriniumMulti, maxAsteroidSize * maxTriniumMulti), resources, material)
				elseif material.value == 4 then
					self:createSmallAsteroid(asteroidPosition, lerp(math.random(), minXanionSize, maxXanionSize, minAsteroidSize * minXanionMulti, maxAsteroidSize * maxXanionMulti), resources, material)
				elseif material.value == 5 then
					self:createSmallAsteroid(asteroidPosition, lerp(math.random(), minOgoniteSize, maxOgoniteSize, minAsteroidSize * minOgoniteMulti, maxAsteroidSize * maxOgoniteMulti), resources, material)
				elseif material.value == 6 then
					self:createSmallAsteroid(asteroidPosition, lerp(math.random(), minAvorionSize, maxAvorionSize, minAsteroidSize * minAvorionMulti, maxAsteroidSize * maxAvorionMulti), resources, material)
				else
					--Error Block
					self:createSmallAsteroid(asteroidPosition, lerp(math.random(), minMineralSize, maxMineralSize, minAsteroidSize * minMineralMulti, maxAsteroidSize * maxMineralMulti), resources, material)
				end
			else
				self:createSmallAsteroid(asteroidPosition, lerp(math.random(), minMineralSize, maxMineralSize, minAsteroidSize * minMineralMulti, maxAsteroidSize * maxMineralMulti), resources, material)
			end
		else
			--print("Non mineral Spawn")
			self:createSmallAsteroid(asteroidPosition, lerp(math.random(), minRockSize, maxRockSize, minAsteroidSize * minRockMulti, maxAsteroidSize * maxRockMulti), resources, material)
		end
    end

    return mat
end

function SectorGenerator:createDenseAsteroidField(probability)
    local size = getFloat(minDenseFuzzy, maxDenseFuzzy)

    return self:createAsteroidFieldEx(denseAsteroidCount * size, maxDenseBeltVolume * size, minDenseAsteroidCount, maxDenseAsteroidCount, 1, probability);
end

function SectorGenerator:createAsteroidField(probability)
    local size = getFloat(minNormalFuzzy, maxNormalFuzzy)

    return self:createAsteroidFieldEx(normalAsteroidCount * size, maxNormalBeltVolume * size, minNormalAsteroidCount, maxNormalAsteroidCount, 1, probability);
end

function SectorGenerator:createSmallAsteroidField(probability)
    local size = getFloat(minSmallFuzzy, maxSmallFuzzy)

    return self:createAsteroidFieldEx(smallAsteroidCount * size, maxSmallBeltVolume * size, minSmallAsteroidCount, maxSmallAsteroidCount, 1, probability);
end

function SectorGenerator:createEmptyAsteroidField()
    local size = getFloat(minEmptyFuzzy, maxEmptyFuzzy)

    return self:createAsteroidFieldEx(emptyAsteroidCount * size, maxEmptyBeltVolume * size, minEmptyAsteroidCount, maxEmptyAsteroidCount, 0);
end

function SectorGenerator:createEmptySmallAsteroidField()
    local size = getFloat(minEmptySmallFuzzy, maxEmptySmallFuzzy)

    return self:createAsteroidFieldEx(emptySmallAsteroidCount * size, maxEmptySmallBeltVolume * size, minEmptySmallAsteroidCount, maxEmptySmallAsteroidCount, 0);
end

-- create an asteroid
function SectorGenerator:createBigAsteroid(position)
    position = position or self:getPositionInSector(5000)
	-- (position, getFloat(min size multiple, max size multiple), resources y/n)
    return self:createBigAsteroidEx(position, getFloat(minBigSize * minBigMulti, maxBigSize * maxBigMulti), 1)
end

-- create an empty asteroid
function SectorGenerator:createEmptyBigAsteroid()
    local position = self:getPositionInSector(5000)
    return self:createBigAsteroidEx(position, getFloat(minBigRockSize * minBigRockMulti, maxBigRockSize * maxBigRockMulti), 0)
end

function SectorGenerator:createBigAsteroidEx(position, size, resources)

    local material = self:getAsteroidType()

    --acquire a random seed for the asteroid
    local plan = PlanGenerator.makeBigAsteroidPlan(size, resources, material)
    plan.accumulatingHealth = false

    local asteroid = Sector():createAsteroid(plan, resources, position)
    return asteroid
end

function SectorGenerator:createStation(faction, scriptPath, scale)

    local plan = PlanGenerator.makeStationPlan(faction, scriptPath, scale)
    if plan == nil then
        printlog("Error while generating a station plan for faction ".. faction .. ".")
        return
    end

    local position = self:findStationPositionInSector(plan.radius);
    local station
    -- has to be done like this, passing nil for a string doesn't work
    if scriptPath then
        station = Sector():createStation(faction, plan, position, scriptPath)
    else
        station = Sector():createStation(faction, plan, position)
    end

    AddDefaultStationScripts(station)

    station.crew = station.minCrew
    station.shieldDurability = station.shieldMaxDurability

    return station
end

function SectorGenerator:createWreckage(faction, plan, breaks)
    local wreckages = {SectorGenerator:createUnstrippedWreckage(faction, plan, breaks)}

    for _, wreckage in pairs(wreckages) do
        if random():test(0.9) then
            ShipUtility.stripWreckage(wreckage)
        end
    end

    return unpack(wreckages)
end

function SectorGenerator:createUnstrippedWreckage(faction, plan, breaks)

    breaks = breaks or 10

    if not plan then
        if math.random() < 0.5 then
            plan = PlanGenerator.makeShipPlan(faction)
        else
            plan = PlanGenerator.makeFreighterPlan(faction)
        end
    end

    local plans = {}
    if breaks > 0 then
        local tries = 0

        while tries < breaks do
            tries = tries + 1

            -- find a random index and break at that point
            local index = math.random(0, plan.numBlocks - 1)
            index = plan:getNthIndex(index)

            local newPlans = {plan:divide(index)}
            for _, p in pairs(newPlans) do
                table.insert(plans, p)
            end
        end
    end

    table.insert(plans, plan)

    local wreckages = {}

    for _, plan in pairs(plans) do
        -- create the wreckage from the plan
        plan.accumulatingHealth = false
        local wreckage = Sector():createWreckage(plan, self:getPositionInSector(5000))

        table.insert(wreckages, wreckage)

        if math.random(1, 5) == 1 then

            -- add cargo
            local index = math.random(1, tablelength(goodsArray))
            local g = goodsArray[index]
            local good = g:good()

            local maxValue = math.random(500, 3000) * Balancing_GetSectorRichnessFactor();
            local maxVolume = 100

            local amount = math.floor(math.min(maxValue / good.price, maxVolume / good.size))

            wreckage:addCargo(good, amount);
        end
    end

    return unpack(wreckages)
end

function SectorGenerator:createShipyard(faction)
    local station = self:createStation(faction, "data/scripts/entity/merchants/shipyard.lua");
    station:addScript("data/scripts/entity/merchants/repairdock.lua")

    station:addScript("data/scripts/entity/merchants/consumer.lua", ShipyardConsumerArguments())

    return station
end

function SectorGenerator:createEquipmentDock(faction)
    local station = self:createStation(faction, "data/scripts/entity/merchants/equipmentdock.lua");

    station:addScript("data/scripts/entity/merchants/turretmerchant.lua")
    station:addScript("data/scripts/entity/merchants/fightermerchant.lua")
    station:addScript("data/scripts/entity/merchants/consumer.lua", EquipmentDockConsumerArguments())

    ShipUtility.addArmedTurretsToCraft(station)

    return station
end

function SectorGenerator:createRepairDock(faction)
    local station = self:createStation(faction, "data/scripts/entity/merchants/repairdock.lua");

    station:addScript("data/scripts/entity/merchants/consumer.lua", RepairDockConsumerArguments())

    return station
end

function SectorGenerator:createMilitaryBase(faction)
    local station = self:createStation(faction, "data/scripts/entity/merchants/militaryoutpost.lua");

    station:addScript("data/scripts/entity/merchants/consumer.lua", MilitaryOutpostConsumerArguments())

    ShipUtility.addArmedTurretsToCraft(station)

    return station
end

function SectorGenerator:createResearchStation(faction)
    local station = self:createStation(faction, "data/scripts/entity/merchants/researchstation.lua");

    station:addScript("data/scripts/entity/merchants/consumer.lua", ResearchStationConsumerArguments())

    return station
end

function SectorGenerator:createTurretFactory(faction)
    local station = self:createStation(faction, "data/scripts/entity/merchants/turretfactory.lua");

    station:addScript("data/scripts/entity/merchants/turretfactoryseller.lua", "Turret Factory"%_t, unpack(getTurretFactorySoldGoods()))

    return station
end

function SectorGenerator:createFighterFactory(faction)
    local station = self:createStation(faction, "data/scripts/entity/merchants/fighterfactory.lua")
    station:addScript("data/scripts/entity/merchants/fightermerchant.lua")

    return station
end

function SectorGenerator:createBeacon(position, faction, text, args)
    local desc = EntityDescriptor()
    desc:addComponents(
       ComponentType.Plan,
       ComponentType.BspTree,
       ComponentType.Intersection,
       ComponentType.Asleep,
       ComponentType.DamageContributors,
       ComponentType.BoundingSphere,
       ComponentType.BoundingBox,
       ComponentType.Velocity,
       ComponentType.Physics,
       ComponentType.Scripts,
       ComponentType.ScriptCallback,
       ComponentType.Title,
       ComponentType.Owner,
       ComponentType.InteractionText,
       ComponentType.FactionNotifier
       )

    local plan = PlanGenerator.makeBeaconPlan()

    desc.position = position or self:getPositionInSector()
    desc:setMovePlan(plan)
    desc.title = "Beacon"%_t
    if faction then desc.factionIndex = faction.index end

    local beacon = Sector():createEntity(desc)
    beacon:addScript("beacon", text, args)
    return beacon
end

function SectorGenerator:createGates()

    local map = GatesMap(Server().seed)
    local targets = map:getConnectedSectors({x = self.coordX, y = self.coordY})

    for _, target in pairs(targets) do

        local faction = Galaxy():getLocalFaction(target.x, target.y)
        if faction ~= nil then

            local desc = EntityDescriptor()
            desc:addComponents(
               ComponentType.Plan,
               ComponentType.BspTree,
               ComponentType.Intersection,
               ComponentType.Asleep,
               ComponentType.DamageContributors,
               ComponentType.BoundingSphere,
               ComponentType.PlanMaxDurability,
               ComponentType.Durability,
               ComponentType.BoundingBox,
               ComponentType.Velocity,
               ComponentType.Physics,
               ComponentType.Scripts,
               ComponentType.ScriptCallback,
               ComponentType.Title,
               ComponentType.Owner,
               ComponentType.FactionNotifier,
               ComponentType.WormHole,
               ComponentType.EnergySystem,
               ComponentType.EntityTransferrer
               )

            local plan = PlanGenerator.makeGatePlan(Seed(faction.index) + Server().seed, faction.color1, faction.color2, faction.color3)

            local dir = vec3(target.x - self.coordX, 0, target.y - self.coordY)
            normalize_ip(dir)

            local position = MatrixLookUp(dir, vec3(0, 1, 0))
            position.pos = dir * 2000.0

            local specs = SectorSpecifics(target.x, target.y, Server().seed)

            desc:setMovePlan(plan)
            desc.position = position
            desc.factionIndex = faction.index
            desc.invincible = true
            desc:addScript("data/scripts/entity/gate.lua")

            local wormhole = desc:getComponent(ComponentType.WormHole)
            wormhole:setTargetCoordinates(target.x, target.y)
            wormhole.visible = false
            wormhole.visualSize = 50
            wormhole.passageSize = 50
            wormhole.oneWay = true

            Sector():createEntity(desc)
        end
    end


end

function SectorGenerator:createRandomWormHole()

    local value = math.random()

    if value < 0.1 then
        return self:createRandomizedWormHole()
    elseif value < 0.55 then
        return self:createRingWormHole()
    else
        return self:createDeepWormHole()
    end
end

function SectorGenerator:wormHoleAllowed(from, to)

    self.passageMap = self.passageMap or PassageMap(Server().seed)

    -- a wormhole can't be inside an unpassable sector
    if not self.passageMap:passable(from.x, from.y) or not self.passageMap:passable(to.x, to.y) then
        return false
    end

    -- if they're not either both inside or both outside, then the wormhole crosses the ring -> illegal
    if self.passageMap:insideRing(from.x, from.y) ~= self.passageMap:insideRing(to.x, to.y) then
        return false
    end

    return true
end

function SectorGenerator:createRingWormHole(angle)

    -- this type of wormhole goes around in a ring
    local distfactor = (500 - math.sqrt(self.coordX * self.coordX + self.coordY * self.coordY)) / 500 -- factor from 0 to 1
    if distfactor > 1.0 then dist = 1.0 end -- clamp at 1 max

    angle = angle or 4.0 + 40.0 * math.random() ^ 5.0 * distfactor

    if math.random() < 0.5 then angle = -angle end

    local x = math.cos(angle) * self.coordX - math.sin(angle) * self.coordY
    local y = math.sin(angle) * self.coordX + math.cos(angle) * self.coordY

    x = x + math.random(-20, 20)
    y = y + math.random(-20, 20)

    local from = {x = self.coordX, y = self.coordY}
    local to = {x = x, y = y}

    if not self:wormHoleAllowed(from, to) then return end

    return self:createWormHole(x, y, ColorRGB(1, 1, 0))

end

function SectorGenerator:createDeepWormHole(wormHoleDistance)

    local dist = math.sqrt(self.coordX * self.coordX + self.coordY * self.coordY)

    local x = self.coordX / dist
    local y = self.coordY / dist

    wormHoleDistance = wormHoleDistance or math.random(30, 100)

    -- towards center
    x = self.coordX - x * wormHoleDistance
    y = self.coordY - y * wormHoleDistance

    -- plus a little randomness
    x = x + math.random(-wormHoleDistance / 5, wormHoleDistance / 5);
    y = y + math.random(-wormHoleDistance / 5, wormHoleDistance / 5);

    local from = {x = self.coordX, y = self.coordY}
    local to = {x = x, y = y}

    if not self:wormHoleAllowed(from, to) then return end

    return self:createWormHole(x, y, ColorRGB(0, 1, 1))

end

function SectorGenerator:createRandomizedWormHole()

    -- completely random
    local x = math.random(self.coordX - 200, self.coordX + 200)
    local y = math.random(self.coordY - 200, self.coordY + 200)

    local from = {x = self.coordX, y = self.coordY}
    local to = {x = x, y = y}

    if not self:wormHoleAllowed(from, to) then return end

    return self:createWormHole(x, y, ColorRGB(0, 1, 0))
end

function SectorGenerator:createWormHole(x, y, color, size)

    local from = {x = self.coordX, y = self.coordY}
    local to = {x = x, y = y}
    if not self:wormHoleAllowed(from, to) then
        print (string.format("Wormhole from %i:%i to %i:%i is not allowed", from.x, from.y, to.x, to.y))
        return
    end

    -- position it
    local d = vec2(x - self.coordX, y - self.coordY)
    local dist = length(d)
    d = d / dist

    color = color or ColorRGB(0, 1, 1)
    size = size or math.random(30, 100) + dist / 4 -- the further it goes, the bigger it is

    local wormHole = Sector():createWormHole(x, y, color, size)

    -- wormholes are placed at 20 km outside the sector, up to 70 km outside the sector (if it were going from top to bottom of the galaxy)
    wormHole.translation = dvec3(d.x * 2000 + dist * 5, math.random(-500, 500), d.y * 2000 + dist * 5)

    -- look in the direction where it's going
    wormHole.orientation = MatrixLookUp(vec3(d.x, 0, d.y), vec3(0, 1, 0))

    return wormHole;
end

function SectorGenerator:addAmbientEvents()
    Sector():addScriptOnce("sector/passingships.lua")
    Sector():addScriptOnce("sector/traders.lua")
    Sector():addScriptOnce("sector/factionwar/initfactionwar.lua")
end

function SectorGenerator:addOffgridAmbientEvents()
end

function SectorGenerator:getWormHoleProbability()
    return 1 / 30
end

return setmetatable({new = new}, {__call = function(_, ...) return new(...) end})
