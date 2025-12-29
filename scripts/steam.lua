local path = require('path')

local paths_lib = StaticFindObject('/Script/Engine.Default__BlueprintPathsLibrary')	-- docs:  https://dev.epicgames.com/documentation/en-us/unreal-engine/python-api/class/Paths?highlight=paths&application_version=4.27#unreal.Paths

local fs = require('fs')



local M = {}



--[[
Get steam user id in uint64 format from game save directory.

How:
	Base saves dir  "C:\Users\<username>\AppData\Local\SB\Saved\"  contains  "steam_autocloud.vdf",
		that file contains ID of currently used Steam account.
	Actual saves dir  "C:\Users\<username>\AppData\Local\SB\Saved\SaveGames\<steam-id>\"  also contains  "steam_autocloud.vdf",
		which contains ID of Steam account from that directory.
	So we just pick all directories per steam user and compare content of "steam_autocloud.vdf",
		if they match - this is our directory.
]]
function M.get_steam_user_id__from_autocloud_vdf_files()
	local save_dir_base				= paths_lib:ProjectSavedDir():ToString()
	local save_dir_game				= path.join(save_dir_base, 'SaveGames')
	local save_dir_game__iterate	= path.join(save_dir_game, '*')
	local root_autocloud_vdf_path	= path.join(save_dir_game, 'steam_autocloud.vdf')
	local root_autocloud_content	= fs.file__read(root_autocloud_vdf_path)
	local steam_user_id				= nil

	if not root_autocloud_content then
		return nil
	end

	path.each(save_dir_game__iterate, function(path_current, _mode)
		local autocloud_vdf_path	= path.join(path_current, 'steam_autocloud.vdf')
		local autocloud_vdf_content	= fs.file__read(autocloud_vdf_path)
		local is_current_steam_user	= root_autocloud_content == autocloud_vdf_content
		if not is_current_steam_user then
			return
		end
		local _, steam_user_id_current	= path.splitpath(path_current)
		if steam_user_id_current then
			steam_user_id = steam_user_id_current
		end
	end, {
		skipfiles = true,
	})

	return steam_user_id
end



--[[
We just pick first save game directory.
It's not guaranteed that this user - is our current Steam user,
	but in most cases people have only one Steam account connected,
	so it'll work well.
Should be used if "get_steam_user_id__from_autocloud_vdf_files" failed.
]]
function M.get_steam_user_id__from_first_save_dir()
	local save_dir_base				= paths_lib:ProjectSavedDir():ToString()
	local save_dir_game				= path.join(save_dir_base, 'SaveGames')
	local save_dir_game__iterate	= path.join(save_dir_game, '*')
	local steam_user_id				= nil

	path.each(save_dir_game__iterate, function(path_current, _mode)
		local _, steam_user_id_current	= path.splitpath(path_current)
		if steam_user_id_current then
			steam_user_id = steam_user_id_current
		end
	end, {
		reverse		= true,	-- we need to pick first
		skipfiles	= true,
	})

	return steam_user_id
end



return M
