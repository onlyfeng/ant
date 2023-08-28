local ecs = ...
local world = ecs.world
local w = world.w

local math3d    = require "math3d"

local ientity   = ecs.require "ant.render|components.entity"
local iom       = ecs.require "ant.objcontroller|obj_motion"
local is = ecs.system "init_system"

function is:init()
    ientity.create_grid_entity("polyline_grid", 64, 64, 1, 5)
    --world:create_instance "/pkg/ant.test.bake_scene/assets/scene/1.glb|mesh.prefab"
    -- world:create_instance "/pkg/ant.test.bake_scene/assets/scene/box.prefab"
    -- world:create_instance "/pkg/ant.test.bake_scene/assets/scene/light.prefab"
    -- world:create_instance "/pkg/ant.test.bake_scene/assets/scene/box.prefab"
    world:create_instance "/pkg/ant.test.bake_scene/assets/scene/scene.prefab"
end

function is:init_world()
    local mq = w:first("main_queue camera_ref:in")
    local eyepos<const> = math3d.vector(0.0, 2.5, -15.0)
    local dir<const> = math3d.sub(math3d.vector(0.0, 0.0, 0.0), eyepos)
    iom.set_position(mq.camera_ref, eyepos)
    iom.set_direction(mq.camera_ref, dir)
end

function is:data_changed()
    
end