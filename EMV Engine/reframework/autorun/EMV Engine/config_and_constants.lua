local M = {}

--- Creates and returns the configuration table, injecting necessary external dependencies.
--- @param dependencies table A table containing required global or SDK references.
--- @param dependencies.sdk table The REFramework SDK object.
--- @param dependencies.isDMC boolean Flag indicating if the game is DMC5.
--- @param dependencies.Matrix4x4f userdata The REFramework Matrix4x4f constructor.
--- @param dependencies.ValueType userdata The REFramework ValueType constructor.
function M.create(dependencies)
    local sdk = dependencies.sdk
    local isDMC = dependencies.isDMC
    local Matrix4x4f = dependencies.Matrix4x4f
    local ValueType = dependencies.ValueType

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
        -- Dependency Injected Value:
        add_DMC5_names = isDMC or false, 
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
            -- Dependency Injected Value:
            worldmatrix = Matrix4x4f and Matrix4x4f.identity() or nil,
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
        ["System.SByte"] = sdk.create_sbyte,
        ["System.Byte"] = sdk.create_sbyte,
        ["System.Int16"] = sdk.create_int16,
        ["System.UInt16"] = sdk.create_uint16,
        ["System.Int32"] = sdk.create_int32,
        ["System.UInt32"] = sdk.create_uint32,
        ["System.Int64"] = sdk.create_int64,
        ["System.UInt64"] = sdk.create_uint64,
        ["System.Single"] = sdk.create_single,
        ["System.Double"] = sdk.create_double,
        ["System.String"] = sdk.create_managed_string,
        ["System.Array"] = sdk.create_managed_array,
        ["via.ResourceHolder"] = sdk.create_resource,
    }
    
    -- Object Examples (requires dynamic lookups, which is fine in the central init.lua)
    -- We include the constructors/classes here so init.lua can build these objects later.
    exports.REMgdObj_objects = {
        ValueType = ValueType,
        -- RETransform will be assigned later by init.lua, as it relies on 'scene' being available.
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
