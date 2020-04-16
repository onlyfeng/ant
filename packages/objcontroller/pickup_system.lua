--luacheck: ignore self
local ecs = ...
local world = ecs.world

ecs.import "ant.scene"
local lua_math = math
local mathpkg 	= import_package "ant.math"
local mu, mc 	= mathpkg.util, mathpkg.constant
local math3d	= require "math3d"

local renderpkg = import_package "ant.render"
local fbmgr 	= renderpkg.fbmgr
local renderutil= renderpkg.util
local viewidmgr = renderpkg.viewidmgr

local assetmgr = import_package "ant.asset"

local bgfx 		= require "bgfx"

--update pickup view
local function enable_pickup(enable)
	local e = world:singleton_entity "pickup"
	e.visible = enable

	if not enable then
		e.pickup.nextstep = nil
	end
end

local function update_viewinfo(e, clickx, clicky) 
	local mq = world:singleton_entity "main_queue"
	local camera = world[mq.camera_eid].camera

	local pickupcamera = world[e.camera_eid].camera

	local rt = mq.render_target.viewport.rect

	local ndc2D = mu.pt2D_to_NDC({clickx, clicky}, rt)
	local eye, at = mu.NDC_near_far_pt(ndc2D)

	local vp = mu.view_proj(camera)
	local ivp = math3d.inverse(vp)
	eye = math3d.transformH(ivp, eye, 1)
	at = math3d.transformH(ivp, at, 1)
	pickupcamera.eyepos.v = eye
	pickupcamera.viewdir.v= math3d.normalize(math3d.sub(at, eye))
end

local leftmousepress_mb = world:sub {"mouse", "LEFT"}
local pickup_watch_sys = ecs.system "pickup_watch_system"
function pickup_watch_sys:data_changed()
	for _,_,state,x,y in leftmousepress_mb:unpack() do
		if state == "DOWN" then
			enable_pickup(true)
			local pickupentity = world:singleton_entity "pickup"
			update_viewinfo(pickupentity, x, y)
			local pickupcomp = pickupentity.pickup
			pickupcomp.nextstep = "blit"
		end
	end
end

-- function pickup_watch_sys:end_frame()

-- end


local function packeid_as_rgba(eid)
    return {(eid & 0x000000ff) / 0xff,
            ((eid & 0x0000ff00) >> 8) / 0xff,
            ((eid & 0x00ff0000) >> 16) / 0xff,
            ((eid & 0xff000000) >> 24) / 0xff}    -- rgba
end

local function traverse_from_center( blitdata,w,h )
	assert(w==h)
    local function incr(v2a,v2b)
        for i = 1,#v2a do
            v2a[i] =  v2a[i] +   v2b[i]
        end
	end
    -- local function dosth(v2)
    --     log.info_a("trav:",v2)
    -- end
    local start_move = {1,-1}
    local move_count=nil
    local step_incr = 2
    local step = {
        {-1,0},
        {0,1},
        {1,0},
        {0,-1}
    }
    if w%2==0 then
        move_count = 1
    else
        move_count = 0
    end
    local  cur_pos = {lua_math.floor(w/2)-1,lua_math.floor(w/2)}
    log.trace_a(cur_pos)
    local found_eid = nil
    while true do
        incr(cur_pos,start_move)
        if cur_pos[2]<0 then
            break
        end
        if move_count >0 then
            for i = 1,4 do
                for j = 1,move_count do
                    incr(cur_pos,step[i])
                    found_eid = blitdata[cur_pos[1]*w+cur_pos[2]]
                    if found_eid ~= 0 then
                        return found_eid
                    end
                end
            end
        end
        move_count = move_count + step_incr
    end
end

local function which_entity_hitted(blitdata, viewrect)
	return traverse_from_center(blitdata,viewrect.w,viewrect.h)
end

local pickup_sys = ecs.system "pickup_system"

local pick_material_cache = {}

local accessor = assetmgr.get_accessor "material"
local load_uniform = accessor.load_uniform

local function pick_material(material_template, eid)
	local pm = pick_material_cache[eid]
	if pm then
		return pm
	end

	local vv = packeid_as_rgba(eid)
	local m = assetmgr.patch(material_template, {
		properties = {
			uniforms = {
				u_id = load_uniform{type="color", vv,},
			}
		}
	})
	pick_material_cache[eid] = m
	return m
end

local function replace_material(result, material)
	if result then
		for _, item in ipairs(result) do
			item.material = pick_material(material, item.eid)
		end
	end
end

local function recover_material(result)
	if result then
		for i=1, result.n do
			result[i].properties.uniforms.u_id = nil
		end
	end
end

local function recover_filter(filter)
	local result = filter.result
	recover_material(result.opaticy)
	recover_material(result.translucent)
end

function pickup_sys:refine_filter()
	local e = world:singleton_entity "pickup"
	if e.visible then
		local filter = e.primitive_filter

		local material = e.material
		local result = filter.result
		replace_material(result.opaticy, material)
		replace_material(result.translucent, material[1])
	end
end

ecs.tag "can_select"

-- pickup_system
local raw_buf = ecs.component "raw_buffer"
	.w "int" (1)
	.h "int" (1)
	.elemsize "int" (4)
function raw_buf:init()
	self.handle = bgfx.memory_texture(self.w*self.h * self.elemsize)
	return self
end

ecs.component_alias("blit_viewid", "viewid") 
ecs.component "blit_buffer"
	.raw_buffer "raw_buffer"
	.rb_idx 	"rb_index"

ecs.component_alias("pickup_viewtag", "boolean")

--pick_ids:array of pick_eid
--last_pick:last pick id when mult pick supported
ecs.component "pickup_cache"
	.last_pick "int" (-1)
	.pick_ids "int[]"

ecs.component "pickup"
	.blit_buffer "blit_buffer"
	.blit_viewid "blit_viewid"
	.pickup_cache "pickup_cache"

local pup = ecs.policy "pickup"
	pup.unique_component "pickup"
	pup.require_component "material"
	pup.require_component "view_mode"
	pup.require_system "pickup_system"
	
local sp = ecs.policy "select"
	sp.require_component "can_select"
	sp.require_system "pickup_watch_system"
	sp.require_system "pickup_system"

	sp.require_policy "pickup"


local pickup_buffer_w, pickup_buffer_h = 8, 8
local pickupviewid = viewidmgr.get "pickup"

local function add_pick_entity()
	local fb_renderbuffer_flag = renderutil.generate_sampler_flag {
		RT="RT_ON",
		MIN="POINT",
		MAG="POINT",
		U="CLAMP",
		V="CLAMP"
	}

	local cameraeid = world:create_entity {
		policy = {
			"ant.render|camera",
			"ant.general|name",
		},
		data = {
			camera = {
				viewdir = mc.T_ZAXIS,
				updir = mc.T_YAXIS,
				eyepos = mc.T_ZERO_PT,
				frustum = {
					type="mat", n=0.1, f=100, fov=1, aspect=pickup_buffer_w / pickup_buffer_h
				},
			},
			name = "camera.pickup"
		}
	}

	local fbidx = fbmgr.create {
		render_buffers = {
			fbmgr.create_rb {
				w = pickup_buffer_w,
				h = pickup_buffer_h,
				layers = 1,
				format = "RGBA8",
				flags = fb_renderbuffer_flag,
			},
			fbmgr.create_rb {
				w = pickup_buffer_w,
				h = pickup_buffer_h,
				layers = 1,
				format = "D24S8",
				flags = fb_renderbuffer_flag,
			}
		}
	}

	local blit_rbidx = fbmgr.create_rb {
		w = pickup_buffer_w,
		h = pickup_buffer_h,
		layers = 1,
		format = "RGBA8",
		flags = renderutil.generate_sampler_flag {
			BLIT="BLIT_AS_DST",
			BLIT_READBACK="BLIT_READBACK_ON",
			MIN="POINT",
			MAG="POINT",
			U="CLAMP",
			V="CLAMP",
		}
	}
	return world:create_entity {
		policy = {
			"ant.general|name",
			"ant.render|render_queue",
			"ant.objcontroller|pickup",
		},
		data = {
			material = {
				'/pkg/ant.resources/depiction/materials/pickup_opacity.material',
				'/pkg/ant.resources/depiction/materials/pickup_transparent.material',
			},
			view_mode = "s",
			pickup = {
				blit_buffer = {
					raw_buffer = {
						w = pickup_buffer_w,
						h = pickup_buffer_h,
						elemsize = 4,
					},
					rb_idx = blit_rbidx,
				},
				blit_viewid = viewidmgr.get "pickup_blit",
				pickup_cache = {
					last_pick = -1,
					pick_ids = {},
				},
			},
			camera_eid = cameraeid,
			render_target = {
				viewport = {
					rect = {
						x = 0, y = 0, w = pickup_buffer_w, h = pickup_buffer_h,
					},
					clear_state = {
						color = 0,
						depth = 1,
						stencil = 0,
						clear = "all"
					},
				},
				fb_idx = fbidx,
			},
			viewid = pickupviewid,
			primitive_filter = {
				filter_tag = "can_select"
			},
			visible = false,
			name = "pickup_renderqueue",
		}

	}
end

function pickup_sys:init()
	add_pick_entity()
end

local function blit(blitviewid, blit_buffer, colorbuffer)
	local rb = fbmgr.get_rb(blit_buffer.rb_idx)
	local rbhandle = rb.handle
	
	bgfx.blit(blitviewid, rbhandle, 0, 0, assert(colorbuffer.handle))
	return bgfx.read_texture(rbhandle, blit_buffer.raw_buffer.handle)
end

local function print_raw_buffer(rawbuffer)
	local data = rawbuffer.handle
	for i=1, pickup_buffer_w do
		local t = {tostring(i) .. ":"}
		for j=1, pickup_buffer_h do
			t[#t+1] = data[(i-1)*pickup_buffer_w + j-1]
		end

		print(table.concat(t, ' '))
	end
end

local function select_obj(pickup_com,blit_buffer, viewrect)
	--print_raw_buffer(blit_buffer.raw_buffer)
	local selecteid = which_entity_hitted(blit_buffer.raw_buffer.handle, viewrect)
	if selecteid and selecteid<100 then
		log.info("selecteid",selecteid)
		pickup_com.pickup_cache.last_pick = selecteid
		pickup_com.pickup_cache.pick_ids = {selecteid}
		local name = assert(world[selecteid]).name
		print("pick entity id : ", selecteid, ", name : ", name)
		-- world:update_func("after_pickup")()
		world:pub {"pickup",selecteid,pickup_com.pickup_cache.pick_ids}
	else
		pickup_com.pickup_cache.last_pick = nil
		pickup_com.pickup_cache.pick_ids = {}
		-- world:update_func("after_pickup")()
		world:pub {"pickup",nil,{}}
		print("not found any eid")
	end
end

local state_list = {
	blit = "wait",
	wait = "select_obj",
}

local function check_next_step(pickupcomp)
	pickupcomp.nextstep = state_list[pickupcomp.nextstep]	
end

function pickup_sys:pickup()
	local pickupentity = world:singleton_entity "pickup"

	if pickupentity.visible then
		local pickupcomp = pickupentity.pickup
		local nextstep = pickupcomp.nextstep
		if nextstep == "blit" then
			local fb = fbmgr.get(pickupentity.render_target.fb_idx)
			local rb = fbmgr.get_rb(fb[1])
			blit(pickupcomp.blit_viewid, pickupcomp.blit_buffer, rb)
		elseif nextstep	== "select_obj" then
			recover_filter(pickupentity.primitive_filter)
			select_obj(pickupcomp,pickupcomp.blit_buffer, pickupentity.render_target.viewport.rect)
			--print_raw_buffer(pickupcomp.blit_buffer.raw_buffer)
			enable_pickup(false)
		end

		check_next_step(pickupcomp)
	end
end