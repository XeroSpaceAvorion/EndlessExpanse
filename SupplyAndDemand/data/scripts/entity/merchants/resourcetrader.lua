package.path = package.path .. ";data/scripts/lib/?.lua"
require ("randomext")
require ("galaxy")
require ("utility")
require ("stringutility")
require ("faction")
require ("player")
require ("merchantutility")
local Dialog = require("dialogutility")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace ResourceDepot
ResourceDepot = {}

ResourceDepot.tax = 0.2

-- Menu items
local window = 0
local buyAmountTextBox = 0
local sellAmountTextBox = 0

--Table that contains the actual stock
local stock = {}
--Table that contains desired stock.
local desiredStock = {}

local buyPrice = {}
local sellPrice = {}

local soldGoodStockLabels = {}
local soldGoodPriceLabels = {}
local soldGoodTextBoxes = {}
local soldGoodButtons = {}

local boughtGoodNameLabels = {}
local boughtGoodStockLabels = {}
local boughtGoodPriceLabels = {}
local boughtGoodTextBoxes = {}
local boughtGoodButtons = {}
local best = nil

local shortageMaterial
local shortageAmount
local shortageTimer

--Inaptitude:
local standardSupply = 100000;

local guiInitialized = false

-- if this function returns false, the script will not be listed in the interaction window,
-- even though its UI may be registered
function ResourceDepot.interactionPossible(playerIndex, option)
	--print("TELL INAPTITUDE TO REMOVE THE REASON FOR THIS WARNING THIS ASAP")
	--return true
    return CheckFactionInteraction(playerIndex, -25000)
end

function ResourceDepot.getUpdateInterval()
    return 15
end

function ResourceDepot.restore(data)

	local mats = NumMaterials()

--	print("data present: " .. tablelength(data))
	print("XeroSpaceAvorion::SupplyAndDemand init")

	if tablelength(data) == mats*2+3 then
		--print("modded -> modded load")

		for i=1,mats do
	  		stock[i] = 	data[i]
         	desiredStock[i] = data[i+mats]
		--	print("(" .. i .. ")" .. "Desired: " .. desiredStock[i] .. " actual: " .. stock[i])
		end

		shortageMaterial = data[1+mats*2]
		shortageAmount = data[2+mats*2]
		shortageTimer = data[3+mats*2]

		for i=1,tablelength(data) do
			if data[i] ~= nil then
			--	print("data[" .. i .. "] == " .. data[i])
			end
		end

	else
		print("XeroSpaceAvorion::SupplyAndDemand: first restocking of station tablelength was: " .. tablelength(data))
		ResourceDepot.generateResourcesAndTrackSupply()
	end

    if shortageTimer == nil then
        shortageTimer = -random():getInt(15 * 60, 60 * 60)
    elseif shortageTimer >= 0 and shortageMaterial ~= nil then
        ResourceDepot.startShortage()
    end
end

function ResourceDepot.secure()
    data = {}

	mats = NumMaterials();

		--print("mats" .. mats)

	for i=1,mats do
		data[i] = stock[i]
		data[i+mats] = desiredStock[i]
	end

    --Notice: the -1 prevents problems with tablelength!
	data[1+mats*2] = shortageMaterial or -1
	data[2+mats*2] = shortageAmount or -1
	data[3+mats*2] = shortageTimer

    return data
end

function ResourceDepot.initialize()
    local station = Entity()

    if station.title == "" then
        station.title = "Resource Depot"%_t
    end

	ResourceDepot.UpdatePricesByStock()

    if onServer() then

		--Generate not only resources, but keep track of 'natural' starting supply.
		ResourceDepot.generateResourcesAndTrackSupply();

        -- resource shortage
        shortageTimer = -random():getInt(15 * 60, 60 * 60)

        math.randomseed(appTimeMs())
    end

    if onClient() and EntityIcon().icon == "" then
        EntityIcon().icon = "data/textures/icons/pixel/resources.png"
        InteractionText(station.index).text = Dialog.generateStationInteractionText(station, random())
    end
end

-- create all required UI elements for the client side
function ResourceDepot.initUI()
    local res = getResolution()
    local size = vec2(700, 650)

    local menu = ScriptUI()
    window = menu:createWindow(Rect(res * 0.5 - size * 0.5, res * 0.5 + size * 0.5));
    menu:registerWindow(window, "Trade Materials"%_t);

    window.caption = ""
    window.showCloseButton = 1
    window.moveable = 1

    -- create a tabbed window inside the main window
    local tabbedWindow = window:createTabbedWindow(Rect(vec2(10, 10), size - 10))

    -- create buy tab
    local buyTab = tabbedWindow:createTab("Buy"%_t, "data/textures/icons/purse.png", "Buy from station"%_t)
    ResourceDepot.buildBuyGui(buyTab)

    -- create sell tab
    local sellTab = tabbedWindow:createTab("Sell"%_t, "data/textures/icons/coins.png", "Sell to station"%_t)
    ResourceDepot.buildSellGui(sellTab)

    ResourceDepot.retrieveData();
    guiInitialized = true
end


function ResourceDepot.buildBuyGui(window)
    ResourceDepot.buildGui(window, 1)
end

function ResourceDepot.buildSellGui(window)
    ResourceDepot.buildGui(window, 0)
end

function ResourceDepot.buildGui(window, guiType)

    local buttonCaption = ""
    local buttonCallback = ""
    local textCallback = ""

    if guiType == 1 then
        buttonCaption = "Buy"%_t
        buttonCallback = "onBuyButtonPressed"
        textCallback = "onBuyTextEntered"
    else
        buttonCaption = "Sell"%_t
        buttonCallback = "onSellButtonPressed"
        textCallback = "onSellTextEntered"
    end

    local nameX = 10
    local stockX = 250
    local volX = 340
    local priceX = 390
    local textBoxX = 480
    local buttonX = 550

    -- header
    -- createLabel(window, vec2(nameX, 10), "Name", 15)
    window:createLabel(vec2(stockX, 0), "Stock"%_t, 15)
    window:createLabel(vec2(priceX, 0), "Cr"%_t, 15)

    local y = 25
    for i = 1, NumMaterials() do

        local yText = y + 6

        local frame = window:createFrame(Rect(0, y, textBoxX - 10, 30 + y))

        local nameLabel = window:createLabel(vec2(nameX, yText), "", 15)
        local stockLabel = window:createLabel(vec2(stockX, yText), "", 15)
        local priceLabel = window:createLabel(vec2(priceX, yText), "", 15)
        local numberTextBox = window:createTextBox(Rect(textBoxX, yText - 6, 60 + textBoxX, 30 + yText - 6), textCallback)
        local button = window:createButton(Rect(buttonX, yText - 6, window.size.x, 30 + yText - 6), buttonCaption, buttonCallback)

        button.maxTextSize = 16

        numberTextBox.text = "0"
        numberTextBox.allowedCharacters = "0123456789"
        numberTextBox.clearOnClick = 1

        if guiType == 1 then
            table.insert(soldGoodStockLabels, stockLabel)
            table.insert(soldGoodPriceLabels, priceLabel)
            table.insert(soldGoodTextBoxes, numberTextBox)
            table.insert(soldGoodButtons, button)
        else
            table.insert(boughtGoodNameLabels, nameLabel)
            table.insert(boughtGoodStockLabels, stockLabel)
            table.insert(boughtGoodPriceLabels, priceLabel)
            table.insert(boughtGoodTextBoxes, numberTextBox)
            table.insert(boughtGoodButtons, button)
        end

        nameLabel.caption = Material(i - 1).name
        nameLabel.color = Material(i - 1).color

        y = y + 35
    end

end

--function renderUIIndicator(px, py, size)
--
--end
--
-- this function gets called every time the window is shown on the client, ie. when a player presses F
function ResourceDepot.onShowWindow(optionIndex, material)
    local interactingFaction = Faction(Entity(Player().craftIndex).factionIndex)

    if material then
        ResourceDepot.updateLine(material, interactingFaction)
    else
        for material = 1, NumMaterials() do
            ResourceDepot.updateLine(material, interactingFaction)
        end
    end
end

function ResourceDepot.updateLine(material, interactingFaction)
    remoteBuyPrice = ResourceDepot.getBuyPriceAndTax(material, interactingFaction, 1)
    remoteSellPrice = ResourceDepot.getSellPriceAndTax(material, interactingFaction, 1)

    soldGoodPriceLabels[material].caption = tostring(remoteBuyPrice)
    boughtGoodPriceLabels[material].caption = tostring(remoteSellPrice)

    -- resource shortage
    if shortageMaterial == material then
        soldGoodStockLabels[material].caption = "---"
        soldGoodTextBoxes[material]:hide()
        soldGoodButtons[material].active = false

        data = {amount = shortageAmount, material = Material(material - 1).name}
        boughtGoodStockLabels[material].caption = "---"
        boughtGoodNameLabels[material].caption = "Deliver ${amount} ${material}"%_t % data
        boughtGoodTextBoxes[material]:hide()

    else
        soldGoodStockLabels[material].caption = createMonetaryString(stock[material])
        soldGoodTextBoxes[material]:show()
        soldGoodButtons[material].active = true

        boughtGoodStockLabels[material].caption = createMonetaryString(stock[material])
        boughtGoodNameLabels[material].caption = Material(material - 1).name
        boughtGoodTextBoxes[material]:show()
    end
end
--
---- this function gets called every time the window is closed on the client
--function onCloseWindow()
--
--end
--
--function update(timeStep)
--
--end

function equalizeResources(timeStep)
	local timefactor = timeStep/60

	local factorPerminute = 0.05  *timefactor--5%.
	local minimumPerMinute = 10 *timefactor --when equalizing, please do at least 100.

	--print("timefactor " .. timefactor .. " diff per update: " .. factorPerminute .. " minimum: ")

	local mats =  NumMaterials();

	 --Regenerate, or lose 10% to go back to normal stats.
	for i = 1, mats do

		local shortage = desiredStock[i] - stock[i]
		if(shortage ~= 0) then
			local bonus = 1
			-- -6 through +6.
			local worseness = (best - i )
			local comparison = math.abs(worseness)

			local d = math.abs(shortage)
			local change = math.min(
								math.max(math.ceil(d * factorPerminute),math.ceil(minimumPerMinute))
								,d)


			 --power 1.3 yields a nice curve where 6 = 10x increase in change speed.
			--http://fooplot.com/#W3sidHlwZSI6MCwiZXEiOiJ4XjEuMyIsImNvbG9yIjoiIzAwMDAwMCJ9LHsidHlwZSI6MTAwMCwid2luZG93IjpbIi00LjI2NCIsIjguNzM1OTk5OTk5OTk5OTk5IiwiLTEuNDcyMDAwMDAwMDAwMDA0NCIsIjYuNTI3OTk5OTk5OTk5OTk5Il19XQ--
			bonus = bonus + math.pow(comparison,1.3)
 			--print("material " .. i  .. "worseness: " .. worseness .. " bonus: " .. bonus .. "desired: " .. desiredStock[i] .. " current: " .. stock[i] .. " changebeforeamplification: " .. change);

			if shortage < 0 then
				stock[i] = stock[i] - math.min(change * bonus,d) --Cap change to exact distance to ideal stock.
			elseif shortage > 0 then
				stock[i] = stock[i] + math.min(change* bonus,d)  --Cap change to exact distance to ideal stock.
			end

			--Negative stock is not allowed and super destructive.
			stock[i] = math.max(0,stock[i])

			--Broadcast the new stock to clients.
			if onServer() then
			     broadcastInvokeClientFunction("setData", i, stock[i])
			end
		end
	end
end


function updateClient(timeStep)
	--equalizeResources()

	invokeServerFunction("getData")
end

function ResourceDepot.updateServer(timeStep)
    shortageTimer = shortageTimer + timeStep

	equalizeResources(timeStep)

	if guiInitialized then
		ResourceDepot.onShowWindow(0, material)
	end

    if shortageTimer >= 0 and shortageMaterial == nil then
        ResourceDepot.startShortage()
    elseif shortageTimer >= 30 * 60 then
        ResourceDepot.stopShortage()
    end
end

--function renderUI()
--
--end

-- client sided
function ResourceDepot.onBuyButtonPressed(button)
    local material = 0

    for i = 1, NumMaterials() do
        if soldGoodButtons[i].index == button.index then
            material = i
        end
    end

    local amount = soldGoodTextBoxes[material].text
    if amount == "" then
        amount = 0
    else
        amount = tonumber(amount)
    end

    invokeServerFunction("buy", material, amount);

end

function ResourceDepot.onSellButtonPressed(button)

    local material = 0

    for i = 1, NumMaterials() do
        if boughtGoodButtons[i].index == button.index then
            material = i
        end
    end

    local amount = boughtGoodTextBoxes[material].text
    if amount == "" then
        amount = 0
    else
        amount = tonumber(amount)
    end

    -- resource shortage
    if material == shortageMaterial then
        amount = shortageAmount
    end

    invokeServerFunction("sell", material, amount);
end

function ResourceDepot.onBuyTextEntered()

end

function ResourceDepot.onSellTextEntered()

end

function ResourceDepot.retrieveData()
    invokeServerFunction("getData")
end

function ResourceDepot.setData(material, amount, shortage)
    if shortage ~= nil then
        if shortage >= 0 then
            shortageMaterial = material
            shortageAmount = shortage
        else
            if shortageMaterial ~= nil then
                shortageMaterial = nil
                shortageAmount = nil
            end
        end
    end

    stock[material] = amount

    if guiInitialized then
        ResourceDepot.onShowWindow(0, material)
    end

end


-- server sided
function ResourceDepot.buy(material, amount)

    if amount <= 0 then return end

    local seller, ship, player = getInteractingFaction(callingPlayer, AlliancePrivilege.SpendResources)
    if not seller then return end

    local station = Entity()

    local numTraded = math.min(stock[material], amount)
    local price, tax = ResourceDepot.getBuyPriceAndTax(material, seller, numTraded);

    local errors = {}
    errors[EntityType.Station] = "You must be docked to the station to trade."%_T
    errors[EntityType.Ship] = "You must be closer to the ship to trade."%_T
    if not CheckPlayerDocked(player, station, errors) then
        return
    end

    local ok, msg, args = seller:canPay(price)
    if not ok then
        player:sendChatMessage(station.title, 1, msg, unpack(args))
        return
    end

    receiveTransactionTax(station, tax)

    seller:pay("Bought resources for %1% credits."%_T, price)
    seller:receiveResource("", Material(material - 1), numTraded)

    stock[material] = stock[material] - numTraded

    ResourceDepot.improveRelations(numTraded, ship, seller)

    -- update
    broadcastInvokeClientFunction("setData", material, stock[material])
end

function ResourceDepot.sell(material, amount)

    if amount <= 0 then return end

    local buyer, ship, player = getInteractingFaction(callingPlayer, AlliancePrivilege.SpendResources)
    if not buyer then return end

    local station = Entity()

    local errors = {}
    errors[EntityType.Station] = "You must be docked to the station to trade."%_T
    errors[EntityType.Ship] = "You must be closer to the ship to trade."%_T
    if not CheckPlayerDocked(player, station, errors) then
        return
    end

    local playerResources = {buyer:getResources()}
    local numTraded = math.min(playerResources[material], amount)
    local price, tax = ResourceDepot.getSellPriceAndTax(material, buyer, numTraded);

    -- resource shortage
    if material == shortageMaterial then
        if numTraded < shortageAmount then
            buyer:sendChatMessage("Server"%_t, 1, "You don't have enough ${material}."%_t % {material = Material(material - 1).name})
            return
        end
    end

    receiveTransactionTax(station, tax)

    buyer:receive("Sold resources for %1% credits."%_T, price);
    buyer:payResource("", Material(material - 1), numTraded);

    stock[material] = stock[material] + numTraded

    ResourceDepot.improveRelations(numTraded, ship, buyer)

    -- update
    broadcastInvokeClientFunction("setData", material, stock[material]);

    if material == shortageMaterial then
        ResourceDepot.stopShortage()
    end
end

-- relations improve when trading
function ResourceDepot.improveRelations(numTraded, ship, buyer)
    relationsGained = relationsGained or {}

    local gained = relationsGained[buyer.index] or 0
    local maxGainable = 10000
    local gainable = math.max(0, maxGainable - gained)

    local gain = numTraded / 20
    gain = math.min(gain, gainable)

    -- mining ships get higher relation gain
    if ship:getNumUnarmedTurrets() > ship:getNumArmedTurrets() then
        gain = gain * 1.5
    end

    Galaxy():changeFactionRelations(buyer, Faction(), gain)

    -- remember that the player gained that many relation points
    gained = gained + gain
    relationsGained[buyer.index] = gained
end

function ResourceDepot.getBuyingFactor(material, orderingFaction)
    local stationFaction = Faction()

    if orderingFaction.index == Faction().index then return 1 end

    local percentage = 1;
    local relation = stationFaction:getRelations(orderingFaction.index)

    -- 2.0 at relation = 0
    -- 1.2 at relation = 100000
    if relation >= 0 then
		--WARNING vanilla script does not have ANY method by which price can be communicate to it.
		--therefore prices MUST remain the same.
        percentage = lerp(relation, 0, 100000, 2, 1.2)
    end

    -- 2.0 at relation = 0
    -- 3.0 at relation = -10000
    -- 3.0+ at relation < -10000
    if relation < 0 then
		--WARNING vanilla script does not have ANY method by which price can be communicate to it.
		--therefore prices MUST remain the same.
        percentage = lerp(relation, -10000, 0, 3, 2)
    end

    -- adjust for resource shortage
    if material == shortageMaterial then
		--WARNING vanilla script does not have ANY method by which price can be communicate to it.
		--therefore prices MUST remain the same.
        percentage = percentage * 1.5
    end

    return percentage
end

function ResourceDepot.getSellingFactor(material, orderingFaction)

    local stationFaction = Faction()

    if orderingFaction.index == Faction().index then return 1 end

    local percentage = 1;
    local relation = stationFaction:getRelations(orderingFaction.index)

    -- 0.5 at relation = 0
    -- 0.8 at relation = 100000
    if relation >= 0 then
		--WARNING vanilla script does not have ANY method by which price can be communicate to it.
		--therefore prices MUST remain the same.
        percentage = lerp(relation, 0, 100000, 0.4, 0.6)
    end

    -- 0.5 at relation = 0
    -- 0.1 at relation <= -10000
    if relation < 0 then
		--WARNING vanilla script does not have ANY method by which price can be communicate to it.
		--therefore prices MUST remain the same.
        percentage = lerp(relation, -10000, 0, 0.4, 0.7);

        percentage = math.max(percentage, 0.1);
    end

    -- adjust for resource shortage
    if material == shortageMaterial then
		--WARNING vanilla script does not have ANY method by which price can be communicate to it.
		--therefore prices MUST remain the same.
        percentage = percentage * 2
    end

    return percentage
end

function ResourceDepot.getSellPriceAndTax(material, buyer, num)
    local price = round(sellPrice[material] * ResourceDepot.getSellingFactor(material, buyer), 1) * num
    local tax = round(price * ResourceDepot.tax)

    if Faction().index == buyer.index then
        price = price - tax
        -- don't pay out for the second time
        tax = 0
    end

    return price, tax
end

function ResourceDepot.getBuyPriceAndTax(material, seller, num)
    local price = round(buyPrice[material] * ResourceDepot.getBuyingFactor(material, seller), 1) * num
    local tax = round(price * ResourceDepot.tax)

    if Faction().index == seller.index then
        price = price - tax
        -- don't pay out for the second time
        tax = 0
    end

    return price, tax
end

function ResourceDepot.getData()

    local player = Player(callingPlayer)

    for i = 1, NumMaterials() do
        invokeClientFunction(player, "setData", i, stock[i]);
    end

end

function ResourceDepot.startShortage()
    -- find material
    local probabilities = Balancing_GetMaterialProbability(Sector():getCoordinates());
    local materials = {}
    for mat, value in pairs(probabilities) do
        if value > 0 then
            table.insert(materials, mat)
        end
    end

    local numMaterials = tablelength(materials)
    if numMaterials == 0 then
        terminate()
    end

    shortageMaterial = materials[random():getInt(1, numMaterials)] + 1
    shortageAmount = random():getInt(5, 25) * 1000

    -- apply
    stock[shortageMaterial] = 0

    broadcastInvokeClientFunction("setData", shortageMaterial, 0, shortageAmount)

    local values = {material = Material(shortageMaterial - 1).name, amount = shortageAmount}
    local text = "We need ${amount} ${material}, quickly! If you can deliver in the next 30 minutes we will pay you handsomely."
    Sector():broadcastChatMessage(Entity().title, 0, text%_t % values)
end

function ResourceDepot.stopShortage()
    local material = shortageMaterial
    shortageMaterial = nil
    shortageAmount = nil
    shortageTimer = -random():getInt(45 * 60, 90 * 60)

    broadcastInvokeClientFunction("setData", material, stock[material], -1)
end

--TODO this needs to extra work to work; we probably need to set a maximum on the resources you may by.
function ResourceDepot.UpdatePricesByStock()

	local materialsCount = NumMaterials()
	for i = 1, materialsCount do
		--WARNING vanilla script does not have ANY method by which price can be communicate to it.
		--therefore prices MUST remain the same.
		sellPrice[i] = 10 * Material(i - 1).costFactor;
		buyPrice[i] = 10 * Material(i - 1).costFactor;
	end
end

--Methods added to produce extra functionality.
function ResourceDepot.generateResourcesAndTrackSupply()
	math.randomseed(Sector().seed + Sector().numEntities)

	-- best buy price: 1 iron for 10 credits
	-- best sell price: 1 iron for 10 credits
	local x, y = Sector():getCoordinates();

	local probabilities = Balancing_GetMaterialProbability(x, y);

	stock = {}
	desiredStock = {}

	for i = 1, NumMaterials() do
		--DesiredStock will contain the desired stock.
		desiredStock[i] =  math.max(0, probabilities[i - 1] - 0.1) * (getInt(5000, 10000) * Balancing_GetSectorRichnessFactor(x, y))
		if desiredStock[i] > 0 then best = i end
		stock[i] = desiredStock[i];
	end

	--Some stupid resource docks spawn without e.g. iron; ensure always at least half of best material.
	for i = 1, best do
		if i < best then
			 desiredStock[i] = math.max(desiredStock[i],desiredStock[best] / 2 )
		end
	end

	--Vanilla code; makes the lower tier materials less rare and rounds?
	--Top loop is dodgy, though.
	local num = 0
	for i = NumMaterials(), 1, -1 do
		stock[i] = stock[i] + num
		num = num + stock[i] / 4;
	end

	for i = 1, NumMaterials() do
		stock[i] = round(stock[i])
	end
end


function table.empty (self)
    for _, _ in pairs(self) do
        return false
    end
    return true
end
