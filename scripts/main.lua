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

	-- if character_id == 'ADAM' then
	-- 	logger.debug('is adam, returning')
	-- 	return
	-- 	-- goto next_replacement
	-- end

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

			local is_mod_outfit_missing				= mod_outfit == nil
			local is_mod_outfit_for_other_character	= mod_outfit.CharacterID ~= character_id
			if is_mod_outfit_missing then
				logger.error('mod fit is missing in game but present in saved file', replacement.UniqueFitID)
				goto next_replacement
			end
			if is_mod_outfit_for_other_character then
				logger.info('replacement is for other character, skipping')
				logger.debug('mod_outfit.CharacterID', mod_outfit.CharacterID, 'character_id', character_id)
				goto next_replacement
			end

			local mesh_paths = tables.map(mod_outfit.OutfitDatas, function(outfit_data)
				return outfit_data.Mesh
			end)
			logger.inspect('mesh_paths', mesh_paths)
			logger.inspect('mod_outfit.OutfitPaths',  mod_outfit.OutfitPaths)

			local outfit_mesh
			if replacement.OutfitMesh then
				local is_outfit_data_missing = (
					not		tables.has_value(mod_outfit.OutfitPaths,	replacement.OutfitMesh)
					and not	tables.has_value(mesh_paths,				replacement.OutfitMesh)
					)
				if is_outfit_data_missing then
					logger.error('mesh', replacement.OutfitMesh, 'is missing in mod', replacement.UniqueFitID)
					goto next_replacement
				end
				outfit_mesh	= replacement.OutfitMesh
			else	-- take from first "OutfitPaths" oor first "OutfitDatas.Mesh"
				outfit_mesh	= mod_outfit.OutfitPaths[1] or mesh_paths[1]
			end

			logger.debug('selected outfit_mesh', outfit_mesh)
			assert(outfit_mesh, 'outfit mesh is missing in mod')

			local asset_data	= assets.UEAssetData.from_path(outfit_mesh)
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
		xpcall(
			function()
				func(table.unpack(func_args))
			end,
			function(err)
				print(debug.traceback(err, 2))
			end
		)
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
local function _replace_mesh__eve()
	_replace_mesh(assets.CharacterID.eve)
end
local function _replace_mesh__adam()
	_replace_mesh(assets.CharacterID.adam)
end
local function _replace_mesh__lily()
	_replace_mesh(assets.CharacterID.lily)
end
local function _replace_mesh__drone()
	_replace_mesh(assets.CharacterID.drone)
end

--[[
We need separate debounce per character,
	otherwise they would interrupt each other.
Also functions must be defined before launched in hook,
	otherwise they won't be debounced.
]]
local _replace_mesh__eve__debounced		= _func__log_traceback(ue.debounce(_replace_mesh__eve, 1000))
local _replace_mesh__adam__debounced	= _func__log_traceback(ue.debounce(_replace_mesh__adam, 2000))	-- lil bit more to wait he's settled,  bc he doesn't have "NotifyBP_SetMesh" or "ApplyMeshInfo"
local _replace_mesh__lily__debounced	= _func__log_traceback(ue.debounce(_replace_mesh__lily, 2000))	-- lil bit more to wait he's settled,  bc she doesn't have "NotifyBP_SetMesh" or "ApplyMeshInfo"
local _replace_mesh__drone__debounced	= _func__log_traceback(ue.debounce(_replace_mesh__drone, 1000))



ExecuteInGameThread(function()
	--[[
	These objects don't exist on game start, Eve's obj is loaded soon before, Adam's - only when you load game.
	So manually load them
	]]
	local uasset_data__eve		= assets.UEAssetData.from_path('/Game/Art/Character/PC/CH_P_EVE_01/Blueprints/CH_P_EVE_01_Blueprint.CH_P_EVE_01_Blueprint_C')
	local uasset_data__adam		= assets.UEAssetData.from_path('/Game/Art/Character/NPC/CH_NPC_Adam_01/Blueprints/CH_NPC_Adam_01_Blueprint.CH_NPC_Adam_01_Blueprint_C')
	local uasset_data__lily		= assets.UEAssetData.from_path('/Game/Art/Character/NPC/CH_NPC_01/Blueprints/CH_NPC_01_Blueprint.CH_NPC_01_Blueprint_C')
	local uasset_data__drone	= assets.UEAssetData.from_path('/Game/Art/Character/NPC/CH_NPC_Drone/BluePrints/CH_Drone_BP.CH_Drone_BP_C')
	uasset_data__eve:load()
	uasset_data__adam:load()
	uasset_data__lily:load()
	uasset_data__drone:load()

	--[[
	Hooks for Eve.
	]]
	ue.register_blueprint_hook('/Game/Art/Character/PC/CH_P_EVE_01/Blueprints/CH_P_EVE_01_Blueprint.CH_P_EVE_01_Blueprint_C:NotifyBP_SetMesh', function()
		--[[
		Cannot parse args well - they're "RemoteUnrealParam".
			So we don't know where body, when hair will be set.
			So just debounce it.
		Didn't hook with "NotifyOnNewObject('/Script/SB.SBCharacter')"
			bc meshes are replaced after some time after new char created.
		]]
		-- logger.debug('EVEs NotifyBP_SetMesh  !!!!!!!!!')
		_replace_mesh__eve__debounced()
	end)

	--[[
	Hooks for Adam.

	Adam doesn't have have n recieve "NotifyBP_SetMesh",  but seems it works and with "ReceiveBeginPlay"
		while Eve receives "NotifyBP_SetMesh" multiple times after "ReceiveBeginPlay",  replacing on "ReceiveBeginPlay" on her will be rewritten.
	]]
	ue.register_blueprint_hook('/Game/Art/Character/NPC/CH_NPC_Adam_01/Blueprints/CH_NPC_Adam_01_Blueprint.CH_NPC_Adam_01_Blueprint_C:ReceiveBeginPlay', function()
		-- logger.debug('ADAMs ReceiveBeginPlay  <<<<<<<<<')
		_replace_mesh__adam__debounced()
	end)

	--[[
	Hooks for Lily.
	]]
	ue.register_blueprint_hook('/Game/Art/Character/NPC/CH_NPC_01/Blueprints/CH_NPC_01_Blueprint.CH_NPC_01_Blueprint_C:ReceiveBeginPlay', function()
		-- logger.debug('LILYs ReceiveBeginPlay  ..........')
		_replace_mesh__lily__debounced()
	end)

	--[[
	Hooks for Drone.

	"ApplyMeshInfo" is launched after "ReceiveBeginPlay", should be our target.
	]]
	ue.register_blueprint_hook('/Game/Art/Character/NPC/CH_NPC_Drone/BluePrints/CH_Drone_BP.CH_Drone_BP_C:ApplyMeshInfo', function()
		-- logger.debug('DRONEs ApplyMeshInfo  ???????')
		_replace_mesh__drone__debounced()
	end)
end)



-- ue.register_blueprint_hook('/Game/Art/Character/PC/CH_P_EVE_01/Blueprints/CH_P_EVE_01_Blueprint.CH_P_EVE_01_Blueprint_C:Event_ChangeBattleState', function(...)
-- 	print('Blueprint_C:Event_ChangeBattleState', ...)
-- -- CNS refreshed state on it
-- end)
