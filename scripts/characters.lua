local KismetLib	= StaticFindObject('/Script/Engine.Default__KismetSystemLibrary')

local enums		= require('enums')
local logger	= require('logger')
local strings	= require('strings')



local M = {}



--[[
Class containing all currently found in game characters instances.
]]
M.Characters			= {}
M.Characters.__index	= M.Characters


--[[
Find all spawned characters.
]]
function M.Characters.find()
	-- local allEveBlueprints = FindAllOf("/Game/Art/Character/PC/CH_P_EVE_01/Blueprints/CH_P_EVE_01_Blueprint.CH_P_EVE_01_Blueprint_C")
	-- for _, obj in pairs(allEveBlueprints) do
	-- 	logger.inspect_object('obj', obj)
	-- end
	local characters	= FindAllOf('SBCharacter')  -- '/Script/SB.SBCharacter'
	local eve			= nil
	if not characters then
		logger.warn('no characters found, dont apply new nanosuit')
		return
	else
		for _, character in pairs(characters) do
			local character_path		= KismetLib:GetPathName(character):ToString()
			local character_object_name	= KismetLib:GetObjectName(character):ToString()
			local is_eve				= strings.starts_with(character_object_name, 'CH_P_EVE_01_Blueprint')
			local is_eve_in_game		= strings.starts_with(character_path, '/Game/Art')
				-- eve in lobby like:  /Game/Lobby/Lobby.LOBBY:PersistentLevel.CH_P_EVE_01_Blueprint_C_2147482505
				-- eve in game like:   /Game/Art/BG/WorldMap/Level_P/E04.E04:PersistentLevel.CH_P_EVE_01_Blueprint_C_2147482114
			if is_eve and is_eve_in_game then
				eve = character
			end
		end
	end

	return setmetatable({
		[enums.Characters.eve]		= eve,
		[enums.Characters.lily]		= nil,	-- TODO
		[enums.Characters.adam]		= nil,	-- TODO
		[enums.Characters.drone]	= nil,	-- TODO
	}, M.Characters)
end



function M.Characters.replace_mesh(
		character,
		new_mesh_asset,
		mesh_type	-- "FitMeshType" in JSON	-- TODO:  validate we have it
		)
	local mesh_slot			= M._FitMeshType_To_SkeletalMeshSlot[mesh_type]
	local mesh_component	= character:GetSBSkeletalMeshComponent(mesh_slot)
	mesh_component:SetSkeletalMesh(new_mesh_asset, true)
	mesh_component:ResetOverrideMaterials()		-- otherwise would leave old materials
end



--[[
Taken from "Enum /Script/SB.ESBSkelMeshSlot".
]]
M._SkeletalMeshSlots = {
	Body			= 0,
	Face			= 1,
	Hair1			= 2,
	Ponytail		= 3,
	PonytailShort	= 4,
	Weapon1			= 5,
	Weapon2			= 6,
	Weapon3			= 7,
	Weapon4			= 8,
	Accessory1		= 9,
	Accessory2		= 10,
	Accessory3		= 11,
	Accessory4		= 12,
	Accessory5		= 13,
	Etc1			= 14,
	Etc2			= 15,
	Num				= 16,
	All				= 100,
	MAX				= 101,
}



M._FitMeshType_To_SkeletalMeshSlot = {
	Body	= M._SkeletalMeshSlots.Body,
	Face	= M._SkeletalMeshSlots.Face,
	Hair	= M._SkeletalMeshSlots.Hair1,
}



return M
