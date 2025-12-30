--[[
Save and load mod settings to mod or game saves directory.
Usually it's "C:/Users/<username>/AppData/Local/SB/Saved/".

Notes:
	Didn't name just "save" to allow using local variables named "save".
]]

local json	= require('dkjson')
local path	= require('path')

local enums			= require('enums')
local fs			= require('fs')
local strings		= require('strings')
local tables		= require('tables')



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
	assert(tables.is_table_or_nil(data_raw[enums.Characters.eve]),		('SavedSettings[%s] should be string or omitted'):format(data_raw[enums.Characters.eve]))
	assert(tables.is_table_or_nil(data_raw[enums.Characters.lily]),		('SavedSettings[%s] should be string or omitted'):format(data_raw[enums.Characters.lily]))
	assert(tables.is_table_or_nil(data_raw[enums.Characters.adam]),		('SavedSettings[%s] should be string or omitted'):format(data_raw[enums.Characters.adam]))
	assert(tables.is_table_or_nil(data_raw[enums.Characters.drone]),	('SavedSettings[%s] should be string or omitted'):format(data_raw[enums.Characters.drone]))
	local data = {
		[enums.Characters.eve]	= data_raw[enums.Characters.eve] and M.Replacement.new(data_raw[enums.Characters.eve]),
	}
	return setmetatable(data, M.SavedSettings)
end



M.Replacement			= {}
M.Replacement.__index	= M.Replacement



function M.Replacement.new(data_raw)
	assert(strings.is_string(data_raw.UseFitId),	'Replacement.UseFitId is required string')
	assert(strings.is_string(data_raw.UseOutfit),	'Replacement.UseOutfit is required string')
	-- assert(numbers.is_number_or_nil(data_raw.UseOutfitData),	'Replacement.UseOutfitData should be number or omitted')

	if data_raw.UseOutfit and not data_raw.UseFitId then
		assert(false, 'Replacement.UseFitId must be specified if Replacement.UseOutfit was')
	end
	-- if data_raw.UseOutfitData and not data_raw.UseFitId then
	-- 	assert(false, 'Replacement.UseFitId must be specified if Replacement.UseOutfitData was')
	-- end

	local data = {
		UseFitId	= data_raw.UseFitId,
		UseOutfit	= data_raw.UseOutfit,
	}
	return setmetatable(data, M.Replacement)
end



return M
