local MOD_NAME = 'SNS'

local M = {}



function M.info(...)
	print('['..MOD_NAME..'] ', ...)
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
	print('['..MOD_NAME..']['..level..'] ', ...)
end


function M.inspect_object(msg, obj)
	local ue = require('ue')	-- avoid recursive imports

	local obj_str = ue.inspect_stringify(obj)	-- supports also standard objects
	M.debug(msg, obj_str)
end



return M
