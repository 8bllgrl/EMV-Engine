local M = {}

--- Creates and returns the configuration table, injecting necessary external dependencies.
--- @param dependencies table A table containing required global or SDK references.
--- @param dependencies.sdk table The REFramework SDK object.
--- @param dependencies.isDMC boolean Flag indicating if the game is DMC5.
--- @param dependencies.Matrix4x4f userdata The REFramework Matrix4x4f constructor.
--- @param dependencies.ValueType userdata The REFramework ValueType constructor.
--- @param dependencies.scene userdata The REFramework scene object (needed for initial object refs).
function M.create(deps)
    -- This module only defines constants and config tables, injecting dependencies as values.
    local exports = {}
    
    -- Metadata and Version
    exports.version = "2.0.5"

    -- Default Settings:
    exports.default_SettingsCache = {}
    exports.SettingsCache = {
        load_json = true,
        exception_methods = {},
        generic_count_methods = {["via.motion.Motion"] = "get_JointCount"},
        typedef_names_to_extensions = {},
        max_element_size = 100,
        use_child_windows = false,
        transparent_bg = false,
        always_update_lists = false,
        affect_children = true,
        show_all_fields = false,
        remember_materials = true,
        show_console = true,
        show_uvars = true,
        detach_collection = false,
        show_editable_tables = false,
        add_DMC5_names = deps.isDMC or false, 
        embed_mobj_control_panel = true,
        cache_orderedPairs = false,
        use_pcall = true,
        increments = {},
        objs_to_update = {},
        update_module_idx = 1,
        use_color_bytes = false,
        show_enable_checkboxes = true,
        load_resources = true,
        max_open_time = 30,
        Collection_data = {
            collection_xforms = {},
            worldmatrix = deps.Matrix4x4f and deps.Matrix4x4f.identity() or nil,
            only_parents = true,
            search_enemies = true,
            enable_component_search = true, 
            enable_exclude_search = true,
            enable_include_search = false,
            case_sensitive = false,
            enabled_new_components = {},
            must_have = {
                checked = true, 
                Component="via.motion.MotionFsm2"
            },
            search_for = {
                "via.physics.CharacterController",
                "via.motion.ActorMotion",
                "via.motion.DummySkeleton",
            },
            included = {
                "[New]"
            },
            excluded = {
                "gimmick",
            },
        }
    }

    -- Static Game-Specific Names (Constants)
    exports.cog_names = { 
        ["re2"] = "COG", 
        ["re3"] = "COG", 
        ["re7"] = "Hip", 
        ["re8"] = "Hip", 
        ["dmc5"] = "Hip", 
        ["mhrise"] = "Cog", 
        ["sf6"] = "C_Hip", 
        ["re4"] = "Hip", 
    }
    
    exports.mat_types = {
        [1] = "MaterialFloat",
        [4] = "MaterialFloat4",
        [0] = "MaterialBool"
    }
    
    exports.nums_to_xyzw = {
        [0]="x",
        [1]="y",
        [2]="z",
        [3]="w",
    }

    -- Type-to-Function Mapping (Uses injected 'sdk')
    exports.typedef_to_function = {
        ["System.SByte"] = deps.sdk.create_sbyte,
        ["System.Byte"] = deps.sdk.create_sbyte,
        ["System.Int16"] = deps.sdk.create_int16,
        ["System.UInt16"] = deps.sdk.create_uint16,
        ["System.Int32"] = deps.sdk.create_int32,
        ["System.UInt32"] = deps.sdk.create_uint32,
        ["System.Int64"] = deps.sdk.create_int64,
        ["System.UInt64"] = deps.sdk.create_uint64,
        ["System.Single"] = deps.sdk.create_single,
        ["System.Double"] = deps.sdk.create_double,
        ["System.String"] = deps.sdk.create_managed_string,
        ["System.Array"] = deps.sdk.create_managed_array,
        ["via.ResourceHolder"] = deps.sdk.create_resource,
    }
    
    -- Object Examples (Instantiated in init.lua using 'deps' provided below)
    exports.REMgdObj_objects_DEFS = {
        -- These are placeholders for what needs to be instantiated later in init.lua:
        "ValueType", 
        "RETransform", 
        "REManagedObject",
        "BHVT" -- special case for MotionFsm2 Layer
    }
    
    -- Local variables (Constants) that were previously spread out
    exports.misc_vars = {
        is_any_ctx_menu_open = false,
        tooltip_timers = 0,
        hovered_this_frame = 0,
        update_modules = {
            "UpdateBehavior",
            "PrepareRendering",
            "UpdateMotion",
            "LateUpdateBehavior",
        },
        skip_props = {
            HashCode = true,
            --Type = true,
            _DeltaTime = true,
            _UpdateCost = true,
            _LateUpdateCost = true,
            _IsInstanceEnable = true,
            
        },
    }

    return exports
end

return M
