--[[
	Set sprite properties for climbing, square takes properties from objects, objects from sprites.
	To prevent falling during climbing we make the custom sprites more persistent and able to pass their properties to the square.
	IDs used are in the range for fileNumber 100, used by mod SpearTraps
--]]

local Ladders = {}

Ladders.idW, Ladders.idN = 26476542, 26476543
Ladders.climbSheetTopW = "TopOfLadderW"
Ladders.climbSheetTopN = "TopOfLadderN"


---@return IsoObject topOfLadder
function Ladders.getTopOfLadder(square, north)
	local objects = square:getObjects()
	for i = 0, objects:size() - 1 do
		local obj = objects:get(i)
		local name = obj:getTextureName()
		if name == ( north and Ladders.climbSheetTopN or Ladders.climbSheetTopW ) then
			return obj
		end
	end
	return nil
end

---@return IsoObject topOfLadder
function Ladders.addTopOfLadder(square, north)
	local props = square:getProperties()
	if props:Is(north and IsoFlagType.WallN or IsoFlagType.WallW) or props:Is(IsoFlagType.WallNW) then
		Ladders.removeTopOfLadder(square)
		return nil
	end

	if props:Is(north and IsoFlagType.climbSheetTopN or IsoFlagType.climbSheetTopW) then
		return Ladders.getTopOfLadder(square, north)
	else
		local object = IsoObject.new(getCell(), square, north and Ladders.climbSheetTopN or Ladders.climbSheetTopW)
		square:transmitAddObjectToSquare(object, -1)
		return object
	end
end

function Ladders.removeTopOfLadder(square)
	if not square then return end
	local objects = square:getObjects()
	for i = objects:size() - 1, 0, - 1  do
		local object = objects:get(i)
		local sprite = object:getTextureName()
		if sprite == Ladders.climbSheetTopN or sprite == Ladders.climbSheetTopW then
			square:transmitRemoveItemFromSquare(object)
		end
	end
end

function Ladders.makeLadderClimbable(square, north)
	local x, y, z = square:getX(), square:getY(), square:getZ()
	local flags = north and { climbSheet = IsoFlagType.climbSheetN, climbSheetTop = IsoFlagType.climbSheetTopN, Wall = IsoFlagType.WallN }
		or { climbSheet = IsoFlagType.climbSheetW, climbSheetTop = IsoFlagType.climbSheetTopW, Wall = IsoFlagType.WallW }
	local topSquare = square
	local topObject

	while true do
		topObject = topSquare:Is(flags.climbSheetTop) and Ladders.getTopOfLadder(topSquare,north)
		z = z + 1
		local aboveSquare = getSquare(x, y, z)
		if not aboveSquare or aboveSquare:TreatAsSolidFloor() or aboveSquare:Is("RoofGroup") then break end
		if aboveSquare:Is(flags.climbSheet) then
			if topObject then topSquare:transmitRemoveItemFromSquare(topObject) end
			topSquare = aboveSquare
		elseif not (aboveSquare:Is(flags.Wall) or aboveSquare:Is(IsoFlagType.WallNW)) then
			if topObject then topSquare:transmitRemoveItemFromSquare(topObject) end
			topSquare = aboveSquare
			break
		else
			Ladders.removeTopOfLadder(aboveSquare)
			break
		end
	end

	-- if topSquare == square then return end
	return Ladders.addTopOfLadder(topSquare, north)
end

function Ladders.makeLadderClimbableFromTop(square)

	local x = square:getX()
	local y = square:getY()
	local z = square:getZ() - 1

	local belowSquare = getSquare(x, y, z)
	if belowSquare then
		Ladders.makeLadderClimbableFromBottom(getSquare(x - 1, y,     z))
		Ladders.makeLadderClimbableFromBottom(getSquare(x + 1, y,     z))
		Ladders.makeLadderClimbableFromBottom(getSquare(x,     y - 1, z))
		Ladders.makeLadderClimbableFromBottom(getSquare(x,     y + 1, z))
	end
end

function Ladders.makeLadderClimbableFromBottom(square)

	if not square then return end

	local topObj
	local props = square:getProperties()
	if props:Is(IsoFlagType.climbSheetN) then
		Ladders.makeLadderClimbable(square, true)
	elseif props:Is(IsoFlagType.climbSheetW) then
		Ladders.makeLadderClimbable(square, false)
	end
end

-- The wookiee says to use getCore():getKey("Interact")
-- because then it respects their vanilla rebindings.
function Ladders.OnKeyPressed(key)
	-- This method only make the Ladder Climbable,
	-- It is not really do the climb things.
	-- Vanilla ClimbSheetRope is the action do the climb
	-- only make squares area climbable, 
	-- ClimbSheetReope/ClimbDownSheetReop will take careaof. 
	-- use UpdatePlayerChunk to check player current square have ladder or not

	if key == getCore():getKey("Interact") then
		local player = getPlayer()
		if not player or player:isDead() then return end
		if MainScreen.instance:isVisible() then return end

		-- Will store last player to attempt to climb a ladder.
		Ladders.player = player 
		-- might be for some reason I don know. 
		-- seems is not usefull at all. maybe on server or with gamepad?

		-- -- unset anyway before climb ladder or rope. 
		-- Ladders.player:setVariable("ClimbLadder", false)

		local square = player:getSquare()
		Ladders.makeLadderClimbableFromTop(square)
		Ladders.makeLadderClimbableFromBottom(square)
	end
end

Events.OnKeyPressed.Add(Ladders.OnKeyPressed)


function Ladders.UpdatePlayerChunk(player)
	if player:getCurrentStateName() == "ClimbSheetRopeState" or player:getCurrentStateName() == "ClimbDownSheetRopeState" then
		local square = player:getSquare()
		if not square then return end

		local is_climb_ladder = false
		local objects = square:getObjects()
		for i=0, objects:size() - 1 do
			if Ladders.ladderTiles[objects:get(i):getTextureName()] then
				is_climb_ladder = true
				break
			end
		end
		if player:getVariable("ClimbLadder") ~= is_climb_ladder then
			player:setVariable("ClimbLadder", is_climb_ladder)
		end
		if isDebugEnabled() then
			print(is_climb_ladder and '------------ IS CLIMBING LADDER-----------' or '------------ IS CLIMBING SHEETROPE -----------')
		end
	end
end

Events.OnPlayerUpdate.Add(Ladders.UpdatePlayerChunk);


--
-- When a player places a crafted ladder, he won't be able to climb it unless:
-- - the ladder sprite has the proper flags set
-- - the player moves to another chunk and comes back
-- - the player quit and load the saved game
-- - the same sprite was already spawned and went through the LoadGridsquare event
--
-- We add the missing flags here to work around the issue.
--

-- Compatibility: Adding a backup for anyone who needs it.

Ladders.ISMoveablesAction = {
	perform = ISMoveablesAction.perform
}

local ISMoveablesAction_perform = ISMoveablesAction.perform

function ISMoveablesAction:perform()

	ISMoveablesAction_perform(self)

	if self.mode == 'pickup' then
		Ladders.removeTopOfLadder(getSquare(self.square:getX(), self.square:getY(), self.square:getZ()+1))
	end
end

require "TimedActions/ISDestroyStuffAction"
Ladders.ISDestroyStuffAction = {
	perform = ISDestroyStuffAction.perform,
 }

function ISDestroyStuffAction:perform()
	if self.item:haveSheetRope() then
		Ladders.removeTopOfLadder(self.item:getSquare())
	end
	return Ladders.ISDestroyStuffAction.perform(self)
end

-- Animations

--
-- Some tiles for ladders are missing the proper flags to
-- make them climbable so we add the missing flags here.
--
-- We actually attempt to list all vanilla ladders in order
-- to flag them all using mod data; this allows us to base
-- our animation on whether the object is a ladder, rather than
-- simply climbable.
--
-- I also include many ladder tiles from mods.
--


-- No need this anymore, check player current square have ladder or not in UpdatePlayerChunk
-- the old way is bad idea, it could trigger ladder animation when climb on sheet rope.
-- because the topOjbect might not exists when stand above.
-- also the old way checked every 4 square around, what if have ladder or sheetrope very close?
-- any way the old way mixed the `make` sqaure climbable with climb animation selecttion.
-- even I could do some ducktype tp fake it work, but the logic still wrong. bad idea anyway.

--topObject means we added custom ladder object, excluded tile list is smaller that included
-- function Ladders.switchClimbAnim(square)
-- 	if not square then return end

-- 	local player = getPlayer()
-- 	local is_ladder = false
-- 	local objects = square:getObjects()
-- 	for i=0, objects:size() - 1 do
-- 		if Ladders.ladderTiles[objects:get(i):getTextureName()] then
-- 			is_ladder = true
-- 			break
-- 		end
-- 	end

-- 	if is_ladder then
-- 		Ladders.player:setVariable("ClimbLadder", true)
-- 	end
	
-- end

Ladders.westLadderTiles = {
	"industry_02_86", "location_sewer_01_32", "industry_railroad_05_20", "industry_railroad_05_36", "walls_commercial_03_0",
	"edit_ddd_RUS_decor_house_01_16", "edit_ddd_RUS_decor_house_01_19", "edit_ddd_RUS_industry_crane_01_72",
	"edit_ddd_RUS_industry_crane_01_73", "rus_industry_crane_ddd_01_24", "rus_industry_crane_ddd_01_25",
	"A1 Wall_48", "A1 Wall_80", "A1_CULT_36", "aaa_RC_6", "trelai_tiles_01_30", "trelai_tiles_01_38",
	"industry_crane_rus_72", "industry_crane_rus_73"
}

Ladders.northLadderTiles = {
	"location_sewer_01_33", "industry_railroad_05_21", "industry_railroad_05_37",
	"edit_ddd_RUS_decor_house_01_17", "edit_ddd_RUS_decor_house_01_18",
	"edit_ddd_RUS_industry_crane_01_76", "edit_ddd_RUS_industry_crane_01_77",
	"A1 Wall_49", "A1 Wall_81", "A1_CULT_37", "aaa_RC_14", "trelai_tiles_01_31",
	"trelai_tiles_01_39", "industry_crane_rus_76", "industry_crane_rus_77",
}

for index = 1, 62 do
	local name = "basement_objects_02_" .. index
	if index % 2 == 0 then
		Ladders.westLadderTiles[#Ladders.westLadderTiles + 1] = name
	else
		Ladders.northLadderTiles[#Ladders.northLadderTiles + 1] = name
	end
end

-- Generate Table for faster check during anim choice
Ladders.ladderTiles = {}

for each, name in ipairs(Ladders.westLadderTiles) do
	Ladders.ladderTiles[name] = true
end

for each, name in ipairs(Ladders.northLadderTiles) do
	Ladders.ladderTiles[name] = true
end



Ladders.holeTiles = {
	"floors_interior_carpet_01_24"
}

Ladders.poleTiles = {
	"recreational_sports_01_32", "recreational_sports_01_33"
}
-- Ladders.sheetRopes = {
-- 	"crafted_01_0", "crafted_01_1", "crafted_01_3", "crafted_01_4", "crafted_01_5", 
-- 	"crafted_01_8", "crafted_01_9", "crafted_01_10", "crafted_01_13", "crafted_01_14", "crafted_01_15", 
-- 	"crafted_01_22", "crafted_01_23",
-- 	"crafted_01_48", "crafted_01_49", "crafted_01_50", "crafted_01_53",
-- }



Ladders.setLadderClimbingFlags = function(manager)
	local IsoFlagType, ipairs = IsoFlagType, ipairs

	for each, name in ipairs(Ladders.westLadderTiles) do
		local props = manager:getSprite(name):getProperties()
		props:Set(IsoFlagType.climbSheetW)
	end

	for each, name in ipairs(Ladders.northLadderTiles) do
		local props = manager:getSprite(name):getProperties()
		props:Set(IsoFlagType.climbSheetN)
	end

	for each, name in ipairs(Ladders.holeTiles) do
		local props = manager:getSprite(name):getProperties()
		props:Set(IsoFlagType.climbSheetTopW)
		props:Set(IsoFlagType.HoppableW)
		props:UnSet(IsoFlagType.solidfloor)
	end

	for each, name in ipairs(Ladders.poleTiles) do
		local props = manager:getSprite(name):getProperties()
		props:Set(IsoFlagType.climbSheetW)
	end

	local spriteW = manager:AddSprite(Ladders.climbSheetTopW,Ladders.idW)
	spriteW:setName(Ladders.climbSheetTopW)
	local propsW = spriteW:getProperties()
	propsW:Set(IsoFlagType.climbSheetTopW)
	propsW:Set(IsoFlagType.HoppableW)
	propsW:CreateKeySet()

	local spriteN = manager:AddSprite(Ladders.climbSheetTopN,Ladders.idN)
	spriteN:setName(Ladders.climbSheetTopN)
	local propsN = spriteN:getProperties()
	propsN:Set(IsoFlagType.climbSheetTopN)
	propsN:Set(IsoFlagType.HoppableN)
	propsN:CreateKeySet()

end

Events.OnLoadedTileDefinitions.Add(Ladders.setLadderClimbingFlags)


local is_world_ladder_or_pole = function(worldobjects)
	for _, obj in ipairs(worldobjects) do
		local texture_name = obj:getTextureName()
		if Ladders.ladderTiles[texture_name] or Ladders.poleTiles[texture_name] then
			return true
		end
	end
end


Ladders.doBuildMenu = function(player, context, worldobjects, test)
	
	local climbOption = context:getOptionFromName(getText("ContextMenu_Climb_Sheet_Rope"))
	local removeRopeOption = context:getOptionFromName(getText("ContextMenu_Remove_escape_rope"))

	if climbOption then
		local square = nil
		local is_down = false
		local is_ladder = is_world_ladder_or_pole(worldobjects)
		local playerObj = getSpecificPlayer(player)
		
		local opt_name = is_ladder and getText("ContextMenu_Climb_Ladder") or climbOption.name
		context:removeOptionByName(climbOption.name)
		if square and playerObj:canClimbSheetRope(square) and playerObj:getPerkLevel(Perks.Strength) >= 0 then
			if is_ladder then
				Ladders.player:setVariable("ClimbLadder", true)
			else
				Ladders.player:setVariable("ClimbLadder", false)
			end
			context:addOptionOnTop(opt_name, worldobjects, ISWorldObjectContextMenu.onClimbSheetRope, square, is_down, player)
		end
	end

	-- take care remove escape rope, ledder's no need this option
	-- otherwise will cause Error.
	if removeRopeOption then
		if is_world_ladder_or_pole(worldobjects) then
			context:removeOptionByName(removeRopeOption.name)
		end
	end
end

Events.OnFillWorldObjectContextMenu.Add(Ladders.doBuildMenu)

return Ladders
