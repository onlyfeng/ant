local ecs = ...
local world = ecs.world
local cu = require "render.components.util"
local mu = require "math.util"
local shader_mgr    = require "render.resources.shader_mgr"

local asset_lib     = require "asset"
local bgfx          = require "bgfx"

local add_entity_sys = ecs.system "add_entities_system"
add_entity_sys.singleton "math_stack"
add_entity_sys.dependby "iup_message"

function add_entity_sys:init()
    do
        local bunny_eid = world:new_entity(table.unpack(cu.get_sceneobj_compoent_names()))
        local bunny = world[bunny_eid]

        -- should read from serialize file
        local ms = self.math_stack
        ms(bunny.scale.v, {1, 1, 1}, "=")
        ms(bunny.position.v, {0, 0, 0, 1}, "=")
        ms(bunny.direction.v, {0, 0, 1, 0}, "=")

        bunny.render = asset_lib["test/simplerender/bunny.render"]
    
        -- bind the update function. this update should add by material editor
        local materials = bunny.render.materials
    
        function utime_update (uniform)
            if uniform.value == nil then
                uniform.value = 0
            end

            uniform.value = uniform.value + 1
            return uniform.value
        end

        -- actully, these materials are the same material. we need to manager the materials, and only use material id to replace
        for _, material in ipairs(materials) do            
            local uniforms = material.uniform
            local u_time = uniforms.u_time
            assert(u_time, "need define u_time uniform")
            u_time.update = utime_update
        end
    end
    
    do
        local camera_eid = world:new_entity("main_camera", "viewid", "direction", "position", "frustum", "view_rect", "clear_component")
        local camera = world[camera_eid]
        camera.viewid.id = 0
    
        self.math_stack(camera.position.v,    {0, 0, -5, 1},  "=")
        self.math_stack(camera.direction.v,   {0, 0, 1, 0},   "=")

        local frustum = camera.frustum
        mu.frustum_from_fov(frustum, 0.1, 10000, 60, 1)
    end
end