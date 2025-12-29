--[[
Helper functions to work with Lua tables.
]]

local M = {}



function M.is_table(unknown_value)
	return type(unknown_value) == 'table'
end



function M.is_table_or_nil(unknown_value)
	return unknown_value == nil or type(unknown_value) == 'table'
end



function M.is_list_of(function_to_check_each_value, table)
	assert(type(function_to_check_each_value) == 'function', 'function_to_check_each_value must be a function')

	if type(table) ~= 'table' then
		return false
	end

	for key = 1, #table do	-- this will also ensure there are no non-numeric keys, no holes
		local value				= table[key]
		local is_value_valid	= function_to_check_each_value(value)
		if not is_value_valid then	-- key is valid anyway - we iterate manually by numbers
			return false
		end
	end

	return true
end



-- Added a separate function to don't create "booleans.lua" for one "is_boolean" func
function M.is_list_of_booleans(table)
	local function _is_boolean(value)
		return type(value) == 'boolean'
	end
	return M.is_list_of(_is_boolean, table)
end



-- Added a separate function to don't create "number.lua" for one "is_number" func
function M.is_list_of_numbers(table)
	local function _is_number(value)
		return type(value) == 'number'
	end
	return M.is_list_of(_is_number, table)
end



--[[
Find first matching result in table on which "function_" will return "true".
]]
function M.find(table, function_)
	for _, value in pairs(table) do
		if function_(value) then
			return value
		end
	end
	return nil
end



--[[
Return new table with numeric indexes
	by iterating over values with numberic indexes of existing table,
	applying "function" to each of them.
Alternative to Python's "list.map()".
]]
function M.list_map(list_table, function_)
	local result = {}
	for index = 1, #list_table do
		result[index] = function_(list_table[index], index)
	end
	return result
end



function M.list_has_value(list_table, value)
	for _, value_current in ipairs(list_table) do
		local present_in_list = value_current == value
		if present_in_list then
			return true
		end
	end
	return false
end



function M.get_case_insensitive(table, key)
	key = key:lower()
	for k, value in pairs(table) do
		local is_our_key = type(k) == 'string' and k:lower() == key
		if is_our_key then
			return value
		end
	end
end



--[[
Merge any number of passed tables.
Only values are preserved, keys ingored,
	will set new keys from 0 to number of elements.
]]
function M.merge(...)
	local result = {}
	for i = 1, select('#', ...) do
		local t = select(i, ...)
		for _, v in ipairs(t) do
			table.insert(result, v)
		end
	end
	return result
end



--[[
Prefer using "logger.inspect_object()", it call this if needed.
]]
function M.inspect_stringify(value, indent, visited, tostring_func)
	indent	= indent or ''
	visited	= visited or {}

	if type(value) ~= 'table' then
		if tostring_func then
			local value_str = tostring_func(value, indent, visited)
			if value_str then
				return value_str
			end
		end
		return tostring(value)
	end

	-- table
	if visited[value] then
		return '<table_cycle>'
	end
	visited[value] = true

	local nextIndent = indent .. '  '
	local out = '{\n'

	for k, v in pairs(value) do
		out = out
			.. nextIndent
			.. M.inspect_stringify(k, '', visited, tostring_func) .. ' = '
			.. M.inspect_stringify(v, nextIndent, visited, tostring_func)
			.. ',\n'
	end

	out = out .. indent .. '}'
	return out
end



return M
