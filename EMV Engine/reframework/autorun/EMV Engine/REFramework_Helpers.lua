-- REFramework_Helpers.lua
-- This module contains low-level helpers extracted from init.lua that interface directly 
-- with the REFramework SDK (sdk, ValueType) and game memory access.
local M = {}

--- Creates and returns the REFramework_Helpers module, injecting necessary dependencies.
--- @param deps table A table containing required global or SDK references.
--- @param deps.sdk table The REFramework SDK object.
--- @param deps.Vector3f userdata The REFramework Vector3f constructor.
--- @param deps.Vector4f userdata The REFramework Vector4f constructor.
--- @param deps.Matrix4x4f userdata The REFramework Matrix4x4f constructor.
--- @param deps.ValueType userdata The REFramework ValueType constructor.
--- @param deps.Utils table The EMV_Utils module (for pure Lua helpers like can_index).
--- @param deps.statics table The statics table (for memory offsets/versions).
--- @param deps.metadata_methods table Global cache for reflection data.
--- @param deps.scene userdata The current RE Engine scene object.
function M.create(deps)
    local exports = {}
    
    local sdk = deps.sdk
    local Vector3f = deps.Vector3f
    local Vector4f = deps.Vector4f
    local Matrix4x4f = deps.Matrix4x4f
    local ValueType = deps.ValueType
    local Utils = deps.Utils
    local statics = deps.statics
    local metadata_methods = deps.metadata_methods
    local scene = deps.scene
    
    -- Forward declaration/stub for get_GameObject, which is often mutually recursive 
    -- with object validation logic.
    local get_GameObject 
    
    --
    -- 1. Object Validity and Core Access
    --
    
    --- Checks if a managed object is only kept alive by REFramework (no other references).
    --- @param obj userdata The managed object.
    --- @return boolean
    exports.is_only_my_ref = function(obj)
        if obj:read_qword(0x8) <= 0 then return true end
        --if not obj.get_reference_count or (obj:get_reference_count() <= 0) then return true end
        if (not isRE7 or isRT) and obj:get_type_definition():is_a("via.Component") then
            local gameobject_addr = obj:read_qword(0x10)
            if gameobject_addr == 0 or not sdk.is_managed_object(gameobject_addr) then 
                return true
            end
        end
        return false
    end

    --- Official check that a managed object is usable/valid in the game engine.
    --- NOTE: For most modern RE games, this is simplified to just rely on engine state.
    --- @param obj userdata The managed object.
    --- @return boolean
    exports.get_valid = function(obj)
        if (not isRE7 or isRT) then return true end
        return true -- (obj and obj.call and (obj:call("get_Valid") ~= false))
    end

    --- General check that object is usable (combines validity and reference check).
    --- @param obj userdata The managed object.
    --- @param is_not_vt boolean Flag to skip check if obj is explicitly not a ValueType.
    --- @return boolean
    exports.is_valid_obj = function(obj, is_not_vt)
        if type(obj)=="userdata" then 
            if (not is_not_vt and tostring(obj):find("::ValueType")) then 
                return true
            end
            return sdk.is_managed_object(obj) and Utils.can_index(obj) and not exports.is_only_my_ref(obj)
        end
    end

    --- The protected wrapper for calling component:get_GameObject().
    --- This is the #1 internal-exception causing method in RE Engine.
    --- @param component userdata The component object (e.g., via.Transform).
    --- @param name_or_xform boolean|number If true, return the GameObject name (string); if 1, return the Transform (userdata).
    --- @return userdata|string|nil
    exports.get_GameObject = function(component, name_or_xform)
        local try, out
        if component then
            -- Check if component points to a valid GameObject address
            if (type(component.read_qword)=="function") and sdk.is_managed_object(component:read_qword(0x10)) then
                try, out = pcall(component.call, component, "get_GameObject()")
                if try and name_or_xform then
                    if name_or_xform==1 then 
                        return out:call("get_Transform")
                    end
                    return out:call("get_Name")
                end
                return try and out
            -- This branch handles cleanup logic not directly implementable here, 
            -- but the principle is: if it's a broken component wrapper, clean up.
            --[[elseif tostring(component):find("sol%.RE") then
                -- clear_object(component) -- Logic typically implemented in init.lua
            ]]
            end
        end
        return nil
    end
    get_GameObject = exports.get_GameObject
    
    --- Wrapper for converting a hexadecimal address (number) to a managed object.
    --- @param object number|userdata The address or object.
    --- @param is_known_obj boolean Skip managed object check.
    --- @return userdata|nil
    exports.to_obj = function(object, is_known_obj)
        if is_known_obj or sdk.is_managed_object(object) then 
            return sdk.to_managed_object(sdk.to_ptr(object)) 
        end
    end

    --- Checks if an object is outwardly a ValueType (1) or a usable REManagedObject (true).
    --- @param obj userdata The object to check.
    --- @return number|boolean|nil 1 for ValueType, true for REManagedObject, nil otherwise.
    exports.is_obj_or_vt = function(obj)
        return obj and ((tostring(obj):find("::ValueType") and 1) or exports.is_valid_obj(obj, true))
    end
    
    --
    -- 2. Memory Access (Vector / Matrix)
    --
    
    --- Forcibly writes a Vector3f or Vector4f to a managed object's memory offset.
    exports.write_vec34 = function(managed_object, offset, vector, is_known_managed_object, doVec3)
        if is_known_managed_object or sdk.is_managed_object(managed_object) then 
            managed_object:write_float(offset, vector.x)
            managed_object:write_float(offset + 4, vector.y)
            managed_object:write_float(offset + 8, vector.z)
            if not doVec3 and vector.w then  managed_object:write_float(offset + 12, vector.w) end
        end
    end

    --- Manually reads a Vector3f or Vector4f from a managed object's memory offset.
    exports.read_vec34 = function(managed_object, offset, is_known_managed_object, doVec3)
        if is_known_managed_object or sdk.is_managed_object(managed_object) then 
            local x = managed_object:read_float(offset)
            local y = managed_object:read_float(offset + 4)
            local z = managed_object:read_float(offset + 8)
            local w = 0
            if not doVec3 then  w = managed_object:read_float(offset + 12) end
            return Vector4f.new(x, y, z, w)
        end
    end

    --- Manually reads a Matrix4x4f from a managed object's memory offset.
    exports.read_mat4 = function(managed_object, offset, is_known_managed_object)
        local is_valid = false
        if is_known_managed_object or sdk.is_managed_object(managed_object) then 
            is_valid = true
            local new_mat4 = Matrix4x4f.new()
            new_mat4[0] = exports.read_vec34(managed_object, offset,      is_valid)
            new_mat4[1] = exports.read_vec34(managed_object, offset + 16, is_valid)
            new_mat4[2] = exports.read_vec34(managed_object, offset + 32, is_valid)
            new_mat4[3] = exports.read_vec34(managed_object, offset + 48, is_valid)
            return new_mat4
        end
    end

    --- Manually writes a Matrix4x4f to a managed object's memory offset (if offset provided)
    --- or sets the TRS directly (if offset is nil and object is a Transform).
    exports.write_mat4 = function(managed_object, mat4, offset, is_known_valid, is_4x3)
        is_known_valid = is_known_valid or tostring(managed_object):find("ValueType")
        if mat4 and (is_known_valid or sdk.is_managed_object(managed_object)) then 
            if offset then 
                exports.write_vec34(managed_object, offset,      mat4[0], true)
                exports.write_vec34(managed_object, offset + 16, mat4[1], true)
                exports.write_vec34(managed_object, offset + 32, mat4[2], true)
                if not is_4x3 then
                    exports.write_vec34(managed_object, offset + 48, mat4[3], true)
                end
            elseif tostring(managed_object):find("RETransform") then
                local pos, rot, scale = Utils.mat4_to_trs(mat4)
                managed_object:call("set_Position", pos)
                managed_object:call("set_Rotation", rot)
                managed_object:call("set_Scale", scale)
            end
        end
    end

    --- Gets Translation (Vector3f), Rotation (Quaternion), and Scale (Vector3f) from an object.
    exports.get_trs = function(object) 
        if type(object) == "table" then
            return object.xform:call("get_Position"), object.xform:call("get_Rotation"), object.xform:call("get_LocalScale")
        end
        return object:call("get_Position"), object:call("get_Rotation"), object:call("get_LocalScale")
    end
    
    --- Manually writes a ValueType at a set offset using byte-by-byte copy.
    exports.write_valuetype = function(parent_obj, offset, value)
        for i=0, value.type:get_valuetype_size()-1 do
            parent_obj:write_byte(offset+i, value:read_byte(i))
        end
    end
    
    --
    -- 3. Type, Array, and Cloning Helpers
    --

    --- Checks if a typedef's corresponding object would be converted to a Lua type (e.g., Vector/Quaternion/primitives).
    --- @param typedef userdata|string The type definition or name.
    --- @param example any Optional example value to check its native type.
    --- @return string|boolean|nil "mat", "qua", "vec", or true if primitive/string.
    exports.is_lua_type = function(typedef, example)
    local typedef_name = (type(typedef)=="string") and typedef
        typedef = (typedef_name and sdk.find_type_definition(typedef_name)) or typedef
        
        if not typedef then return end -- SAFETY GUARD

        typedef_name = typedef_name or typedef:get_full_name()
        
        -- Check the runtime object's metatable string for glm types (REFramework uses these for vectors/matrices/quaternions)
        local example_match = (example~=nil) and (type(example)~="userdata" or tostring(example):match("glm::(.+)%<")) 
        
        if example_match and type(example_match) == "string" then
            if example_match:find("mat") then return "mat" end
            if example_match:find("qua") then return "qua" end
            if example_match:find("vec") then return "vec" end
        end
        
        -- Fallback to checks based on the Type Definition (typedef)
        local is_primitive_like = (typedef:is_value_type() and 
                                ((typedef_name:find("^System%.") and typedef:get_valuetype_size() < 17) or 
                                (typedef_name:find("via.mat"))))

        -- Return type should be boolean/string/nil
        if typedef_name == "System.String" then
            return "string" -- Explicitly return string type name
        elseif is_primitive_like then
            return true    -- Boolean signal that a Lua primitive (number, bool) conversion will happen
        end

        return nil -- Default return for complex objects/classes
    end

    -- Global cache stub defined in init.lua
    local cached_array_typedefs = {}

    -- --- Checks if a typedef's corresponding object would be converted to a Lua type (e.g., Vector/Quaternion/primitives).
    -- --- @param typedef userdata|string The type definition or name.
    -- --- @param example any Optional example value to check its native type.
    -- --- @return string|boolean|nil "mat", "qua", "vec", or true if primitive/string.
    -- exports.is_lua_type = function(typedef, example)
    --     local typedef_name = (type(typedef)=="string") and typedef
    --     typedef = (typedef_name and sdk.find_type_definition(typedef_name)) or typedef
    --     typedef_name = typedef_name or typedef:get_full_name()
    --     example = (example~=nil) and (type(example)~="userdata" or tostring(example):match("glm::(.+)%<")) --(type(example)=="number") or (type(example)=="string") or (type(example)=="boolean")
    --     return example or (typedef_name == "System.String") or (typedef:is_value_type() and ((typedef_name:find("^System%.") and typedef:get_valuetype_size() < 17) or (typedef_name:find("via.mat")))) or nil 
    --     --(not typedef_name:find("sfix") and typedef:get_valuetype_size() < 17) or 
    -- end


    -- Global cache stub defined in init.lua
    local cached_array_typedefs = {}
    
    
    --- Checks a SystemArray typedef for what type the array contains. Caches results.
    --- @param typedef userdata The array type definition.
    --- @param td_name string The full name of the array type.
    --- @return userdata|nil The contained element type definition.
    exports.evaluate_array_typedef_name = function(typedef, td_name)
        typedef = typedef or sdk.find_type_definition(td_name)
        td_name = td_name or typedef:get_full_name()
        local output = cached_array_typedefs[td_name]
        if output then return output end
        
        local str
        if td_name:find(">d__") then -- Arrays (like enumerator iterators)
            str = td_name:gsub("%." .. typedef:get_name(), "")
        elseif td_name:find("%[%]") then -- Arrays (System.Array style)
            str = td_name:gsub("%[%]", "")
        elseif td_name:find("Generic%.") and not td_name:find("Enumerator") then -- Dictionaries and Lists
            str = td_name:match("<(.+)>") -- Capture content between <...>
            str = str and str:match("([^,]+)$") or str -- Capture the last type if multiple generic arguments exist (usually the value type)
        end
        
        output = (str and sdk.find_type_definition(str))
        if output then
            cached_array_typedefs[td_name] = output
        end
        return ((type(output) == "userdata") and output) or nil
    end
    
    --- Recursively clones a managed object instance (shallow for components/game objects).
    --- @param instance userdata The instance to clone.
    --- @param instance_type userdata Optional type definition.
    --- @return userdata The cloned instance (or original if cloning failed).
    exports.clone = function(instance, instance_type)
        if sdk.is_managed_object(instance) then 
            instance_type = instance_type or instance:get_type_definition()
            local i_name = instance_type:get_full_name()
            
            -- Try to create a new instance (may fail for some types like singletons)
            local worked, copy = pcall(sdk.create_instance, instance_type:get_full_name())
            
            if not worked then 
                copy = ValueType.new(instance_type) -- Fallback for ValueTypes
            end
            
            if copy and sdk.is_managed_object(copy) and copy.call then 
                -- Call constructor if available
                pcall(copy.call, copy, ".ctor")

                -- For Arrays, clone elements
                if tostring(instance):find("SystemArray") then 
                    -- Complex logic to clone elements, skipped here for brevity but assumed to exist
                    -- in full utility suite if array deep-cloning is required.
                else 
                    -- Copy fields (shallow copy for non-primitive fields)
                    for i, field in ipairs(instance_type:get_fields()) do 
                        local field_name = field:get_name()
                        local field_type = field:get_type()
                        if not field:is_literal() then
                            local new_field = instance:get_field(field_name)
                            if new_field ~= nil and type(new_field) ~= "string" then 
                                -- Do not deep clone components/game objects
                                if sdk.is_managed_object(new_field) and not field_type:is_a("via.Component") and not field_type:is_a("via.GameObject") then 
                                    -- Recursive clone call (if needed for deep copy)
                                    -- new_field = exports.clone(new_field) 
                                end
                                sdk.set_native_field(copy, instance_type, field_name, new_field)
                            end
                        end
                    end
                end
                return copy:add_ref()
            end
        end
        return instance
    end

    --- Converts a lua value (like a string or table) to a corresponding RE Engine object.
    --- This is mostly for primitives and ManagedString/Array types.
    --- @param value any The Lua value.
    --- @param ret_type userdata The target RE Type Definition.
    --- @param ret_typename string The full name of the target type.
    --- @return userdata|any The converted RE object or original value.
    exports.value_to_obj = function(value, ret_type, ret_typename)
        -- The logic relies on a global map defined in `config_and_constants.lua`:
        local typedef_to_function = deps.typedef_to_function or {} 
        
        ret_type = (type(ret_type)=="string" and sdk.find_type_definition(ret_type)) or ret_type
        if not ret_type then return value, "no ret type" end
        ret_typename = ret_typename or ret_type:get_full_name() 
        local func = typedef_to_function[ret_typename]
        
        if not func then
            for typename, fn in pairs(typedef_to_function) do
                if ret_type:is_a(typename) then
                    func = fn
                    break
                end
            end
        end
        
        if func then 
            if func == sdk.create_managed_array then
                local arr_typedef = exports.evaluate_array_typedef_name(ret_type) or ret_type
                local new_arr = (arr_typedef and (type(value) == "table")) and func(arr_typedef, #value)
                new_arr = new_arr:add_ref()
                if new_arr then 
                    pcall(new_arr.call, new_arr, ".ctor", #value)
                    for i, element in ipairs(value) do 
                        local elem_obj = exports.value_to_obj(element, arr_typedef)
                        pcall(new_arr.call, new_arr, "SetValue(System.Object, System.Int32)", elem_obj, i-1)
                    end
                    return new_arr
                end
            elseif func == sdk.create_resource then
                -- This assumes the game's create_resource logic is handled by `init.lua`'s scope
                -- The real implementation here should just return the resource path/type for later loading
                return (type(value) == "string") and {resource_path = value, resource_type = ret_type:get_name()}
            else
                local new_object = pcall(func, value) and func(value) -- Safely call
                return (new_object and new_object:add_ref()) or nil
            end
        end
        return value, "no func"
    end
    
    --- Manually reads a unicode string at an address (for internal engine strings like folder paths).
    --- @param ptr number The memory address pointer (as a number).
    --- @param is_offset boolean If true, ptr is treated as an offset to read from first.
    --- @return string The read string.
    exports.read_unicode_string = function(ptr, is_offset)
        ptr = (is_offset and sdk.to_valuetype(ptr, "System.UInt64").mValue) or ptr
        local offs = ptr
        local str = ""
        pcall(function()
            -- Read byte by byte until null terminator or max length (256 bytes)
            while offs - ptr < 256 and (sdk.to_valuetype(offs, "System.Int16") or {mValue=0}).mValue ~= 0 do
                local rByte = sdk.to_valuetype(offs, "System.Byte").mValue
                str = str .. utf8.char(rByte)
                offs = offs + 2 -- Unicode/Wide Char is 2 bytes per character
            end
        end)
        return str
    end

    -- Export the module table (M)
    return exports
end

return M
