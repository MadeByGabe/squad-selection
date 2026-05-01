function widget:GetInfo()
	return {
		name = "Squad Selection Colored Markers",
		desc = "Squad Selection companion widget: draws GPU-accelerated colored circle markers below units using addSquadChangeListener(). Requires GL4.",
		author = "Baldric",
		date = "2026",
		license = "GNU GPL, v2 or later",
		layer = -999998,
		enabled = false,
	}
end


local spIsGUIHidden = Spring.IsGUIHidden
local spGetViewGeometry = Spring.GetViewGeometry

local glDepthTest = gl.DepthTest
local glDepthMask = gl.DepthMask
local glBlending = gl.Blending
local glGetVBO = gl.GetVBO

local LuaShader = gl.LuaShader
local InstanceVBOTable = gl.InstanceVBOTable
local pushElementInstance = InstanceVBOTable and InstanceVBOTable.pushElementInstance
local popElementInstance = InstanceVBOTable and InstanceVBOTable.popElementInstance

local MARKER_SIZE_PX = 12
local MARKER_OPACITY = 0.5

local GOLDEN_HUE_STEP = 0.381966
local SQUAD_SAT = 0.75
local SQUAD_VAL = 0.7

local marker_ready = false
local marker_init_failed = false
local marker_fail_reason = nil
local marker_shader = nil
local markerInstanceVBO = nil
local markerQuadVBO = nil
local marker_instance_cache = {0, 0, 0, 0, 0, 0, 0}

local listener_fn = nil
local show_reserves_cache = false

local function hsv_to_rgb(h, s, v)
	local i = math.floor(h * 6)
	local f = h * 6 - i
	local p = v * (1 - s)
	local q = v * (1 - f * s)
	local t = v * (1 - (1 - f) * s)
	i = i % 6
	if i == 0 then
		return v, t, p
	elseif i == 1 then
		return q, v, p
	elseif i == 2 then
		return p, v, t
	elseif i == 3 then
		return p, q, v
	elseif i == 4 then
		return t, p, v
	else
		return v, p, q
	end
end


local function index_to_color(idx)
	local h = ((idx - 1) * GOLDEN_HUE_STEP) % 1
	return hsv_to_rgb(h, SQUAD_SAT, SQUAD_VAL)
end


local marker_vs_src = [[
#version 430
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shader_storage_buffer_object : require
#extension GL_ARB_shading_language_420pack : require

layout (location = 0) in vec2 quadVertex;
layout (location = 1) in vec3 color;
layout (location = 2) in uvec4 instData;

//__ENGINEUNIFORMBUFFERDEFS__

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

uniform vec2 viewport;
uniform float size;

out vec3 v_color;
out vec2 v_localPos;

void main() {
	vec3 worldPos = uni[instData.y].drawPos.xyz;

	vec4 clip = cameraViewProj * vec4(worldPos, 1.0);
	vec2 ndcScale = vec2(2.0 / viewport.x, 2.0 / viewport.y) * size;
	clip.xy += quadVertex * ndcScale * clip.w;

	gl_Position = clip;
	v_color = color;
	v_localPos = quadVertex;
}
]]

local marker_fs_src = [[
#version 430

in vec3 v_color;
in vec2 v_localPos;

uniform float opacity;

out vec4 fragColor;

void main() {
	float dist = length(v_localPos);
	if (dist > 1.0) discard;
	float edge = fwidth(dist);
	float alpha = 1.0 - smoothstep(1.0 - edge, 1.0, dist);
	fragColor = vec4(v_color, alpha * opacity);
}
]]

local function init_gl_marker()
	if marker_ready or marker_init_failed then
		return marker_ready
	end
	if not LuaShader or not InstanceVBOTable then
		marker_fail_reason = "GL4 unavailable"
		marker_init_failed = true
		return false
	end

	local engineUniformBufferDefs = LuaShader.GetEngineUniformBufferDefs()
	local vsSrc = marker_vs_src:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs)

	marker_shader = LuaShader({
		vertex = vsSrc,
		fragment = marker_fs_src,
		uniformFloat = {
			viewport = {1.0, 1.0},
			opacity = MARKER_OPACITY,
			size = MARKER_SIZE_PX,
		},
	}, "Squad Colored Markers GL4")

	if not marker_shader:Initialize() then
		marker_fail_reason = "shader compile failed"
		marker_shader = nil
		marker_init_failed = true
		return false
	end

	markerQuadVBO = glGetVBO(GL.ARRAY_BUFFER, false)
	if not markerQuadVBO then
		marker_shader = nil
		marker_init_failed = true
		marker_fail_reason = "quad VBO creation failed"
		return false
	end
	markerQuadVBO:Define(4, {
		{
			id = 0,
			name = "quadVertex",
			size = 2,
		}})
	markerQuadVBO:Upload({-1, -1, 1, -1, -1, 1, 1, 1})

	local instanceLayout = {
		{
			id = 1,
			name = "color",
			size = 3,
		}, {
			id = 2,
			name = "instData",
			size = 4,
			type = GL.UNSIGNED_INT,
		}}
	markerInstanceVBO = InstanceVBOTable.makeInstanceVBOTable(instanceLayout, 128, "squadColoredMarkersVBO", 2)
	markerInstanceVBO.numVertices = 4
	markerInstanceVBO.vertexVBO = markerQuadVBO
	markerInstanceVBO.VAO = InstanceVBOTable.makeVAOandAttach(markerQuadVBO, markerInstanceVBO.instanceVBO)

	marker_ready = true
	return true
end


local function cleanup_gl_marker()
	if markerInstanceVBO then
		if markerInstanceVBO.VAO then
			markerInstanceVBO.VAO:Delete()
		end
		if markerInstanceVBO.instanceVBO then
			markerInstanceVBO.instanceVBO:Delete()
		end
	end
	if markerQuadVBO then
		markerQuadVBO:Delete()
	end
	if marker_shader and marker_shader.Finalize then
		marker_shader:Finalize()
	end
	markerInstanceVBO = nil
	markerQuadVBO = nil
	marker_shader = nil
	marker_ready = false
	marker_init_failed = false
end


local function get_api()
	return WG and WG['squadselection']
end


local function marker_visible(sq)
	return sq and (not sq.is_reserve or show_reserves_cache)
end


local function push_unit(unit_id, sq)
	if not marker_ready or not sq.index then
		return
	end
	local r, g, b = index_to_color(sq.index)
	marker_instance_cache[1] = r
	marker_instance_cache[2] = g
	marker_instance_cache[3] = b
	pushElementInstance(markerInstanceVBO, marker_instance_cache, unit_id, true, false, unit_id)
end


local function pop_unit(unit_id)
	if not marker_ready then
		return
	end
	if markerInstanceVBO.instanceIDtoIndex[unit_id] then
		popElementInstance(markerInstanceVBO, unit_id)
	end
end


local function rebuild_all()
	if not marker_ready then
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

	-- Pop any units no longer in a visible squad.
	for uid in pairs(markerInstanceVBO.instanceIDtoIndex) do
		if not desired[uid] then
			popElementInstance(markerInstanceVBO, uid)
		end
	end
end


local function on_squad_change(event, unit_id, squad)
	if not marker_ready and not init_gl_marker() then
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


local draw_error_logged = false

function widget:Initialize()
	if not LuaShader or not InstanceVBOTable then
		Spring.Echo("[Squad Colored Markers] GL4 not available, removing widget")
		widgetHandler:RemoveWidget()
		return
	end

	local api = get_api()
	if api and api.addSquadChangeListener then
		if init_gl_marker() then
			listener_fn = on_squad_change
			api.addSquadChangeListener(listener_fn)
		else
			Spring.Echo("[Squad Colored Markers] GL init failed: " .. tostring(marker_fail_reason))
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
		if not marker_ready and not init_gl_marker() then
			if not draw_error_logged then
				Spring.Echo("[Squad Colored Markers] GL init failed: " .. tostring(marker_fail_reason))
				draw_error_logged = true
			end
			return
		end
		listener_fn = on_squad_change
		api.addSquadChangeListener(listener_fn)
	end
end


function widget:DrawWorldPreUnit()
	if spIsGUIHidden() then
		return
	end
	if not marker_ready or not markerInstanceVBO or markerInstanceVBO.usedElements == 0 then
		return
	end

	-- Detect showReserveSquads toggle.
	local api = get_api()
	if api then
		local sr = api.getShowReserveSquads and api.getShowReserveSquads() or false
		if sr ~= show_reserves_cache then
			show_reserves_cache = sr
			rebuild_all()
			if markerInstanceVBO.usedElements == 0 then
				return
			end
		end
	end

	local vsx, vsy = spGetViewGeometry()

	glDepthTest(false)
	glDepthMask(false)
	glBlending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
	marker_shader:Activate()
	marker_shader:SetUniform("viewport", vsx, vsy)
	marker_shader:SetUniform("opacity", MARKER_OPACITY)
	marker_shader:SetUniform("size", MARKER_SIZE_PX)
	markerInstanceVBO.VAO:DrawArrays(GL.TRIANGLE_STRIP, 4, 0, markerInstanceVBO.usedElements, 0)
	marker_shader:Deactivate()
	glBlending(false)
	glDepthMask(true)
	glDepthTest(true)
end


function widget:Shutdown()
	if listener_fn then
		local api = get_api()
		if api and api.removeSquadChangeListener then
			api.removeSquadChangeListener(listener_fn)
		end
		listener_fn = nil
	end
	cleanup_gl_marker()
end

