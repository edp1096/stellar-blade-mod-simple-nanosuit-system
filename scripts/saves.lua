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
	local save_dir			= fs.save_dir__get()
	local save_path__mod	= path.join(mod_dir,	M.SETTINGS_FILE_NAME)
	local save_path__saves	= path.join(save_dir,	M.SETTINGS_FILE_NAME)
	local settings_raw_str	= nil

	if fs.file__check_exists(save_path__mod) then
		settings_raw_str	= fs.file__read(save_path__mod)
	elseif fs.file__check_exists(save_path__saves) then
		settings_raw_str	= fs.file__read(save_path__saves)
	else
		error(('cannot read save file, tried: %s, %s'):format(save_path__mod, save_path__saves))
	end

	local settings_raw	= json.decode(settings_raw_str)
	local settings		= M.SavedSettings.new(settings_raw)
	return settings
end



function M.SavedSettings.new(data_raw)
	assert(numbers.is_boolean_or_nil(data_raw.Enabled),							'SavedSettings.Enabled should contain list of Replacement or empty list')
	assert(tables.is_list_of_or_nil(data_raw.Replacements, tables.is_table),	'SavedSettings.Replacements should contain list of Replacement or be an empty list')

	if data_raw.Enabled == nil then		-- check in separate thread bc we can't just compare "data_raw.Enabled or true" - we also expect false
		data_raw.Enabled = true
	end

	local data = {
		Enabled			= data_raw.Enabled,
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

	if data_raw.Enabled == nil then		-- check in separate thread bc we can't just compare "data_raw.Enabled or true" - we also expect false
		data_raw.Enabled = true
	end

	local data = {
		UniqueFitID	= data_raw.UniqueFitID,
		OutfitMesh	= data_raw.OutfitMesh,
		Enabled		= data_raw.Enabled,
	}

	return setmetatable(data, M.Replacement)
end



return M
