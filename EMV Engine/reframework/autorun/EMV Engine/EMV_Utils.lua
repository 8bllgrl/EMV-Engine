--- EMV Engine Utility Module
--- Contains pure Lua functions for table manipulation, math, and string operations.
local M = {}

--- Creates and returns the utility table, injecting necessary core dependencies.
--- @param deps table A table containing required global or SDK references.
--- @param deps.Vector3f userdata The REFramework Vector3f constructor.
--- @param deps.Vector4f userdata The REFramework Vector4f constructor.
--- @param deps.Matrix4x4f userdata The REFramework Matrix4x4f constructor.
--- @param deps.Quaternion userdata The REFramework Quaternion constructor.
--- @param deps.os table The Lua os table (for clock/randomseed).
function M.create(deps)
    local exports = {}
    
    local os = deps.os
    local Vector3f = deps.Vector3f
    local Vector4f = deps.Vector4f
    local Matrix4x4f = deps.Matrix4x4f
    local Quaternion = deps.Quaternion
    
    -- Table and Lua Object Functions --------------------------------------------------------

    --- Inserts a value into an ordered list of strings alphabetically (binary insert).
    function exports.binsert(t, value, fcomp)
        local fcomp = fcomp or function(a, b) return a < b end
        local iStart, iEnd, iMid, iState = 1, #t, 1, 0
        while iStart <= iEnd do
            iMid = math.floor((iStart + iEnd) / 2)
            if fcomp(value, t[iMid]) then
                iEnd = iMid - 1
                iState = 0
            else
                iStart = iMid + 1
                iState = 1
            end
        end
        local pos = iMid + iState
        table.insert(t, pos, value)
        return pos
    end

    --- Extends tbl_a with the contents of tbl_b (only indexed values).
    function exports.extend(tbl_a, tbl_b)
        for _, item in ipairs(tbl_b) do
            table.insert(tbl_a, item)
        end
    end

    --- Gets the next value in a table (useful for non-indexed tables).
    function exports.nextValue(tbl)
        local _, value = next(tbl)
        return value
    end

    --- Tests if a Lua variable can be indexed (handles tables and metatables with __index).
    -- NOTE: This function requires access to getmetatable, which is a Lua global/built-in.
    function exports.can_index(lua_object)
        local mt = getmetatable(lua_object)
        return (not mt and type(lua_object) == "table") or (mt and (not not mt.__index))
    end

    --- Get a random chance. 1/ratio odds (e.g., random(60) is 1/60th chance).
    function exports.random(ratio)
        if ratio == 1 then return true end
        math.randomseed(math.floor(os.clock() * 100))
        return (math.random(1, ratio) == 1)
    end

    --- Get a random number in a range.
    function exports.random_range(start, finish)
        if start >= finish then return start end
        math.randomseed(math.floor(os.clock() * 100))
        return math.random(start, finish)
    end

    --- Get dictionary size and boundary keys.
    function exports.get_table_size(tbl)
        if type(tbl) ~= "table" then return 0 end
        local i, first_key, last_key = 0
        for k, _ in pairs(tbl) do
            i = i + 1
            first_key = first_key or k
            last_key = k
        end
        return i, first_key, last_key
    end

    --- Test if a table is an array (has continuous numerical keys starting at 1).
    function exports.isArray(t)
        local i = 0
        if not t[1] then return false end
        if t["n"] ~= nil then return true end
        for _ in pairs(t) do
            i = i + 1
            if t[i] == nil then return false end
        end
        return true
    end

    --- Removes an element from an ordered table based on a keep_function predicate.
    function exports.arrayRemove(tbl, keep_function)
        local j = 1
        for i = 1, #tbl do
            if keep_function(tbl[i]) then
                if (i ~= j) then
                    tbl[j] = tbl[i]
                    tbl[i] = nil
                end
                j = j + 1
            else
                tbl[i] = nil
            end
        end
        return tbl
    end

    -- NOTE: get_args is highly dependent on REFramework's `sdk.to_managed_object` 
    -- and is better moved later or stubbed out in a separate 'reframework_utils.lua'.
    -- We are skipping it for a pure core utility file.

    --- Converts a std::vector (REFramework type) into a standard Lua table.
    function exports.vector_to_table(std_vector)
        local new_table = {}
        for _, element in ipairs(std_vector) do
            table.insert(new_table, element)
        end
        return new_table
    end

    --- Appends an item to an indexed table only if the item (or its key field) is unique.
    function exports.insert_if_unique(tbl_a, item, key)
        if key ~= nil then
            local comparator = item[key]
            for _, element in ipairs(tbl_a) do
                if element[key] == comparator then
                    return
                end
            end
        else
            for _, element in ipairs(tbl_a) do
                if element == item then
                    return
                end
            end
        end
        table.insert(tbl_a, item)
        return true
    end

    --- Merges two indexed tables, optionally preventing duplicates.
    function exports.merge_indexed_tables(table_a, table_b, is_vec, no_dupes)
        table_a = table_a or {}
        table_b = table_b or {}
        local insert_method = no_dupes and table.insert or exports.insert_if_unique
        if is_vec then
            local new_tbl = {}
            for _, value_a in ipairs(table_a) do insert_method(new_tbl, value_a) end
            for _, value_b in ipairs(table_b) do insert_method(new_tbl, value_b) end
            return new_tbl
        else
            for _, value_b in ipairs(table_b) do insert_method(table_a, value_b) end
            return table_a
        end
    end

    --- Merges two hashed dictionaries (non-indexed tables). table_b merges into table_a.
    function exports.merge_tables(table_a, table_b, no_overwrite)
        table_a = table_a or {}
        table_b = table_b or {}
        if no_overwrite then
            for key_b, value_b in pairs(table_b) do
                if table_a[key_b] == nil then
                    table_a[key_b] = value_b
                end
            end
        else
            for key_b, value_b in pairs(table_b) do table_a[key_b] = value_b end
        end
        return table_a
    end

    --- Creates a recursive deep copy of a table up to a maximum layer depth.
    function exports.deep_copy(tbl, max_layers)
        local loops = {}
        local function recurse(sub_tbl, layer)
            local new_tbl = {}
            for key, value in pairs(sub_tbl or {}) do
                if (not max_layers or layer <= max_layers) and type(value) == "table" then
                    if not loops[value] then
                        loops[value] = exports.merge_tables({}, value)
                        loops[value] = recurse(loops[value], layer + 1)
                    end
                    new_tbl[key] = loops[value]
                else
                    new_tbl[key] = value
                end
            end
            return new_tbl
        end
        return recurse(tbl, 0)
    end

    --- Reverses the order of an indexed table (array).
    function exports.reverse_table(t)
        local new_table = {}
        for i = #t, 1, -1 do
            table.insert(new_table, t[i])
        end
        return new_table
    end

    --- Finds the index of a value in an array, optionally matching by a key field.
    function exports.find_index(tbl, value, key)
        if key ~= nil then
            for i, item in ipairs(tbl) do
                if item[key] == value then
                    return i
                end
            end
        else
            for i, item in ipairs(tbl) do
                if item == value then
                    return i
                end
            end
        end
    end

    --- Checks if a name is unique in a table and appends a number if it is not.
    -- NOTE: This logic assumes a dictionary of names (`names_table[name] = true` pattern)
    function exports.resolve_duplicate_names(names_table, name, key)
        if key then
            local new_names_tbl = {}
            for _, v in pairs(names_table) do
                new_names_tbl[v[key]] = true
            end
            names_table = new_names_tbl
        end
        local ctr = 0
        local new_name = name
        while names_table[new_name] do
            ctr = ctr + 1
            new_name = name .. " (" .. string.format("%01d", ctr) .. ")"
        end
        return new_name
    end

    --- Sorts any table by a given key using quicksort algorithm, maintaining original index if not an array.
    function exports.qsort(tbl, key, ascending)
        if type(tbl) ~= "table" then return end
        local testkey, test = next(tbl)
        if test and test[key] ~= nil then
            local arrayOutput = not exports.isArray(tbl) and {}
            if arrayOutput then
                for key, value in pairs(tbl) do
                    -- NOTE: Assuming recursive usage of deep_copy/merge_tables
                    local copy = exports.merge_tables({ __key = key }, value) 
                    table.insert(arrayOutput, copy)
                end
                tbl = arrayOutput
            end
            
            local sort_func
            if ascending then
                sort_func = function(obj1, obj2) return obj1[key] < obj2[key] end
            else
                sort_func = function(obj1, obj2) return obj1[key] > obj2[key] end
            end
            
            -- Complex type sorting logic retained from original monolith
            if type(test[key]) == "table" then 
                local is_array_type = exports.isArray(test[key])
                if ascending then
                    sort_func = function (obj1, obj2) 
                        return (is_array_type and #obj1[key] or exports.get_table_size(obj1[key])) 
                            < (is_array_type and #obj2[key] or exports.get_table_size(obj2[key]))
                    end
                else
                    sort_func = function (obj1, obj2) 
                        return (is_array_type and #obj1[key] or exports.get_table_size(obj1[key])) 
                            > (is_array_type and #obj2[key] or exports.get_table_size(obj2[key]))
                    end
                end
            end
            
            table.sort(tbl, sort_func)
            return tbl
        end
        return tbl, false
    end

    -- Ordered Pairs (for alphabetical/multitype key sorting) ---------------------------------
    
    local function cmp_multitype(op1, op2)
        local type1, type2 = type(op1), type(op2)
        if type1 ~= type2 then --cmp by type
            return type1 < type2
        elseif type1 == "number" or type1 == "string" then --type2 is equal to type1
            return op1 < op2 --comp by default
        elseif type1 == "boolean" then
            return op1 == true
        else
            -- NOTE: tostring(userdata) returns address, providing a stable sort for objects/userdata
            return tostring(op1) < tostring(op2) 
        end
    end

    local function __genOrderedIndex(t, do_multitype)
        local orderedIndex = {}
        for key in pairs(t) do
            orderedIndex[#orderedIndex + 1] = key
        end
        table.sort(orderedIndex, do_multitype and cmp_multitype)
        return orderedIndex
    end

    -- Note: This implementation relies on a global cache (G_ordered) and `SettingsCache.cache_orderedPairs`.
    -- Since those are managed by `init.lua` and `config_and_constants.lua`, we cannot make this function pure,
    -- and it is better moved to a "Service" module later. However, we'll keep the core logic exported
    -- in case the main script wants to import and run it with its own state.
    
    -- We are temporarily skipping `orderedNext` and `orderedPairs` because they rely too heavily
    -- on external state (`SettingsCache`, `G_ordered`, `uptime`). They are services, not pure utilities.

    -- String Utilities ----------------------------------------------------------------------

    --- Splits a string into parts using a greedy pattern.
    function exports.split(str, separator, in_half)
        local t = {}
        for split_str in string.gmatch(str, "([^" .. separator .. "]" .. "+" .. ")") do
            table.insert(t, split_str)
            if in_half then
                table.insert(t, str:sub(split_str:len() + 1, -1))
                break
            end
        end
        return t
    end

    --- Splits a string into parts using a lazy pattern.
    function exports.Split(s, delimiter)
        local result = {}
        for match in (s .. delimiter):gmatch("(.-)" .. delimiter) do
            table.insert(result, match)
        end
        return result
    end

    -- Math Utilities ------------------------------------------------------------------------

    --- Gets the magnitude (length) of a vector (requires Vector3f/Vector4f to be defined on input).
    function exports.magnitude(vector)
        return math.sqrt(vector.x^2 + vector.y^2 + vector.z^2)
    end

    --- Gets the scale components from a Matrix4x4f.
    function exports.mat4_scale(mat)
        return Vector3f.new(exports.magnitude(mat[0]), exports.magnitude(mat[1]), exports.magnitude(mat[2]))
    end
    
    -- NOTE: write_vec34, read_vec34, read_mat4, write_mat4 rely on REFramework's specific 
    -- read_float/write_float methods on managed objects/ValueTypes, and are therefore 
    -- NOT pure utilities. We will move them to a 'reframework_utils.lua' file later.

    --- Converts Matrix4x4f to Translation, Rotation (Quaternion), and Scale (Vector3f).
    function exports.mat4_to_trs(mat4, as_tbl)
        local pos = mat4[3]:to_vec3()
        local rot = mat4:to_quat()
        local scale = exports.mat4_scale(mat4)
        if as_tbl then return { pos, rot, scale } end
        return pos, rot, scale
    end

    --- Converts Translation, Rotation (Quaternion), and Scale (Vector3f) back to a Matrix4x4f.
    function exports.trs_to_mat4(translation, rotation, scale)
        if type(translation) == "table" then
            translation, rotation, scale = table.unpack(translation)
        end
        local scale_mat = Matrix4x4f.new(
            Vector4f.new(scale.x or 1, 0, 0, 0),
            Vector4f.new(0, scale.y or 1, 0, 0),
            Vector4f.new(0, 0, scale.z or 1, 0),
            Vector4f.new(0, 0, 0, 1)
        )
        local new_mat = rotation:to_mat4() or Matrix4x4f.identity()
        new_mat = new_mat * scale_mat
        new_mat[3] = ((translation and translation.to_vec4 and translation:to_vec4()) or translation) or new_mat[3]
        return new_mat
    end

    --- Limits a variable's range.
    function exports.clamp(val, lowerlimit, upperlimit)
        if val < lowerlimit then
            val = lowerlimit
        elseif val > upperlimit then
            val = upperlimit
        end
        return val
    end

    --- Implements the Smoothstep interpolation function.
    function exports.smoothstep(edge0, edge1, x)
        x = exports.clamp((x - edge0) / (edge1 - edge0), 0.0, 1.0)
        return x * x * (3 - 2 * x)
    end
    
    return exports
end

-- Export the module table (M)
return M
