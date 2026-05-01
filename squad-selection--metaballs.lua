function widget:GetInfo()
	return {
		name = "Squad Selection Metaballs",
		desc = "Squad Selection companion widget: draws GPU-accelerated colored circle blobs around units using addSquadChangeListener(). Requires GL4.",
		author = "Baldric",
		date = "2026",
		license = "GNU GPL, v2 or later",
		layer = -999998,
		enabled = false,
	}
end


local spIsGUIHidden = Spring.IsGUIHidden
local spGetViewGeometry = Spring.GetViewGeometry
local spEcho = Spring.Echo

local LuaShader = gl.LuaShader
local InstanceVBOTable = gl.InstanceVBOTable
local pushElementInstance = InstanceVBOTable and InstanceVBOTable.pushElementInstance
local popElementInstance = InstanceVBOTable and InstanceVBOTable.popElementInstance

local CIRCLE_RADIUS = 170
local CIRCLE_OPACITY = 1
local CIRCLE_SEGMENTS = 32
local STENCIL_RESOLUTION = 1

local ready = false
local init_failed = false

local stencilShader = nil
local fullscreenShader = nil
local circleInstanceVBO = nil
local stencilTexture = nil
local fullscreenVAO = nil
local fullscreenVBO = nil

local circleInstanceCache = {0, 0, 0, 0, 0, 0, 0, 0}
local listener_fn = nil
local show_reserves_cache = false

local is_air = {} -- defID -> bool
local defid_cache = {} -- unitID -> defID or false

local function get_defid(unit_id)
	local v = defid_cache[unit_id]
	if v ~= nil then
		return v
	end
	local id = Spring.GetUnitDefID(unit_id)
	v = id or false
	defid_cache[unit_id] = v
	return v
end


-------------------------------------------------------------------------------
-- Shaders (inline)
-------------------------------------------------------------------------------

local stencil_vs_src = [[
#version 430 core
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shader_storage_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

#line 10000

layout (location = 0) in vec4 circlepointposition;
layout (location = 1) in vec4 radius_color;
layout (location = 2) in uvec4 instData;

//__ENGINEUNIFORMBUFFERDEFS__

uniform sampler2D heightmapTex;

struct SUniformsBuffer {
    uint composite;
    uint unused2;
    uint unused3;
    uint unused4;

    float maxHealth;
    float health;
    float unused5;
    float unused6;

    vec4 drawPos;
    vec4 speed;
    vec4[4] userDefined;
};

layout(std140, binding=1) readonly buffer UniformsBuffer {
    SUniformsBuffer uni[];
};

out DataVS {
    flat vec4 v_color;
    vec2 v_localPos;
};

void main() {
    vec4 center = vec4(uni[instData.y].drawPos.xyz, 1.0);
    float circleRadius = abs(radius_color.x);
    bool isAir = radius_color.x < 0.0;

    if (SphereInViewSignedDistance(center.xyz, circleRadius) > 0.0) {
        gl_Position = vec4(2.0, 0.0, 0.0, 1.0);
        return;
    }

    vec4 vertex = vec4(center.xyz, 1.0);
    vertex.xz += circlepointposition.xy * circleRadius;

    if (isAir) {
        vertex.y = max(0.0, center.y + 6.0);
    } else {
        vec2 uvhm = heightmapUVatWorldPos(vertex.xz);
        vertex.y = textureLod(heightmapTex, uvhm, 0.0).x + 6.0;
    }

    gl_Position = cameraViewProj * vertex;
    v_color = vec4(radius_color.yzw, 1.0);
    v_localPos = circlepointposition.xy;
}
]]

local stencil_fs_src = [[
#version 430
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

//__ENGINEUNIFORMBUFFERDEFS__

in DataVS {
    flat vec4 v_color;
    vec2 v_localPos;
};

out vec4 fragColor;

void main() {
    float dist = length(v_localPos);
    fragColor = vec4(v_color.rgb, 1.0 - dist);
}
]]

local fullscreen_vs_src = [[
#version 430 core

layout (location = 0) in vec2 position;

out vec2 v_uv;

void main() {
    gl_Position = vec4(position, 0.0, 1.0);
    v_uv = position * 0.5 + 0.5;
}
]]

local fullscreen_fs_src = [[
#version 430 core

uniform sampler2D stencilTex;

in vec2 v_uv;
out vec4 fragColor;

void main() {
    vec4 stencil = texture(stencilTex, v_uv);
    float val = stencil.a;

    if (val <= 0.001) {
        discard;
    }

    vec3 color = stencil.rgb;

    float outer = (val >= 0.17 && val <= 0.20) ? 1.0 : 0.0;
    fragColor = vec4(color, outer);
}
]]

-------------------------------------------------------------------------------
-- GL init / cleanup
-------------------------------------------------------------------------------

local function create_stencil_texture()
	local vsx, vsy = spGetViewGeometry()
	if stencilTexture then
		gl.DeleteTexture(stencilTexture)
	end
	stencilTexture = gl.CreateTexture(vsx / STENCIL_RESOLUTION, vsy / STENCIL_RESOLUTION, {
		fbo = true,
		min_filter = GL.NEAREST,
		mag_filter = GL.LINEAR,
		wrap_s = GL.CLAMP_TO_EDGE,
		wrap_t = GL.CLAMP_TO_EDGE,
	})
	return stencilTexture ~= nil
end


local function init_gl()
	if ready or init_failed then
		return ready
	end
	if not gl.CreateShader or not LuaShader or not InstanceVBOTable then
		init_failed = true
		return false
	end

	local engineDefs = LuaShader.GetEngineUniformBufferDefs()
	local vsSrc = stencil_vs_src:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineDefs)
	local fsSrc = stencil_fs_src:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineDefs)

	stencilShader = LuaShader({
		vertex = vsSrc,
		fragment = fsSrc,
		uniformInt = {
			heightmapTex = 0,
		},
	}, "Squad Metaballs Stencil GL4")

	if not stencilShader:Initialize() then
		spEcho("[Squad Metaballs] stencil shader compile failed")
		stencilShader = nil
		init_failed = true
		return false
	end

	fullscreenShader = LuaShader({
		vertex = fullscreen_vs_src,
		fragment = fullscreen_fs_src,
		uniformInt = {
			stencilTex = 0,
		},
	}, "Squad Metaballs Fullscreen GL4")

	if not fullscreenShader:Initialize() then
		spEcho("[Squad Metaballs] fullscreen shader compile failed")
		stencilShader:Finalize()
		stencilShader = nil
		fullscreenShader = nil
		init_failed = true
		return false
	end

	if not create_stencil_texture() then
		spEcho("[Squad Metaballs] stencil texture creation failed")
		stencilShader:Finalize()
		fullscreenShader:Finalize()
		stencilShader = nil
		fullscreenShader = nil
		init_failed = true
		return false
	end

	local circleVBO, numVertices = InstanceVBOTable.makeCircleVBO(CIRCLE_SEGMENTS, nil, true, "SquadCirclesCompanion")
	local instanceLayout = {
		{
			id = 1,
			name = "radius_color",
			size = 4,
		}, {
			id = 2,
			name = "instData",
			size = 4,
			type = GL.UNSIGNED_INT,
		}}

	circleInstanceVBO = InstanceVBOTable.makeInstanceVBOTable(instanceLayout, 128, "squadCirclesCompanionVBO", 2)
	circleInstanceVBO.numVertices = numVertices
	circleInstanceVBO.vertexVBO = circleVBO
	circleInstanceVBO.VAO = InstanceVBOTable.makeVAOandAttach(circleVBO, circleInstanceVBO.instanceVBO)

	fullscreenVBO = gl.GetVBO(GL.ARRAY_BUFFER, false)
	fullscreenVBO:Define(3, {
		{
			id = 0,
			name = "position",
			size = 2,
		}})
	fullscreenVBO:Upload({-1, -1, 3, -1, -1, 3})
	fullscreenVAO = gl.GetVAO()
	fullscreenVAO:AttachVertexBuffer(fullscreenVBO)

	ready = true
	return true
end


local function cleanup_gl()
	if stencilTexture then
		gl.DeleteTexture(stencilTexture)
		stencilTexture = nil
	end
	if fullscreenVBO then
		fullscreenVBO:Delete()
		fullscreenVBO = nil
	end
	if fullscreenVAO then
		fullscreenVAO:Delete()
		fullscreenVAO = nil
	end
	if stencilShader and stencilShader.Finalize then
		stencilShader:Finalize()
	end
	if fullscreenShader and fullscreenShader.Finalize then
		fullscreenShader:Finalize()
	end
	stencilShader = nil
	fullscreenShader = nil
	circleInstanceVBO = nil
	ready = false
	init_failed = false
	defid_cache = {}
end


-------------------------------------------------------------------------------
-- Instance management
-------------------------------------------------------------------------------

local function get_api()
	return WG and WG['squadselection']
end


local function marker_visible(sq)
	return sq and (not sq.is_reserve or show_reserves_cache)
end


local function push_unit(unit_id, sq)
	if not ready or not sq.color then
		return
	end
	local def_id = get_defid(unit_id)
	circleInstanceCache[1] = (def_id and is_air[def_id]) and -CIRCLE_RADIUS or CIRCLE_RADIUS
	circleInstanceCache[2] = sq.color[1]
	circleInstanceCache[3] = sq.color[2]
	circleInstanceCache[4] = sq.color[3]
	pushElementInstance(circleInstanceVBO, circleInstanceCache, unit_id, true, false, unit_id)
end


local function pop_unit(unit_id)
	if not ready then
		return
	end
	if circleInstanceVBO.instanceIDtoIndex[unit_id] then
		popElementInstance(circleInstanceVBO, unit_id)
	end
	defid_cache[unit_id] = nil
end


local function rebuild_all()
	if not ready then
		return
	end

	local api = get_api()
	if not api or not api.getSquadState then
		return
	end

	local state = api.getSquadState()
	if not state then
		return
	end

	show_reserves_cache = api.getShowReserveSquads and api.getShowReserveSquads() or false

	local desired = {}
	for i = 1, #state.squads do
		local sq = state.squads[i]
		if #sq > 0 and marker_visible(sq) then
			for j = 1, #sq do
				local uid = sq[j]
				desired[uid] = true
				push_unit(uid, sq)
			end
		end
	end

	for uid in pairs(circleInstanceVBO.instanceIDtoIndex) do
		if not desired[uid] then
			popElementInstance(circleInstanceVBO, uid)
		end
	end
end


local function on_squad_change(event, unit_id, squad)
	if not ready and not init_gl() then
		return
	end

	if event == "add" then
		if marker_visible(squad) then
			push_unit(unit_id, squad)
		end
	elseif event == "remove" then
		pop_unit(unit_id)
	elseif event == "rebuild" then
		rebuild_all()
	end
end


-------------------------------------------------------------------------------
-- Lifecycle
-------------------------------------------------------------------------------

function widget:Initialize()
	if not LuaShader or not InstanceVBOTable then
		spEcho("[Squad Metaballs] GL4 not available, removing widget")
		widgetHandler:RemoveWidget()
		return
	end

	for defID, def in pairs(UnitDefs) do
		if def.canFly then
			is_air[defID] = true
		end
	end

	local api = get_api()
	if api and api.addSquadChangeListener then
		if init_gl() then
			listener_fn = on_squad_change
			api.addSquadChangeListener(listener_fn)
		else
			spEcho("[Squad Metaballs] GL init failed, removing widget")
			widgetHandler:RemoveWidget()
		end
	end
end


function widget:Update()
	if listener_fn then
		return
	end
	local api = get_api()
	if api and api.addSquadChangeListener then
		if not ready and not init_gl() then
			return
		end
		listener_fn = on_squad_change
		api.addSquadChangeListener(listener_fn)
	end
end


function widget:ViewResize()
	if ready then
		create_stencil_texture()
	end
end


local function draw_stencil_pass()
	gl.Clear(GL.COLOR_BUFFER_BIT, 0, 0, 0, 0)
	gl.Texture(0, "$heightmap")
	stencilShader:Activate()
	circleInstanceVBO.VAO:DrawArrays(GL.TRIANGLE_FAN, circleInstanceVBO.numVertices, 0, circleInstanceVBO.usedElements, 0)
	stencilShader:Deactivate()
end


function widget:DrawGenesis()
	if not ready or not stencilTexture or not circleInstanceVBO then
		return
	end
	if circleInstanceVBO.usedElements > 0 then
		gl.RenderToTexture(stencilTexture, draw_stencil_pass)
	end
end


function widget:DrawWorldPreUnit()
	if spIsGUIHidden() then
		return
	end
	if not ready or not fullscreenVAO or not stencilTexture or not circleInstanceVBO then
		return
	end
	if circleInstanceVBO.usedElements == 0 then
		return
	end

	-- Detect showReserveSquads toggle.
	local api = get_api()
	if api then
		local sr = api.getShowReserveSquads and api.getShowReserveSquads() or false
		if sr ~= show_reserves_cache then
			show_reserves_cache = sr
			rebuild_all()
			if circleInstanceVBO.usedElements == 0 then
				return
			end
		end
	end

	gl.DepthMask(false)
	gl.DepthTest(false)
	gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
	fullscreenShader:Activate()
	gl.Texture(0, stencilTexture)
	fullscreenVAO:DrawArrays(GL.TRIANGLES, 3)
	fullscreenShader:Deactivate()
	gl.Texture(0, false)
	gl.Blending(false)
	gl.DepthTest(true)
	gl.DepthMask(true)
end


function widget:Shutdown()
	if listener_fn then
		local api = get_api()
		if api and api.removeSquadChangeListener then
			api.removeSquadChangeListener(listener_fn)
		end
		listener_fn = nil
	end
	cleanup_gl()
end


