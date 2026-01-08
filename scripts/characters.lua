local logger	= require('logger')
local strings	= require('strings')
local tables	= require('tables')
local ue		= require('ue')



local M = {}



--[[
Find all spawned characters.
Return table:
	[character_id]: [character_instance_1, ...]
]]
function M.find()
	local assets = require('assets')	-- avoid recursive imports

	local characters	= FindAllOf('SBCharacter') or {}  -- '/Script/SB.SBCharacter'
	local data			= {
		[assets.CharacterID.eve]	= {},
		[assets.CharacterID.adam]	= {},
		[assets.CharacterID.lily]	= {},
		[assets.CharacterID.drone]	= {},
	}

	if not characters then
		logger.warn('no characters found, dont apply new nanosuit')
	end

	for _, character in pairs(characters) do
		local character_parsed = M.parse(character)
		for character_id, character_instances in pairs(character_parsed) do	-- this loops only once bc "parse" returns one key - char name
			for _, character_instance in pairs(character_instances) do		-- this loops once too bc "parse" returns only one instance in list
																				-- left this 2 loops just for simplicity
				table.insert(data[character_id], character_instance)		-- this executes only if character is supported
			end
		end
	end

	return data
end



--[[
Receive "/Script/SB.SBCharacter" instance,
	return table with character name as key, list-like table with character instance as value.
Return value maybe a bit complicated,
	but made compatible with output of "find()",
	so it could be ised in place of it.
TODO:
	support other characters
]]
function M.parse(character)
	local assets = require('assets')	-- avoid recursive imports

	local character_path		= ue.inspect__get__PathName(character)
	local character_object_name	= ue.inspect__get__ObjectName(character)
	local is_adam				= strings.starts_with(character_object_name,	'CH_NPC_Adam_01_Blueprint_C')	-- may have 2 instances of adam in game at once
	local is_lily				= strings.starts_with(character_object_name,	'CH_NPC_01_Blueprint_C')
	local is_drone				= strings.starts_with(character_object_name,	'CH_Drone_BP_C')
	local is_eve				= strings.starts_with(character_object_name,	'CH_P_EVE_01_Blueprint_C')
	local is_eve_in_game		= strings.starts_with(character_path,			'/Game/Art')
		-- eve in lobby like:  "/Game/Lobby/Lobby.LOBBY:PersistentLevel.CH_P_EVE_01_Blueprint_C_2147482505"
		-- eve in game like:   "/Game/Art/BG/WorldMap/Level_P/E04.E04:PersistentLevel.CH_P_EVE_01_Blueprint_C_2147482114"
		-- TODO:  check what's it for: "/Game/Art/Character/PC/CH_P_EVE_01/Blueprints/CH_P_EVE_01_Blueprint.CH_P_EVE_01_Blueprint_C"

	if is_eve and is_eve_in_game then
		return {[assets.CharacterID.eve]	= {character}}
	elseif is_adam then
		return {[assets.CharacterID.adam]	= {character}}
	elseif is_lily then
		return {[assets.CharacterID.lily]	= {character}}
	elseif is_drone then
		return {[assets.CharacterID.drone]	= {character}}
	end
	-- logger.warn('unsupported character', character_object_name)
	return {}
end



function M.mesh_asset__apply(
		character_id,
		character,
		replacement,
		new_mesh_asset,
		mod_outfit,
		mesh_type
		)
	local mesh_component = M.mesh_component__get(character_id, character, mesh_type)

	M.mesh_component__replace_mesh(
		mesh_component,
		new_mesh_asset
		)
	M.mesh_component__adjust_materials(
		mesh_component,
		replacement,
		mod_outfit
		)
end



--[[
Reason:
	We have to use "GetSBSkeletalMeshComponent" bc
			could not find property on Eve's class which points to glasses mesh component, only.
		There are "SBAccSlot1", "SBAccSlot3" props, but no "SBAccSlot2" prop on character object.
		Existing ones:
			local mesh_components_by_type = {
				[assets.FitMeshType.Body]		= character.Mesh,
				[assets.FitMeshType.Face]		= character.Mesh_Face,
				[assets.FitMeshType.Hair]		= character.SBHair,
				[assets.FitMeshType.PonyTail]	= character.SBPonytail,
				[assets.FitMeshType.PonyTail]	= character.SBPonytailShort,
				[assets.FitMeshType.Ears]		= character.SBAccSlot1,
				[assets.FitMeshType.Eyes]		= character.SBAccSlot3,		-- wing
				[assets.FitMeshType.Weapon]		= character.WeaponComponent,
			}
]]
function M.mesh_component__get(
		character_id,
		character,
		mesh_type
		)
	local assets = require('assets')	-- avoid recursive imports

	local is_eve	= character_id == assets.CharacterID.eve
	local is_adam	= character_id == assets.CharacterID.adam
	local is_lily	= character_id == assets.CharacterID.lily
	local is_drone	= character_id == assets.CharacterID.drone
	local mesh_component

	if is_eve then
		local is_ponytail	= mesh_type == assets.FitMeshType.PonyTail
		local use_short		= character.bShortPonyTail
		local slot

		if is_ponytail and use_short then
			slot = M._Eve_SkeletalMeshSlots.PonytailShort
		elseif is_ponytail then
			slot = M._Eve_SkeletalMeshSlots.Ponytail
		else
			local mesh_components__table = {
				[assets.FitMeshType.Body]		= M._Eve_SkeletalMeshSlots.Body,
				[assets.FitMeshType.Face]		= M._Eve_SkeletalMeshSlots.Etc1,
				[assets.FitMeshType.Hair]		= M._Eve_SkeletalMeshSlots.Hair1,
				[assets.FitMeshType.Ears]		= M._Eve_SkeletalMeshSlots.Accessory1,
				[assets.FitMeshType.Eyes]		= M._Eve_SkeletalMeshSlots.Accessory2,
				[assets.FitMeshType.Weapon]		= M._Eve_SkeletalMeshSlots.Weapon1,
			}
			slot = mesh_components__table[mesh_type]
		end

		assert(slot ~= nil, 'unable to get slot for mesh component for character '..character_id)
		mesh_component = character:GetSBSkeletalMeshComponent(slot)
	elseif is_adam then
		local mesh_components__table = {
			[assets.FitMeshType.Body]	= character.Mesh,
			[assets.FitMeshType.Face]	= character.Mesh_Face,
			[assets.FitMeshType.Ears]	= character.Mesh_FaceMask,
		}
		mesh_component = mesh_components__table[mesh_type]
	elseif is_lily then
		local mesh_components__table = {
			[assets.FitMeshType.Body]	= character.Mesh,	-- no other available
		}
		mesh_component = mesh_components__table[mesh_type]
	elseif is_drone then
		local mesh_components__table = {
			[assets.FitMeshType.Body]	= character.Mesh,	-- no other available
		}
		mesh_component = mesh_components__table[mesh_type]
	end

	assert(mesh_component, ('unable to get mesh component %s for character %s'):format(mesh_type, character_id))

	-- logger.inspect('mesh_component', mesh_component)
	return mesh_component
 end



 --[[
 Taken from "Enum /Script/SB.ESBSkelMeshSlot".
 ]]
 M._Eve_SkeletalMeshSlots = {
	Body			= 0,	-- PathName = /Game/Art/BG/WorldMap/Level_P/E04.E04:PersistentLevel.CH_P_EVE_01_Blueprint_C_2147482127.CharacterMesh0,	DisplayName = CH_P_EVE_01_Blueprint_C_2147482127.CharacterMesh0 CH_P_EVE_21,
	Face			= 1,	-- InvalidUEObject
	Hair1			= 2,	-- PathName = /Game/Art/BG/WorldMap/Level_P/E04.E04:PersistentLevel.CH_P_EVE_01_Blueprint_C_2147482127.SBHair,			DisplayName = CH_P_EVE_01_Blueprint_C_2147482127.SBHair CH_P_EVE_Hair02,
	Ponytail		= 3,	-- PathName = /Game/Art/BG/WorldMap/Level_P/E04.E04:PersistentLevel.CH_P_EVE_01_Blueprint_C_2147482127.SBPonytail,		DisplayName = CH_P_EVE_01_Blueprint_C_2147482127.SBPonytail CH_P_EVE_Hair_PonyTail_Short,
	PonytailShort	= 4,	-- PathName = /Game/Art/BG/WorldMap/Level_P/E04.E04:PersistentLevel.CH_P_EVE_01_Blueprint_C_2147482127.SBPonytailShort,	DisplayName = CH_P_EVE_01_Blueprint_C_2147482127.SBPonytailShort,
	Weapon1			= 5,	-- PathName = /Game/Art/BG/WorldMap/Level_P/E04.E04:PersistentLevel.CH_P_EVE_01_Blueprint_C_2147482127.SBSkeletalMeshComponent_2147481301,		DisplayName = CH_P_EVE_01_Blueprint_C_2147482127.SBSkeletalMeshComponent_2147481301 CH_W_Sword_01,
	Weapon2			= 6,	-- InvalidUEObject
	Weapon3			= 7,	-- InvalidUEObject
	Weapon4			= 8,	-- InvalidUEObject
	Accessory1		= 9,	-- PathName = /Game/Art/BG/WorldMap/Level_P/E04.E04:PersistentLevel.CH_P_EVE_01_Blueprint_C_2147482127.SBAccSlot1,		DisplayName = CH_P_EVE_01_Blueprint_C_2147482127.SBAccSlot1 ACC_EAR_03M,
	Accessory2		= 10,	-- PathName = /Game/Art/BG/WorldMap/Level_P/E04.E04:PersistentLevel.CH_P_EVE_01_Blueprint_C_2147482127.SBSkeletalMeshComponent_2147479962,		DisplayName = CH_P_EVE_01_Blueprint_C_2147482127.SBSkeletalMeshComponent_2147479962 ACC_GLA_12M,
	Accessory3		= 11,	-- PathName = /Game/Art/BG/WorldMap/Level_P/E04.E04:PersistentLevel.CH_P_EVE_01_Blueprint_C_2147482127.SBAccSlot3,		DisplayName = CH_P_EVE_01_Blueprint_C_2147482127.SBAccSlot3,	represent wing
	Accessory4		= 12,	-- InvalidUEObject
	Accessory5		= 13,	-- InvalidUEObject
	Etc1			= 14,	-- PathName = /Game/Art/BG/WorldMap/Level_P/E04.E04:PersistentLevel.CH_P_EVE_01_Blueprint_C_2147482127.Mesh_Face,		DisplayName = CH_P_EVE_01_Blueprint_C_2147482127.Mesh_Face CH_P_EVE_Face_Jali3,
	Etc2			= 15,	-- InvalidUEObject
	Num				= 16,	-- InvalidUEObject
	All				= 100,	-- InvalidUEObject
	MAX				= 101,	-- InvalidUEObject
 }



function M.mesh_component__replace_mesh(
		mesh_component,
		new_mesh_asset
		)

	local retries_max	= 10
	local retry_current	= 0

	--[[
	Sometimes mesh component may be unavailable not looking to debounce.
	So add checks here.
	]]
	local function _replace_mesh()
		-- skip validation on init
		local some_obj_invalid	= not mesh_component:IsValid() or not new_mesh_asset:IsValid()
		if some_obj_invalid then
			error('some are invalid')
		end

		mesh_component:SetSkeletalMesh(new_mesh_asset, true)
		mesh_component:ResetOverrideMaterials()		-- otherwise would leave old materials
	end

	--[[
	Mesh component is unavailable on character load.
	So wait for it.
	Don't use it now, bc we launch "replace_mesh" after "NotifyBP_SetMesh" and "debounce" it,
		but left in case if prev approach would be unstable.
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

	_replace_mesh()
	-- _replace_mesh_after(true)	-- launch only if works unstable
end



function M.mesh_component__adjust_materials(
			mesh_component,
			replacement,
			mod_outfit
		)

	local assets = require('assets')

	if not (mod_outfit.UserConfigs or replacement.UserConfigs) then
		logger.info('no mod_outfit.UserConfigs or replacement.UserConfigs')
		return
	end

	--[[
	Can modify only dynamic materials.
	Multiple controls can use one material,  so don't recreate it.
	]]
	local function _get_or_create__dynamic_material(material_index)
		local material		= mesh_component:GetMaterial(material_index)
		local material_new	= material
		local is_dynamic	= ue.inspect__get__ClassName(material_new) == 'MaterialInstanceDynamic'	--
		if not is_dynamic then	--
			material_new	= mesh_component:CreateDynamicMaterialInstance(material_index, material, material:GetFName())	-- NAME_None	material:GetName()	:GetFName()
		end
		return material_new
	end

	--[[
	- Apply "UserConfigs":
		- from "mod_outfit" (defaults)
		- from "replacement"
	]]

	local scalar_controls = tables.chain(mod_outfit.UserConfigs.ScalarControls, replacement.UserConfigs.ScalarControls)
	for _, scalar_control in pairs(scalar_controls) do
		local dynamic_material = _get_or_create__dynamic_material(scalar_control.MaterialIndex)
		dynamic_material:SetScalarParameterValue(ue.FindOrAddFName(scalar_control.ParamName), scalar_control.Value)
	end

	local vector_controls = tables.chain(mod_outfit.UserConfigs.VectorControls, replacement.UserConfigs.VectorControls)
	for _, vector_control in pairs(vector_controls) do
		local dynamic_material = _get_or_create__dynamic_material(vector_control.MaterialIndex)
		dynamic_material:SetVectorParameterValue(ue.FindOrAddFName(vector_control.ParamName), { R = vector_control.Value[1], G = vector_control.Value[2], B = vector_control.Value[3], A = vector_control.Value[4] })
	end

	local texture_options = tables.chain(mod_outfit.UserConfigs.TextureOptions, replacement.UserConfigs.TextureOptions)
	for _, texture_option in pairs(texture_options) do
		local texture_path
		local is_value_from_mod_outfit	= type(texture_option.Value) == 'number'	-- we have different values for simplicity in saved settings
		if is_value_from_mod_outfit then
			texture_path = texture_option.Textures[texture_option.Value]
		else
			texture_path = texture_option.Value
		end
		local dynamic_material	= _get_or_create__dynamic_material(texture_option.MaterialIndex)
		local texture_asset		= assets.UEAssetData.from_path(texture_path):load()
		dynamic_material:SetTextureParameterValue(ue.FindOrAddFName(texture_option.ParamName), texture_asset)
	end

	local material_toggles = tables.chain(mod_outfit.UserConfigs.MaterialToggles, replacement.UserConfigs.MaterialToggles)
	for _, material_toggle in pairs(material_toggles) do
		local section_id__unused	= 0	-- works with any value
		local lod_id				= 0	-- main LOD
		mesh_component:ShowMaterialSection(material_toggle.MaterialIndex, section_id__unused, material_toggle.Value, lod_id)
	end

	local shape_keys = tables.chain(mod_outfit.UserConfigs.ShapeKeys, replacement.UserConfigs.ShapeKeys)
	for _, shape_key in pairs(shape_keys) do
		local remove_zero_weight	= false		-- let's don't remove from list shape keys with zero values for now
		mesh_component:SetMorphTarget(ue.FindOrAddFName(shape_key.ShapeKeyName), shape_key.Value, remove_zero_weight)
	end
end



return M
