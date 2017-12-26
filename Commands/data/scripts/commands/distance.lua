package.path = package.path .. ";data/scripts/lib/?.lua"

require ("galaxy")
function execute(sender, commandName, ...)
    local args = {...}

	local player = Player(sender)
	local x,y = player:getSectorCoordinates()
	local distance = math.sqrt(x*x+y*y)
	local boss = ""

	if distance > 380 and distance < 430 then
	 boss = "Warning: Traffic shows more Boss swoks than usual."
	elseif  distance > 280 and distance < 340 then
	 boss = "Warning: Traffic shows more AI appear than usual."
	end

	player:sendChatMessage("Xero Maps", ChatMessageType.Whisp, "Your distance to 0;0 is " .. round(distance) .. " sectors. " .. boss .. ".")

    return 0, "", ""
end

function getDescription()
    return "Calculates your distance to the core"
end

function getHelp()
    return "Tells you the distance to the core."
end
