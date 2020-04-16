local ecs = ...
local pipeline = ecs.pipeline

pipeline "init" {
    "init",
    "init_blit_render",
    "post_init",
}

pipeline "exit" {
    "exit",
}

pipeline "update" {
    "timer",
    "data_changed",
    pipeline "scene"{
        "update_hierarchy_scene",
        "update_transform",
    },
    pipeline "collider" {
        "update_collider_transform",
        "update_collider",
    },
    pipeline "animation" {
        "animation_state",
        "sample_animation_pose",
        pipeline "refine_animation_pose" {
            "do_refine",
            "do_ik",
        },
        "skin_mesh",
        "end_animation",
    },
    pipeline "sky" {
        "update_sun",
        "update_sky",
    },
    "widget",
    pipeline "render" {
        "shadow_camera",
        "load_render_properties",
        pipeline "handle_primitive"{
            "filter_primitive",
            "refine_filter",
        },
        "debug_shadow",
        "cull",
        "render_commit",
        pipeline "postprocess" {
            "bloom",
            "tonemapping",
            "combine_postprocess",
        }
    },
    pipeline "select"{
        "update_select_view",
        "update_filter_material",
        "pickup",
        "after_pickup",
    },
    "update_editable_hierarchy",
    pipeline "ui" {
        "ui_start",
        "ui_update",
        "ui_end",
    },
    "end_frame",
    "final",
}
