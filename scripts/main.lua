local config		= require('config')	-- read it before importing from "packages"
local assets		= require('assets')
local characters	= require('characters')
local logger		= require('logger')
local saves			= require('saves')
local tables		= require('tables')
local ue_objects	= require('ue_objects')



local save		= nil
local mods_info	= nil



local function read_mods_and_save_file_from_disk(reload)
	if reload or not save or not mods_info then
		save		= saves.SavedSettings.read()
		mods_info	= assets.mods_info__find()
		logger.info('save', ue_objects.inspect_stringify(save))
	end
end



local function apply_mod_to_character(character_name, character)
	-- local save		= saves.SavedSettings.read()	-- using global ones
	-- local mods_info	= assets.mods_info__find()

	if not save[character_name] then
		logger.warn(('no save for %s,  skipping applying nanosuit'):format(character_name))
		return
	end
	if not character then
		logger.warn(('%s not found,  skipping applying nanosuit'):format(character_name))
		return
	end

	local save_current	= save[character_name]
	if not save_current.UseFitId then
		logger.warn(('no UseFitId specified for character %s,  skipping applying nanosuit'):format(character_name))
		return
	end

	local mod_fit_info = nil
	for _, mod_fits_info in pairs(mods_info) do
		for _, mod_fit_info__current in pairs(mod_fits_info) do
			if mod_fit_info__current.UniqueFitID == save_current.UseFitId then
				mod_fit_info = mod_fit_info__current
				goto endmodfitloops
			end
		end
		::endmodfitloops::
	end
	logger.info('mod_fit_info', ue_objects.inspect_stringify(mod_fit_info))

	local mod_fit_missing = mod_fit_info == nil
	if mod_fit_missing then
		logger.error('mod fit is missing in game but present in save file', save_current.UseFitId)
		return
	end

	local meshes_current = tables.list_map(mod_fit_info.OutfitDatas, function(outfit_data)
			return outfit_data.Mesh
		end)
	print('meshes_current: ', meshes_current)

	local outfit_missing = (
		not		tables.list_has_value(mod_fit_info.OutfitPaths,	save_current.UseOutfit)
		and not	tables.list_has_value(meshes_current,			save_current.UseOutfit)
		)
	if outfit_missing then
		logger.error('mesh', save_current.UseOutfit, 'is missing in mod', save_current.UseFitId)
		return
	end

	local asset_data	= assets.UEAssetData.from_path(save_current.UseOutfit)
	local asset			= asset_data:load()

	characters.Characters.replace_mesh(character, asset, mod_fit_info.FitMeshType)
end



--[[
Is launched manually on key press.
Force reload mods info from disk, apply mods to characters.
]]
local function main()
	local force_reload_from_disk = true
	read_mods_and_save_file_from_disk(force_reload_from_disk)
	local characters_parsed = characters.Characters.find()

	for character_name, character in pairs(characters_parsed) do
		apply_mod_to_character(character_name, character)
	end
end



local function main__show_traceback()
	xpcall(main, function(err)
		print(debug.traceback(err, 2))
	end)
end



RegisterKeyBind(config.KEY__RELOAD_MOD, function()
	logger.info(('key %s hit,  loading custom nanosuit'):format(config.KEY__RELOAD_MOD))
	ExecuteInGameThread(main__show_traceback)	-- it crashes often if execute not in game thread
end)



-- NotifyOnNewObject('/Script/SB.SBCharacter', function(character_raw)
-- 	logger.info('SBCharacter loaded')
-- 	ExecuteInGameThread(function()	-- it crashes often if execute not in game thread
-- 		read_mods_and_save_file_from_disk()
-- 		local character_parsed = characters.Characters.parse(character_raw)

-- 		for character_name, character in pairs(character_parsed) do
-- 			apply_mod_to_character(character_name, character)
-- 		end
-- 	end)
-- end)



-- RegisterHook('/Script/SB.SBCharacter:NotifyBP_SetMesh', function(self, result)
-- 	print('NotifyBP_SetMesh')
-- end)
-- RegisterHook('/Script/SB.SBCharacter:NotifyBP_InitActor', function(self, result)
-- 	print('NotifyBP_InitActor')
-- end)
-- RegisterHook('/Script/SB.SBCharacter:NotifyBP_PostInit', function(self, result)
-- 	print('NotifyBP_PostInit')
-- end)
-- RegisterHook('/Script/SB.SBCharacter:NotifyBP_FinishedLevelSequence', function(self, result)
-- 	print('NotifyBP_FinishedLevelSequence')
-- end)
RegisterHook('/Game/Art/Character/PC/CH_P_EVE_01/Blueprints/CH_P_EVE_01_Blueprint.CH_P_EVE_01_Blueprint_C:NotifyBP_SetMesh', function(self, result)
	print('NotifyBP_SetMesh')
end)
-- RegisterHook('/Game/Art/Character/PC/CH_P_EVE_01/Blueprints/CH_P_EVE_01_Blueprint.CH_P_EVE_01_Blueprint_C:NotifyBP_InitActor', function(self, result)
-- 	print('NotifyBP_InitActor')
-- end)
-- RegisterHook('/Game/Art/Character/PC/CH_P_EVE_01/Blueprints/CH_P_EVE_01_Blueprint.CH_P_EVE_01_Blueprint_C:NotifyBP_PostInit', function(self, result)
-- 	print('NotifyBP_PostInit')
-- end)
-- RegisterHook('/Game/Art/Character/PC/CH_P_EVE_01/Blueprints/CH_P_EVE_01_Blueprint.CH_P_EVE_01_Blueprint_C:NotifyBP_FinishedLevelSequence', function(self, result)
-- 	print('NotifyBP_FinishedLevelSequence')
-- end)



-- RegisterHook('/Script/Engine.PlayerController:SwitchLevel', function()	-- on game start in main menu, after game load
-- 	print('SwitchLevel')
-- end)
-- RegisterHook('/Script/Engine.PlayerController:RestartLevel', function()	-- on game start in main menu, after game load
-- 	print('RestartLevel')
-- end)
-- RegisterHook('/Script/Engine.PlayerController:ClientCommitMapChange', function()	-- on game start in main menu, after game load
-- 	print('ClientCommitMapChange')
-- end)
-- RegisterHook('/Script/Engine.PlayerController:ClientRestart', function()	-- on game start in main menu, after game load
-- 	print('ClientRestart')
-- end)

RegisterHook('/Game/Art/Character/PC/CH_P_EVE_01/Blueprints/CH_P_EVE_01_Blueprint.CH_P_EVE_01_Blueprint_C:ReceiveBeginPlay', function()	-- on game start in main menu, after game load
	print('EVE ReceiveBeginPlay')
end)

RegisterHook('/Script/Engine.Actor:EnableInput', function()
	print('EnableInput')
end)
RegisterHook('/Script/Engine.PlayerController:SetCinematicMode', function()
	print('SetCinematicMode')
end)






-- RegisterHook(
--     "/Game/Art/Character/PC/CH_P_EVE_01/Blueprints/CH_P_EVE_01_Blueprint.CH_P_EVE_01_Blueprint_C:Event_ChangeBattleState",
--     function(Context, ...)
--         OnChangeBattleState(Context, ...)
-- OutfitRefreshFlag = true
--     end
-- )



-- RegisterHook(
-- 	"/Game/Art/Character/PC/CH_P_EVE_01/Blueprints/CH_P_EVE_01_Blueprint.CH_P_EVE_01_Blueprint_C:NotifyBP_FinishedLevelSequence",
-- 	function(Context)
-- 		ExtraLog("NotifyBP_FinishedLevelSequence called")
-- 		-- OutfitRefreshFlag = true
-- 	end
-- )
