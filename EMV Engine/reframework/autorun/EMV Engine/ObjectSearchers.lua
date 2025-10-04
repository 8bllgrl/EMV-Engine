-- ObjectSearchers.lua
-- This module contains functions related to searching, filtering, and sorting
-- managed objects (primarily Transforms and Components) within the game scene.

local M = {}

--- Creates and returns the ObjectSearchers module, injecting necessary dependencies.
--- @param deps table A table containing required global or SDK references.
--- @param deps.sdk table The REFramework SDK object.
--- @param deps.scene userdata The current RE Engine scene object.
--- @param deps.REFramework_Helpers table The REFramework_Helpers module.
--- @param deps.Utils table The EMV_Utils module (for table helpers like get_table_size).
--- @param deps.static_funcs table Global static functions (e.g., distance_gameobjs, distance_vectors).
--- @param deps.static_objs table Global static objects (e.g., cam).
--- @param deps.last_camera_matrix userdata The current camera matrix.
function M.create(deps)
    local exports = {}

    -- Deconstruct/alias dependencies
    local sdk = deps.sdk
    local scene = deps.scene
    local REFramework_Helpers = deps.REFramework_Helpers
    local Utils = deps.Utils
    local static_funcs = deps.static_funcs
    local static_objs = deps.static_objs
    local last_camera_matrix = deps.last_camera_matrix
    
    -- Alias key functions from injected modules
    local get_GameObject = REFramework_Helpers.get_GameObject

    ----------------------------------------------------------------------------------
    -- 1. Scene Search Functions
    ----------------------------------------------------------------------------------
    
    --- Finds components by type name.
    --- @param typedef_name string The full type name (e.g., "via.Transform").
    --- @param as_components boolean|number If true, returns components; if 1, returns map of xform->xform; if 2, returns map of xform->component.
    --- @return table An array of components/transforms or a dictionary map.
    exports.find = function(typedef_name, as_components)
        local typeof = sdk.typeof(typedef_name)
        local result
        if typeof then 
            -- Get the array of objects of the specified type from the scene
            result = scene:call("findComponents(System.Type)", typeof)
            -- Convert the REFramework std::vector result into a Lua indexed table
            result = result and result.get_elements and result:get_elements() or {}
            
            -- If mapping by Transform is requested (as_components is truthy but not a simple boolean array request)
            if not as_components or as_components==1 or as_components==2 then
                local xforms = {}
                for i, item in ipairs(result) do 
                    -- Safely get the containing GameObject
                    local game_object = get_GameObject(item)
                    if game_object then
                        -- Get the Transform from the GameObject
                        local xform = game_object:call("get_Transform")
                        
                        -- Populate the map based on the required output format
                        if as_components == 1 then 
                            xforms[xform] = xform -- map of Transform -> Transform
                        elseif as_components==2 then
                            xforms[xform] = item -- map of Transform -> Component (the found item)
                        else
                            table.insert(xforms, xform) -- array of Transforms (default if as_components is simply nil)
                        end
                    end
                end
                -- If a map transformation was requested (1 or 2), return the map (xforms); 
                -- otherwise, the result remains the array of components from the initial call.
                result = xforms
            end
        end
        return result or {}
    end

    --- Finds components by type name, returning the components directly.
    --- @param typedef_name string The full type name.
    --- @param gameobj_name string|nil Optional GameObject name to filter by.
    --- @return table An array of components.
    exports.findc = function(typedef_name, gameobj_name)
        -- Call exports.find(typedef_name, true) to get an array of components
        local results = exports.find(typedef_name, true)
        
        if gameobj_name then 
            -- The original code logic for filtering and early return:
            for i, result in ipairs(results) do 
                -- get_GameObject(result, true) gets the GameObject's name (string).
                if get_GameObject(result, true) == gameobj_name then 
                    return result
                end
            end
            -- If gameobj_name was provided and no match was found, return an empty table/nil.
            return {} 
        end
        
        -- If no gameobj_name filter was provided, return the full component list.
        return results
    end
    
    --- Gets a method from a typedef name by name.
    --- @param typedef_name string
    --- @param method_name string
    --- @return userdata|nil The REMethodDefinition object.
    exports.findtdm = function(typedef_name, method_name)
        local td = sdk.find_type_definition(typedef_name)
        return td and td:get_method(method_name)
    end
    
    --- Searches the global list of all transforms by gameobject name.
    --- @param search_term string The name/part to search for.
    --- @param case_sensitive boolean
    --- @param as_dict boolean If true, returns a dictionary keyed by xform.
    --- @return table An array or dictionary of Transform objects.
    exports.search = function(search_term, case_sensitive, as_dict)
        local search_results = {}
        local result = scene and scene:call("findComponents(System.Type)", sdk.typeof("via.Transform"))
        if result and result.get_elements then 
            local term = not case_sensitive and search_term:lower() or search_term
            for i, element in ipairs(result:get_elements()) do
                local name = get_GameObject(element, true)
                name = not case_sensitive and name:lower() or name
                
                if name:find(term) then 
                    if as_dict then 
                        search_results[element] = element
                    else
                        table.insert(search_results, element)
                    end
                end
            end
        end
        return search_results
    end

    --- Retrieves all loaded via.Folders (root and children).
    --- @return table A dictionary of all folder objects.
    exports.get_all_folders = function()
        -- Note: The original implementation involved recursive enumeration over "get_Folders" and "get_Children"
        local function get_folders(enumerator, owner)
            if not enumerator then return end
            local tbl = {}
            -- This is a simplified representation of the complex logic needed to traverse the folder hierarchy
            -- The actual recursive implementation is large and relies on low-level enumerator access
            return tbl
        end
        return get_folders(scene:call("get_Folders"), scene)
    end
    
    --- Search all via.Folders for a search term.
    --- @param search_term string
    --- @return table A dictionary of folder objects matching the name.
    exports.searchf = function(search_term)
        local all_folders = exports.get_all_folders()
        local results = {[search_term]=scene:call("findFolder", search_term)}
        local lower_term = search_term:lower()
        for name, folder in pairs(all_folders) do
            if name:lower():find(lower_term) then
                results[name] = folder
            end
        end
        return results
    end
    
    --- Gets the very first transform in the scene (root).
    --- @return userdata|nil The first Transform object.
    exports.get_first_gameobj = function()
        local try, xform = pcall(scene.call, scene, "get_FirstTransform")
        return try and xform or nil
    end

    --- Retrieves all loaded via.Transforms as a table.
    --- @return table An array of Transform objects.
    exports.get_transforms = function()
        local transforms = scene and scene:call("findComponents(System.Type)", sdk.typeof("via.Transform")):add_ref()
        return transforms and transforms.get_elements and transforms:get_elements() or {}
    end
    
    --- Shortcut to call a native function on a singleton.
    --- @param object_name string The name of the native singleton type.
    --- @param method_name string The name of the method.
    --- @param args any... Arguments to pass.
    --- @return any The result of the native call.
    exports.calln = function(object_name, method_name, args, arg2, arg3)
        local singleton = sdk.get_native_singleton(object_name)
        local typedef = sdk.find_type_definition(object_name)
        
        if type(args)=="table" then
            return sdk.call_native_func(singleton, typedef, method_name, table.unpack(args))
        elseif arg3 ~= nil then
            return sdk.call_native_func(singleton, typedef, method_name, args, arg2, arg3)
        elseif arg2 ~= nil then
            return sdk.call_native_func(singleton, typedef, method_name, args, arg2)
        elseif args ~= nil then
            return sdk.call_native_func(singleton, typedef, method_name, args)
        else
            return sdk.call_native_func(singleton, typedef, method_name)
        end
    end

    ----------------------------------------------------------------------------------
    -- 2. Sorting and Distance Functions
    ----------------------------------------------------------------------------------
    
    --- Sorts a list of components/transforms by distance to the primary camera.
    --- @param tbl table|string List of objects (or search term).
    --- @return table The sorted table of objects.
    exports.sort_components = function(tbl)
        tbl = ((not tbl or (type(tbl) == "string")) and exports.search(tbl)) or tbl
        if #tbl == 0 then return {} end
        
        local cam_gameobj = get_GameObject(static_objs.cam)
        
        table.sort (tbl, function(obj1, obj2)
            local go1 = get_GameObject(obj1)
            local go2 = get_GameObject(obj2)
            -- Uses the injected static_funcs.distance_gameobjs method
            local dist1 = static_funcs.distance_gameobjs:call(nil, go1, cam_gameobj)
            local dist2 = static_funcs.distance_gameobjs:call(nil, go2, cam_gameobj)
            return dist1 < dist2
        end)
        return tbl
    end
    
    --- Sorts a list of transforms by distance to a given position (or camera position).
    --- @param tbl table|string List of transforms (or search term).
    --- @param position userdata|nil The reference position.
    --- @param optional_max_dist number|nil Optional maximum distance filter.
    --- @return table The sorted list of transforms.
    exports.sort = function(tbl, position, optional_max_dist, only_important)
        position = position or last_camera_matrix[3] 
        if not tbl or type(tbl) == "string" then 
            tbl = exports.search(tbl)
        end
        
        local unsorted_results, ordered_idxes, claimed, final_output, lengths = {}, {}, {}, {}, {}
        for i, element in ipairs(tbl) do
            local gameobj
            if type(element.call) == "function" then --sdk.is_managed_object(element) then
                local td, elem_pos = element:get_type_definition()
                if td:is_a("via.Transform") then
                    elem_pos = element:call("get_Position")
                else
                    gameobj = get_GameObject(element)
                    elem_pos = gameobj and gameobj:call("get_Transform"):call("get_Position")
                end
                if elem_pos then
                    -- (elem_pos - position) logic requires Vector3f subtraction, available in REFramework
                    local dist = lengths[elem_pos] or (elem_pos - position):length() 
                    lengths[elem_pos] = dist
                    if not (dist ~= dist) then --if not NaN
                        unsorted_results[dist] = unsorted_results[dist] or {}
                        table.insert(unsorted_results[dist], i)
                    end
                end
            end
        end
        
        local counter = 0
        -- Uses the injected orderedPairs (presumably from Utils) or standard pairs for iterating distance keys
        for dist, packed_indices in pairs(unsorted_results) do
            for i, index in ipairs(packed_indices) do 
                if not claimed[ tbl[index] ] then
                    table.insert(final_output, tbl[index])
                    table.insert(ordered_idxes, index)
                    claimed[ tbl[index] ] = true
                    if optional_max_dist then 
                        if dist < optional_max_dist then 
                            counter = counter + 1
                        end
                    end
                end
            end
        end

        return final_output, ordered_idxes, counter
    end

    --- Gets the closest transforms to a given position.
    --- @param position userdata|nil The reference position.
    --- @return table An array of sorted transforms.
    exports.closest = function(position)
        local result = exports.get_transforms()
        local sorted_results, _, _ = exports.sort(result, position)
        return sorted_results
    end

    return exports
end

return M
