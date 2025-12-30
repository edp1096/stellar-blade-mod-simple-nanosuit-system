--[[
Filesystem-related helpers.
About directories, files, etc.
]]

local lfs	= require('lfs')
local path	= require('path')	-- not just "path" to allow naming local variables so

local paths_lib = StaticFindObject('/Script/Engine.Default__BlueprintPathsLibrary')	-- docs:  https://dev.epicgames.com/documentation/en-us/unreal-engine/python-api/class/Paths?highlight=paths&application_version=4.27#unreal.Paths

local logger = require('logger')




local M = {}



function M.file__check_exists(path_)
	local attr		= lfs.attributes(path_)
	local exists	= attr ~= nil and attr.mode == 'file'
	return exists
end



function M.file__read(path_)
	local file, err = io.open(path_, 'r')  -- read in text mode

	if not file then
		logger.error('Error reading file', path_, err)
		return nil
	end

	local content = file:read('*a')  -- read all
	file:close()

	return content
end



function M.file__write(path_, content)
	local file, err = io.open(path_, 'w')  -- 'w' = create or truncate
	if not file then
			error(err)
	end

	file:write(content)
	file:close()
end



function M.mod_dir__get()
	local info			= debug.getinfo(1, 'S')
	local script_file	= info.source
		-- example:  "@E:/Games/.../ue4ss/Mods/SNS/scripts/main.lua"

	if script_file:sub(1, 1) == '@' then
		script_file = script_file:sub(2)
	end

	local scripts_dir	= path.dirname(path.dirname(script_file))
	local mod_dir		= path.join(scripts_dir, '../')

	return mod_dir
end



function M.save_dir__get()
	local steam = require('steam')	-- avoid recursive imports

	local save_dir_base = paths_lib:ProjectSavedDir():ToString()
		-- like "C:\Users\<username>\AppData\Local\SB\Saved\"
		-- but actual save files are placed in subdir: ".\SaveGames\<steam-id>"
		-- so get Steam ID first

	local success, result	= pcall(steam.get_steam_user_id__from_autocloud_vdf_files)
	local steam_user_id		= nil
	if success then
		steam_user_id = result
	else
		logger.error('error getting steam id from .vdf files', steam_user_id)
		steam_user_id = nil
	end

	if not steam_user_id then
		steam_user_id = steam.get_steam_user_id__from_first_save_dir()	-- don't safe handle - if we can't - should fail
	end

	if not steam_user_id then
		return nil
	end

	local save_dir = path.join(save_dir_base, 'SaveGames', steam_user_id)
	return save_dir
end



return M
