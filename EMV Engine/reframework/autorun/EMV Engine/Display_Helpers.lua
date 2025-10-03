-- Display_Helpers.lua

local M = {}

--- Creates and returns the Display Helpers module.
--- @param deps table A table containing required global, SDK, and utility references.
function M.create(deps)
    local exports = {}
    
    -- Deconstruct/alias dependencies
    local sdk = deps.sdk
    local imgui = deps.imgui
    local draw = deps.draw
    local Utils = deps.Utils -- From EMV_Utils.lua
    local get_GameObject = deps.REFramework_Helpers.get_GameObject
    local get_enum = deps.get_enum
    
    local static_funcs = deps.static_funcs
    local statics = deps.statics
    local misc_vars = deps.misc_vars
    local SettingsCache = deps.SettingsCache
    
    ----------------------------------------------------------------------------------
    -- 1. Global Logging (logv, re.msg_safe)
    ----------------------------------------------------------------------------------
    
    --- Calls re.msg without displaying every single frame (STUB).
    function exports.msg_safe(msg, msg_id, frame_limit)
        -- TODO: Move implementation from init.lua
    end

    --- Generic text logger for most variables (STUB).
    function exports.log_value(value, value_name, layer_limit, layer, verbose, return_over_print)
        -- TODO: Move implementation from init.lua
        return tostring(value)
    end
    
    --- Global printer version of exports.log_value (STUB).
    function exports.logv(value, value_name, layer_limit, layer, verbose)
        -- TODO: Move implementation from init.lua
        return exports.log_value(value, value_name, layer_limit, layer, verbose, true)
    end

    ----------------------------------------------------------------------------------
    -- 2. Value Formatting (Vectors, Matrices, Types)
    ----------------------------------------------------------------------------------
    
    --- Format a vector2, vector3, vector4 or Quaternion as text (STUB).
    function exports.vector_to_string(vector) 
        -- TODO: Move implementation from init.lua
        return "STUB_VECTOR"
    end

    --- Format a matrix4 as text (STUB).
    function exports.mat4_to_string(mat, padding) 
        -- TODO: Move implementation from init.lua
        return "STUB_MATRIX"
    end

    --- Format a table of bytes into a string (STUB).
    function exports.log_bytes(bytes) 
        -- TODO: Move implementation from init.lua
        return "STUB_BYTES"
    end

    --- Display the bytes of a managed object as text (STUB).
    function exports.read_bytes(obj)
        -- TODO: Move implementation from init.lua
        return "STUB_READ_BYTES"
    end

    --- Format all attributes of a method as text (STUB).
    function exports.log_method(method, padding)
        -- TODO: Move implementation from init.lua
        return "STUB_METHOD"
    end

    --- Format all attributes of a field as text (STUB).
    function exports.log_field(field, padding)
        -- TODO: Move implementation from init.lua
        return "STUB_FIELD"
    end

    --- Format all attributes of a field as text (STUB).
    function exports.log_typedef(td, padding)
        -- TODO: Move implementation from init.lua
        return "STUB_TYPEDEF"
    end

    --- Display Translation, Rotation and Scale as text (STUB).
    function exports.log_transform(pos, rot, scale, xform)
        -- TODO: Move implementation from init.lua
        return "STUB_TRS"
    end
    
    --- Returns a string of a lua table as you would see it in JSON (STUB).
    function exports.json_log(value, remove_arraykeys, remove_quotes, key, layer)
        -- TODO: Move implementation from init.lua
        return "STUB_JSON_LOG"
    end

    ----------------------------------------------------------------------------------
    -- 3. ImGui/World Drawing Helpers
    ----------------------------------------------------------------------------------

    --- Shows a floating message over an imgui element when hovered (STUB).
    function exports.tooltip(msg, delay)
        -- TODO: Move implementation from init.lua
    end

    --- Creates a colored ImGui tree node (STUB).
    function exports.tree_node_colored(key, white_text, color_text, color)
        -- TODO: Move implementation from init.lua
        return imgui.tree_node_str_id(key, white_text)
    end

    --- Creates a colored ImGui input text (STUB).
    function exports.input_text_colored(white_text, color_text, color, text)
        -- TODO: Move implementation from init.lua
        return imgui.input_text(white_text, text)
    end
    
    --- Displays world coordinates of a vector3-4 field in imgui (STUB).
    function exports.draw_world_pos(pos, name, color)
        -- TODO: Move implementation from init.lua
    end

    --- Offers to display world coordinates for a vector (STUB).
    function exports.offer_show_world_pos(value, name, key_name, obj, field_or_method)
        -- TODO: Move implementation from init.lua
    end

    --- Displays a vector2, 3 or 4 with editable fields in imgui (STUB).
    function exports.show_imgui_vec4(value, name, is_int, increment, normalize)
        -- TODO: Move implementation from init.lua
        return false, value
    end

    return exports
end

return M