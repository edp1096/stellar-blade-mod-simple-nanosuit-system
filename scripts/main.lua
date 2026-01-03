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
local function apply_mod_to_character(character_id)
	if not character_id then
		logger.error('invalid character', character_id)
		return
	end
	if not tables.length(save) then
		logger.info('no outfit replacements are specified in save file,  skipping applying nanosuit')
		return
	end
	if not save.Enabled then
		logger.info('SNS mod is disabled through settings')
		return
	end

	logger.info('processing replacement for character', character_id)
	local characters_parsed		= characters.find()
	local character_instances	= characters_parsed[character_id]

	if not tables.length(character_instances) then
		logger.warn(('%s instances not found,  skipping applying nanosuit'):format(character_id))
		return
	end

	for _, character_instance in pairs(character_instances) do

		for _, replacement in pairs(save.Replacements) do
			logger.info('processing replacement of', replacement.UniqueFitID)

			if not replacement.Enabled then
				logger.info('replacement is disabled, skipping')
				goto next_replacement
			end

			local mod_outfit = nil
			for _, mod_info in pairs(mods_info) do
				for _, mod_outfit__current in pairs(mod_info.ModOutfits) do
					if mod_outfit__current.UniqueFitID == replacement.UniqueFitID then
						mod_outfit = mod_outfit__current
						goto end_find__mod_outfit
					end
				end
			end
			::end_find__mod_outfit::

			local is__mod_outfit__missing				= mod_outfit == nil
			local is__mod_outfit__for_other_character	= mod_outfit.CharacterID ~= character_id
			if is__mod_outfit__missing then
				logger.error('mod fit is missing in game but present in saved file', replacement.UniqueFitID)
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
				not		tables.has_value(mod_outfit.OutfitPaths,	replacement.OutfitMesh)
				and not	tables.has_value(meshes_current,			replacement.OutfitMesh)
				)
			if is_missing__outfit_data then
				logger.error('mesh', replacement.OutfitMesh, 'is missing in mod', replacement.UniqueFitID)
				goto next_replacement
			end

			local asset_data	= assets.UEAssetData.from_path(replacement.OutfitMesh)
			local asset			= asset_data:load()

			logger.info('will apply mod to character', character_id)

			characters.replace_mesh(
				character_id,
				character_instance,
				asset,
				mod_outfit.FitMeshType
				)

			::next_replacement::
		end

	end
end



--[[
Is launched manually on key press.
Force reload mods info from disk, apply mods to characters.
]]
local function main()
	local force_reload_from_disk = true
	read_mods_and_save_file_from_disk(force_reload_from_disk)

	for _, character_id in pairs(assets.CharacterID) do
		apply_mod_to_character(character_id)
	end
end



local function _func__log_traceback(func)
	return function(...)
		local func_args = table.pack(...)
		xpcall(function()
			func(table.unpack(func_args))
		end, function(err)
			print(debug.traceback(err, 2))
		end)
	end
end



RegisterKeyBind(config.KEY__RELOAD_MOD, function()
	logger.info(('key %s hit,  loading custom nanosuit'):format(config.KEY__RELOAD_MOD))
	ExecuteInGameThread(_func__log_traceback(main))	-- it crashes often if execute not in game thread
end)



local function _replace_mesh(character_id)
	ExecuteInGameThread(function()	-- crashes otherwise
		read_mods_and_save_file_from_disk()
		apply_mod_to_character(character_id)
	end)
end

local _replace_mesh__debounced = _func__log_traceback(ue.debounce(_replace_mesh, 500))



ExecuteInGameThread(function()
	--[[
	These objects don't exist on game start, Eve's obj is loaded soon before, Adam's - only when you load game.
	So manually load them
	]]
	local uasset_data__eve	= assets.UEAssetData.from_path('/Game/Art/Character/PC/CH_P_EVE_01/Blueprints/CH_P_EVE_01_Blueprint.CH_P_EVE_01_Blueprint_C')
	local uasset_data__adam	= assets.UEAssetData.from_path('/Game/Art/Character/NPC/CH_NPC_Adam_01/Blueprints/CH_NPC_Adam_01_Blueprint.CH_NPC_Adam_01_Blueprint_C')
	uasset_data__eve:load()
	uasset_data__adam:load()

	-- Hooks for Eve:

	ue.register_blueprint_hook('/Game/Art/Character/PC/CH_P_EVE_01/Blueprints/CH_P_EVE_01_Blueprint.CH_P_EVE_01_Blueprint_C:NotifyBP_SetMesh', function()
		--[[
		Cannot parse args well - they're "RemoteUnrealParam".
			So we don't know where body, when hair will be set.
			So just debounce it.
		Didn't hook with "NotifyOnNewObject('/Script/SB.SBCharacter')"
			bc meshes are replaced after some time after new char created.
		]]
		_replace_mesh__debounced(assets.CharacterID.eve)
	end)

	-- Hooks for Adam:

	--[[
	Adam doesn't have have n recieve "NotifyBP_SetMesh",  but seems it works and with "ReceiveBeginPlay"
		while Eve receives "NotifyBP_SetMesh" multiple times after "ReceiveBeginPlay",  replacing on "ReceiveBeginPlay" on her will be rewritten.
	]]
	ue.register_blueprint_hook('/Game/Art/Character/NPC/CH_NPC_Adam_01/Blueprints/CH_NPC_Adam_01_Blueprint.CH_NPC_Adam_01_Blueprint_C:ReceiveBeginPlay', function()
		_replace_mesh__debounced(assets.CharacterID.adam)
	end)
end)



-- ue.register_blueprint_hook('/Game/Art/Character/PC/CH_P_EVE_01/Blueprints/CH_P_EVE_01_Blueprint.CH_P_EVE_01_Blueprint_C:Event_ChangeBattleState', function(...)
-- 	print('Blueprint_C:Event_ChangeBattleState', ...)
-- -- CNS refreshed state on it
-- end)
