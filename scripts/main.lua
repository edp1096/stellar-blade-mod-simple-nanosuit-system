local KismetLib	= StaticFindObject('/Script/Engine.Default__KismetSystemLibrary')
local UEHelpers	= require('UEHelpers')

local config		= require('config')	-- read it before importing from "packages"
local assets		= require('assets')
local characters	= require('characters')
local enums			= require('enums')
local logger		= require('logger')
local saves			= require('saves')
local strings		= require('strings')
local tables		= require('tables')
local ue_objects	= require('ue_objects')




-- local KismetLib	= StaticFindObject('/Script/Engine.Default__KismetSystemLibrary')
-- NotifyOnNewObject('/Script/SB.SBCharacter', function(Character)
-- 	logger.debug('SBCharacter Blueprint Found!')
-- 	if not Character or not Character:IsValid() then return end

-- 	if not KismetLib or not KismetLib:IsValid() then
-- 		logger.error('Failed to find KismetSystemLibrary, cannot register hooks.')
-- 		return
-- 	end

-- 	local objectName = KismetLib:GetObjectName(Character):ToString()

-- 	if stringStartsWith(objectName, "CH_P_EVE_01_Blueprint") then
-- 		characters[enums.CharacterType.EVE] = Character
-- 		ExtraLog("EVE Blueprint Found!")
-- 	elseif stringStartsWith(objectName, "CH_NPC_01_Blueprint") then
-- 		characters[enums.CharacterType.LILY] = Character
-- 		ExtraLog("LILY Blueprint Found!")
-- 	elseif stringStartsWith(objectName, "CH_NPC_Adam_01_Blueprint") then
-- 		characters[enums.CharacterType.ADAM] = Character
-- 		ExtraLog("ADAM Blueprint Found!")
-- 	elseif stringStartsWith(objectName, "CH_Drone_BP") then
-- 		characters[enums.CharacterType.DRONE] = Character
-- 		ExtraLog("DRONE Blueprint Found!")
-- 	end
-- end)



-- NotifyOnNewObject("/Game/OutfitMods/k7_SkyAceNSFW/0_SkyAceNSFW.0_SkyAceNSFW", function(Context)
--     print('SNS 0_SkyAceNSFW found  !!!!!!!!!!!! <<<<<<<<<<<<<<')
-- end)



local function main()
	local save		= saves.SavedSettings.read()
	local mods_info	= assets.mods_info__find()
	local chars		= characters.Characters.find()
	logger.info('save', ue_objects.inspect_stringify(save))
	logger.info('chars', ue_objects.inspect_stringify(chars))

	for char_name, char in pairs(chars) do
		if not save[char_name] then
			logger.warn(('no save for %s,  skipping applying nanosuit'):format(char_name))
			goto continue
		end
		if not char then
			logger.warn(('%s not found,  skipping applying nanosuit'):format(char_name))
			goto continue
		end

		local save_current	= save[char_name]
		if not save_current.UseFitId then
			logger.warn(('no UseFitId specified for character %s,  skipping applying nanosuit'):format(char_name))
			goto continue
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
			goto continue
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
			goto continue
		end

		local asset_data	= assets.UEAssetData.from_path(save_current.UseOutfit)
		local asset			= asset_data:load()

		characters.Characters.replace_mesh(char, asset, mod_fit_info.FitMeshType)

		::continue::
	end

	-- local asset_data_2	= assets.UEAssetData.from_path('/Game/OutfitMods/k7_SkyAceNSFW/0_SkyAceNSFW.0_SkyAceNSFW')
	-- local asset_2		= asset_data_2:load()

	-- if not chars.eve then
	-- 	logger.warn('eve not found, skipping applying her nanosuit')
	-- 	return
	-- else
	-- 	logger.info('found eve')
	-- 	local mesh_component = chars.eve:GetPropertyValue('Mesh')  -- "SkeletalMeshComponent"
	-- 	local mesh_1	= mesh_component:GetPropertyValue('SkeletalMesh')
	-- 	local mesh_component_2 = chars.eve:GetSBSkeletalMeshComponent(0)
	-- 	mesh_component_2:SetSkeletalMesh(asset_2, true)
	-- 	mesh_component_2:ResetOverrideMaterials()
	-- end
end



local function main__show_traceback()
	xpcall(main, function(err)
		print(debug.traceback(err, 2))
	end)
end



RegisterKeyBind(config.KEY__RELOAD_MOD, function()
	logger.info(('key %s hit,  loading custom nanosuit'):format(config.KEY__RELOAD_MOD))
	ExecuteInGameThread(main__show_traceback)
end)



RegisterHook("/Script/Engine.PlayerController:ClientRestart", function()	-- on game start in main menu, after game load
	print("PlayerController restarted <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<\n")
end)



-- RegisterHook(
--     "/Game/Art/Character/PC/CH_P_EVE_01/Blueprints/CH_P_EVE_01_Blueprint.CH_P_EVE_01_Blueprint_C:Event_ChangeBattleState",
--     function(Context, ...)
--         OnChangeBattleState(Context, ...)
-- OutfitRefreshFlag = true
--     end
-- )



-- RegisterHook(
--     "/Game/Art/Character/PC/CH_P_EVE_01/Blueprints/CH_P_EVE_01_Blueprint.CH_P_EVE_01_Blueprint_C:NotifyBP_FinishedLevelSequence",
--     function(Context)
--         ExtraLog("NotifyBP_FinishedLevelSequence called")
--         OutfitRefreshFlag = true
--     end
-- )
