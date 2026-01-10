--[[
Save and load mod settings to mod or game saves directory.
Usually it's "C:/Users/<username>/AppData/Local/SB/Saved/".

Notes:
	Didn't name just "save" to allow using local variables named "save".
]]

local json	= require('dkjson')
local path	= require('path')

local fs		= require('fs')
local numbers	= require('numbers')
local strings	= require('strings')
local tables	= require('tables')



local M = {}

M.SETTINGS_FILE_NAME = 'sns.settings.json'



M.SavedSettings			= {}
M.SavedSettings.__index	= M.Save



function M.SavedSettings.read()
	local mod_dir			= fs.mod_dir__get()
	local save_path__mod	= path.join(mod_dir,	M.SETTINGS_FILE_NAME)
	local settings_raw_str	= nil

	-- Only check mod directory (fast).
	-- Removed save_dir check because fs.save_dir__get() takes 5+ seconds due to io.popen('dir')
	if fs.file__check_exists(save_path__mod) then
		settings_raw_str	= fs.file__read(save_path__mod)
	else
		error(('cannot read save file: %s'):format(save_path__mod))
	end

	local settings_raw	= json.decode(settings_raw_str)
	local settings		= M.SavedSettings.new(settings_raw)
	return settings
end



function M.SavedSettings.new(data_raw)
	assert(numbers.is_boolean_or_nil(data_raw.Enabled),							'SavedSettings.Enabled should contain list of Replacement or empty list')
	assert(numbers.is_boolean_or_nil(data_raw.ShowPonytail),					'SavedSettings.ShowPonytail should be boolean or nil')
	assert(tables.is_list_of_or_nil(data_raw.Replacements, tables.is_table),	'SavedSettings.Replacements should contain list of Replacement or be an empty list')

	if data_raw.Enabled == nil then		-- check in separate thread bc we can't just compare "data_raw.Enabled or true" - we also expect false
		data_raw.Enabled = true
	end

	local data = {
		Enabled			= data_raw.Enabled,
		ShowPonytail	= data_raw.ShowPonytail ~= false,	-- default to true (show ponytail by default)
		Replacements	= tables.map(data_raw.Replacements or {}, function(data_raw__current)
								return  M.Replacement.new(data_raw__current)
							end),
	}

	return setmetatable(data, M.SavedSettings)
end



M.Replacement			= {}
M.Replacement.__index	= M.Replacement



function M.Replacement.new(data_raw)
	assert(strings.is_string(data_raw.UniqueFitID),			'Replacement.UniqueFitID is required string')			-- same case as in "dekcns.json"
	assert(strings.is_string_or_nil(data_raw.OutfitMesh),	'Replacement.OutfitMesh should be string or omited')	-- take from "dekcns.json" from "OutfitPaths" or "OutfitDatas.Mesh"
	assert(numbers.is_boolean_or_nil(data_raw.Enabled),		'Replacement.Enabled should be boolean or nil')
	assert(tables.is_table_or_nil(data_raw.UserConfigs),	'Replacement.UserConfigs should be UserConfigs or nil')	-- match name in ".dekcns.json"

	if data_raw.Enabled == nil then		-- check in separate thread bc we can't just compare "data_raw.Enabled or true" - we also expect false
		data_raw.Enabled = true
	end

	local data = {
		UniqueFitID	= data_raw.UniqueFitID,
		OutfitMesh	= data_raw.OutfitMesh,
		UserConfigs	= M.UserConfigs.new(data_raw.UserConfigs or {}),
		Enabled		= data_raw.Enabled,
	}

	return setmetatable(data, M.Replacement)
end



--[[
Similar to "assets.UserConfigs",  but simpler.
]]
M.UserConfigs			= {}
M.UserConfigs.__index	= M.UserConfigs



function M.UserConfigs.new(data_raw)
	assert(tables.is_list_of_or_nil(data_raw.MaterialToggles,	tables.is_table), 'UserConfigs.MaterialToggles should be list of "MaterialToggle" or omitted')
	assert(tables.is_list_of_or_nil(data_raw.ScalarControls,	tables.is_table), 'UserConfigs.ScalarControls should be list of "ScalarControl" or omitted')
	assert(tables.is_list_of_or_nil(data_raw.VectorControls,	tables.is_table), 'UserConfigs.VectorControls should be list of "VectorControl" or omitted')
	assert(tables.is_list_of_or_nil(data_raw.TextureOptions,	tables.is_table), 'UserConfigs.TextureOptions should be list of "TextureOption" or omitted')
	assert(tables.is_list_of_or_nil(data_raw.ShapeKeys,			tables.is_table), 'UserConfigs.ShapeKeys should be list of "ShapeKey" or omitted')

	local data = {
		MaterialToggles	= tables.map(data_raw.MaterialToggles or {},	function(data_raw_2)
								return M.MaterialToggle.new(data_raw_2)
							end),
		ScalarControls	= tables.map(data_raw.ScalarControls or {},		function(data_raw_2)
								return M.ScalarControl.new(data_raw_2)
							end),
		VectorControls	= tables.map(data_raw.VectorControls or {},		function(data_raw_2)
								return M.VectorControl.new(data_raw_2)
							end),
		TextureOptions	= tables.map(data_raw.TextureOptions or {},		function(data_raw_2)
								return M.TextureOption.new(data_raw_2)
							end),
		ShapeKeys		= tables.map(data_raw.ShapeKeys or {},			function(data_raw_2)
								return M.ShapeKey.new(data_raw_2)
							end),
	}

	return setmetatable(data, M.UserConfigs)
end



--[[
Similar to "assets.MaterialToggle",  but simpler.
]]
M.MaterialToggle			= {}
M.MaterialToggle.__index	= M.MaterialToggle



function M.MaterialToggle.new(data_raw)
	assert(numbers.is_number(data_raw.MaterialIndex),	'MaterialToggle.MaterialIndex is required number')
	assert(numbers.is_boolean(data_raw.Value),			'MaterialToggle.Value is required boolean')

	local data = {
		MaterialIndex	= data_raw.MaterialIndex,
		Value			= data_raw.Value,
	}

	return setmetatable(data, M.MaterialToggle)
end



--[[
Similar to "assets.ScalarControl",  but simpler.
]]
M.ScalarControl			= {}
M.ScalarControl.__index	= M.ScalarControl



function M.ScalarControl.new(data_raw)
	assert(strings.is_string_or_nil(data_raw.ParamName),	'ScalarControl.ParamName should be string or omitted')
	assert(numbers.is_number(data_raw.MaterialIndex),		'ScalarControl.MaterialIndex is required number')
	assert(numbers.is_number(data_raw.Value),				'ScalarControl.Value is required number')

	local data = {
		ParamName		= data_raw.ParamName,
		MaterialIndex	= data_raw.MaterialIndex,
		Value			= data_raw.Value,
	}

	return setmetatable(data, M.ScalarControl)
end



--[[
Similar to "assets.VectorControl",  but simpler.
]]
M.VectorControl			= {}
M.VectorControl.__index	= M.VectorControl



function M.VectorControl.new(data_raw)
	assert(strings.is_string_or_nil(data_raw.ParamName),			'VectorControl.ParamName should be string or omitted')
	assert(numbers.is_number(data_raw.MaterialIndex),				'VectorControl.MaterialIndex is required number')
	assert(tables.is_list_of(data_raw.Value, numbers.is_number),	'VectorControl.Value is required array of numbers')
	assert(tables.length(data_raw.Value) == 4,						'VectorControl.Value array should contain 4 numbers')

	local data = {
		ParamName		= data_raw.ParamName,
		MaterialIndex	= data_raw.MaterialIndex,
		Value			= data_raw.Value,
	}

	return setmetatable(data, M.VectorControl)
end



--[[
Similar to "assets.TextureOption",  but simpler.
]]
M.TextureOption			= {}
M.TextureOption.__index	= M.TextureOption



function M.TextureOption.new(data_raw)
	assert(strings.is_string_or_nil(data_raw.ParamName),	'TextureOption.ParamName should be string or omitted')
	assert(numbers.is_number(data_raw.MaterialIndex),		'TextureOption.MaterialIndex is required number')
	assert(strings.is_string(data_raw.Value),				'TextureOption.Value is required string')	-- it's number in "assets.TextureOption" - index of texture,  but here we specify path to texture

	local data = {
		ParamName		= data_raw.ParamName,
		MaterialIndex	= data_raw.MaterialIndex,
		Value			= data_raw.Value,
	}

	return setmetatable(data, M.TextureOption)
end



--[[
Similar to "assets.ShapeKey",  but simpler.
]]
M.ShapeKey			= {}
M.ShapeKey.__index	= M.ShapeKey



function M.ShapeKey.new(data_raw)
	assert(strings.is_string(data_raw.ShapeKeyName),	'ShapeKey.ShapeKeyName is required string')
	assert(numbers.is_number(data_raw.Value),			'ShapeKey.Value is required number')

	local data = {
		ShapeKeyName	= data_raw.ShapeKeyName,
		Value			= data_raw.Value,
	}

	return setmetatable(data, M.ShapeKey)
end



return M
