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
Prefer using "logger.inspect()", it call this if needed.
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
Prefer using "logger.inspect()", it call this if needed.
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
			PathName	= M.inspect__get__PathName(ue_obj),
			ObjectName	= M.inspect__get__ObjectName(ue_obj),
			DisplayName	= M.inspect__get__DisplayName(ue_obj),
			Class		= M.inspect__get__Class(ue_obj),
			ClassName	= M.inspect__get__ClassName(ue_obj),
		}
	end)

	if not success then
		return nil
	end
	return result
end



-- returns like  "/Game/Art/BG/WorldMap/Dungeon_P/Matrix_XI.Matrix_XI:PersistentLevel.CH_P_EVE_01_Blueprint_C_2147482121.Mesh_Face.MI_EyeRefractive1_Inst_2147478815"
function M.inspect__get__PathName(ue_obj)
	return kismet_lib:GetPathName(ue_obj):ToString()
end

-- returns like  "MI_EyeRefractive1_Inst_2147478815"
function M.inspect__get__ObjectName(ue_obj)
	return kismet_lib:GetObjectName(ue_obj):ToString()
end

-- returns like  "MI_EyeRefractive1_Inst_2147478815",  often same as "ObjectName"
function M.inspect__get__DisplayName(ue_obj)
	return kismet_lib:GetDisplayName(ue_obj):ToString()
end

-- returns like  "UClass: 00000002456C6758"
function M.inspect__get__Class(ue_obj)
	return tostring(ue_obj:GetClass())
end

-- returns like  "MaterialInstanceDynamic",  "SkeletalMeshComponent"
function M.inspect__get__ClassName(ue_obj)
	return kismet_lib:GetObjectName(ue_obj:GetClass()):ToString()
end



function M.is_fname_userdata(value)
	return tostring(value):find('FNameUserdata')
end



--[[
Blueprints are lazy-loaded, so may be not available on mod load.
]]
function M.register_blueprint_hook(hook_path, function_callback, retries_max)
	if retries_max == nil then
		retries_max = 60
	end
	local retries		= 0
	local RETRY_TIME	= 500

	local function try_register_hook()
		retries = retries + 1

		--[[
		Tried doing:
			local obj = StaticFindObject(hook_path)
			if obj then
		But it still could lead to error.
		]]
		local success, result = pcall(function()
			RegisterHook(hook_path, function_callback)
		end)

		if success then
			return
		end
		logger.warn('expected error setting hook', hook_path, result)

		if retries < retries_max then
			ExecuteWithDelay(RETRY_TIME, try_register_hook)
		else
			logger.warn(('Failed to hook %s (timeout)'):format(hook_path))
		end
	end

	-- ExecuteWithDelay(RETRY_TIME, try_register_hook)
	try_register_hook()
		-- do it first time in sync bc in rare cases GC can delete loaded classes,
		-- so functions we are hooking may not exist
end



--[[
Typical func for frontend development -
	wait "wait_ms" then execute passed "function_".
If this func was called another time(s) during "wait_ms" -
	launch of first functions is skipped, "wait_ms" is reset,
	only last called "function_" is launched.
]]
function M.debounce(function_, wait_ms)
	if not wait_ms then
		wait_ms = 500	-- half of second
	end
	local launches_amount = 0

	return function(...)
		local func_args	= table.pack(...)
		launches_amount	= launches_amount + 1

		ExecuteWithDelay(wait_ms, function()
			launches_amount = launches_amount - 1
			if launches_amount > 0 then
				return
			end
			function_(table.unpack(func_args))
		end)
	end
end



--[[
Fixes "UEHelpers.FindOrAddFName", bc it doesn't account "None_32", "None_35", etc. as "None".
]]
function M.FindOrAddFName(name)
    local fname				= FName(name, EFindName.FNAME_Find)
    local fname_not_found	= (fname:ToString() == 'None') or (fname:ToString():match('^None_'))
    if fname_not_found then
        fname = FName(name, EFindName.FNAME_Add)
    end
    return fname
end



return M
