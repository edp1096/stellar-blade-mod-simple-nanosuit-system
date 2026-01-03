--[[
Helper functions to work with Lua numbers.

TODO:  use it in validation
]]

local M = {}



function M.is_number(unknown_value)
	return type(unknown_value) == 'number'
end



function M.is_number_or_nil(unknown_value)
	return unknown_value == nil or type(unknown_value) == 'number'
end



--[[
Technically it's number too.
Just don't create extra "booleans" module for one check.
]]
function M.is_boolean(unknown_value)
	return type(unknown_value) == 'boolean'
end



function M.is_boolean_or_nil(unknown_value)
	return unknown_value == nil or type(unknown_value) == 'boolean'
end



return M
