--[[
Helpers related to assets packages in "~mods" foler.
]]

local path = require('path')

local AssetRegistryHelpers	= StaticFindObject('/Script/AssetRegistry.Default__AssetRegistryHelpers')
local UEHelpers				= require('UEHelpers')

local fs		= require('fs')
local json		= require('dkjson')
local logger	= require('logger')
local numbers	= require('numbers')
local strings	= require('strings')
local tables	= require('tables')



local M	= {}



function M.mods_info__read()
	local mod_jsons = M.mod_jsons__read()
	local mods_info	= {}	-- {[mod_json_path]: mod_info, ...}

	for _, mod_json_path in pairs(mod_jsons) do
		logger.info('processing', mod_json_path)	-- so we'll see in which JSON error happened

		local mod_info__str	= fs.file__read(mod_json_path)
		local mod_info__raw	= json.decode(mod_info__str)
		local mod_info		= M.ModInfo.new({
			JsonFilePath	= mod_json_path,
			ModOutfits		= mod_info__raw,
		})

		mods_info[mod_json_path] = mod_info
	end

	return mods_info
end



function M.mod_jsons__read()
	local mods_dir = M.mods_directory__get()
	if not mods_dir then
		logger.error('Unable to find Pak Mods directory!')
	end

	local mod_jsons = M._mods_directory__find_mods_jsons__recursive(mods_dir)
	return mod_jsons
end



function M.mods_directory__get()
	local dirs = IterateGameDirectories()
	if not dirs then
		logger.error('no game directories')
		return
	end
	local paks		= dirs.Game.Content.Paks
	local mods_dir	= tables.get_case_insensitive(paks, '~mods')
	if not mods_dir then
		logger.error('Unable to find Content/Paks/~mods directory!')
	end
	return mods_dir
end



-- Recursively go over all subdirectories, add paths to JSON files to "M.mods"
function M._mods_directory__find_mods_jsons__recursive(dir)
	local mod_jsons = {}

	for _, file in pairs(dir.__files) do
		local is_json = file.__absolute_path:match('.dekcns%.json$')  -- ends with ".dekcns.json"
		if is_json then
			 table.insert(mod_jsons, file.__absolute_path)
		end
	end

	for _, subdir in pairs(dir) do
		local mod_jsons__nested = M._mods_directory__find_mods_jsons__recursive(subdir)
		for _, subdir_json__absolute_path in pairs(mod_jsons__nested) do
			table.insert(mod_jsons, subdir_json__absolute_path)
		end
	end

	return mod_jsons
end



--[[
Class containing info about mod JSON.
]]
M.ModInfo			= {}
M.ModInfo.__index	= M.ModInfo



function M.ModInfo.new(data_raw)
	assert(strings.is_string(data_raw.JsonFilePath), 'JsonFilePath is required string')
	assert(tables.is_list_of_or_nil(data_raw.ModOutfits, tables.is_table), 'ModOutfits should be list of ModOutfit or nil')

	local data = {
		JsonFilePath	= data_raw.JsonFilePath,
		ModOutfits		= tables.map(data_raw.ModOutfits,  function(mod_outfit__raw)
								return M.ModOutfit.new(mod_outfit__raw)
							end),
	}

	return setmetatable(data, M.ModInfo)
end



--[[
Class containing parsed data from mod JSON about one outfit.
]]
M.ModOutfit			= {}
M.ModOutfit.__index	= M.ModOutfit



--[[
Validate and return table with mod info data.
Args:
	"data_raw" - table with data to initiate ModOutfit with,  get from mod JSON.
Docs:
	CNS JSON specification:
		https://github.com/Dekita/SB-CustomNanosuitSystem-Docs/blob/main/guides/cns-json-setup.md
		https://github.com/Dekita/SB-CustomNanosuitSystem-Docs/blob/main/guides/cns-json-advanced.md
]]
function M.ModOutfit.new(data_raw)
	assert(strings.is_string(data_raw.UniqueFitID), 'UniqueFitID is required string')
	assert(strings.is_string_or_nil(data_raw.CharacterID), 'ModOutfit.CharacterID should be string or omitted')
	assert(strings.is_string_or_nil(data_raw.DisplayName), 'ModOutfit.DisplayName should be string or omitted')
	assert(strings.is_string_or_nil(data_raw.Description), 'ModOutfit.Description should be string or omitted')
	assert(strings.is_string_or_nil(data_raw.Requirement), 'ModOutfit.Requirement should be string or omitted')
	assert(strings.is_string_or_nil(data_raw.FitMeshType), 'ModOutfit.FitMeshType should be string or omitted')
	assert(strings.is_string_or_nil(data_raw.MeshSubType), 'ModOutfit.MeshSubType should be string or omitted')
	assert(strings.is_string_or_nil(data_raw.OutfitImage), 'ModOutfit.OutfitImage should be string or omitted')
	assert(tables.is_list_of_or_nil(data_raw.OutfitTypes, strings.is_string), 'ModOutfit.OutfitTypes should be list of strings or omitted')
	assert(tables.is_list_of_or_nil(data_raw.OutfitPaths, strings.is_string), 'ModOutfit.OutfitPaths should be list of strings or omitted')
	assert(tables.is_list_of_or_nil(data_raw.OutfitNames, strings.is_string), 'ModOutfit.OutfitNames should be list of strings or omitted')
	assert(strings.is_string_or_nil(data_raw.AnimationBP), 'ModOutfit.AnimationBP should be string or omitted')
	assert(strings.is_string_or_nil(data_raw.PonyPhysics), 'ModOutfit.PonyPhysics should be string or omitted')
	assert(tables.is_list_of_or_nil(data_raw.OutfitDatas, tables.is_table), 'ModOutfit.OutfitDatas should be array of "OutfitData" or omitted')

	if not data_raw.FitMeshType then
		data_raw.FitMeshType = M.FitMeshType.Body
	end
	if data_raw.MeshSubType then
		data_raw.FitMeshType = data_raw.MeshSubType	-- usually we merge "Ponytail" to "FitMeshType"
	end

	assert(tables.has_value(M.FitMeshType, data_raw.FitMeshType),	('ModOutfit.FitMeshType must be one of %s, its "%s"'):format( json.encode(tables.values(M.FitMeshType)), data_raw.FitMeshType ))

	local data = {
		UniqueFitID		= data_raw.UniqueFitID,
		CharacterID		= (data_raw.CharacterID or M.CharacterID.eve):upper(),
		DisplayName		= data_raw.DisplayName or '',
		Description		= data_raw.Description or '',
		Requirement		= data_raw.Requirement or 'None',	-- TODO: validate according enum ?  Known values are: ["None"]
		FitMeshType		= data_raw.FitMeshType,
		OutfitImage		= data_raw.OutfitImage or '',		-- example: "/Game/Art/UI/Texture/Item/NanoSuit/NanoSuit_Icon_BS_102.NanoSuit_Icon_BS_102"
		OutfitTypes		= data_raw.OutfitTypes or {},		-- TODO: validate according enum ?  Known values are: ["NSFW"]
		OutfitPaths		= data_raw.OutfitPaths or {},
			-- TODO: validate according to existing object in UE / .ucas ?
			-- example: ["/Game/OutfitMods/AiK_Naik_Makeup/Face/AiK_Face_MA1.AiK_Face_MA1"]
		OutfitNames		= data_raw.OutfitNames or {},		-- example: ["Vanilla", "Cuffless"]
		AnimationBP		= data_raw.AnimationBP or '',		-- TODO: validate according to existing object in UE / .ucas ?
		PonyPhysics		= data_raw.PonyPhysics or '',		-- TODO: ensure it should be present here, bc it's also in "OutfitData"
		OutfitDatas		= tables.map(data_raw.OutfitDatas or {}, function(data_raw_2, _index)
								return M.OutfitData.new(data_raw_2)
							end),
		UserConfigs		= tables.map(data_raw.UserConfigs or {}, function(data_raw_2, _index)
								return M.UserConfig.new(data_raw_2)
							end),
	}

	return setmetatable(data, M.ModOutfit)
end



--[[
Class containing outfit data.
]]
M.OutfitData			= {}
M.OutfitData.__index	= M.OutfitData



function M.OutfitData.new(data_raw)
	assert(strings.is_non_empty(data_raw.Mesh),							'OutfitData.Mesh is required string')
	assert(tables.is_list_of(data_raw.Materials, strings.is_string),	'OutfitData.Materials is required array of strings')
	assert(tables.is_list_of(data_raw.Parameters, tables.is_table),		'OutfitData.Parameters is required array of "OutfitDataParameter"')
	assert(strings.is_string_or_nil(data_raw.PonyPhysics),				'OutfitData.PonyPhysics should be string or omitted')

	local data = {
		Mesh		= data_raw.Mesh,		-- example: "/Game/CNSRepacked/6138f22cbccb9844/Art/Character/PC/CH_P_EVE_InnerSuit/CH_P_EVE_InnerSuit.CH_P_EVE_InnerSuit"
		Materials	= data_raw.Materials,
			--[[ example: [
				"/Game/Art/Character/PC/CH_P_EVE_InnerSuit/Materials/MI_EVE_Costume_Temp_Inner_Suit.MI_EVE_Costume_Temp_Inner_Suit",
				"/Game/OutfitMods/k7_SkinSuit/Materials/k7_SkinSuit_Inner_Skin02.k7_SkinSuit_Inner_Skin02"
				]
			]]
		Parameters	= tables.map(data_raw.Parameters, function(data_raw_2, _index)
							return M.OutfitDataParameter.new(data_raw_2)
						end),
		PonyPhysics	= data_raw.PonyPhysics,
	}

	return setmetatable(data, M.OutfitData)
end



--[[
Class containing outfit data parameters.
]]
M.OutfitDataParameter			= {}
M.OutfitDataParameter.__index	= M.OutfitDataParameter



function M.OutfitDataParameter.new(data_raw)
	assert(numbers.is_number(data_raw.MaterialIndex),	'OutfitDataParameter.MaterialIndex is required number')
	assert(numbers.is_number(data_raw.LayerIndex),		'OutfitDataParameter.LayerIndex is required number')
	assert(tables.has_value(M.OUTFIT_DATA_PARAM_TYPES, data_raw.ParamType),	'OutfitDataParameter.ParamType is required one of: '..json.encode(M.OUTFIT_DATA_PARAM_TYPES))
	assert(strings.is_string(data_raw.ParamName),		'OutfitDataParameter.ParamName is required string')		-- TODO: validate according to enum ?	Known values: ["BaseColor", "BakeNormal"]
	assert(strings.is_string(data_raw.Association),		'OutfitDataParameter.Association is required string')	-- TODO: validate according to enum ?	Known values: ["Global", "Layer"]
	assert(strings.is_string(data_raw.Value),			'OutfitDataParameter.Value is required string')			-- TODO: validate according to existing object in UE / .ucas ?

	local data = {
		MaterialIndex	= data_raw.MaterialIndex,	-- example: 0
		LayerIndex		= data_raw.LayerIndex,		-- example: -1
		ParamType		= data_raw.ParamType,		-- example: "Texture"
		ParamName		= data_raw.ParamName,		-- example: "BaseColor"
		Association		= data_raw.Association,		-- example: "Layer"
		Value			= data_raw.Value,			-- example: "/Game/OutfitMods/k7_SkinSuit/Textures/k7_SkinSuit_BaseBody_V02_F2_N.k7_SkinSuit_BaseBody_V02_F2_N"
	}

	return setmetatable(data, M.OutfitDataParameter)
end



M.OUTFIT_DATA_PARAM_TYPES = {'Texture', 'Scalar', 'Vector'}



--[[
Class containing user config for suit.
]]
M.UserConfig			= {}
M.UserConfig.__index	= M.UserConfig



function M.UserConfig.new(data_raw)
	assert(tables.is_list_of_or_nil(data_raw.ShapeKeys,			tables.is_table), 'UserConfig.ShapeKeys should be list of "ShapeKey" or omitted')
	assert(tables.is_list_of_or_nil(data_raw.MaterialToggles,	tables.is_table), 'UserConfig.MaterialToggles should be list of "MaterialToggle" or omitted')
	assert(tables.is_list_of_or_nil(data_raw.ScalarControls,	tables.is_table), 'UserConfig.ScalarControls should be list of "ScalarControl" or omitted')
	assert(tables.is_list_of_or_nil(data_raw.VectorControls,	tables.is_table), 'UserConfig.VectorControls should be list of "VectorControl" or omitted')
	assert(tables.is_list_of_or_nil(data_raw.TextureOptions,	tables.is_table), 'UserConfig.TextureOptions should be list of "TextureOption" or omitted')

	local data = {
		ShapeKeys		= tables.map(data_raw.ShapeKeys or {},			function(data_raw_2, _index)
							return M.ShapeKey.new(data_raw_2)
						end),
		MaterialToggles	= tables.map(data_raw.MaterialToggles or {},	function(data_raw_2, _index)
							return M.MaterialToggle.new(data_raw_2)
						end),
		ScalarControls	= tables.map(data_raw.ScalarControls or {},		function(data_raw_2, _index)
							return M.ScalarControl.new(data_raw_2)
						end),
		VectorControls	= tables.map(data_raw.VectorControls or {},		function(data_raw_2, _index)
							return M.VectorControl.new(data_raw_2)
						end),
		TextureOptions	= tables.map(data_raw.TextureOptions or {},		function(data_raw_2, _index)
							return M.TextureOption.new(data_raw_2)
						end),
	}

	return setmetatable(data, M.UserConfig)
end



--[[
Class containing shape key for some mesh.
Originally was displayed in GUI in CNS, but we'll set it manually, so only few fields are required for SNS.
]]
M.ShapeKey			= {}
M.ShapeKey.__index	= M.ShapeKey



function M.ShapeKey.new(data_raw)
	assert(strings.is_string_or_nil(data_raw.DisplayName),	'ShapeKey.DisplayName should be string or omitted')
	assert(strings.is_string_or_nil(data_raw.Description),	'ShapeKey.Description should be string or omitted')
	assert(strings.is_string_or_nil(data_raw.ShapeKeyName),	'ShapeKey.ShapeKeyName should be string or omitted')
	assert(strings.is_string(data_raw.ShapeKeyName),		'ShapeKey.ShapeKeyName is required string')
	assert(numbers.is_number(data_raw.Value),				'ShapeKey.Value is required number')
	assert(numbers.is_number_or_nil(data_raw.Min),			'ShapeKey.Min should be number or omitted')
	assert(numbers.is_number_or_nil(data_raw.Max),			'ShapeKey.Max should be number or omitted')
	assert(numbers.is_number_or_nil(data_raw.Step),			'ShapeKey.Step should be number or omitted')

	local data = {
		DisplayName		= data_raw.DisplayName,		-- example: "Boobs"
		Description		= data_raw.Description,		-- example: "Change the size of Eve's breasts 😳."
		ShapeKeyName	= data_raw.ShapeKeyName,	-- example: "Breasts"
		Value			= data_raw.Value,			-- example: 0.5
		Min				= data_raw.Min,				-- example: 0.0
			-- we don't display them, so allow omiting
			-- TODO later:  validate "Value" according to them
		Max				= data_raw.Max,				-- example: 1.0
			-- we don't display them, so allow omiting
			-- TODO later:  validate "Value" according to them
		Step			= data_raw.Step,			-- example: 0.1
			-- we don't display them, so allow omiting
			-- TODO later:  validate "Value" according to them
	}

	return setmetatable(data, M.ShapeKey)
end



--[[
Class containing toggle config for some material.
Originally was displayed in GUI in CNS, but we'll set it manually, so only few fields are required for SNS.
]]
M.MaterialToggle			= {}
M.MaterialToggle.__index	= M.MaterialToggle



function M.MaterialToggle.new(data_raw)
	assert(strings.is_string_or_nil(data_raw.DisplayName),	'MaterialToggle.DisplayName should be string or omitted')
	assert(strings.is_string_or_nil(data_raw.Description),	'MaterialToggle.Description should be string or omitted')
	assert(strings.is_string_or_nil(data_raw.ControlledBy),	'MaterialToggle.ControlledBy should be string or omitted')
	assert(numbers.is_number(data_raw.MaterialIndex),		'MaterialToggle.MaterialIndex is required number')
	assert(numbers.is_boolean(data_raw.Value),				'MaterialToggle.Value is required boolean')

	local data = {
		DisplayName		= data_raw.DisplayName,		-- example: "Piercing Nose 1"
		Description		= data_raw.Description,		-- example: ""
		ControlledBy	= data_raw.ControlledBy,	-- example: ""
		MaterialIndex	= data_raw.MaterialIndex,	-- example: 16
		Value			= data_raw.Value,			-- example: false
	}

	return setmetatable(data, M.MaterialToggle)
end



--[[
Class containing scalar control config for some material.
Originally was displayed in GUI in CNS, but we'll set it manually, so only few fields are required for SNS.
]]
M.ScalarControl			= {}
M.ScalarControl.__index	= M.ScalarControl



function M.ScalarControl.new(data_raw)
	assert(strings.is_string_or_nil(data_raw.DisplayName),	'ScalarControl.DisplayName should be string or omitted')
	assert(strings.is_string_or_nil(data_raw.Description),	'ScalarControl.Description should be string or omitted')
	assert(strings.is_string_or_nil(data_raw.ParamName),	'ScalarControl.ParamName should be string or omitted')
	assert(strings.is_string_or_nil(data_raw.Association),	'ScalarControl.Association should be string or omitted')
	assert(numbers.is_number(data_raw.LayerIndex),			'ScalarControl.LayerIndex is required number')
	assert(numbers.is_number(data_raw.MaterialIndex),		'ScalarControl.MaterialIndex is required number')
	assert(numbers.is_boolean(data_raw.Value),				'ScalarControl.Value is required boolean')

	local data = {
		DisplayName		= data_raw.DisplayName,		-- example: "Iris Hue Shift Eyes L"
		Description		= data_raw.Description,		-- example: ""
		ParamName		= data_raw.ParamName,		-- example: "IrisHueShift"
		Association		= data_raw.Association,		-- TODO: validate with enum ?  Known values: ["Global"]
		LayerIndex		= data_raw.LayerIndex,		-- example: -1
		MaterialIndex	= data_raw.MaterialIndex,	-- example: 9
		Value			= data_raw.Value,			-- example: 0.849
	}

	return setmetatable(data, M.ScalarControl)
end



--[[
Class containing vector control config for some material.
Originally was displayed in GUI in CNS, but we'll set it manually, so only few fields are required for SNS.
]]
M.VectorControl			= {}
M.VectorControl.__index	= M.VectorControl



function M.VectorControl.new(data_raw)
	assert(strings.is_string_or_nil(data_raw.DisplayName),		'VectorControl.DisplayName should be string or omitted')
	assert(strings.is_string_or_nil(data_raw.Description),		'VectorControl.Description should be string or omitted')
	assert(strings.is_string_or_nil(data_raw.ParamName),		'VectorControl.ParamName should be string or omitted')
	assert(strings.is_string_or_nil(data_raw.Association),		'VectorControl.Association should be string or omitted')
	assert(numbers.is_number(data_raw.LayerIndex),				'VectorControl.LayerIndex is required number')
	assert(numbers.is_number(data_raw.MaterialIndex),			'VectorControl.MaterialIndex is required number')
	assert(tables.is_list_of_numbers(data_raw.Value),			'VectorControl.Value is required array of numbers')
	assert(tables.is_list_of_booleans_or_nil(data_raw.Sliders),	'VectorControl.Sliders should be array of boolean or omitted')
	assert(tables.is_list_of_numbers_or_nil(data_raw.Min),		'VectorControl.Min should be array of number or omitted')
	assert(tables.is_list_of_numbers_or_nil(data_raw.Max),		'VectorControl.Max should be array of number or omitted')
	assert(tables.is_list_of_numbers_or_nil(data_raw.Step),		'VectorControl.Step should be array of number or omitted')

	local data = {
		DisplayName		= data_raw.DisplayName,		-- example: "Sclera Tint Eyes R"
		Description		= data_raw.Description,		-- example: "Tint Color for Sclera"
		ParamName		= data_raw.ParamName,		-- example: "ScleraTint"
		Association		= data_raw.Association,		-- TODO: validate with enum ?  Known values: ["Global"]
		LayerIndex		= data_raw.LayerIndex,		-- example: -1
		MaterialIndex	= data_raw.MaterialIndex,	-- example: 9
		Value			= data_raw.Value,			-- example: [1.0, 1.0, 1.0, 1.0]
		Sliders			= data_raw.Sliders,
			-- example: [true, true, true, false]
			-- we don't display them, so allow omiting
		Min				= data_raw.Min,
			-- example: [0.0, 0.0, 0.0, 0.0]
			-- we don't display them, so allow omiting
			-- TODO later:  validate "Value" according to them
		Max				= data_raw.Max,
			-- example: [30.0, 30.0, 30.0, 1.0]
			-- we don't display them, so allow omiting
			-- TODO later:  validate "Value" according to them
		Step			= data_raw.Step,
			-- example: [0.1, 0.1, 0.1, 0.1]
			-- we don't display them, so allow omiting
			-- TODO later:  validate "Value" according to them
	}

	return setmetatable(data, M.VectorControl)
end



--[[
Class containing texture select option for some material.
Originally was displayed in GUI in CNS, but we'll set it manually, so only few fields are required for SNS.
]]
M.TextureOption			= {}
M.TextureOption.__index	= M.TextureOption



function M.TextureOption.new(data_raw)
	assert(strings.is_string_or_nil(data_raw.DisplayName),			'TextureOption.DisplayName should be string or omitted')
	assert(strings.is_string_or_nil(data_raw.Description),			'TextureOption.Description should be string or omitted')
	assert(strings.is_string_or_nil(data_raw.ParamName),			'TextureOption.ParamName should be string or omitted')
	assert(strings.is_string_or_nil(data_raw.Association),			'TextureOption.Association should be string or omitted')
	assert(numbers.is_number(data_raw.LayerIndex),					'TextureOption.LayerIndex is required number')
	assert(numbers.is_number(data_raw.MaterialIndex),				'TextureOption.MaterialIndex is required number')
	assert(numbers.is_number(data_raw.Value),						'TextureOption.Value is required number')
	assert(tables.is_list_of_or_nil(data_raw.OptionNames, strings.is_string),	'TextureOption.OptionNames should be array of string or omitted')
	assert(tables.is_list_of(data_raw.Textures, strings.is_string),	'TextureOption.Textures is required array of string')

	local data = {
		DisplayName		= data_raw.DisplayName,		-- example: "Tattoo"
		Description		= data_raw.Description,		-- example: ""
		ParamName		= data_raw.ParamName,		-- example: "BaseColor"
		Association		= data_raw.Association,		-- TODO: validate with enum ?  Known values: ["Global"]
		LayerIndex		= data_raw.LayerIndex,		-- example: -1
		MaterialIndex	= data_raw.MaterialIndex,	-- example: 9
		Value			= data_raw.Value,
			-- example: 0
			-- index of texture to apply,  starts from 0
		OptionNames		= data_raw.OptionNames,
			-- example: ["Cross",  "Fck"]
			-- we don't display them
		Textures		= data_raw.Textures,
			-- example: ["/Game/OutfitMods/AiK_Naik_Makeup/Textures/Cross.Cross",  "/Game/OutfitMods/AiK_Naik_Makeup/Textures/Fck.Fck"]
			-- which texture we should apply
			-- TODO later: validate according to existing object in UE / .ucas ?
	}

	return setmetatable(data, M.TextureOption)
end



M.CharacterID = {
	eve		= 'EVE',
	adam	= 'ADAM',
	lily	= 'LILY',
	drone	= 'DRONE',
}



--[[
All possible values for this field.
Docs:
	https://github.com/Dekita/SB-CustomNanosuitSystem-Docs/blob/main/guides/cns-json-setup.md
]]
M.FitMeshType = {
	Body		= 'Body',
    Face		= 'Face',
    Hair		= 'Hair',
    PonyTail	= 'PonyTail',	-- is listed in "MeshSubType", we just simplify it and merge here
    Ears		= 'Ears',		-- usually earrings
    Eyes		= 'Eyes',		-- usually glasses
    Weapon		= 'Weapon',

}



--[[
UE asset info.
Props:
		wrong case for names - copied it from Python docs
	asset_class: The name of the asset’s class
	asset_name: The name of the asset without the package
	object_path: The object path for the asset in the form PackageName.AssetName. Only top level objects in a package can have AssetData
	package_name: The name of the package in which the asset is found, this is the full long package name such as /Game/Path/Package
	package_path: The path to the package in which the asset is found, this is /Game/Path with the Package stripped off
Reason:
	Added bc "LoadAsset" cannot load non-standard assets,
		which weren't already loaded to the game.
	To manually construct data which will be passed to UE functions.
	"AssetRegistry"		can't obtain "AssetData" - always crashes.
	"AssetRegistryImpl"	can't obtain "AssetData" - doesn't see it at all.
	Only "AssetRegistryHelpers" seems to be able to take manually constructed "AssetData" and fetch asset from mods dir with it.
Docs:
	https://dev.epicgames.com/documentation/en-us/unreal-engine/python-api/class/AssetData?application_version=4.27#unreal.AssetData
	https://dev.epicgames.com/documentation/en-us/unreal-engine/python-api/class/AssetRegistryHelpers?application_version=4.27
	https://dev.epicgames.com/documentation/en-us/unreal-engine/python-api/class/AssetRegistry?application_version=4.27
]]
M.UEAssetData			= {}
M.UEAssetData.__index	= M.UEAssetData



--[[
Args:
	object_path
		example:  '/Game/OutfitMods/k7_SkyAceNSFW/0_SkyAceNSFW.0_SkyAceNSFW'
Reason:
	".dekcns.json" files contain only full object paths
]]
function M.UEAssetData.from_path(object_path)
	local directory		= path.dirname(object_path)		-- example:  '/Game/OutfitMods/k7_SkyAceNSFW'
	local extension		= path.extension(object_path)	-- example:  '.0_SkyAceNSFW'
	local object_name	= extension:sub(2)				-- example:  '0_SkyAceNSFW'	-- remove leading dot
		-- don't use separately it's in "object_path"

	return M.UEAssetData.new({
		AssetName   = object_name,
		AssetClass	= 'SkeletalMesh',	-- currently we support only these
		PackagePath = directory,
		PackageName = directory .. '/' .. object_name,
		ObjectPath  = object_path,
	})
end



function M.UEAssetData.new(data_raw)
	assert(strings.is_string(data_raw.AssetName),	'UEAssetData.AssetName is requried string')
	assert(strings.is_string(data_raw.AssetClass),	'UEAssetData.AssetClass is requried string')
	assert(strings.is_string(data_raw.PackagePath),	'UEAssetData.PackagePath is requried string')
	assert(strings.is_string(data_raw.PackageName),	'UEAssetData.PackageName is requried string')
	assert(strings.is_string(data_raw.ObjectPath),	'UEAssetData.ObjectPath is requried string')

	local data = {
		AssetName		= data_raw.AssetName,	-- example:  '0_SkyAceNSFW'
		AssetClass		= data_raw.AssetClass,	-- example:  'SkeletalMesh'
		PackagePath		= data_raw.PackagePath,	-- example:  '/Game/OutfitMods/k7_SkyAceNSFW'
		PackageName		= data_raw.PackageName,	-- example:  '/Game/OutfitMods/k7_SkyAceNSFW/0_SkyAceNSFW'
		ObjectPath		= data_raw.ObjectPath,	-- example:  '/Game/OutfitMods/k7_SkyAceNSFW/0_SkyAceNSFW.0_SkyAceNSFW'
		ue_object		= {	-- Object, suitable passing to UE functions.  Used Fname for that.
			AssetName		= UEHelpers.FindOrAddFName(data_raw.AssetName),		-- example:  '0_SkyAceNSFW'
			AssetClass		= UEHelpers.FindOrAddFName(data_raw.AssetClass),	-- example:  'SkeletalMesh'
			PackagePath		= UEHelpers.FindOrAddFName(data_raw.PackagePath),	-- example:  '/Game/OutfitMods/k7_SkyAceNSFW'
			PackageName		= UEHelpers.FindOrAddFName(data_raw.PackageName),	-- example:  '/Game/OutfitMods/k7_SkyAceNSFW/0_SkyAceNSFW'
			ObjectPath		= UEHelpers.FindOrAddFName(data_raw.ObjectPath),	-- example:  '/Game/OutfitMods/k7_SkyAceNSFW/0_SkyAceNSFW.0_SkyAceNSFW'
		},
	}

	return setmetatable(data, M.UEAssetData)
end



--[[
Load asset from current data and return "UObject" of specified class.
Notes:
	This works only from game thread,  use "ExecuteInGameThread",  crashes otherwise.
	Crashes fewer times if "ExecuteInGameThread" is launched from "RegisterKeyBind".
Could also use this:
		local asset_2 = LoadAsset('/Game/Art/Character/PC/CH_P_EVE_02/CH_P_EVE_02_Body.CH_P_EVE_02_Body')
	but it ha no validation,  crashed more often then using "AssetRegistryHelpers".
Did not use this as it always crashes:
	local AssetRegistry = StaticFindObject('/Script/AssetRegistry.Default__AssetRegistry')
	AssetRegistry:GetAssetByObjectPath(self.ue_object.ObjectPath, false)
]]
function M.UEAssetData:load()
	logger.info(('loading asset %s'):format(self.AssetName))

	local is_valid = AssetRegistryHelpers:IsValid(self.ue_object)
	if not is_valid then
		logger.error('UEAssetData is invalid')
		return
	end

	local asset = AssetRegistryHelpers:GetAsset(self.ue_object)
	if not asset:IsValid() then
		logger.error(('asset "%s" is invalid'):format(self.AssetName))
		return
	end

	logger.info(('obtained asset: %s'):format(asset))
	-- logger.inspect('asset', asset)
	return asset
end



return M
