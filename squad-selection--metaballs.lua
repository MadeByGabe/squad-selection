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
local initFailed = false

local stencilShader = nil
local fullscreenShader = nil
local circleInstanceVBO = nil
local stencilTexture = nil
local fullscreenVAO = nil
local fullscreenVBO = nil

local circleInstanceCache = {0, 0, 0, 0, 0, 0, 0, 0}
local listenerFn = nil
local showReservesCache = false

local isAir = {} -- defID -> bool
local defidCache = {} -- unitID -> defID or false

local function getDefid(unitId)
	local v = defidCache[unitId]
	if v ~= nil then
		return v
	end
	local id = Spring.GetUnitDefID(unitId)
	v = id or false
	defidCache[unitId] = v
	return v
end


-------------------------------------------------------------------------------
-- Shaders (inline)
-------------------------------------------------------------------------------

local stencilVsSrc = [[
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

local stencilFsSrc = [[
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

local fullscreenVsSrc = [[
#version 430 core

layout (location = 0) in vec2 position;

out vec2 v_uv;

void main() {
    gl_Position = vec4(position, 0.0, 1.0);
    v_uv = position * 0.5 + 0.5;
}
]]

local fullscreenFsSrc = [[
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

local function createStencilTexture()
	local vsx, vsy = spGetViewGeometry()
	if stencilTexture then
		gl.DeleteTexture(stencilTexture)
	end
	stencilTexture = gl.CreateTexture(vsx / STENCIL_RESOLUTION, vsy / STENCIL_RESOLUTION, {
		fbo = true,
		minFilter = GL.NEAREST,
		magFilter = GL.LINEAR,
		wrapS = GL.CLAMP_TO_EDGE,
		wrapT = GL.CLAMP_TO_EDGE,
	})
	return stencilTexture ~= nil
end


local function initGl()
	if ready or initFailed then
		return ready
	end
	if not gl.CreateShader or not LuaShader or not InstanceVBOTable then
		initFailed = true
		return false
	end

	local engineDefs = LuaShader.GetEngineUniformBufferDefs()
	local vsSrc = stencilVsSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineDefs)
	local fsSrc = stencilFsSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineDefs)

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
		initFailed = true
		return false
	end

	fullscreenShader = LuaShader({
		vertex = fullscreenVsSrc,
		fragment = fullscreenFsSrc,
		uniformInt = {
			stencilTex = 0,
		},
	}, "Squad Metaballs Fullscreen GL4")

	if not fullscreenShader:Initialize() then
		spEcho("[Squad Metaballs] fullscreen shader compile failed")
		stencilShader:Finalize()
		stencilShader = nil
		fullscreenShader = nil
		initFailed = true
		return false
	end

	if not createStencilTexture() then
		spEcho("[Squad Metaballs] stencil texture creation failed")
		stencilShader:Finalize()
		fullscreenShader:Finalize()
		stencilShader = nil
		fullscreenShader = nil
		initFailed = true
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


local function cleanupGl()
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
	initFailed = false
	defidCache = {}
end


-------------------------------------------------------------------------------
-- Instance management
-------------------------------------------------------------------------------

local function getApi()
	return WG and WG['squadselection']
end


local function markerVisible(sq)
	return sq and (not sq.isReserve or showReservesCache)
end


local function pushUnit(unitId, sq)
	if not ready or not sq.color then
		return
	end
	local defId = getDefid(unitId)
	circleInstanceCache[1] = (defId and isAir[defId]) and -CIRCLE_RADIUS or CIRCLE_RADIUS
	circleInstanceCache[2] = sq.color[1]
	circleInstanceCache[3] = sq.color[2]
	circleInstanceCache[4] = sq.color[3]
	pushElementInstance(circleInstanceVBO, circleInstanceCache, unitId, true, false, unitId)
end


local function popUnit(unitId)
	if not ready then
		return
	end
	if circleInstanceVBO.instanceIDtoIndex[unitId] then
		popElementInstance(circleInstanceVBO, unitId)
	end
	defidCache[unitId] = nil
end


local function rebuildAll()
	if not ready then
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

	for uid in pairs(circleInstanceVBO.instanceIDtoIndex) do
		if not desired[uid] then
			popElementInstance(circleInstanceVBO, uid)
		end
	end
end


local function onSquadChange(event, unitId, squad)
	if not ready and not initGl() then
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
			isAir[defID] = true
		end
	end

	local api = getApi()
	if api and api.addSquadChangeListener then
		if initGl() then
			listenerFn = onSquadChange
			api.addSquadChangeListener(listenerFn)
		else
			spEcho("[Squad Metaballs] GL init failed, removing widget")
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
		if not ready and not initGl() then
			return
		end
		listenerFn = onSquadChange
		api.addSquadChangeListener(listenerFn)
	end
end


function widget:ViewResize()
	if ready then
		createStencilTexture()
	end
end


local function drawStencilPass()
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
		gl.RenderToTexture(stencilTexture, drawStencilPass)
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
	local api = getApi()
	if api then
		local sr = api.getShowReserveSquads and api.getShowReserveSquads() or false
		if sr ~= showReservesCache then
			showReservesCache = sr
			rebuildAll()
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
	if listenerFn then
		local api = getApi()
		if api and api.removeSquadChangeListener then
			api.removeSquadChangeListener(listenerFn)
		end
		listenerFn = nil
	end
	cleanupGl()
end


