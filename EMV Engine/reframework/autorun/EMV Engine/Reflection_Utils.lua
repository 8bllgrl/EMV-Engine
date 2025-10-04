-- Reflection_Utils.lua
-- This module contains functions for querying and retrieving metadata (fields, methods, names)
-- from REFramework TypeDefinitions and managed objects.

local M = {}

--- Creates and returns the Reflection_Utils module.
--- @param deps table A table containing required core dependencies.
--- @param deps.sdk table The REFramework SDK object.
--- @param deps.REFramework_Helpers table The REFramework_Helpers module (for utility checks).
--- @param deps.metadata_methods table Global cache for reflection data (from init.lua).
--- @param deps.get_enum function Global function to retrieve enum definitions.
--- @param deps.misc_vars table Global miscellaneous state variables (for skip_props).
--- @param deps.get_GameObject function Global wrapper for component:get_GameObject().
--- @param deps.create_REMgdObj function Global factory for creating REMgdObj wrappers.
--- @param deps.hashing_method function Global function to hash strings (e.g., via.murmur_hash).
--- @param deps.add_pfb_to_cache function Global function to cache prefabs.
--- @param deps.log table Global log object.
function M.create(deps)
    local exports = {}

    -- Deconstruct core dependencies
    local sdk = deps.sdk
    -- PATCH: Ensure metadata_methods is not nil, preventing the runtime error when accessing it as an upvalue/local.
    local metadata_methods = deps.metadata_methods or {}
    local REFramework_Helpers = deps.REFramework_Helpers
    local get_enum = deps.get_enum
    local misc_vars = deps.misc_vars
    
    -- Deconstruct helper functions/services defined in init.lua
    local get_GameObject = REFramework_Helpers.get_GameObject
    local create_REMgdObj = deps.create_REMgdObj
    local hashing_method = deps.hashing_method
    local add_pfb_to_cache = deps.add_pfb_to_cache
    local log = deps.log
    
    -- Aliases to avoid excessive table lookups (extracted from init.lua locals)
    local next = next
    local pcall = pcall
    local tostring = tostring
    local pairs = pairs
    local table = table
    
    ----------------------------------------------------------------------------------
    -- 1. Metadata Collection
    ----------------------------------------------------------------------------------

    --- Collect and return all applicable fields, methods, counts etc from a managed object 
    --- and store them in a dictionary.
    --- @param typedef userdata The RETypeDefinition to inspect.
    --- @return table The cached property data table.
    exports.get_fields_and_methods = function(typedef)
        
        local td_name = typedef:get_full_name()
        
        -- Check cache first. This line relies on metadata_methods being non-nil.
        if metadata_methods[td_name] then
            return metadata_methods[td_name]
        end

        local propdata = {
            methods = {},
            method_names = {},
            method_full_names = {},
            functions = {},
            fields = {},
            field_names = {},
            clean_field_names = {},
            getters = {},
            setters = {},
            counts = {},
            simple_methods = {},
        }
        
        local td = typedef
        local unique_methods = {}
        while td ~= nil do
            for i, field in ipairs(td:get_fields()) do 
                local field_name = field:get_name()
                if not propdata.fields[field_name] then
                    table.insert(propdata.field_names, field_name)
                    propdata.fields[field_name] = field
                    -- Handles generic field names like <MyField>k__BackingField
                    propdata.clean_field_names[(field_name:match("%<(.+)%>") or field_name):lower()] = i
                end
            end
            local type_unique_methods = {}
            for i, method in ipairs(td:get_methods()) do 
                local param_types = method:get_param_types()
                local method_name = method:get_name()
                
                local method_full_name = method:get_name() .. "("
                for i, param_type in ipairs(param_types) do
                    method_full_name = method_full_name .. (((i ~= 1) and " ") or "") .. param_type:get_full_name() .. (((i ~= #param_types) and ",") or "")
                end
                method_full_name = method_full_name .. ")"
                
                local no_dot_name = method_name:gsub("%.", "")
                local type_unique_name = no_dot_name 
                local ctr = 0
                while type_unique_methods[type_unique_name] do
                    ctr = ctr + 1
                    type_unique_name = no_dot_name .. ctr
                end
                
                type_unique_methods[type_unique_name] = method
                local unique_name = type_unique_name
                if unique_methods[unique_name] then
                    unique_name = unique_name .. "__" .. td:get_name()
                end
                
                unique_methods[unique_name] = method
                propdata.methods[unique_name] = method
                table.insert(propdata.method_names, unique_name)
                propdata.method_full_names[unique_name] = method_full_name
                
                if not propdata.clean_field_names[unique_name:lower()] then
                    propdata.functions[unique_name] =
                        function(obj, args)
                            if args then 
                                return obj:call(method_full_name, table.unpack(args))
                            end
                            return obj:call(method_full_name)
                        end
                    -- Check for Get*Count/Num methods (used for property access to arrays)
                    if method:get_num_params() == 0 and (method_name:find("[Gg]et") == 1 or method_name:find("[Hh]as") == 1) then 
                        local found_idx = method_name:find("Count") or method_name:find("Num")
                        local found_idx = found_idx and ((found_idx == method_name:len()-4) or (found_idx == method_name:len()-2)) and found_idx
                        if found_idx then
                            -- Store count method keyed by the property name (e.g., 'get_JointCount' stored as 'Joint')
                            propdata.counts[method_name:sub(1, found_idx - 1):sub(4, -1)] = method 
                        end
                    end
                end
            end
            td = td:get_parent_type() -- Move up the inheritance chain
        end
        
        -- Categorize into Getters/Setters/Simple Methods
        for i, name in ipairs(propdata.method_names) do 
            local method = propdata.methods[name]
            local lower_name = name:lower()
            local short_name = name:sub(4, -1)
            local num_params = method:get_num_params()
            local ret_typename = method:get_return_type():get_full_name()
            
            if num_params == 0 and (ret_typename == "System.Void" or (ret_typename == "System.Boolean" and lower_name:find("set")==1)) and not name:find("__") then
                propdata.simple_methods[name] = method
            elseif name:len() > 5 then
                if (num_params == 0 or num_params == 1) and (lower_name:find("get") == 1 or lower_name:find("has") == 1) then 
                    if num_params == 1 then 
                        if method:get_param_types()[1]:get_full_name():find("Int") then
                            -- Check if this getter corresponds to an array-like access property
                            for count_name, count_method in pairs(propdata.counts) do 
                                if short_name:find(count_name) or count_name:find(short_name) or short_name:find(count_name:gsub("%_", "")) then 
                                    propdata.counts[short_name] = propdata.counts[short_name] or count_method
                                    if count_name:find("[Gg]et_?" .. short_name .. "[CN][ou][um]") then
                                        propdata.counts[short_name] = count_method
                                        break
                                    end
                                end
                            end
                            propdata.getters[short_name] = method
                        end
                    else
                        propdata.getters[short_name] = method
                    end
                elseif (num_params == 1 or num_params == 2) and lower_name:find("set") == 1 then 
                    if num_params == 2 then 
                        if method:get_param_types()[1]:get_full_name():find("Int") then 
                            propdata.setters[short_name] = method
                        end
                    else
                        propdata.setters[short_name] = method
                    end
                end
            end
        end

        -- Call name and item-type resolution methods (which depend on this propdata result)
        propdata.name_methods = exports.get_name_methods(typedef, propdata)
        propdata.item_type = REFramework_Helpers.evaluate_array_typedef_name(typedef, td_name)
        if propdata.item_type and propdata.item_type:get_full_name() ~= "" then 
            propdata.item_name_methods = exports.get_name_methods(propdata.item_type, exports.get_fields_and_methods(propdata.item_type), true)
        end
        
        metadata_methods[td_name] = propdata
        return propdata
    end

    ----------------------------------------------------------------------------------
    -- 2. Name Resolution
    ----------------------------------------------------------------------------------

    --- Scans a typedef for the best field/method to use as a display name (Name, Path, ID, etc.). 
    --- @param ret_type userdata The RETypeDefinition to inspect.
    --- @param propdata table Cached result from get_fields_and_methods.
    --- @param do_items boolean If true, searches for item-level names in array types.
    --- @return table An indexed table of usable name method/field names (strings).
    exports.get_name_methods = function(ret_type, propdata, do_items)
        
        local ret_typename = ret_type:get_full_name()
        propdata = propdata or metadata_methods[ret_typename] or exports.get_fields_and_methods(ret_type)
        local search_terms = {"Name", "Path", "Comment", "Message", "Title", "Description", "Id", "Index"} 
        local name_methods = (not do_items and propdata.name_methods) or (do_items and propdata.item_name_methods)
        local num_strings = 0
        
        if not name_methods then
            name_methods = {}
            local uniques = {}
            -- Loop through search terms to prioritize which fields/methods are searched first
            for i, search_term in ipairs(search_terms) do
                -- Search Fields
                for f, field_name in pairs(propdata.field_names) do 
                    if not uniques[field_name] then
                        local field = propdata.fields[field_name]
                        local ftype = field:get_type()
                        if ftype then
                            local is_resource = ftype:get_name():find("Holder$")
                            local is_str = ftype:is_a("System.String")
                            local is_guid = ftype:is_a("System.Guid")
                            local is_enum = i==#search_terms and ftype:is_a("System.Enum")
                            
                            if i==1 and is_str then num_strings = num_strings + 1 end
                            
                            if (is_enum or is_resource or (is_str and ((field_name:find(search_term) and field_name:sub(-search_term:len()) == search_term))) or (is_guid and field_name:find(search_term))) then
                                uniques[field_name] = field
                                table.insert(name_methods, field_name)
                                if i == #search_terms then goto exit end
                            end
                        end
                    end     
                end
                
                -- Search Methods (Getters)
                for m, name in pairs(propdata.method_names) do
                    local method = propdata.methods[name]
                    if not uniques[name] and method:get_num_params() == 0 then
                        local mtype = method:get_return_type()
                        local is_resource = mtype:get_name():find("Holder$")
                        local is_str = mtype:is_a("System.String")
                        local is_guid = mtype:is_a("System.Guid")
                        local is_enum = i==#search_terms and mtype:is_a("System.Enum")
                        
                        if i==1 and is_str then num_strings = num_strings + 1 end
                        
                        -- Must be a getter or "has" method
                        if (name:find("[Gg]et") == 1 or name:find("[Hh]as") == 1) and (
                            is_enum or is_resource or (is_str and (name:find(search_term) and name:sub(-search_term:len()) == search_term)) or (is_guid and name:find(search_term))
                        ) then
                            uniques[name] = method
                            table.insert(name_methods, name)
                            if i == #search_terms then goto exit end
                        end
                    end
                end
            end
            ::exit::
        end
        
        if do_items then 
            propdata.item_name_methods = name_methods
        else
            propdata.name_methods = name_methods
        end
        
        return name_methods
    end

    
    ----------------------------------------------------------------------------------
    -- 3. Final Name Retrieval
    ----------------------------------------------------------------------------------

    --- Get the most appropriate name for a managed object element.
    --- @param m_obj userdata The managed object instance.
    --- @param o_tbl table The REMgdObj wrapper object for m_obj (may contain cached data).
    --- @param idx number Optional index for array element.
    --- @param only_relevant boolean Only search relevant name properties (vs fallback ToStrings).
    --- @param skip_if_fail boolean Skip creating the full REMgdObj data cache if it fails.
    --- @return string The resolved name string.
    exports.get_mgd_obj_name = function(m_obj, o_tbl, idx, only_relevant, skip_if_fail)
        
        if type(m_obj)~="userdata" or not m_obj.get_type_definition or not REFramework_Helpers.is_valid_obj(m_obj) then 
            return "" 
        end
        
        -- Create REMgdObj wrapper if it doesn't exist and we aren't explicitly skipping it
        o_tbl = o_tbl or (m_obj.get_type_definition and not skip_if_fail and create_REMgdObj(m_obj))
        if not o_tbl then 
            return m_obj:get_type_definition():get_full_name() 
        end
        
        local typedef, name = o_tbl.type or m_obj:get_type_definition(), nil
        if not typedef then return tostring(m_obj) end
        
        local td_name = typedef:get_full_name()

        -- Special casing for Arrays (which need to show the contained type)
        if typedef:is_a("System.Array") or td_name:match("<(.+)>") then
            name = td_name:match("<(.+)>")
            name = name or (o_tbl.name_full and o_tbl.name_full:gsub("%[%]", "")) or td_name:gsub("%[%]", "")
        
        -- Special casing for primitive/lua-converted types
        elseif (type(m_obj) == "number") or (type(m_obj) == "boolean") or not REFramework_Helpers.is_valid_obj(m_obj) then
            name = typedef:get_name()

        -- Special casing for Components/GameObjects
        elseif typedef:is_a("via.Component") then 
            name = td_name .. " (" .. get_GameObject(m_obj, true) .. ")"
        elseif typedef:is_a("via.GameObject") then
            local try, go_name = pcall(m_obj.call, m_obj, "get_Name")
            name = try and go_name
        
        -- Use resolved name methods (the preferred way)
        elseif o_tbl.item_name_methods or o_tbl.name_methods then
            local fields = o_tbl.fields or (o_tbl.item_type and metadata_methods[o_tbl.item_type:get_full_name()].fields)
            local methods = o_tbl.methods or (o_tbl.item_type and metadata_methods[o_tbl.item_type:get_full_name()].methods)
            
            for i, fm_name in ipairs(o_tbl.item_name_methods or o_tbl.name_methods) do
                local try, resolved_value
                
                if fields and fields[fm_name] then
                    try, resolved_value = pcall(m_obj.get_field, m_obj, fm_name)
                else
                    try, resolved_value = pcall(sdk.call_object_func, m_obj, fm_name)
                end

                resolved_value = try and (resolved_value ~= "") and resolved_value
                
                if resolved_value ~= nil then 
                    local ret_type = (fields and fields[fm_name] and fields[fm_name]:get_type()) 
                        or (methods and methods[fm_name] and methods[fm_name]:get_return_type())
                    
                    if type(resolved_value) == "number" then
                        -- Handle enums
                        if ret_type then
                            local enum, value_to_list_order, enum_names = get_enum(ret_type)
                            name = enum_names[value_to_list_order[resolved_value]]
                        end
                    
                    elseif type(resolved_value) == "userdata" and type(resolved_value.add_ref)=="function" then 
                        -- Handle Resources and GUIDs
                        if resolved_value:get_type_definition():is_a("System.Guid") then
                            -- This relies on the global 'guid_method' from static_funcs
                            name = resolved_value and sdk.find_type_definition("via.gui.message"):get_method("get"):call(nil, m_obj)
                        else
                            -- Assume it's a resource (ResourceHolder)
                            name = resolved_value:call("ToString()"):match("^.+%[@?(.+)%]") 
                        end
                        
                        if type(name)=="string" and name:find("%.pfb$") and add_pfb_to_cache then 
                            add_pfb_to_cache(name)
                        end
                    end
                    
                    name = name or (type(resolved_value)=="string" and resolved_value)
                    
                    if type(name)=="string" then break end
                end
            end
        end
        
        -- Fallback to ToString() if no name was found
        if not name and not only_relevant then 
            local try_tostr, to_str = pcall(sdk.call_object_func, m_obj, "ToString()")
            name = try_tostr and to_str
            name = name or typedef:get_name()
        end
        
        return name or ""
    end
    
    return exports
end

return M
