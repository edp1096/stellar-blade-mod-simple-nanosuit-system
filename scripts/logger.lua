local is_debug = false

local MOD_NAME = 'SNS'
local M = {}

function M.info(...)
	if is_debug then
		print('['..MOD_NAME..'] ', ..., "\n")
	end
end


function M.debug(...)
	return M.log('DEBUG', ...)
end


function M.warn(...)
	return M.log('WARN', ...)
end


function M.error(...)
	return M.log('ERROR', ...)
end


function M.log(level, ...)
	if is_debug then
		print('['..MOD_NAME..']['..level..'] ', ..., "\n")
	end
end


function M.inspect(msg, obj)
	local ue = require('ue')	-- avoid recursive imports

	local obj_str = ue.inspect_stringify(obj)	-- supports also standard objects
	M.debug(msg, obj_str)
end



return M
