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



return M
