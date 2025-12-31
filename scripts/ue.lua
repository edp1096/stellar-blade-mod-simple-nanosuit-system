--[[
Helper functions to work with Unreal Engine objects.
]]

local kismet_lib = StaticFindObject('/Script/Engine.Default__KismetSystemLibrary')	-- docs:  https://dev.epicgames.com/documentation/en-us/unreal-engine/python-api/class/SystemLibrary?application_version=4.27

local logger = require('logger')



local M = {}



function M.find_one_by(class_name_short, function_)
	local candidates = FindAllOf(class_name_short)
	if not candidates then
		return nil
	end

	for _, candidate in pairs(candidates) do
		local is_good = function_(candidate)
		if is_good then
			return candidate
		end
	end
end



--[[
Prefer using "logger.inspect_object()", it call this if needed.
]]
function M.inspect_stringify(value, indent, visited)
	indent	= indent or ''
	visited	= visited or {}	-- to handle nested tables

	local tables			= require('tables')	-- avoid recursive imports
	local is_userdata		= type(value) == 'userdata'	-- all UE objects are "userdata"
	local value_to_inspect	= value

	if is_userdata then
		value_to_inspect = M.inspect(value)
		if not value_to_inspect then
			value_to_inspect = 'InvalidUEObject'
		end
	end

	local function _tostring_func__for_nested_ue_objects(value_2, indent_2, visited_2)
		local is_userdata_2	= type(value_2) == 'userdata'
		if not is_userdata_2 then
			return nil	-- will be handled by default
		end
		local value_2_str = M.inspect_stringify(value_2, indent_2, visited_2)
		return value_2_str
	end

	local object_str = tables.inspect_stringify(value_to_inspect, indent, visited, _tostring_func__for_nested_ue_objects)  -- it supports also all standard non-table objects
	return object_str
end



--[[
Prefer using "logger.inspect_object()", it call this if needed.
]]
function M.inspect(ue_obj)
	local success, result = pcall(function()
		if M.is_fname_userdata(ue_obj) then	-- this check should return before "ue_obj:IsValid()" bc that would fail if "ue_obj" is "is_fname"
			return ('FName(\'%s\')'):format(ue_obj:ToString())
		end

		if not ue_obj or not ue_obj:IsValid() then
			return nil
		end

		return {
			PathName	= kismet_lib:GetPathName(ue_obj):ToString(),
			ObjectName	= kismet_lib:GetObjectName(ue_obj):ToString(),
			DisplayName	= kismet_lib:GetDisplayName(ue_obj):ToString(),	-- often same as "ObjectName"
			Class		= tostring(ue_obj:GetClass()),
			ClassName	= kismet_lib:GetObjectName(ue_obj:GetClass()):ToString(),
		}
	end)

	if not success then
		return nil
	end
	return result
end



function M.is_fname_userdata(value)
	return tostring(value):find('FNameUserdata')
end



--[[
Blueprints are lazy-loaded, so may be not available on mod load.
]]
function M.register_blueprint_hook(hook_path, function_callback)
	local hooked		= false
	local retries		= 0
	local RETRIES_MAX	= 60
	local RETRY_TIME	= 500

	local function try_register_hook()
		if hooked then
			return
		end

		retries = retries + 1

		local obj = StaticFindObject(hook_path)
		if obj then
			RegisterHook(hook_path, function_callback)
			hooked = true
			return
		end

		if retries < RETRIES_MAX then
			ExecuteWithDelay(RETRY_TIME, try_register_hook)
		else
			logger.warn('Failed to hook NotifyBP_FinishedLevelSequence (timeout)')
		end
	end

	ExecuteWithDelay(RETRY_TIME, try_register_hook)
end



function M.debounce(function_, wait_ms)
	if not wait_ms then
		wait_ms = 500	-- half of second
	end
	local launches_amount = 0

	return function()
		launches_amount = launches_amount + 1

		ExecuteWithDelay(wait_ms, function()
			launches_amount = launches_amount - 1
			if launches_amount > 0 then
				return
			end
			function_()
		end)
	end
end




return M
