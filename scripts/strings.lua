local M = {}



function M.is_string(unknown_value)
	return type(unknown_value) == 'string'
end



function M.is_string_or_nil(unknown_value)
	return unknown_value == nil or type(unknown_value) == 'string'
end



function M.is_non_empty(unknown_value)
	return type(unknown_value) == 'string' and unknown_value ~= ''
end



function M.starts_with(str, prefix)
    return str:find(prefix, 1, true) == 1
end



return M
