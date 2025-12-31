local kismet_lib = StaticFindObject('/Script/Engine.Default__KismetSystemLibrary')	-- docs:  https://dev.epicgames.com/documentation/en-us/unreal-engine/python-api/class/SystemLibrary?application_version=4.27

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
	local data			= {}
	local characters	= FindAllOf('SBCharacter') or {}  -- '/Script/SB.SBCharacter'

	if not characters then
		logger.warn('no characters found, dont apply new nanosuit')
	end

	for _, character in pairs(characters) do
		local character_parsed	= M.Characters.parse(character)
		for char_name, char_parsed in pairs(character_parsed) do
			data[char_name] = char_parsed
		end
	end

	return setmetatable(data, M.Characters)
end



--[[
Receive "/Script/SB.SBCharacter" instance,
	return table with it's description if supported.
TODO:
	support other characters
]]
function M.Characters.parse(character)
	local character_path		= kismet_lib:GetPathName(character):ToString()
	local character_object_name	= kismet_lib:GetObjectName(character):ToString()
	local is_adam				= strings.starts_with(character_object_name,	'CH_NPC_Adam_01_Blueprint')
	local is_lily				= strings.starts_with(character_object_name,	'CH_NPC_01_Blueprint')
	local is_drone				= strings.starts_with(character_object_name,	'CH_Drone_BP')
	local is_eve				= strings.starts_with(character_object_name,	'CH_P_EVE_01_Blueprint')
	local is_eve_in_game		= strings.starts_with(character_path,			'/Game/Art')
		-- eve in lobby like:  "/Game/Lobby/Lobby.LOBBY:PersistentLevel.CH_P_EVE_01_Blueprint_C_2147482505"
		-- eve in game like:   "/Game/Art/BG/WorldMap/Level_P/E04.E04:PersistentLevel.CH_P_EVE_01_Blueprint_C_2147482114"
		-- TODO:  check what's it for: "/Game/Art/Character/PC/CH_P_EVE_01/Blueprints/CH_P_EVE_01_Blueprint.CH_P_EVE_01_Blueprint_C"
	if is_adam then
		return {[enums.Characters.adam]		= character}
	elseif is_eve and is_eve_in_game then
		return {[enums.Characters.eve]		= character}
	elseif is_lily then
		return {[enums.Characters.lily]		= character}
	elseif is_drone then
		return {[enums.Characters.drone]	= character}
	end
	-- logger.warn('unsupported character', character_object_name)
	return {}
end



function M.Characters.replace_mesh(
		character,
		new_mesh_asset,
		mesh_type	-- "FitMeshType" in JSON	-- TODO:  validate we have it
		)
	local mesh_slot			= M._FitMeshType_To_SkeletalMeshSlot[mesh_type]
	local retries_max		= 10
	local retry_current		= 0

	local function _replace_mesh(skip_objects_validation)
		local mesh_component	= character:GetSBSkeletalMeshComponent(mesh_slot)
		local some_obj_invalid	= not skip_objects_validation and (not mesh_component:IsValid() or not new_mesh_asset:IsValid())
		if some_obj_invalid then
			error('some are invalid')
		end
		mesh_component:SetSkeletalMesh(new_mesh_asset, true)
		mesh_component:ResetOverrideMaterials()		-- otherwise would leave old materials
	end

	--[[
	Don't use it now, but left in case if prev approach would be unstable.
	]]
	local function _replace_mesh_after(skip_delay_initially)	-- luacheck: ignore 211	-- unused func
		local delay = 1000
		if skip_delay_initially then
			delay = 0
		end
		ExecuteWithDelay(delay, function()	-- wait until mesh component will be loaded
			ExecuteInGameThread(function()	-- don't crash so much
				retry_current = retry_current + 1

				local success, result = pcall(_replace_mesh)
				if not success then
					logger.error('_replace_mesh() error', result)
				end

				local can_retry = retry_current <= retries_max
				if not success and can_retry then
					logger.warn('_replace_mesh_after()  scheduling later after expected error')
					_replace_mesh_after()
				end

				logger.error('_replace_mesh_after()  were unable to launch  _replace_mesh()')
			end)

		end)
	end

	local skip_objects_validation = true
	_replace_mesh(skip_objects_validation)
	-- _replace_mesh_after(true)	-- launch only if works unstable
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
