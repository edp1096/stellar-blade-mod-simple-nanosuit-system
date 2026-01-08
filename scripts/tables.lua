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



function M.is_list_of(table, function_to_check_each_value)
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



function M.is_list_of_or_nil(table, function_to_check_each_value)
	if table == nil then
		return true
	end

	local result = M.is_list_of(table, function_to_check_each_value)
	return result
end



function M.length(table)
	local amount = 0
	for _ in pairs(table) do
		amount = amount + 1
	end
	return amount
end



--[[
Filter all results into a new table.
]]
function M.filter(table, function_)
	for _, value in pairs(table) do
		if function_(value) then
			return value
		end
	end
	return {}
end



--[[
Return new table with numeric indexes
	by iterating over values with numberic indexes of existing table,
	applying "function" to each of them.
Alternative to Python's "list.map()".
TODO:
	replace to just "map"
]]
function M.map(table, function_)
	local result = {}
	for key, value in pairs(table) do
		result[key] = function_(value, key)
	end
	return result
end



--[[
call
	chain({'a', 'b', 'c'},  {'d', 'e'})
will return
	{'a', 'b', 'c', 'd', 'e'}

call
	chain({key1: 'value1', key2: 'value2'},  {'d', 'e'})
will return
	{'value1', 'value2', 'd', 'e'}
or will return
	{'value2', 'value1', 'd', 'e'}
note
	don't sort values inside one func for performance reasons
	if keys are numbers - order is preserved
]]
function M.chain(...)
	local result		= {}
	local args_tables	= table.pack(...)
	local index			= 0

	for arg_index = 1, args_tables.n do
		local table_ = args_tables[arg_index]
			-- "ipairs" stops at first "nil" value
			-- we need first table to go first
		local is_table = type(table_) == 'table'
		if not is_table then
			goto continue
		end

		for _, value in pairs(table_) do	-- don't sort for performance reasons
			index			= index + 1
			result[index]	= value
		end

		::continue::
	end

	return result
end



function M.sorted_pairs(table_, function__compare_values)
	if not function__compare_values then
		function__compare_values = M._sort_by_numbers_then_by_strings_ascending
	end

	-- get sorted keys
	local keys_sorted = {}

	for k in pairs(table_) do
		keys_sorted[#keys_sorted + 1] = k
	end
	table.sort(keys_sorted, function__compare_values)

	-- return iterator by sorted keys n values
	local index = 0
	return function()
		index		= index + 1
		local key	= keys_sorted[index]
		return key, table_[key]	-- will return "nil, nil" when finished,  doesn't affect func result
	end
end



function M._sort_by_numbers_then_by_strings_ascending(a, b)
	local type_of_a = type(a)
	local type_of_b = type(b)

	-- same type → normal comparison
	if type_of_a == type_of_b then
		return a < b
	end

	-- numbers always come first
	if type_of_a == 'number' then
		return true
	end
	if type_of_b == 'number' then
		return false
	end

	-- fallback: string comparison
	return tostring(a) < tostring(b)
end



--[[
Get new list-like table with values of passed table.
]]
function M.values(table_)	-- "table_" to don't shadow "table" library which will be used here
	local result = {}
	for _, value in pairs(table_) do
		table.insert(result, value)
	end
	return result
end



--[[
Get max number value from all table values.
]]
function M.max_value(table_)
	local result = nil

	for _, value in pairs(table_) do
		local is_number			= type(value) == 'number'
		local is_number_bigger	= is_number and (value > result)
		if is_number_bigger then
			result = value
		end
	end

	return result
end



function M.has_value(table, value)
	for _, value_current in pairs(table) do
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
Values with same keys will be overwritten.
]]
function M.merge(...)
	local result = {}
	for i = 1, select('#', ...) do
		local table_ = select(i, ...)
		for key, value in ipairs(table_) do
			result[key] = value
		end
	end
	return result
end



--[[
Prefer using "logger.inspect()", it call this if needed.
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
