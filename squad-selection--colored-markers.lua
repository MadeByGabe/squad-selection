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

local markerReady = false
local markerInitFailed = false
local markerFailReason = nil
local markerShader = nil
local markerInstanceVBO = nil
local markerQuadVBO = nil
local markerInstanceCache = {0, 0, 0, 0, 0, 0, 0}

local listenerFn = nil
local showReservesCache = false

local markerVsSrc = [[
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

local markerFsSrc = [[
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

local function initGlMarker()
	if markerReady or markerInitFailed then
		return markerReady
	end
	if not LuaShader or not InstanceVBOTable then
		markerFailReason = "GL4 unavailable"
		markerInitFailed = true
		return false
	end

	local engineUniformBufferDefs = LuaShader.GetEngineUniformBufferDefs()
	local vsSrc = markerVsSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs)

	markerShader = LuaShader({
		vertex = vsSrc,
		fragment = markerFsSrc,
		uniformFloat = {
			viewport = {1.0, 1.0},
			opacity = MARKER_OPACITY,
			size = MARKER_SIZE_PX,
		},
	}, "Squad Colored Markers GL4")

	if not markerShader:Initialize() then
		markerFailReason = "shader compile failed"
		markerShader = nil
		markerInitFailed = true
		return false
	end

	markerQuadVBO = glGetVBO(GL.ARRAY_BUFFER, false)
	if not markerQuadVBO then
		markerShader = nil
		markerInitFailed = true
		markerFailReason = "quad VBO creation failed"
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

	markerReady = true
	return true
end


local function cleanupGlMarker()
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
	if markerShader and markerShader.Finalize then
		markerShader:Finalize()
	end
	markerInstanceVBO = nil
	markerQuadVBO = nil
	markerShader = nil
	markerReady = false
	markerInitFailed = false
end


local function getApi()
	return WG and WG['squadselection']
end


local function markerVisible(sq)
	return sq and (not sq.isReserve or showReservesCache)
end


local function pushUnit(unitId, sq)
	if not markerReady or not sq.color then
		return
	end
	markerInstanceCache[1] = sq.color[1]
	markerInstanceCache[2] = sq.color[2]
	markerInstanceCache[3] = sq.color[3]
	pushElementInstance(markerInstanceVBO, markerInstanceCache, unitId, true, false, unitId)
end


local function popUnit(unitId)
	if not markerReady then
		return
	end
	if markerInstanceVBO.instanceIDtoIndex[unitId] then
		popElementInstance(markerInstanceVBO, unitId)
	end
end


local function rebuildAll()
	if not markerReady then
		return
	end

	local api = getApi()
	if not api or not api.getSquadState then
		return
	end

	local state = api.getSquadState()
	if not state then
		return
	end

	showReservesCache = api.getShowReserveSquads and api.getShowReserveSquads() or false

	local desired = {}
	for i = 1, #state.squads do
		local sq = state.squads[i]
		if #sq > 0 and markerVisible(sq) then
			for j = 1, #sq do
				local uid = sq[j]
				desired[uid] = true
				pushUnit(uid, sq)
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


local function onSquadChange(event, unitId, squad)
	if not markerReady and not initGlMarker() then
		return
	end

	if event == "add" then
		if markerVisible(squad) then
			pushUnit(unitId, squad)
		end
	elseif event == "remove" then
		popUnit(unitId)
	elseif event == "rebuild" then
		rebuildAll()
	end
end


local drawErrorLogged = false

function widget:Initialize()
	if not LuaShader or not InstanceVBOTable then
		Spring.Echo("[Squad Colored Markers] GL4 not available, removing widget")
		widgetHandler:RemoveWidget()
		return
	end

	local api = getApi()
	if api and api.addSquadChangeListener then
		if initGlMarker() then
			listenerFn = onSquadChange
			api.addSquadChangeListener(listenerFn)
		else
			Spring.Echo("[Squad Colored Markers] GL init failed: " .. tostring(markerFailReason))
			widgetHandler:RemoveWidget()
		end
	end
end


function widget:Update()
	if listenerFn then
		return
	end
	local api = getApi()
	if api and api.addSquadChangeListener then
		if not markerReady and not initGlMarker() then
			if not drawErrorLogged then
				Spring.Echo("[Squad Colored Markers] GL init failed: " .. tostring(markerFailReason))
				drawErrorLogged = true
			end
			return
		end
		listenerFn = onSquadChange
		api.addSquadChangeListener(listenerFn)
	end
end


function widget:DrawWorldPreUnit()
	if spIsGUIHidden() then
		return
	end
	if not markerReady or not markerInstanceVBO or markerInstanceVBO.usedElements == 0 then
		return
	end

	-- Detect showReserveSquads toggle.
	local api = getApi()
	if api then
		local sr = api.getShowReserveSquads and api.getShowReserveSquads() or false
		if sr ~= showReservesCache then
			showReservesCache = sr
			rebuildAll()
			if markerInstanceVBO.usedElements == 0 then
				return
			end
		end
	end

	local vsx, vsy = spGetViewGeometry()

	glDepthTest(false)
	glDepthMask(false)
	glBlending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
	markerShader:Activate()
	markerShader:SetUniform("viewport", vsx, vsy)
	markerShader:SetUniform("opacity", MARKER_OPACITY)
	markerShader:SetUniform("size", MARKER_SIZE_PX)
	markerInstanceVBO.VAO:DrawArrays(GL.TRIANGLE_STRIP, 4, 0, markerInstanceVBO.usedElements, 0)
	markerShader:Deactivate()
	glBlending(false)
	glDepthMask(true)
	glDepthTest(true)
end


function widget:Shutdown()
	if listenerFn then
		local api = getApi()
		if api and api.removeSquadChangeListener then
			api.removeSquadChangeListener(listenerFn)
		end
		listenerFn = nil
	end
	cleanupGlMarker()
end


