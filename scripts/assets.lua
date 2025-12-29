--[[
Helpers related to assets packages in "~mods" foler.
]]

local path = require('path')

local AssetRegistryHelpers	= StaticFindObject('/Script/AssetRegistry.Default__AssetRegistryHelpers')
local UEHelpers				= require('UEHelpers')

local enums		= require('enums')
local fs		= require('fs')
local json		= require('dkjson')
local logger	= require('logger')
local strings	= require('strings')
local tables	= require('tables')



local M	= {}



function M.mods_info__find()
	local mod_jsons = M.mod_jsons__find()
	local mods_info	= {}	-- {[mod_json_path]: mod_info, ...}

	for _, mod_json_path in pairs(mod_jsons) do
		logger.info('processing', mod_json_path)	-- so we'll see to which JSON validation error belong
		local mod_info__str	= fs.file__read(mod_json_path)
		local mod_info__raw	= json.decode(mod_info__str)

		if not tables.is_list_of(tables.is_table, mod_info__raw) then
			logger.error('mod JSON should contain list of objects '..mod_json_path)
			goto continue
		end

		local mod_fits_info = tables.list_map(mod_info__raw,  function(mod_info__raw__current)
				return M.ModFitInfo.new(mod_info__raw__current, mod_json_path)
			end)

		mods_info[mod_json_path] = mod_fits_info

		::continue::
	end

	return mods_info
end



function M.mod_jsons__find()
	local mods_dir = M.mods_directory__get()
	if not mods_dir then
		logger.error('Unable to find Pak Mods directory!')
	end

	local mod_jsons = M.mods_directory__find_mods_jsons(mods_dir)
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
function M.mods_directory__find_mods_jsons(dir)
	local mod_jsons = {}

	for _, file in pairs(dir.__files) do
		local is_json = file.__absolute_path:match('.dekcns%.json$')  -- ends with ".dekcns.json"
		if is_json then
			 table.insert(mod_jsons, file.__absolute_path)
		end
	end

	for _, subdir in pairs(dir) do
		local mod_jsons__nested = M.mods_directory__find_mods_jsons(subdir)
		for _, subdir_json__absolute_path in pairs(mod_jsons__nested) do
			table.insert(mod_jsons, subdir_json__absolute_path)
		end
	end

	return mod_jsons
end



--[[
Class containing parsed data from mod JSON about one outfit.
]]
M.ModFitInfo = {}
M.ModFitInfo.__index = M.ModFitInfo



--[[
Validate and return table with mod info data.
Args:
	"data_raw" - table with data to initiate ModFitInfo with,  get from mod JSON.
Docs:
	CNS JSON specification:
		https://github.com/Dekita/SB-CustomNanosuitSystem-Docs/blob/main/guides/cns-json-setup.md
		https://github.com/Dekita/SB-CustomNanosuitSystem-Docs/blob/main/guides/cns-json-advanced.md
]]
function M.ModFitInfo.new(data_raw)
	assert(type(data_raw.UniqueFitID) == 'string', 'UniqueFitID is required string')
	assert(not data_raw.CharacterID or strings.is_string(data_raw.CharacterID), 'ModFitInfo.CharacterID should be string or omitted')
	assert(not data_raw.DisplayName or strings.is_string(data_raw.DisplayName), 'ModFitInfo.DisplayName should be string or omitted')
	assert(not data_raw.Description or strings.is_string(data_raw.Description), 'ModFitInfo.Description should be string or omitted')
	assert(not data_raw.Requirement or strings.is_string(data_raw.Requirement), 'ModFitInfo.Requirement should be string or omitted')
	assert(not data_raw.FitMeshType or strings.is_string(data_raw.FitMeshType), 'ModFitInfo.FitMeshType should be string or omitted')
	assert(not data_raw.MeshSubType or strings.is_string(data_raw.MeshSubType), 'ModFitInfo.MeshSubType should be string or omitted')
	assert(not data_raw.OutfitImage or strings.is_string(data_raw.OutfitImage), 'ModFitInfo.OutfitImage should be string or omitted')
	assert(not data_raw.OutfitTypes or tables.is_list_of(strings.is_string, data_raw.OutfitTypes), 'ModFitInfo.OutfitTypes should be list of strings or omitted')
	assert(not data_raw.OutfitPaths or tables.is_list_of(strings.is_string, data_raw.OutfitPaths), 'ModFitInfo.OutfitPaths should be list of strings or omitted')
	assert(not data_raw.OutfitNames or tables.is_list_of(strings.is_string, data_raw.OutfitNames), 'ModFitInfo.OutfitNames should be list of strings or omitted')
	assert(not data_raw.AnimationBP or strings.is_string(data_raw.AnimationBP), 'ModFitInfo.AnimationBP should be string or omitted')
	assert(not data_raw.PonyPhysics or strings.is_string(data_raw.PonyPhysics), 'ModFitInfo.PonyPhysics should be string or omitted')
	assert(not data_raw.OutfitDatas or tables.is_list_of(tables.is_table, data_raw.OutfitDatas), 'ModFitInfo.OutfitDatas should be array of "OutfitData" or omitted')

	local data = {
		UniqueFitID		= data_raw.UniqueFitID,
		CharacterID		= data_raw.CharacterID or enums.Characters.eve,
		DisplayName		= data_raw.DisplayName or '',
		Description		= data_raw.Description or '',
		Requirement		= data_raw.Requirement or 'None',	-- TODO: validate according enum ?  Known values are: ["None"]
		FitMeshType		= data_raw.FitMeshType or '',		-- TODO: validate according enum ?  Known values are: ["Body", "Face"]
		MeshSubType		= data_raw.MeshSubType or '',		-- TODO: validate according enum ?
		OutfitImage		= data_raw.OutfitImage or '',		-- example: "/Game/Art/UI/Texture/Item/NanoSuit/NanoSuit_Icon_BS_102.NanoSuit_Icon_BS_102"
		OutfitTypes		= data_raw.OutfitTypes or {},		-- TODO: validate according enum ?  Known values are: ["NSFW"]
		OutfitPaths		= data_raw.OutfitPaths or {},
			-- TODO: validate according to existing object in UE / .ucas ?
			-- example: ["/Game/OutfitMods/AiK_Naik_Makeup/Face/AiK_Face_MA1.AiK_Face_MA1"]
		OutfitNames		= data_raw.OutfitNames or {},		-- example: ["Vanilla", "Cuffless"]
		AnimationBP		= data_raw.AnimationBP or '',		-- TODO: validate according to existing object in UE / .ucas ?
		PonyPhysics		= data_raw.PonyPhysics or '',		-- TODO: ensure it should be present here, bc it's also in "OutfitData"
		OutfitDatas		= tables.list_map(data_raw.OutfitDatas or {}, function(data_raw_2, _index)
				return M.OutfitData.new(data_raw_2)
			end),
		UserConfigs		= tables.list_map(data_raw.UserConfigs or {}, function(data_raw_2, _index)
				return M.UserConfigs.new(data_raw_2)
			end),
	}

	return setmetatable(data, M.ModFitInfo)
end



--[[
Class containing outfit data.
]]
M.OutfitData = {}
M.OutfitData.__index = M.OutfitData



function M.OutfitData.new(data_raw)
	assert(strings.is_non_empty(data_raw.Mesh),							'OutfitData.Mesh is required string')
	assert(tables.is_list_of(strings.is_string, data_raw.Materials),	'OutfitData.Materials is required array of strings')
	assert(tables.is_list_of(tables.is_table, data_raw.Parameters),		'OutfitData.Parameters is required array of "OutfitDataParameter"')
	assert(strings.is_string_or_nil(data_raw.PonyPhysics),				'OutfitData.PonyPhysics should be string or omitted')
	local data = {
		Mesh		= data_raw.Mesh,		-- example: "/Game/CNSRepacked/6138f22cbccb9844/Art/Character/PC/CH_P_EVE_InnerSuit/CH_P_EVE_InnerSuit.CH_P_EVE_InnerSuit"
		Materials	= data_raw.Materials,
			--[[ example: [
				"/Game/Art/Character/PC/CH_P_EVE_InnerSuit/Materials/MI_EVE_Costume_Temp_Inner_Suit.MI_EVE_Costume_Temp_Inner_Suit",
				"/Game/OutfitMods/k7_SkinSuit/Materials/k7_SkinSuit_Inner_Skin02.k7_SkinSuit_Inner_Skin02"
				]
			]]
		Parameters	= tables.list_map(data_raw.Parameters, function(data_raw_2, _index)
				return M.OutfitDataParameter.new(data_raw_2)
			end),
		PonyPhysics	= data_raw.PonyPhysics,
	}
	return setmetatable(data, M.OutfitData)
end



--[[
Class containing outfit data parameters.
]]
M.OutfitDataParameter = {}
M.OutfitDataParameter.__index = M.OutfitDataParameter



function M.OutfitDataParameter.new(data_raw)
	assert(type(data_raw.MaterialIndex)	== 'number',	'OutfitDataParameter.MaterialIndex is required number')
	assert(type(data_raw.LayerIndex)	== 'number',	'OutfitDataParameter.LayerIndex is required number')
	assert(tables.list_has_value(M.OUTFIT_DATA_PARAM_TYPES, data_raw.ParamType),	'OutfitDataParameter.ParamType is required one of: '..json.encode(M.OUTFIT_DATA_PARAM_TYPES))
	assert(type(data_raw.ParamName)		== 'string',	'OutfitDataParameter.ParamName is required string')		-- TODO: validate according to enum ?	Known values: ["BaseColor", "BakeNormal"]
	assert(type(data_raw.Association)	== 'string',	'OutfitDataParameter.Association is required string')	-- TODO: validate according to enum ?	Known values: ["Global", "Layer"]
	assert(type(data_raw.Value)			== 'string',	'OutfitDataParameter.Value is required string')			-- TODO: validate according to existing object in UE / .ucas ?
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
M.UserConfig = {}
M.UserConfig.__index = M.UserConfig



function M.UserConfig.new(data_raw)
	(data_raw.ShapeKeys			and assert(tables.is_list_of(tables.is_table, data_raw.ShapeKeys),			'UserConfig.ShapeKeys should be list of "ShapeKey" or omitted'))
	(data_raw.MaterialToggles	and assert(tables.is_list_of(tables.is_table, data_raw.MaterialToggles),	'UserConfig.MaterialToggles should be list of "MaterialToggle" or omitted'))
	(data_raw.ScalarControls	and assert(tables.is_list_of(tables.is_table, data_raw.ScalarControls),		'UserConfig.ScalarControls should be list of "ScalarControl" or omitted'))
	(data_raw.VectorControls	and assert(tables.is_list_of(tables.is_table, data_raw.VectorControls),		'UserConfig.VectorControls should be list of "VectorControl" or omitted'))
	(data_raw.TextureOptions	and assert(tables.is_list_of(tables.is_table, data_raw.TextureOptions),		'UserConfig.TextureOptions should be list of "TextureOption" or omitted'))
	local data = {
		ShapeKeys		= tables.list_map(data_raw.ShapeKeys,		function(data_raw_2, _index)
				return M.ShapeKey.new(data_raw_2)
			end),
		MaterialToggles	= tables.list_map(data_raw.MaterialToggles,	function(data_raw_2, _index)
				return M.MaterialToggle.new(data_raw_2)
			end),
		ScalarControls	= tables.list_map(data_raw.ScalarControls,	function(data_raw_2, _index)
				return M.ScalarControl.new(data_raw_2)
			end),
		VectorControls	= tables.list_map(data_raw.VectorControls,	function(data_raw_2, _index)
				return M.VectorControl.new(data_raw_2)
			end),
		TextureOptions	= tables.list_map(data_raw.TextureOptions,	function(data_raw_2, _index)
				return M.TextureOption.new(data_raw_2)
			end),
	}
	return setmetatable(data, M.UserConfig)
end



--[[
Class containing shape key for some mesh.
Originally was displayed in GUI in CNS, but we'll set it manually, so only few fields are required for SNS.
]]
M.ShapeKey = {}
M.ShapeKey.__index = M.ShapeKey



function M.ShapeKey.new(data_raw)
	(data_raw.DisplayName	and assert(strings.is_string(data_raw.DisplayName),		'ShapeKey.DisplayName should be string or omitted'))
	(data_raw.Description	and assert(strings.is_string(data_raw.Description),		'ShapeKey.Description should be string or omitted'))
	(data_raw.ShapeKeyName	and assert(strings.is_string(data_raw.ShapeKeyName),	'ShapeKey.ShapeKeyName should be string or omitted'))
	assert(strings.is_string(data_raw.ShapeKeyName),	'ShapeKey.ShapeKeyName is required string')
	assert(type(data_raw.Value)	== 'number',			'ShapeKey.Value is required number')
	(data_raw.Min	and assert(type(data_raw.Min)	== 'number',	'ShapeKey.Min should be number or omitted'))
	(data_raw.Max	and assert(type(data_raw.Max)	== 'number',	'ShapeKey.Max should be number or omitted'))
	(data_raw.Step	and assert(type(data_raw.Step)	== 'number',	'ShapeKey.Step should be number or omitted'))
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
M.MaterialToggle = {}
M.MaterialToggle.__index = M.MaterialToggle



function M.MaterialToggle.new(data_raw)
	(data_raw.DisplayName	and assert(strings.is_string(data_raw.DisplayName),		'MaterialToggle.DisplayName should be string or omitted'))
	(data_raw.Description	and assert(strings.is_string(data_raw.Description),		'MaterialToggle.Description should be string or omitted'))
	(data_raw.ControlledBy	and assert(strings.is_string(data_raw.ControlledBy),	'MaterialToggle.ControlledBy should be string or omitted'))
	assert(type(data_raw.MaterialIndex)	== 'number',	'MaterialToggle.MaterialIndex is required number')
	assert(type(data_raw.Value)			== 'boolean',	'MaterialToggle.Value is required boolean')
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
M.ScalarControl = {}
M.ScalarControl.__index = M.ScalarControl



function M.ScalarControl.new(data_raw)
	(data_raw.DisplayName	and assert(strings.is_string(data_raw.DisplayName),	'ScalarControl.DisplayName should be string or omitted'))
	(data_raw.Description	and assert(strings.is_string(data_raw.Description),	'ScalarControl.Description should be string or omitted'))
	(data_raw.ParamName		and assert(strings.is_string(data_raw.ParamName),	'ScalarControl.ParamName should be string or omitted'))
	(data_raw.Association	and assert(strings.is_string(data_raw.Association),	'ScalarControl.Association should be string or omitted'))
	assert(type(data_raw.LayerIndex)	== 'number',	'ScalarControl.LayerIndex is required number')
	assert(type(data_raw.MaterialIndex)	== 'number',	'ScalarControl.MaterialIndex is required number')
	assert(type(data_raw.Value)			== 'boolean',	'ScalarControl.Value is required boolean')
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
M.VectorControl = {}
M.VectorControl.__index = M.VectorControl



function M.VectorControl.new(data_raw)
	(data_raw.DisplayName	and assert(strings.is_string(data_raw.DisplayName),	'VectorControl.DisplayName should be string or omitted'))
	(data_raw.Description	and assert(strings.is_string(data_raw.Description),	'VectorControl.Description should be string or omitted'))
	(data_raw.ParamName		and assert(strings.is_string(data_raw.ParamName),	'VectorControl.ParamName should be string or omitted'))
	(data_raw.Association	and assert(strings.is_string(data_raw.Association),	'VectorControl.Association should be string or omitted'))
	assert(type(data_raw.LayerIndex)	== 'number',			'VectorControl.LayerIndex is required number')
	assert(type(data_raw.MaterialIndex)	== 'number',			'VectorControl.MaterialIndex is required number')
	assert(type(data_raw.Value)			== 'boolean',			'VectorControl.Value is required boolean')
	assert(assert(tables.is_list_of_booleans(data_raw.Value),	'VectorControl.Value is required array of numbers'))
	(data_raw.Sliders	and assert(tables.is_list_of_booleans(data_raw.Sliders),	'VectorControl.Sliders should be array of boolean or omitted'))
	(data_raw.Min		and assert(tables.is_list_of_numbers(data_raw.Min),			'VectorControl.Min should be array of number or omitted'))
	(data_raw.Max		and assert(tables.is_list_of_numbers(data_raw.Max),			'VectorControl.Max should be array of number or omitted'))
	(data_raw.Step		and assert(tables.is_list_of_numbers(data_raw.Step),		'VectorControl.Step should be array of number or omitted'))
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
M.TextureOption = {}
M.TextureOption.__index = M.TextureOption



function M.TextureOption.new(data_raw)
	(data_raw.DisplayName	and assert(strings.is_string(data_raw.DisplayName),	'TextureOption.DisplayName should be string or omitted'))
	(data_raw.Description	and assert(strings.is_string(data_raw.Description),	'TextureOption.Description should be string or omitted'))
	(data_raw.ParamName		and assert(strings.is_string(data_raw.ParamName),	'TextureOption.ParamName should be string or omitted'))
	(data_raw.Association	and assert(strings.is_string(data_raw.Association),	'TextureOption.Association should be string or omitted'))
	assert(type(data_raw.LayerIndex)	== 'number',	'TextureOption.LayerIndex is required number')
	assert(type(data_raw.MaterialIndex)	== 'number',	'TextureOption.MaterialIndex is required number')
	assert(type(data_raw.Value)			== 'number',	'TextureOption.Value is required number')
	(data_raw.OptionNames	and assert(tables.is_list_of(strings.is_string, data_raw.OptionNames),	'TextureOption.OptionNames should be array of string or omitted'))
	assert(tables.is_list_of(strings.is_string, data_raw.Textures),	'TextureOption.Textures is required array of string')
	local data = {
		DisplayName		= data_raw.DisplayName,		-- example: "Tattoo"
		Description		= data_raw.Description,		-- example: ""
		ParamName		= data_raw.ParamName,		-- example: "BaseColor"
		Association		= data_raw.Association,		-- TODO: validate with enum ?  Known values: ["Global"]
		LayerIndex		= data_raw.LayerIndex,		-- example: -1
		MaterialIndex	= data_raw.MaterialIndex,	-- example: 9
		OptionNames		= data_raw.OptionNames,
			-- example: ["Cross",  "Fck"]
			-- we don't display them
		Textures		= data_raw.Textures,
			-- example: ["/Game/OutfitMods/AiK_Naik_Makeup/Textures/Cross.Cross",  "/Game/OutfitMods/AiK_Naik_Makeup/Textures/Fck.Fck"]
			-- which texture we should apply
			-- TODO later: validate according to existing object in UE / .ucas ?
		Value			= data_raw.Value,
			-- example: 0
			-- index of texture to apply,  starts from 0
	}
	return setmetatable(data, M.TextureOption)
end



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
M.UEAssetData = {}
M.UEAssetData.__index = M.UEAssetData



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
	return asset
end



return M
