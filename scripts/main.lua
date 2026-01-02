local config		= require('config')	-- read it before importing from "packages"
local assets		= require('assets')
local characters	= require('characters')
local logger		= require('logger')
local saves			= require('saves')
local tables		= require('tables')
local ue			= require('ue')



local save		= nil
local mods_info	= nil



local function read_mods_and_save_file_from_disk(reload)
	if reload or not save or not mods_info then
		save		= saves.SavedSettings.read()
		mods_info	= assets.mods_info__read()
		logger.info('save', ue.inspect_stringify(save))
	end
end



--[[
We apply mod to specific character bc sometimes only certain characters are loaded / reloaded,
	so we need to process only them.
]]
local function apply_mod_to_character(character_id, character)
	if not tables.length(save) then
		logger.info('no outfit replacements are specified in save file,  skipping applying nanosuit')
		return
	end
	if not character then
		logger.warn(('%s not found,  skipping applying nanosuit'):format(character_id))
		return
	end

	logger.info('processing replacement for character', character_id)

	for _, saved_replacement in pairs(save) do
		logger.info('processing replacement of', saved_replacement.UniqueFitID)

		local mod_outfit = nil
		for _, mod_info in pairs(mods_info) do
			for _, mod_outfit__current in pairs(mod_info.ModOutfits) do
				if mod_outfit__current.UniqueFitID == saved_replacement.UniqueFitID then
					mod_outfit = mod_outfit__current
					goto end_find__mod_outfit
				end
			end
		end
		::end_find__mod_outfit::

		local is__mod_outfit__missing				= mod_outfit == nil
		local is__mod_outfit__for_other_character	= mod_outfit.CharacterID ~= character_id
		if is__mod_outfit__missing then
			logger.error('mod fit is missing in game but present in saved file', saved_replacement.UniqueFitID)
			goto next_replacement
		end
		if is__mod_outfit__for_other_character then
			logger.info('replacement is for other character, skipping')
			logger.debug('mod_outfit.CharacterID', mod_outfit.CharacterID, 'character_id', character_id)
			goto next_replacement
		end

		local meshes_current = tables.map(mod_outfit.OutfitDatas, function(outfit_data)
			return outfit_data.Mesh
		end)

		local is_missing__outfit_data = (
			not		tables.has_value(mod_outfit.OutfitPaths,	saved_replacement.OutfitMesh)
			and not	tables.has_value(meshes_current,			saved_replacement.OutfitMesh)
			)
		if is_missing__outfit_data then
			logger.error('mesh', saved_replacement.OutfitMesh, 'is missing in mod', saved_replacement.UniqueFitID)
			goto next_replacement
		end

		local asset_data	= assets.UEAssetData.from_path(saved_replacement.OutfitMesh)
		local asset			= asset_data:load()

		logger.info('will apply mod to character', character_id)

		characters.replace_mesh(
			character_id,
			character,
			asset,
			mod_outfit.FitMeshType
			)

		::next_replacement::
	end
end



--[[
Is launched manually on key press.
Force reload mods info from disk, apply mods to characters.
]]
local function main()
	local force_reload_from_disk = true
	read_mods_and_save_file_from_disk(force_reload_from_disk)

	local characters_parsed = characters.find()

	for character_id, character_instances in pairs(characters_parsed) do
		for _, character_instance in pairs(character_instances) do
			apply_mod_to_character(character_id, character_instance)
		end
	end
end



local function _func__log_traceback(func)
	return function()
		xpcall(func, function(err)
			print(debug.traceback(err, 2))
		end)
	end
end



RegisterKeyBind(config.KEY__RELOAD_MOD, function()
	logger.info(('key %s hit,  loading custom nanosuit'):format(config.KEY__RELOAD_MOD))
	ExecuteInGameThread(_func__log_traceback(main))	-- it crashes often if execute not in game thread
end)



local function _replace_eve_mesh()
	ExecuteInGameThread(function()	-- crashes otherwise
		read_mods_and_save_file_from_disk()
		local characters_parsed = characters.find()
		for _, character_instance in pairs(characters_parsed[assets.CharacterID.eve]) do
			apply_mod_to_character(assets.CharacterID.eve, character_instance)
		end
	end)
end

local _replace_eve_mesh__debounced = _func__log_traceback(ue.debounce(_replace_eve_mesh, 500))



ue.register_blueprint_hook('/Game/Art/Character/PC/CH_P_EVE_01/Blueprints/CH_P_EVE_01_Blueprint.CH_P_EVE_01_Blueprint_C:NotifyBP_SetMesh', function()
	--[[
	Cannot parse args well - they're "RemoteUnrealParam".
		So we don't know where body, when hair will be set.
		So just debounce it.
	Didn't hook with "NotifyOnNewObject('/Script/SB.SBCharacter')"
		bc meshes are replaced after some time after new char created.
	]]
	_replace_eve_mesh__debounced()
end)



-- ue.register_blueprint_hook('/Game/Art/Character/PC/CH_P_EVE_01/Blueprints/CH_P_EVE_01_Blueprint.CH_P_EVE_01_Blueprint_C:Event_ChangeBattleState', function(...)
-- 	print('Blueprint_C:Event_ChangeBattleState', ...)
-- -- CNS refreshed state on it
-- end)
