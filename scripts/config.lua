--[[
Contains global mod config.

Should be loaded before anyhthing else bc it setups path to side packages
	(installed by "luarocks").
]]



--[[
Obtain dir of mod.
Previously used:
		local _mod_dir = ('%s/SB/Binaries/Win64/ue4ss/Mods/SNS'):format(IterateGameDirectories().__absolute_path)
	but it caused crash
]]
function _mod_dir__get()
	local info			= debug.getinfo(1, 'S')
	local script_file	= info.source
		-- example:  "@E:/Games/.../ue4ss/Mods/SNS/scripts/main.lua"

	if script_file:sub(1, 1) == '@' then
		script_file = script_file:sub(2)
	end

	return script_file .. '/../..'
end



--[[
This code allows importing side "packages" from "luarocks" install directory.
Should be ran before anything other.
]]
-- local _mod_dir = ('%s/SB/Binaries/Win64/ue4ss/Mods/SNS'):format(IterateGameDirectories().__absolute_path)
	-- caused crash
local _mod_dir = _mod_dir__get()
	-- accessing by dots to mod dirs doesn't work:  "IterateGameDirectories().SB.Binaries.Win64.ue4ss.Mods.SNS"
--[[
set path to installed by "luarocks" packages,
so "require('package_name')" will work
]]
package.path =
	package.path
	.. (';%s/packages/share/lua/5.4/?.lua'):format(_mod_dir)
	.. (';%s/packages/share/lua/5.4/?/init.lua'):format(_mod_dir)
--[[
also allow importing ".dll" modules installed by "luarocks".
]]
package.cpath =
	package.cpath
	.. (';%s/packages/lib/lua/5.4/?.dll'):format(_mod_dir)
	.. (';%s/scripts/?.dll'):format(_mod_dir)



--[[
This is a regular config module code.
]]

local M = {
	KEY__RELOAD_MOD = Key.F9,	-- options:  https://docs.ue4ss.com/lua-api/table-definitions/key.html
}



return M
