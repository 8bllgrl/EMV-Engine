-- Display_Helpers.lua

local M = {}

--- Creates and returns the Display Helpers module.
--- @param deps table A table containing required global, SDK, and utility references.
--- @param deps.sdk table The REFramework SDK object.
--- @param deps.imgui table The REFramework ImGui object.
--- @param deps.draw table The REFramework Draw object.
--- @param deps.Utils table The EMV_Utils module (for pure Lua helpers).
--- @param deps.REFramework_Helpers table The REFramework_Helpers module.
--- @param deps.get_enum function Function to retrieve enum values/names.
--- @param deps.orderedPairs function Custom function for sorting dictionary keys.
--- @param deps.static_funcs table Global static functions (e.g., calc_color).
--- @param deps.statics table Global static constants (e.g., width, height).
--- @param deps.misc_vars table Global miscellaneous state variables.
--- @param deps.SettingsCache table Global settings cache.
--- @param deps.log table Global log object.
--- @param deps.re table Global re object (for msg).
--- @param deps.tics number Current frame count.
--- @param deps.uptime number Current application uptime.
--- @param deps.msg_ids table Cache for message IDs (for msg_safe).
--- @param deps.world_positions table Cache for world position markers.
--- @param deps.last_camera_matrix userdata The current camera matrix.
function M.create(deps)
    local exports = {}

    -- Deconstruct/alias dependencies
    local sdk = deps.sdk
    local imgui = deps.imgui
    local draw = deps.draw
    local Utils = deps.Utils -- From EMV_Utils.lua
    local REFramework_Helpers = deps.REFramework_Helpers
    local get_GameObject = REFramework_Helpers.get_GameObject
    local get_enum = deps.get_enum
    local orderedPairs = deps.orderedPairs
    local log = deps.log
    local re = deps.re
    local tics = deps.tics
    local uptime = deps.uptime
    local msg_ids = deps.msg_ids
    local world_positions = deps.world_positions
    local last_camera_matrix = deps.last_camera_matrix

    local static_funcs = deps.static_funcs
    local statics = deps.statics
    local misc_vars = deps.misc_vars
    local SettingsCache = deps.SettingsCache

    -- Alias other required utility functions (often internal REFramework types)
    local Vector4f = deps.Vector4f

    ----------------------------------------------------------------------------------
    -- 2. Value Formatting (Local Helpers)
    ----------------------------------------------------------------------------------

    --- Format a vector2, vector3, vector4 or Quaternion as text.
    --- @param vector userdata The REFramework vector/quaternion object.
    --- @return string
    local function vector_to_string(vector)
        return vector and ("[" .. vector.x .. ", " .. vector.y
            .. (vector.z and (", " .. vector.z) or "")
            .. (vector.w and (", " .. vector.w) or "") .. "]") or "nil"
    end

    --- Format a matrix4 as text.
    --- @param mat userdata The REFramework Matrix4x4f object.
    --- @param padding string Indentation string.
    --- @return string
    local function mat4_to_string(mat, padding)
        padding = padding or ""
        if mat then
            local transform_string = "\n" .. padding .. "[" .. mat[0].x .. ", " .. mat[0].y .. ", " .. mat[0].z .. ", " .. mat[0].w .. "]\n"
            transform_string = transform_string .. padding .. "[" .. mat[1].x .. ", " .. mat[1].y .. ", " .. mat[1].z .. ", " .. mat[0].w .. "]\n"
            transform_string = transform_string .. padding .. "[" .. mat[2].x .. ", " .. mat[2].y .. ", " .. mat[2].z .. ", " .. mat[0].w .. "]\n"
            return transform_string .. padding .. "[" .. mat[3].x .. ", " .. mat[3].y .. ", " .. mat[3].z .. ", " .. mat[0].w .. "]"
        end
        return "nil"
    end

    --- Format a table of bytes into a string (similar to hex dump).
    --- @param bytes table An indexed table of byte values (numbers 0-255).
    --- @return string
    local function log_bytes(bytes)
        local msg = {""}
        for i, sbyte in ipairs(bytes) do
            if i ~= 1 and (i-1) % 4 == 0 then table.insert(msg, "  ") end
            if i ~= 1 and (i-1) % 16 == 0 then
                local str_msg = {""}
                for b=i-16, i-1 do
                    table.insert(str_msg, string.char(bytes[b]))
                end
                table.insert(msg, "	" .. string.gsub(table.concat(str_msg), "%c", ".") .. "\n")
            end
            table.insert(msg, string.format("%02X ", tostring(sbyte)))
        end
        return table.concat(msg)
    end

    --- Display the bytes of a managed object as text, similar to a hex editor.
    --- @param obj userdata The managed object.
    --- @return string
    local function read_bytes(obj)
        local tab = {}
        local sz = obj:get_type_definition():get_size()
        if sz > 8192 then sz = 8192 end
        for i=1, sz do
            table.insert(tab, obj:read_byte(i-1))
        end
        return "\n" .. log_bytes(tab)
    end

    --- Format all attributes of a method as text.
    --- @param method userdata The REMethodDefinition object.
    --- @param padding string Indentation string.
    --- @return string
    local function log_method(method, padding)
        padding = (padding or "") .. "    "
        local msg = {"\n" .. padding .. method:get_return_type():get_full_name() .. " " .. method:get_name() .. "("}

        local param_types = method:get_param_types()
        local param_names = method:get_param_names()
        for i, param in ipairs(param_names) do
            if i ~= 1 then table.insert(msg, ", ") end
            table.insert(msg, param)
        end
        table.insert(msg, ")\n  "
            .. padding .. "Declaring Type: " .. method:get_declaring_type():get_full_name() .. "\n  "
            .. padding .. "Is Static: " .. tostring(method:is_static())
        )
        if method:get_num_params() > 0 then
            for i, param in ipairs(param_names) do
                table.insert(msg, "\n    " .. padding .. tostring(i) .. ". " .. param_types[i]:get_full_name() .. " " .. param)
            end
        end
        return table.concat(msg)
    end

    --- Format all attributes of a field as text.
    --- @param field userdata The REField object.
    --- @param padding string Indentation string.
    --- @return string
    local function log_field(field, padding)
        padding = (padding or "") .. "    "
        return field:get_type():get_full_name() .. " " .. field:get_name()
            .. "\n" .. padding .. "Declaring Type: " .. field:get_declaring_type():get_full_name()
            .. "\n" .. padding .. "Offset from Base: " .. field:get_offset_from_base()
            .. "\n" .. padding .. "Offset from FieldPtr: " .. field:get_offset_from_fieldptr()
            .. "\n" .. padding .. "Flags: " .. tostring(field:get_flags())
            .. "\n" .. padding .. "Is Static: " .. tostring(field:is_static())
            .. "\n" .. padding .. "Is Literal: " .. tostring(field:is_literal())
    end

    --- Format all attributes of a type definition as text.
    --- @param td userdata The RETypeDefinition object.
    --- @param padding string Indentation string.
    --- @return string
    local function log_typedef(td, padding)
        padding = (padding or "") .. "\n    "
        return td:get_full_name()
            .. padding .. "Size: " .. td:get_size()
            .. padding .. "Is Enum: " .. tostring(td:is_a("System.Enum"))
            .. padding .. "Is Component: " .. tostring(td:is_a("via.Component"))
            .. padding .. "Is ValueType: " .. tostring(td:is_value_type())
            .. padding .. "Is UserData: " .. tostring(td:is_a("via.UserData"))
            .. padding .. "Is by Ref: " .. tostring(td:is_by_ref())
            .. padding .. "Is Pointer: " .. tostring(td:is_by_ref())
            .. padding .. "Is Primitive: " .. tostring(td:is_primitive())
            .. padding .. "Is Generic Type: " .. tostring(td:is_generic_type())
            .. padding .. "Is Generic Type Definition: " .. tostring(td:is_generic_type_definition())
    end

    --- Display Translation, Rotation and Scale as text.
    --- @param pos userdata The position vector (via.vec3).
    --- @param rot userdata The rotation quaternion (via.Quaternion).
    --- @param scale userdata The scale vector (via.vec3).
    --- @param xform userdata Optional Transform object.
    --- @return string
    local function log_transform(pos, rot, scale, xform)
        if xform then
            pos = pos or REFramework_Helpers.get_trs(xform)
            rot = rot or REFramework_Helpers.get_trs(xform)
            scale = scale or REFramework_Helpers.get_trs(xform)
        end
        if not pos or not rot or not scale then return "nil" end
        return "[" .. tostring(pos.x) .. ", " .. tostring(pos.y) .. ", " .. tostring(pos.z) .. "]\n"
            .. "[" .. tostring(rot.x) .. ", " .. tostring(rot.y) .. ", " .. tostring(rot.z) .. ", " .. tostring(rot.w) .. "]\n"
            .. "[" .. tostring(scale.x) .. ", " .. tostring(scale.y) .. ", " .. tostring(scale.z) .. "]"
    end

    --- Generic text logger for most variables, intended for debugging/printing.
    local function log_value(value, value_name, layer_limit, layer, verbose, return_over_print)
        local msg = {""}
        local indent = (layer == 0 and {"	   "}) or {""}
        layer = layer or 0
        layer_limit = layer_limit or 1 -- "-1" means no limit

        if layer > 0 then
            for i=1, layer do
                table.insert(indent, "	")
            end
        end
        indent = table.concat(indent)

        if value ~= nil then
            local str_val = tostring(value)
            local val_type = type(value)
            if val_type == "string" then
                table.insert(msg, str_val)
            elseif val_type == "table" or str_val:sub(1,15) == "sol.std::vector" then
                local is_vec = (val_type ~= "table")
                if (not is_vec and (next(value) ~= nil)) or value[1] then
                    local len = 0
                    local is_array = is_vec or (value[1] ~= nil and Utils.isArray(value))
                    if is_array then
                        if verbose then
                            table.insert(msg, (is_vec and " [vector] " or " ") .. " [" .. #value .. " elements] ")
                        end
                        if (layer < layer_limit) or (layer_limit == -1) then
                            for i, val in ipairs(value) do
                                local addition = "\n" .. log_value(val, i, layer_limit, layer + 1, verbose, true)
                                len = len + addition:len()
                                if (layer_limit < 2) and (len > 512) then break end
                                table.insert(msg, addition)
                            end
                        end
                    elseif (not value.__pairs or pcall(value.__pairs, value)) then
                        if verbose then
                            local name = value.name or (value.obj and exports.logv(value.obj, nil, 0, 0, verbose, true)) or ""
                            table.insert(msg, " [dictionary] " .. name .. " (" .. Utils.get_table_size(value) .. " elements) ")
                        end
                        if (layer < layer_limit) or (layer_limit == -1) then
                            for key, val in orderedPairs(value) do
                                local addition = "\n" .. log_value(value[key], tostring(key), layer_limit, layer + 1, verbose, true)
                                len = len + addition:len()
                                if (layer_limit < 2) and (len > 512) then break end
                                table.insert(msg, addition)
                            end
                            value.__orderedIndex = nil
                        end
                    else
                        table.insert(msg, str_val)
                    end
                else
                    table.insert(msg, "{}")
                end
            elseif Utils.can_index(value) and pcall(function() return value.x end) then
                local mt = getmetatable(value)
                if type(mt.__type) == "table" and mt.__type.name and not value.x then
                    local typename = mt.__type.name
                    if typename == "sdk::RETypeDefinition" then
                        table.insert(msg, log_typedef(value, indent))
                    elseif typename == "sdk::REMethodDefinition" then
                        table.insert(msg, log_method(value, indent))
                    elseif typename == "sdk::REField" then
                        table.insert(msg, log_field(value, indent))
                    elseif typename == "glm::mat<4,4,float,0>" then
                        table.insert(msg, (verbose and "[matrix]" or "") .. mat4_to_string(value, indent .. "	"))
                    elseif typename == "api::sdk::ValueType" or typename == "sdk::SystemArray" or sdk.is_managed_object(value) then
                        local og_value = value
                        if val_type == "number" then
                            value = sdk.to_managed_object(value)
                        end
                        local typedef
                        if not pcall(function()
                            typedef = value:get_type_definition()
                            msg = typedef and {typedef:get_full_name()}
                        end) or not typedef then return "" end
                        if msg[1] == "via.GameObject" and value:call("get_Valid") then
                            msg[1] = value:call("get_Name")
                        elseif typedef:is_a("via.Component") then
                            local gameobj = get_GameObject(value)
                            if gameobj then
                                table.insert(msg, 1, " " .. gameobj:call("get_Name") .. " -> ")
                            end
                        end
                        if val_type ~= "number" then
                            table.insert(msg, " @ " .. tostring(value:get_address()))
                        else
                            table.insert(msg, " @ " .. tostring(og_value))
                        end
                    else
                        -- This block relied on the global logv being defined, which is exports.logv now.
                        -- Since this is just for internal logging/debugging display, we'll simplify.
                        table.insert(msg, str_val)
                    end
                elseif string.find(str_val, "mat<4") then
                    table.insert(msg, (verbose and "[matrix]" or "") .. mat4_to_string(value, indent .. "	"))
                elseif value.x and string.find(str_val, "sol%.glm::") then
                    table.insert(msg, vector_to_string(value))
                else
                    table.insert(msg, str_val)
                end
            else
                table.insert(msg, str_val)
            end
        else
            table.insert(msg, "nil")
        end

        if value_name then
            table.insert(msg, 1, tostring(value_name) .. ": ")
        end

        table.insert(msg, 1, indent)

        msg = table.concat(msg)

        if return_over_print then
            return msg, msg:len()
        else
            log.info(msg)
        end
    end

    --- Returns a string of a lua table as you would see it in JSON.
    local function json_log(value, remove_arraykeys, remove_quotes, key, layer)

        if (value == nil) then
            return "null"
        end

        local msg, indent = {""}, {""}
        layer = layer or 0
        if layer > 0 then
            for i=1, layer do
                indent[#indent+1] = "	"
            end
        end
        indent = table.concat(indent)

        if value ~= nil then
            if type(value) == "table" then

                local is_empty = (next(value) == nil)
                local is_arr = Utils.isArray(value)

                table.insert(msg, (key and ("\"" .. tostring(key) .. "\": ") or "") .. ((is_empty and "[],") or (is_arr and "[") or "{"))

                if not is_empty then
                    for tbl_key, tbl_val in orderedPairs(value) do
                        if type(tbl_val)=="table" then
                            -- This recursive call needs to call the inner function again
                            table.insert(msg, "\n" .. json_log(tbl_val, remove_arraykeys, remove_quotes, (not is_arr or not remove_arraykeys) and tbl_key, layer + 1))
                        else
                            local is_string = (type(tbl_val)=="string") and "\"" or ""
                            table.insert(msg,  "\n" .. indent .. "	" .. ((not is_arr or not remove_arraykeys) and ("\"" .. tostring(tbl_key) .. "\":	") or "") .. is_string .. tostring(tbl_val) .. is_string .. ",")
                        end
                    end
                    -- Remove trailing comma from the last element added
                    if msg[#msg]:sub(-1) == ',' then
                        msg[#msg] = msg[#msg]:sub(1, -2)
                    end

                    if not is_arr then
                        table.insert(msg, "\n" .. indent .. "},")
                    else
                        table.insert(msg, "\n" .. indent .. "],")
                    end
                end
            else
                local is_string = (type(value)=="string") and "\"" or ""
                table.insert(msg,  "\"" .. tostring(key or "") .. "\":	" .. is_string .. tostring(value) .. is_string .. ",")
            end
        else
            table.insert(msg, "null")
        end

        table.insert(msg, 1, indent)
        msg = table.concat(msg)

        if remove_quotes then
            msg = msg:gsub("\"", "")
        end
        -- Final removal of trailing comma if it's the outermost call.
        if layer == 0 and msg:sub(-1) == ',' then
            msg = msg:sub(1, -2)
        end

        return msg
    end


    ----------------------------------------------------------------------------------
    -- 1. Global Logging (exports)
    ----------------------------------------------------------------------------------

    --- Calls re.msg without displaying every single frame.
    --- @param msg string The message to display/log.
    --- @param msg_id number A unique ID to limit message frequency.
    --- @param frame_limit number Min frames between displaying the message via re.msg.
    function exports.msg_safe(msg, msg_id, frame_limit)
        re.msgs_this_frame = re.msgs_this_frame or 0
        re.msgs_this_frame = re.msgs_this_frame + 1
        frame_limit = frame_limit or 15
        if re.msgs_this_frame > 10 then
            log.info("Frame " .. tics .. " Exceeded re.msg output: " .. tostring(msg))
        -- Use provided msg_ids table from deps (passed from init.lua locals)
        elseif msg_id and (not msg_ids[msg_id] or ((tics == msg_ids[msg_id])) or (frame_limit and ((tics - msg_ids[msg_id]) > frame_limit))) then
            msg_ids[msg_id] = tics
            re.msg(tostring(msg))
        else
            log.info(tostring(msg))
        end
    end

    --- Generic text logger for most variables (the implementation is local function `log_value`).
    function exports.log_value(value, value_name, layer_limit, layer, verbose, return_over_print)
        return log_value(value, value_name, layer_limit, layer, verbose, return_over_print)
    end

    --- Global printer version of exports.log_value.
    function exports.logv(value, value_name, layer_limit, layer, verbose)
        return log_value(value, value_name, layer_limit, layer, verbose, true)
    end

    ----------------------------------------------------------------------------------
    -- 2. Value Formatting (exports)
    ----------------------------------------------------------------------------------

    --- Format a vector2, vector3, vector4 or Quaternion as text.
    function exports.vector_to_string(vector)
        return vector_to_string(vector)
    end

    --- Format a matrix4 as text.
    function exports.mat4_to_string(mat, padding)
        return mat4_to_string(mat, padding)
    end

    --- Format a table of bytes into a string.
    function exports.log_bytes(bytes)
        return log_bytes(bytes)
    end

    --- Display the bytes of a managed object as text.
    function exports.read_bytes(obj)
        return read_bytes(obj)
    end

    --- Format all attributes of a method as text.
    function exports.log_method(method, padding)
        return log_method(method, padding)
    end

    --- Format all attributes of a field as text.
    function exports.log_field(field, padding)
        return log_field(field, padding)
    end

    --- Format all attributes of a field as text.
    function exports.log_typedef(td, padding)
        return log_typedef(td, padding)
    end

    --- Display Translation, Rotation and Scale as text.
    function exports.log_transform(pos, rot, scale, xform)
        return log_transform(pos, rot, scale, xform)
    end

    --- Returns a string of a lua table as you would see it in JSON.
    function exports.json_log(value, remove_arraykeys, remove_quotes, key, layer)
        return json_log(value, remove_arraykeys, remove_quotes, key, layer)
    end

    ----------------------------------------------------------------------------------
    -- 3. ImGui/World Drawing Helpers
    ----------------------------------------------------------------------------------

    --- Shows a floating message over an imgui element when hovered.
    function exports.tooltip(msg, delay)
        delay = delay or 0.5
        if imgui.is_item_hovered() then
            if delay then
                misc_vars.tooltip_timers = misc_vars.tooltip_timers or uptime
                misc_vars.hovered_this_frame = tics
            end
            if not delay or not misc_vars.tooltip_timers or ((uptime - misc_vars.tooltip_timers) > delay) then
                imgui.set_tooltip(msg or "")
            end

        elseif delay and misc_vars.hovered_this_frame < tics-1 then
            misc_vars.tooltip_timers = nil
        end
    end

    --- Creates a colored ImGui tree node.
    function exports.tree_node_colored(key, white_text, color_text, color)
        local output = imgui.tree_node_str_id(key or 'a', white_text or "")
        imgui.same_line()
        imgui.text_colored(color_text or "", color or 0xFFE0853D)
        return output
    end

    --- Creates a colored ImGui input text.
    function exports.input_text_colored(white_text, color_text, color, text)
        local changed, value = imgui.input_text(white_text or "", text)
        imgui.same_line()
        imgui.text_colored(color_text or "", color or 0xFFE0853D)
        return changed, value
    end

    --- Displays world coordinates of a vector3-4 field in imgui.
    function exports.draw_world_pos(pos, name, color)
        if type(pos.z) ~= "number" then
            pos = pos[3] --matrices
        end
        draw.world_text((name or "Position") .. "\n[" .. pos.x .. ", " .. pos.y .. ", " .. pos.z .. "]", pos, color or 0xFF00FFFF)
    end

    --- Offers to display world coordinates for a vector field in IMGUI.
    function exports.offer_show_world_pos(value, name, key_name, obj, field_or_method)
        -- Check if the vector has a significant magnitude or is already being tracked
        if value:length() > 5 or (world_positions[obj] and world_positions[obj][name]) then
            local o_tbl = deps._data[obj] -- Assuming access to global object data cache
            o_tbl.world_positions = o_tbl.world_positions or world_positions[obj] or {}
            local wpos_tbl, changed = o_tbl.world_positions[name]
            if not wpos_tbl then
                wpos_tbl = {}
                wpos_tbl.method = field_or_method.call and field_or_method
                wpos_tbl.field = field_or_method.get_data and field_or_method
                wpos_tbl.name = ((o_tbl.Name or o_tbl.name) .. "\n") .. name
                o_tbl.world_positions[name] = wpos_tbl
            end
            imgui.same_line()
            imgui.push_id(key_name .. name .. "Id")
                changed, wpos_tbl.active = imgui.checkbox("Display", wpos_tbl.active)
                if wpos_tbl.active then
                    wpos_tbl.color = changed and (math.random(0x1,0x00FFFFFF) - 1 + 4278190080) or wpos_tbl.color
                    world_positions[obj] = o_tbl.world_positions
                end
            imgui.pop_id()
        end
    end

    --- Displays a vector2, 3 or 4 with editable fields in imgui.
    --- @param value userdata The vector/quaternion object.
    --- @param name string The IMGUI label.
    --- @param is_int boolean If true, treat as integers.
    --- @param increment number The drag sensitivity.
    --- @param normalize boolean If true, normalize after changes.
    --- @return boolean changed
    --- @return userdata value The potentially updated vector/quaternion.
    function exports.show_imgui_vec4(value, name, is_int, increment, normalize)
        if not value then return false, value end
        local changed = false
        local increment = increment or 0.01

        if type(value) ~= "number" then
            if value.w then
                if name:find("olor") then
                    -- Color logic depends on calc_color from static_funcs
                    changed, value = imgui.color_edit4(name, value, (not SettingsCache.use_color_bytes and 17301504) or nil)
                    if SettingsCache.use_color_bytes then
                        imgui.text_colored("Adjusted for Gamma: ["
                        .. static_funcs.calc_color(value.x) .. ", " .. static_funcs.calc_color(value.y) .. ", " .. static_funcs.calc_color(value.z) .. ", " .. static_funcs.calc_color(value.w) .. "]", 0xFFE0853D)
                    end
                else
                    changed, value = imgui.drag_float4(name, value, increment, -10000.0, 10000.0)
                    -- if changed and normalize then value:normalize() end
                end
            elseif value.z then
                if is_int then
                    changed, value = imgui.drag_float3(name, value, 1.0, -16777216, 16777216)
                elseif name:find("olor") then
                    -- Color logic depends on calc_color from static_funcs
                    changed, value = imgui.color_edit3(name, value, (not SettingsCache.use_color_bytes and 17301504) or nil)
                    if SettingsCache.use_color_bytes then
                        imgui.text_colored("Adjusted for Gamma: ["
                        .. static_funcs.calc_color(value.x) .. ", " .. static_funcs.calc_color(value.y) .. ", " .. static_funcs.calc_color(value.z) .. "]", 0xFFE0853D)
                    end
                else
                    changed, value = imgui.drag_float3(name, value, increment, -10000.0, 10000.0)
                end
            elseif value.y then
                if is_int then
                    changed, value = imgui.drag_float2(name, value, 1.0, -16777216, 16777216)
                else
                    changed, value = imgui.drag_float2(name, value, increment, -10000.0, 10000.0)
                end
            end
        else
            changed, value = imgui.drag_float(name, value, increment, -10000.0, 10000.0)
        end
        return changed, value
    end

    -- Export the module table (M)
    return exports
end

return M
