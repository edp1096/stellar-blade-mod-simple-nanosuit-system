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
		mod_outfit,		-- to be applied to "character"
		mesh_path,		-- selected one
		mesh_asset		-- to apply to character
		)

	local mesh_component = M.mesh_component__get(character_id, character, mod_outfit.FitMeshType)	-- "FitMeshType" not in "replacement",  but it "assets.ModInfo"

	M.mesh_component__replace_mesh(
		mesh_component,
		mesh_asset
		)
	M.mesh_component__adjust_materials(
		mesh_component,
		replacement,
		mod_outfit,
		mesh_path
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
		mesh_asset	-- to load into "mesh_component"
		)

	local retries_max	= 10
	local retry_current	= 0

	--[[
	Sometimes mesh component may be unavailable not looking to debounce.
	So add checks here.
	]]
	local function _replace_mesh()
		-- skip validation on init
		local some_obj_invalid	= not mesh_component:IsValid() or not mesh_asset:IsValid()
		if some_obj_invalid then
			error('some are invalid')
		end

		mesh_component:SetSkeletalMesh(mesh_asset, true)
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
			mod_outfit,		-- all info about mod
			mesh_path		-- selected
		)

	logger.info('characters.mesh_component__adjust_materials()  called')


	--[[
	Checks.
	]]

	if not (mod_outfit.UserConfigs or replacement.UserConfigs) then
		logger.info('no mod_outfit.UserConfigs or replacement.UserConfigs')
		return
	end


	--[[
	Imports.
	]]

	local assets	= require('assets')	-- avoid recursive imports
	local saves		= require('saves')


	--[[
	Get parameters.
	]]

	local outfit_data = tables.find(mod_outfit.OutfitDatas, function(outfit_data__current)
		local is_current_data = outfit_data__current.Mesh == mesh_path
		if is_current_data then
			return outfit_data__current
		end
		end)  or  {}

	local outfit_data__parameters = outfit_data.Parameters or {}

	local scalar_controls__from_parameters = tables.map_filter(outfit_data__parameters, function(param)
		local is_scalar_control = param.ParamType == assets.OutfitData_Parameter_Type.Scalar
		if is_scalar_control then
			return saves.ScalarControl.new(param)
		end
		end)
	local vector_controls__from_parameters = tables.map_filter(outfit_data__parameters, function(param)
		local is_vector_control = param.ParamType == assets.OutfitData_Parameter_Type.Vector
		if is_vector_control then
			return saves.VectorControl.new(param)
		end
		end)
	local texture_options__from_parameters = tables.map_filter(outfit_data__parameters, function(param)
		local is_texture_option = param.ParamType == assets.OutfitData_Parameter_Type.Texture
		if is_texture_option then
			return saves.TextureOption.new(param)
		end
		end)


	--[[
	Apply "UserConfigs":
		- made from "Parameters"
		- from "mod_outfit" (defaults)
		- from "replacement"
	]]

	local scalar_controls = tables.chain( scalar_controls__from_parameters,  mod_outfit.UserConfigs.ScalarControls,  replacement.UserConfigs.ScalarControls )
	for _, scalar_control in pairs(scalar_controls) do
		local dynamic_material = M.mesh_component__dynamic_material__get_or_create(mesh_component, scalar_control.MaterialIndex)
		if dynamic_material then
			dynamic_material:SetScalarParameterValue(ue.FindOrAddFName(scalar_control.ParamName), scalar_control.Value)
		end
	end

	local vector_controls = tables.chain( vector_controls__from_parameters,  mod_outfit.UserConfigs.VectorControls,  replacement.UserConfigs.VectorControls )
	for _, vector_control in pairs(vector_controls) do
		local dynamic_material = M.mesh_component__dynamic_material__get_or_create(mesh_component, vector_control.MaterialIndex)
		if dynamic_material then
			dynamic_material:SetVectorParameterValue(ue.FindOrAddFName(vector_control.ParamName), { R = vector_control.Value[1], G = vector_control.Value[2], B = vector_control.Value[3], A = vector_control.Value[4] })
		end
	end

	local texture_options = tables.chain( texture_options__from_parameters,  mod_outfit.UserConfigs.TextureOptions,  replacement.UserConfigs.TextureOptions )
	for _, texture_option in pairs(texture_options) do
		local dynamic_material	= M.mesh_component__dynamic_material__get_or_create(mesh_component, texture_option.MaterialIndex)
		if not dynamic_material then
			goto continue__texture_options
		end

		local texture_path
		local is_value_index = type(texture_option.Value) == 'number'

		if is_value_index then
			-- Value is an index, need to find Textures array
			if texture_option.Textures then
				-- Textures array is available (from mod_outfit or parameters)
				texture_path = texture_option.Textures[texture_option.Value]
			else
				-- Textures array not available, need to find it from mod_outfit
				-- Find matching TextureOption in mod_outfit by ParamName + MaterialIndex
				local mod_texture_option = tables.find(mod_outfit.UserConfigs.TextureOptions, function(mod_opt)
					if mod_opt.ParamName == texture_option.ParamName
						and mod_opt.MaterialIndex == texture_option.MaterialIndex then
						return mod_opt
					end
				end)

				if mod_texture_option and mod_texture_option.Textures then
					texture_path = mod_texture_option.Textures[texture_option.Value]
				else
					logger.error(('Cannot resolve texture index %d for ParamName=%s MaterialIndex=%d - no Textures array found in mod outfit'):format(
						texture_option.Value,
						texture_option.ParamName or 'nil',
						texture_option.MaterialIndex
					))
					goto continue__texture_options
				end
			end
		else
			-- Value is a direct texture path
			texture_path = texture_option.Value
		end

		if not texture_path then
			logger.error(('Texture path is nil for ParamName=%s MaterialIndex=%d'):format(
				texture_option.ParamName or 'nil',
				texture_option.MaterialIndex
			))
			goto continue__texture_options
		end

		local texture_asset = assets.UEAssetData.from_path(texture_path):load()
		dynamic_material:SetTextureParameterValue(ue.FindOrAddFName(texture_option.ParamName), texture_asset)

		::continue__texture_options::
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



--[[
Can modify only dynamic materials.
Multiple controls can use one material,  so don't recreate it.
]]
function M.mesh_component__dynamic_material__get_or_create(mesh_component, material_index)
	local material = mesh_component:GetMaterial(material_index)

	if not material:IsValid() then	-- mod may contain multiple meshes,  some meshes may miss some materials
		return nil
	end

	local material_new	= material
	local is_dynamic	= ue.inspect__get__ClassName(material_new) == 'MaterialInstanceDynamic'
	if not is_dynamic then
		material_new	= mesh_component:CreateDynamicMaterialInstance(material_index, material, material:GetFName())	-- NAME_None	material:GetName()	:GetFName()
	end
	return material_new
end




--[[
Hide ponytail mesh components for a character.
Args:
	character - character instance (SBCharacter)
]]
function M.hide_ponytail(character)
	if not character or not character:IsValid() then
		logger.warn('invalid character, cannot hide ponytail')
		return
	end

	-- Method 1: Try to set mesh to null/none
	if character.SBPonytail and character.SBPonytail:IsValid() then
		logger.info('hiding SBPonytail')
		-- Try multiple methods to hide the ponytail
		character.SBPonytail:SetSkeletalMesh(nil, true)
		character.SBPonytail:SetVisibility(false, true)
		character.SBPonytail:SetHiddenInGame(true, true)
	end

	if character.SBPonytailShort and character.SBPonytailShort:IsValid() then
		logger.info('hiding SBPonytailShort')
		character.SBPonytailShort:SetSkeletalMesh(nil, true)
		character.SBPonytailShort:SetVisibility(false, true)
		character.SBPonytailShort:SetHiddenInGame(true, true)
	end
end



--[[
Show ponytail mesh components for a character (reverse of hide_ponytail).
Args:
	character - character instance (SBCharacter)
]]
function M.show_ponytail(character)
	if not character or not character:IsValid() then
		logger.warn('invalid character, cannot show ponytail')
		return
	end

	-- Restore visibility for ponytail components
	if character.SBPonytail and character.SBPonytail:IsValid() then
		logger.info('showing SBPonytail')
		character.SBPonytail:SetVisibility(true, true)
		character.SBPonytail:SetHiddenInGame(false, true)
	end

	if character.SBPonytailShort and character.SBPonytailShort:IsValid() then
		logger.info('showing SBPonytailShort')
		character.SBPonytailShort:SetVisibility(true, true)
		character.SBPonytailShort:SetHiddenInGame(false, true)
	end
end

return M


