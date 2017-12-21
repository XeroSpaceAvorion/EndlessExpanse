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

local stock = {}
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

local shortageMaterial
local shortageAmount
local shortageTimerz

local guiInitialized = false

-- if this function returns false, the script will not be listed in the interaction window,
-- even though its UI may be registered
function ResourceDepot.interactionPossible(playerIndex, option)
    return CheckFactionInteraction(playerIndex, -25000)
end

function ResourceDepot.getUpdateInterval()
    return 60
end

function ResourceDepot.restore(data)
    stock = data

    -- keep compatibility with old saves
    if tablelength(stock) == 10 then
        shortageMaterial = table.remove(stock, 8)
        shortageAmount = table.remove(stock, 8)
        shortageTimer = table.remove(stock, 8)

        if shortageMaterial == -1 then shortageMaterial = nil end
        if shortageAmount == -1 then shortageAmount = nil end
    end

    if shortageTimer == nil then
        shortageTimer = -random():getInt(15 * 60, 60 * 60)
    elseif shortageTimer >= 0 and shortageMaterial ~= nil then
        ResourceDepot.startShortage()
    end
end

function ResourceDepot.secure()
    data = {}
    for k, v in pairs(stock) do
        table.insert(data, k, v)
    end

    table.insert(data, shortageMaterial or -1)
    table.insert(data, shortageAmount or -1)
    table.insert(data, shortageTimer)

    return data
end

function ResourceDepot.initialize()
    local station = Entity()

    if station.title == "" then
        station.title = "Resource Depot"%_t
    end

    for i = 1, NumMaterials() do
        sellPrice[i] = 10 * Material(i - 1).costFactor
        buyPrice[i] = 10 * Material(i - 1).costFactor
    end

    if onServer() then
        math.randomseed(Sector().seed + Sector().numEntities)

        -- best buy price: 1 iron for 10 credits
        -- best sell price: 1 iron for 10 credits
        local x, y = Sector():getCoordinates();

        local probabilities = Balancing_GetMaterialProbability(x, y);

        for i = 1, NumMaterials() do
            stock[i] = math.max(0, probabilities[i - 1] - 0.1) * (getInt(5000, 10000) * Balancing_GetSectorRichnessFactor(x, y))
        end

        local num = 0
        for i = NumMaterials(), 1, -1 do
            stock[i] = stock[i] + num
            num = num + stock[i] / 4;
        end

        for i = 1, NumMaterials() do
            stock[i] = round(stock[i])
        end

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

--function updateClient(timeStep)
--
--end

function ResourceDepot.updateServer(timeStep)
    shortageTimer = shortageTimer + timeStep

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
        if numTraded ~= shortageAmount then
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
        percentage = lerp(relation, 0, 100000, 2, 1.2)
    end

    -- 2.0 at relation = 0
    -- 3.0 at relation = -10000
    -- 3.0+ at relation < -10000
    if relation < 0 then
        percentage = lerp(relation, -10000, 0, 3, 2)
    end

    -- adjust for resource shortage
    if material == shortageMaterial then
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
        percentage = lerp(relation, 0, 100000, 0.4, 0.6)
    end

    -- 0.5 at relation = 0
    -- 0.1 at relation <= -10000
    if relation < 0 then
        percentage = lerp(relation, -10000, 0, 0.1, 0.4);

        percentage = math.max(percentage, 0.1);
    end

    -- adjust for resource shortage
    if material == shortageMaterial then
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
