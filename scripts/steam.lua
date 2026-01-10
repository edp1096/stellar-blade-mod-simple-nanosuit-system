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

	-- Use io.popen to list directories (lfs-dependent path.each not available in UE4SS)
	local handle = io.popen('dir "' .. save_dir_game .. '" /b /ad')
	if not handle then
		return nil
	end

	local result = handle:read("*a")
	handle:close()

	-- Iterate through directories to find matching steam_autocloud.vdf
	for dir_name in result:gmatch("[^\r\n]+") do
		if dir_name and dir_name ~= "" then
			local path_current = path.join(save_dir_game, dir_name)
			local autocloud_vdf_path = path.join(path_current, 'steam_autocloud.vdf')
			local autocloud_vdf_content = fs.file__read(autocloud_vdf_path)
			local is_current_steam_user = root_autocloud_content == autocloud_vdf_content
			if is_current_steam_user then
				local _, steam_user_id_current = path.splitpath(path_current)
				if steam_user_id_current then
					steam_user_id = steam_user_id_current
					break
				end
			end
		end
	end

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
	local steam_user_id				= nil

	-- Use io.popen to list directories (lfs-dependent path.each not available in UE4SS)
	local handle = io.popen('dir "' .. save_dir_game .. '" /b /ad')
	if not handle then
		return nil
	end

	local result = handle:read("*a")
	handle:close()

	-- Get first directory (steam user id)
	for dir_name in result:gmatch("[^\r\n]+") do
		if dir_name and dir_name ~= "" then
			steam_user_id = dir_name
			break
		end
	end

	return steam_user_id
end



return M
