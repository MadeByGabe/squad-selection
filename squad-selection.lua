local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Squad Selection",
		desc = "Automagical squad creation and proximity-based selection",
		author = "Baldric, yyyy",
		date = "2026",
		license = "GNU GPL, v2 or later",
		layer = 300,
		enabled = true,
	}
end


-------------------------------------------------------------------------------
-- Squad Selection
--
-- Feature gallery:        https://bar-stuff.madebygabe.dev/squad-selection
-- Readme / documentation: https://github.com/MadeByGabe/squad-selection
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Config
-------------------------------------------------------------------------------

local config = {
	preset = "custom", -- active playstyle preset; see PRESETS below. Defaults to "custom" so the widget never presumes a playstyle: a fresh install, or a config saved before presets existed, keeps every setting exactly as it is until the player picks one
	cyclingToNextSquad = true, -- when full squad/type is selected, exclude it to cycle to next
	leftClickSelectsSquad = true, -- left-click can be used to select squads
	leftClickAlternativeSelection = false, -- switches left-click (replace and append) between the normal selection — the whole closest squad, any kind, no distance cap — and the alternative one defined by leftClickAlternativeArgs. Bind a hotkey via `squad_setting toggle leftClickAlternativeSelection` to flip on demand
	leftClickAlternativeArgs = {1, 0.5, "distance_850"}, -- what the alternative left-click selection does; same tokens as the squad_select_portion action: step values, an optional "distance_<N>" cap and an optional "manual"/"reserve" squad-kind filter. Default is 100% then 50% within 850 elmos.
	leftClickAppendFiltersDomain = true, -- when true, left-click Shift-append only cycles into squads whose domains ⊆ the selection's; when false, append behaves like the plain `append` keyword
	leftClickFilteredRetargets = true, -- when true, Alt+Ctrl-click (replace-mode filtered) acts like the `retarget` keyword: if the closest unit's type isn't in the current selection, treat the click as a fresh selection on that new type instead of using the selection's types as the filter. Append mode is unaffected.
	rightClickSquadCreate = false, -- right-click creates squads; bind a hotkey via `squad_setting toggle rightClickSquadCreate` to flip on demand
	rightClickMovesSquad = true, -- right-click commands the closest squad
	rightClickMoveRange = 850, -- max world-distance (elmos) from the cursor for the right-click-move feature to highlight/pick a squad; 0 = unlimited. Also caps the passive closest-squad highlight, even when rightClickMovesSquad is off — left-click select itself has no cap, so a squad farther than this is still selectable, just not previewed
	rightClickMoveControlsReserves = false, -- when false, the right-click-move feature ignores reserve squads and only picks manual ones; when true it can command reserves too and converts the commanded reserve into a manual squad
	ctrlRightClickCreatesSquad = false, -- Ctrl+right-click creates a squad (click still passes through, so the engine's move-in-formation runs too which can cause issues)
	ctrlRightClickDragCreatesSquad = true, -- hold Ctrl then right-click drag past the engine's MouseDragFrontCommandThreshold to create a squad (click still passes through)
	commandCreatesSquad = false,
	mergeIntoReserves = true, -- when false, `squad_create` never merges the selection into a reserve squad; it always creates a fresh manual squad
	showReserveSquads = false, -- when true, auto per-factory reserves + uncategorized reserve are visualized
	viewselectionDoubleTapMs = 300, -- second rapid same-place non-append squad-select tap (single-step, or multi-step at the last step) calls viewselection on the just-selected squad (0 disables)
	viewselectionDoubleTapPx = 5, -- max screen-pixel distance between the two taps (0 disables the gesture, same as Ms — the comparison is strict)
	mruSize = 3, -- how many recent squads squad_cycle_recent cycles through
	excludeConstructors = true, -- when true, the curated constructor/commander list (CONSTRUCTOR_UNITS) is excluded from squad tracking
	excludeResurrectionUnits = false, -- when true, the curated resurrection-unit list (RESURRECTION_UNITS) is excluded from squad tracking
	excludeCombatEngineers = false, -- when true, the curated combat-engineer list (COMBAT_ENGINEER_UNITS) is excluded from squad tracking
	excludedUnitTypes = "", -- comma-separated unit names the player has manually excluded from squad tracking (independent of the three toggles above)
	visualizationMode = "convexHull", -- "convexHull" or "none"
	showVisualizationOptions = false, -- panel-only: reveal the detailed hull options
	convexHullPadding = 60, -- space (in elmos) between the units and the hull boundary
	convexHullArcResolution = 0.4, -- angle that each chord of the arc spans in radians; smaller = smoother but more expensive
	convexHullFillOpacity = 0.25,
	convexHullBorderOpacity = 0.3,
	convexHullBorderThickness = 2,
	convexHullColorMode = "player", -- "player" (player color), "custom" (single custom RGB), "squad" (per-squad golden-ratio hue)
	convexHullCustomColorR = 0, -- Red component of custom hull color (0–1)
	convexHullCustomColorG = 0.3, -- Green component
	convexHullCustomColorB = 0.7, -- Blue component
	-- Animation tuning (no panel control).
	reserveStripePeriod = 64, -- diagonal-stripe period in world elmos for reserve squad fills
	reserveStripeAlphaMul = 0.3, -- opacity of the dim stripe band relative to the bright band
	hullPulseAmplitude = 0.25, -- breathing pulse amplitude on hull alpha
	hullPulseRate = 1.5, -- breathing pulse rate; period ≈ 2π / rate seconds
	idleColorBlendSeconds = 0.5, -- seconds for the idle/active hull color to fully crossfade (0 = instant)
	highlightBlendSeconds = 0.1, -- seconds for the closest-squad highlight to fade in/out (0 = instant)
	debug = false,
}

-- Snapshot of the defaults defined above, used by `squad_setting reload`.
local configDefaults = {}
for k, v in pairs(config) do
	configDefaults[k] = v
end

-------------------------------------------------------------------------------
-- Playstyle presets
--
-- The widget supports several playstyles and each one wants a different set of
-- its switches. A preset owns a group of settings and writes them all in one
-- go; `custom` owns nothing. Writing an owned setting by hand afterwards (panel
-- row, squad_setting, WG setter) drops the active preset back to `custom`, so
-- the preset shown never lies about what the config actually holds.
-------------------------------------------------------------------------------

local PRESET_NAMES = {"minimal", "autogroup", "squad", "custom"}

local PRESETS = {
	-- Least surprising way to use the widget.
	minimal = {
		cyclingToNextSquad = false,
		leftClickAppendFiltersDomain = false,
		leftClickAlternativeSelection = false,
		mergeIntoReserves = true,
		rightClickSquadCreate = false,
		ctrlRightClickCreatesSquad = false,
		ctrlRightClickDragCreatesSquad = true,
		rightClickMoveControlsReserves = false,
		showReserveSquads = false,
		visualizationMode = "convexHull",
		convexHullColorMode = "player",
	},
	-- For players who mostly filter their group selections and only occasionally build a manual squad.
	autogroup = {
		cyclingToNextSquad = true,
		leftClickAppendFiltersDomain = true,
		leftClickAlternativeSelection = false,
		mergeIntoReserves = true,
		rightClickSquadCreate = false,
		ctrlRightClickCreatesSquad = false,
		ctrlRightClickDragCreatesSquad = true,
		rightClickMoveControlsReserves = false,
		showReserveSquads = true,
		visualizationMode = "convexHull",
		convexHullColorMode = "player",
	},
	-- For players who create and merge manual squads constantly.
	squad = {
		cyclingToNextSquad = true,
		leftClickAppendFiltersDomain = true,
		leftClickAlternativeSelection = true,
		mergeIntoReserves = false,
		rightClickSquadCreate = true,
		ctrlRightClickCreatesSquad = false,
		ctrlRightClickDragCreatesSquad = false,
		rightClickMoveControlsReserves = true,
		showReserveSquads = true,
		visualizationMode = "convexHull",
		convexHullColorMode = "squad",
	},
	custom = {},
}

-- Union of every key any preset writes.
local PRESET_OWNED_KEYS = {}
for _, values in pairs(PRESETS) do
	for key in pairs(values) do
		PRESET_OWNED_KEYS[key] = true
	end
end

-------------------------------------------------------------------------------
-- Localized Spring API
--
-- Avoids repeated global table lookups. Matters most in DrawScreen where we
-- iterate every tracked unit each frame; negligible for one-shot calls in
-- Initialize, but kept here as an at-a-glance "imports" list.
-------------------------------------------------------------------------------

local spEcho = Spring.Echo
local spGetMyTeamID = Spring.GetMyTeamID
local spGetTeamUnits = Spring.GetTeamUnits
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitPosition = Spring.GetUnitPosition
local spGetSelectedUnits = Spring.GetSelectedUnits
local spSelectUnitArray = Spring.SelectUnitArray
local spGetMouseState = Spring.GetMouseState
local spTraceScreenRay = Spring.TraceScreenRay
local spIsGUIHidden = Spring.IsGUIHidden
local spGetModKeyState = Spring.GetModKeyState
local spGetSpectatingState = Spring.GetSpectatingState
local spGetActiveCommand = Spring.GetActiveCommand
local spGetDefaultCommand = Spring.GetDefaultCommand
local spGetMyPlayerID = Spring.GetMyPlayerID
local spGetGroupUnits = Spring.GetGroupUnits
local spGetUnitGroup = Spring.GetUnitGroup
local spGetMouseCursor = Spring.GetMouseCursor
local spGetConfigInt = Spring.GetConfigInt
local spIsReplay = Spring.IsReplay
local spGetGroundHeight = Spring.GetGroundHeight
local spGetUnitCommandCount = Spring.GetUnitCommandCount
local spGetTeamColor = Spring.GetTeamColor
local spSendCommands = Spring.SendCommands
local spGiveOrder = Spring.GiveOrder
local spGetMiniMapGeometry = Spring.GetMiniMapGeometry
local spIsSphereInView = Spring.IsSphereInView
local spGetTimer = Spring.GetTimer
local spDiffTimers = Spring.DiffTimers
local spGetUnitsInCylinder = Spring.GetUnitsInCylinder
local spGetMiniMapRotation = Spring.GetMiniMapRotation

local glColor = gl.Color
local glDepthTest = gl.DepthTest
local glLineWidth = gl.LineWidth
local glCreateShader = gl.CreateShader
local glDeleteShader = gl.DeleteShader
local glUseShader = gl.UseShader
local glGetUniformLocation = gl.GetUniformLocation
local glUniform = gl.Uniform
local glGetVBO = gl.GetVBO
local glGetVAO = gl.GetVAO

-------------------------------------------------------------------------------
-- State
-------------------------------------------------------------------------------

local squads = {} -- ordered list of squad arrays
local unitSquad = {} -- unitID -> the squad array it belongs to
local unitSlot = {} -- unitID -> index within that squad (for O(1) removal)
local factorySquad = {} -- factoryUnitID -> squad (every factory gets an auto-created squad)
local uncategorizedReserve = {} -- domain -> reserve squad ("land" | "air" | "naval") for units with no factory origin

local mru = {} -- most-recently-used squads, newest at index 1

local squadSelCount = {} -- squad table -> number of selected units in it
local selectionDirty = true -- forces a full recount on the first draw frame
local squadIdleState = {} -- squad table -> true when >50% of the squad is idle
local squadIdleBlend = {} -- squad table -> 0..1 blend between team color and idle color
local squadHighlightBlend = {} -- squad table -> 0..1 blend for the closest-squad preview highlight (opacity only)
local squadControlBlend = {} -- squad table -> 0..1 blend for the actively-commanded squad (RMB held); adds the border emphasis
local squadHideIdleAirHull = {} -- squad table -> true when an idle squad is entirely airborne air units
local idleScanIndex = 0 -- round-robin index into squads for incremental idle-state updates

local highlightTarget = nil
local controlTarget = nil
local highlightRecomputeAccum = 0.0 -- dt accumulator (seconds) gating the throttle recompute
local HIGHLIGHT_RECOMPUTE_INTERVAL = 1 / 30 -- 30 Hz is enough for a cosmetic highlight

local pendingDragCreate = nil -- { x, y } screen pos of a Ctrl+RMB press awaiting a drag past MouseDragFrontCommandThreshold to fire squad_create (config.ctrlRightClickDragCreatesSquad)
local pendingSquadMove = nil -- { squad, formation, keepSelection, x, y, requiresDrag, dragged } captured on an Alt/Space RMB (or plain RMB with empty selection) press (config.rightClickMovesSquad)
local highlightLockedSquad = nil -- while Shift is held over the squad-move highlight, the latched target squad — so a Shift-queue stays on one squad even as the cursor drifts near others
local beforeSquadSelectCallback = nil -- optional WG hook: return false to cancel a doSquadSelect call
local squadChangeListeners = {} -- array of callback functions

-- Unit classification caches (declared early so utility helpers capture locals, not globals).
local defidOf = {} -- unitID -> defID (false when lookup fails)
local isCombat = {} -- defID -> bool
local isFactory = {} -- defID -> bool (immobile with buildOptions)
local isStrafingAir = {} -- defID -> bool (air units that strafe/fly around while idle)
local unitDomain = {} -- defID -> "land" | "air" | "naval"

local lastSquadSelect = nil -- { t, x, y, append, kind, squad } of most recent successful doSquadSelect; powers two same-mode double-tap gestures (replace→replace fires viewselection, append→append upgrades plain append to append_domain), both gated to a matching `kind` (selection type) so mixed sequences don't fire, and gates the reserve-merge branch of createSquadFromSelection on `squad`

-------------------------------------------------------------------------------
-- Debug
-------------------------------------------------------------------------------

-- Varargs so call sites pay no concatenation cost when debug is off.
local function log(...)
	if not config.debug then
		return
	end
	local n = select("#", ...)
	if n == 1 then
		spEcho("[Squad] " .. tostring((...)))
		return
	end
	local parts = {...}
	for i = 1, n do
		parts[i] = tostring(parts[i])
	end
	spEcho("[Squad] " .. table.concat(parts))
end


-------------------------------------------------------------------------------
-- Utility
-------------------------------------------------------------------------------

local function constrain(x, min, max)
	return math.max(min, math.min(max, x))
end


-- Move `current` toward `target` by at most `step` (for animated blends).
local function approach(current, target, step)
	if current < target then
		return math.min(current + step, target)
	end
	return math.max(current - step, target)
end


-- Recompute whether a squad is "idle" (>50% units with no commands).
local function refreshSquadIdleState(sq)
	local size = #sq
	if size == 0 then
		squadIdleState[sq] = false
		squadHideIdleAirHull[sq] = false
		return false
	end

	local threshold = math.floor(size * 0.5) + 1
	local idle = 0
	local idleReached = false
	for i = 1, size do
		if spGetUnitCommandCount(sq[i]) == 0 then
			idle = idle + 1
			if idle >= threshold then
				idleReached = true
				break
			end
		end
		if idle + (size - i) < threshold then
			break
		end
	end

	if not idleReached then
		squadIdleState[sq] = false
		squadHideIdleAirHull[sq] = false
		return false
	end

	squadIdleState[sq] = true

	-- Hide hull only when the whole squad is strafing-air and currently flying.
	local hideHull = true
	for i = 1, size do
		local u = sq[i]
		local defId = defidOf[u]
		if not (defId and isStrafingAir[defId]) then
			hideHull = false
			break
		end
		local x, y, z = spGetUnitPosition(u)
		if not x then
			hideHull = false
			break
		end
		if y <= spGetGroundHeight(x, z) + 50 then
			hideHull = false
			break
		end
	end
	squadHideIdleAirHull[sq] = hideHull
	return true
end


local function sweepIdleState()
	local present = {}
	for i = 1, #squads do
		present[squads[i]] = true
	end
	for sq, _ in pairs(squadIdleState) do
		if not present[sq] then
			squadIdleState[sq] = nil
			squadIdleBlend[sq] = nil
			squadHideIdleAirHull[sq] = nil
			squadHighlightBlend[sq] = nil
			squadControlBlend[sq] = nil
		end
	end
	if highlightLockedSquad and not present[highlightLockedSquad] then
		highlightLockedSquad = nil
	end
end


-------------------------------------------------------------------------------
-- Squad identity
--
-- Each squad gets a monotonically increasing integer index on creation,
-- stored as squad.index. Companion widgets use this to derive their own
-- colors, letters, or other visuals. squad.tag_seed (golden-ratio step
-- over index) is used internally for hull animation phase offsets and color.
-------------------------------------------------------------------------------

local nextSquadTag = 0

-------------------------------------------------------------------------------
-- Per-squad color helpers
-------------------------------------------------------------------------------

local GOLDEN_HUE_STEP = 0.381966
local SQUAD_SAT = 0.75
local SQUAD_VAL = 0.7

local function hsvToRgb(h, s, v)
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


local function indexToColor(idx)
	local h = ((idx - 1) * GOLDEN_HUE_STEP) % 1
	return hsvToRgb(h, SQUAD_SAT, SQUAD_VAL)
end


local function assignSquadTag(squad)
	nextSquadTag = nextSquadTag + 1
	squad.index = nextSquadTag
	-- Golden-ratio step spreads consecutive squads ~0.618 of a period apart.
	squad.tagSeed = nextSquadTag * 0.6180339887
	squad.color = {indexToColor(nextSquadTag)}
end


-- Unit classification
--
-- isCombat[defID] — true if the unit type is squad-eligible.
-------------------------------------------------------------------------------

local function getDefid(unitId)
	local v = defidOf[unitId]
	if v ~= nil then
		return v
	end
	local id = spGetUnitDefID(unitId)
	v = id or false
	defidOf[unitId] = v
	return v
end


-- Curated constructor + commander list. Every mobile unit is squad-eligible by
-- default; these are excluded when config.excludeConstructors is on. A literal
-- list (rather than a buildOptions heuristic) because BAR has too many
-- faction/tier/edge cases — combat units that happen to build (Commando, Infestor)
local CONSTRUCTOR_UNITS = "armcom,corcom,armca,corca,armck,corck,armcs,corcs,armbeaver,cormuskrat,armcv,corcv,armaca,coraca,corch,armch,armack,corack,corcsa,armcsa,armacv,coracv,armacsub,coracsub,legck,legcom,legack,legcv,legotter,legacv,legca,legaca,legnavyconship,leganavyconsub,legch,legspcon"

-- Curated resurrection-unit list. 
local RESURRECTION_UNITS = "armrectr,cornecro,legrezbot,legnavyrezsub,armrecl,correcl"

-- Curated combat-engineer list.
local COMBAT_ENGINEER_UNITS = "armfark,legaceb,armconsul,corfast,legdecom,armdecom,cordecom,leganavyengineer,armmls,cormls"

--- Parse a comma-separated name list into `set[name] = true` (whitespace trimmed).
local function addExcludedNames(set, csv)
	for name in csv:gmatch("[^,]+") do
		set[name:match("^%s*(.-)%s*$")] = true
	end
end


--- Pre-compute isCombat for every defID in one pass.
--
-- Squad eligibility is "any mobile unit, minus exclusions". 
local function classifyUnitdefs()
	local excluded = {}
	if config.excludeConstructors then
		addExcludedNames(excluded, CONSTRUCTOR_UNITS)
	end
	if config.excludeResurrectionUnits then
		addExcludedNames(excluded, RESURRECTION_UNITS)
	end
	if config.excludeCombatEngineers then
		addExcludedNames(excluded, COMBAT_ENGINEER_UNITS)
	end
	if config.excludedUnitTypes and config.excludedUnitTypes ~= "" then
		addExcludedNames(excluded, config.excludedUnitTypes)
	end

	for defID, def in pairs(UnitDefs) do
		-- Squad eligibility, speed is needed because of mines
		if def.canMove and def.speed and def.speed > 0 and not excluded[def.name] then
			isCombat[defID] = true
		else
			isCombat[defID] = false
		end

		if def.isFactory then
			isFactory[defID] = true
		end

		isStrafingAir[defID] = def.isStrafingAirUnit and true or false

		if def.canFly then
			unitDomain[defID] = "air"
		elseif def.minWaterDepth and def.minWaterDepth > 0 then
			unitDomain[defID] = "naval"
		else
			unitDomain[defID] = "land"
		end
	end
end


local function reserveDomainForDef(defId)
	return unitDomain[defId] or "land"
end


local function getUncategorizedReserveForDef(defId)
	local d = reserveDomainForDef(defId)
	return uncategorizedReserve[d] or uncategorizedReserve.land
end


-------------------------------------------------------------------------------
-- Squad change listeners
--
-- Companion widgets register via WG['squadselection'].addSquadChangeListener(fn).
-- Callbacks receive (event, unitID, squad):
--   "add"     — unitID was added to squad
--   "remove"  — unitID was removed from squad (fired before internal cleanup)
--   "rebuild" — wholesale state change; unitID and squad are nil.
--               Listeners should re-read getSquadState() and rebuild from scratch.
-- Registering a listener immediately fires "rebuild" so the companion can sync.
-------------------------------------------------------------------------------

local function notifySquadChange(event, unitId, squad)
	for i = 1, #squadChangeListeners do
		local ok, err = pcall(squadChangeListeners[i], event, unitId, squad)
		if not ok then
			spEcho("[Squad] listener error: " .. tostring(err))
		end
	end
end


-------------------------------------------------------------------------------
-- Squad operations
-------------------------------------------------------------------------------

local function addToSquad(unitId, squad)
	local slot = #squad + 1
	squad[slot] = unitId
	unitSquad[unitId] = squad
	unitSlot[unitId] = slot
	if squad.index then
		notifySquadChange("add", unitId, squad)
	end
	squadIdleState[squad] = false
	squadHideIdleAirHull[squad] = false
end


-- Swap-with-last removal: O(1), order within a squad is not meaningful.
local function removeFromSquad(unitId)
	local squad = unitSquad[unitId]
	if not squad then
		return
	end

	notifySquadChange("remove", unitId, squad)

	local slot = unitSlot[unitId]
	local last = squad[#squad]

	if last ~= unitId then
		squad[slot] = last
		unitSlot[last] = slot
	end

	squad[#squad] = nil
	unitSquad[unitId] = nil
	unitSlot[unitId] = nil
	squadIdleState[squad] = false
	squadHideIdleAirHull[squad] = false
end


-------------------------------------------------------------------------------
-- MRU (most-recently-used squads)
--
-- Push points are both inside createSquadFromSelection: successful squad
-- creation, and right-click on a selection that already matches an existing squad. 
-- Plain selection changes and command issuance do NOT push.
-------------------------------------------------------------------------------

local function pushToMru(sq)
	if not sq then
		return
	end
	for i = 1, #mru do
		if mru[i] == sq then
			table.remove(mru, i)
			break
		end
	end
	table.insert(mru, 1, sq)
	while #mru > config.mruSize do
		mru[#mru] = nil
	end
end


local function sweepMru()
	local present = {}
	for _, sq in ipairs(squads) do
		present[sq] = true
	end
	for i = #mru, 1, -1 do
		if not present[mru[i]] then
			table.remove(mru, i)
		end
	end
end


local function recallMru(i)
	local sq = mru[i]
	if not sq then
		return
	end
	local units = {}
	for j = 1, #sq do
		units[j] = sq[j]
	end
	spSelectUnitArray(units)
	spSendCommands("viewselection")
end


-- A squad is prunable when empty, except:
--   - the uncategorized reserve is permanent
--   - factory reserves are kept while any factory still references them
local function isPrunable(sq)
	if #sq ~= 0 then
		return false
	end
	if sq.uncatDomain then
		return false
	end
	if sq.fromFactory then
		for _, fsq in pairs(factorySquad) do
			if fsq == sq then
				return false
			end
		end
		return true
	end
	return not sq.isReserve
end


local function pruneEmptySquads()
	for i = #squads, 1, -1 do
		local sq = squads[i]
		if isPrunable(sq) then
			log("Squad [", sq.index or "?", "] emptied and removed")
			squadSelCount[sq] = nil
			table.remove(squads, i)
		end
	end
	sweepMru()
	sweepIdleState()
end


-------------------------------------------------------------------------------
-- Squad creation from selection
-------------------------------------------------------------------------------

-- Returns true if every unit in `sq` is present in `selectedSet`.
-- Empty squads return false to avoid vacuous matches.
local function squadFullySelected(sq, selectedSet)
	if #sq == 0 then
		return false
	end
	for i = 1, #sq do
		if not selectedSet[sq[i]] then
			return false
		end
	end
	return true
end


-- Returns the squad if the selection's combat units exactly match one squad
-- (including reserves), nil otherwise.
local function selectionIsExistingSquad(selected)
	local squad = nil
	local combatCount = 0
	for i = 1, #selected do
		local u = selected[i]
		local defId = getDefid(u)
		if defId and isCombat[defId] then
			combatCount = combatCount + 1
			local s = unitSquad[u]
			if squad == nil then
				squad = s
			elseif s ~= squad then
				return nil
			end
		end
	end
	if squad == nil or #squad ~= combatCount then
		return nil
	end
	return squad
end


--- Create a new hidden reserve squad and register it in `squads`.
-- Used for per-factory auto-squads and the uncategorized reserve.
local function makeReserveSquad(fromFactory)
	local sq = {}
	assignSquadTag(sq)
	sq.isReserve = true
	sq.fromFactory = fromFactory or false
	squads[#squads + 1] = sq
	return sq
end


--- Auto-create a reserve squad for a newly built/received factory.
local function createFactorySquad(factoryId)
	local sq = makeReserveSquad(true)
	factorySquad[factoryId] = sq
	log("Factory ", factoryId, " → auto squad [", sq.index, "]")
	return sq
end


--- "This selection becomes one squad" — merges or splits depending on state.
--  - If the selection already exactly occupies one squad (no other factories
--    reference it) → no-op.
--  - Otherwise → reassign all selected factories to a fresh shared squad.
--    Units already built stay in their old squads
local function assignFactorySquad()
	local selected = spGetSelectedUnits()
	local factories = {}
	for i = 1, #selected do
		local u = selected[i]
		local defId = getDefid(u)
		if defId and isFactory[defId] then
			factories[#factories + 1] = u
		end
	end
	if #factories == 0 or #factories ~= #selected then
		return
	end

	-- Detect the "already exactly one squad" case.
	local selectionSet = {}
	for i = 1, #factories do
		selectionSet[factories[i]] = true
	end
	local shared = factorySquad[factories[1]]
	local allShare = shared ~= nil
	for i = 2, #factories do
		if factorySquad[factories[i]] ~= shared then
			allShare = false
			break
		end
	end
	if allShare then
		local extra = false
		for fid, sq in pairs(factorySquad) do
			if sq == shared and not selectionSet[fid] then
				extra = true
				break
			end
		end
		if not extra then
			return
		end
	end

	-- Reassign all selected factories to a fresh shared squad.
	local newSquad = makeReserveSquad(true)
	for i = 1, #factories do
		factorySquad[factories[i]] = newSquad
	end

	pruneEmptySquads()

	log("Factory squad [", newSquad.index, "] assigned to ", #factories, " factory(s)")
end


local playerInputSinceLastResquad = false
local function createSquadFromSelection(unitThatMustBeInSelection)
	local selected = spGetSelectedUnits()
	if #selected == 0 then
		return
	end

	local requiredUnitPresent = false
	if unitThatMustBeInSelection then
		for i = 1, #selected do
			if selected[i] == unitThatMustBeInSelection then
				requiredUnitPresent = true
			end
		end
		if not requiredUnitPresent then
			return
		end
	end

	local existing = selectionIsExistingSquad(selected)
	if existing and not existing.isReserve then
		pushToMru(existing)
		return
	end

	-- `existing` being nil here means the selection spans more than one squad
	-- (or partial squads). If it fully contains a reserve squad in that mix
	-- AND the player's last widget squad-select targeted that same reserve,
	-- merge the rest of the selection INTO that reserve instead of creating a
	-- new manual squad. When the selection is exactly one reserve (`existing`
	-- set + isReserve), we skip this branch and fall through to new-squad
	-- creation — extracting the reserve into a manual squad is the intended
	-- action in that case.
	--
	-- The `lastSquadSelect.squad == sq` gate captures player intent: merging
	-- only happens when the player explicitly squad-selected the reserve via
	-- the widget. Manual selections that happen to include all of a (possibly
	-- one-unit) reserve don't trigger merges — common case is selecting a
	-- fresh factory output to reinforce a manual squad, where the new unit's
	-- reserve being trivially "fully selected" used to swallow the manual
	-- squad on squad_create.
	local targetReserve = lastSquadSelect and lastSquadSelect.squad
	if not existing and targetReserve and targetReserve.isReserve and config.mergeIntoReserves then
		local selectedSet = {}
		for i = 1, #selected do
			selectedSet[selected[i]] = true
		end
		if squadFullySelected(targetReserve, selectedSet) then
			local sq = targetReserve
			local moved = 0
			for i = 1, #selected do
				local u = selected[i]
				local defId = getDefid(u)
				if defId and isCombat[defId] and unitSquad[u] ~= sq then
					removeFromSquad(u)
					addToSquad(u, sq)
					moved = moved + 1
				end
			end
			pruneEmptySquads()
			playerInputSinceLastResquad = false
			notifySquadChange("rebuild", nil, nil)
			selectionDirty = true
			pushToMru(sq)

			local units = {}
			for i = 1, #sq do
				units[i] = sq[i]
			end
			spSelectUnitArray(units)

			log("Merged ", moved, " unit(s) → reserve squad [", sq.index or "?", "]")
			return
		end
	end

	local newSquad = {}
	for i = 1, #selected do
		local u = selected[i]
		local defId = getDefid(u)
		if defId and isCombat[defId] then
			removeFromSquad(u)
			addToSquad(u, newSquad)
			playerInputSinceLastResquad = false
		end
	end

	if #newSquad == 0 then
		return
	end

	-- A non-reserve source squad fully consumed by the selection is now
	-- empty; inherit its identity so the player's "real" squad carries on
	-- under the same index instead of getting a fresh one.
	local donor
	for _, sq in ipairs(squads) do
		if #sq == 0 and not sq.isReserve then
			donor = sq
			break
		end
	end

	if donor then
		newSquad.index, newSquad.tagSeed, newSquad.color = donor.index, donor.tagSeed, donor.color
	else
		assignSquadTag(newSquad)
	end
	squads[#squads + 1] = newSquad
	pruneEmptySquads()
	playerInputSinceLastResquad = false
	notifySquadChange("rebuild", nil, nil)
	-- Selection itself didn't change, but selected units moved between squads.
	-- Force DrawWorldPreUnit to rebuild per-squad selected counts.
	selectionDirty = true
	pushToMru(newSquad)

	log("New squad [", newSquad.index, "]: ", #newSquad, " units")
end


-------------------------------------------------------------------------------
-- Finding closest unit
--
-- Resolve the mouse cursor to a world (x, z). Reads the PIP minimap (via the
-- WG API), then the standard engine minimap geometry, then falls back to a
-- screen ray into the 3D world. Both minimap paths account for minimap
-- rotation.
-------------------------------------------------------------------------------

local function getMouseWorldPos()
	local mx, my = spGetMouseState()

	-- PIP minimap: when active, the engine minimap is hidden/minimized so
	-- spGetMiniMapGeometry() returns stale data. Use the WG API instead.
	local wgMinimap = WG and WG["minimap"]
	local wgPip0 = WG and WG["pip0"]
	local pipMinimized = wgPip0 and wgPip0.IsMinimized and wgPip0.IsMinimized()
	if wgMinimap and wgMinimap.isPipMinimapActive and wgMinimap.isPipMinimapActive() and not pipMinimized then
		local getBounds = wgMinimap.getScreenBounds
		local getWorldArea = wgMinimap.getVisibleWorldArea
		if getBounds and getWorldArea then
			local l, b, r, t = getBounds()
			if l and r > l and t > b and mx >= l and mx <= r and my >= b and my <= t then
				local normX = (mx - l) / (r - l)
				local normY = (my - b) / (t - b)

				-- (mirrors gui_pip's PipToWorldCoords).
				local getRotation = wgMinimap.getRotation
				local rot = getRotation and getRotation() or 0
				if rot ~= 0 then
					local dx, dy = normX - 0.5, normY - 0.5
					local cosR, sinR = math.cos(-rot), math.sin(-rot)
					normX = dx * cosR - dy * sinR + 0.5
					normY = dx * sinR + dy * cosR + 0.5
				end

				local wl, wr, wb, wt = getWorldArea()
				local wx = wl + (wr - wl) * normX
				local wz = wb + (wt - wb) * normY
				return wx, wz
			end
		end
	end

	-- Standard minimap (engine geometry).
	local mmX, mmY, mmW, mmH, minimized, maximized = spGetMiniMapGeometry()
	if mmX and mmW > 0 and mmH > 0 and not minimized and not maximized then
		local rx = (mx - mmX) / mmW
		local ry = (my - mmY) / mmH
		if rx >= 0 and rx <= 1 and ry >= 0 and ry <= 1 then
			local relX = rx
			local relY = 1 - ry

			-- (mirrors gui_pip's standard-minimap click handling).
			local rot = spGetMiniMapRotation and spGetMiniMapRotation() or 0
			if rot ~= 0 then
				local dx, dy = relX - 0.5, relY - 0.5
				local cosR, sinR = math.cos(rot), math.sin(rot)
				relX = dx * cosR - dy * sinR + 0.5
				relY = dx * sinR + dy * cosR + 0.5
			end

			local wx = Game.mapSizeX * relX
			local wz = Game.mapSizeZ * relY
			return wx, wz
		end
	end

	-- Normal path: trace screen ray into the 3D world.
	local _, coords = spTraceScreenRay(mx, my, true)
	if not coords then
		return nil
	end
	return coords[1], coords[3] -- world x, world z
end

-- Cylinder radius (elmos) for perf heuristic.
local SEARCH_RADIUS = 850

-- Squad-kind gate shared by both scans: "manual" keeps player-created squads,
-- "reserve" keeps per-factory + uncategorized reserves, nil keeps everything.
local function squadMatchesKind(sq, squadKind)
	if not squadKind then
		return true
	end
	if squadKind == "reserve" then
		return sq.isReserve == true
	end
	return not sq.isReserve
end


-- Full scan over every tracked unit. Fallback when the cylinder finds nothing.
local function findClosestSquadFullScan(filterDefs, groupSet, exclude, wx, wz, domainFilter, maxDistSq, squadKind)
	local bestUnit = nil
	local bestDistSq = maxDistSq or math.huge

	for _, squad in ipairs(squads) do
		local squadOk = squadMatchesKind(squad, squadKind)
		if squadOk and domainFilter then
			for j = 1, #squad do
				local d = unitDomain[defidOf[squad[j]]]
				if d and not domainFilter[d] then
					squadOk = false
					break
				end
			end
		end
		if squadOk then
			for j = 1, #squad do
				local u = squad[j]
				if not (exclude and exclude[u]) and not (groupSet and not groupSet[u]) then
					if not filterDefs or (defidOf[u] and filterDefs[defidOf[u]]) then
						local x, _, z = spGetUnitPosition(u)
						if x then
							local dx = x - wx
							local dz = z - wz
							local distSq = dx * dx + dz * dz
							if distSq < bestDistSq then
								bestDistSq = distSq
								bestUnit = u
							end
						end
					end
				end
			end
		end
	end

	return bestUnit and unitSquad[bestUnit] or nil, bestUnit
end


-- Returns the squad containing the unit closest to (wx, wz), or nil if none.
-- Optional filterDefs (defID set), groupSet (unitID set), and exclude
-- (unitID set) narrow the search. A unit is a candidate only if it passes all three filters.
-- domainFilter (set of allowed domain strings) rejects entire squads whose
-- units include any domain not in the set — so e.g. a pure-land filter skips
-- mixed land+air squads, not just their air units.
-- squadKind ("manual"/"reserve") restricts the search to that kind of squad;
-- nil considers both.
--
-- A cylinder around the cursor pre-filters the candidates. 
local function findClosestSquad(filterDefs, groupSet, exclude, wx, wz, domainFilter, maxDistSq, squadKind)
	local radius = maxDistSq and math.sqrt(maxDistSq) or SEARCH_RADIUS
	local candidates = spGetUnitsInCylinder(wx, wz, radius)

	local bestUnit = nil
	local bestDistSq = maxDistSq or math.huge
	local domainOk = domainFilter and {} -- memo: squad table -> bool

	for i = 1, #candidates do
		local u = candidates[i]
		local squad = unitSquad[u] -- nil for untracked units (enemy/allied/non-combat)
		if squad and squadMatchesKind(squad, squadKind) and not (exclude and exclude[u]) and not (groupSet and not groupSet[u]) then
			if not filterDefs or (defidOf[u] and filterDefs[defidOf[u]]) then
				-- domainFilter is squad-level: check the whole squad, not just its
				-- in-cylinder units. Memoized so each squad is inspected once.
				local squadOk = true
				if domainFilter then
					squadOk = domainOk[squad]
					if squadOk == nil then
						squadOk = true
						for j = 1, #squad do
							local d = unitDomain[defidOf[squad[j]]]
							if d and not domainFilter[d] then
								squadOk = false
								break
							end
						end
						domainOk[squad] = squadOk
					end
				end
				if squadOk then
					local x, _, z = spGetUnitPosition(u)
					if x then
						local dx = x - wx
						local dz = z - wz
						local distSq = dx * dx + dz * dz
						if distSq < bestDistSq then
							bestDistSq = distSq
							bestUnit = u
						end
					end
				end
			end
		end
	end

	-- Unbounded miss: a qualifying squad, if any, is farther than SEARCH_RADIUS.
	if not bestUnit and not maxDistSq then
		return findClosestSquadFullScan(filterDefs, groupSet, exclude, wx, wz, domainFilter, maxDistSq, squadKind)
	end

	return bestUnit and unitSquad[bestUnit] or nil, bestUnit
end


-- Squad-kind filter for the right-click-move pick. Reserves are left alone
-- unless the player opted into commanding them.
local function rightClickMoveSquadKind()
	if config.rightClickMoveControlsReserves then
		return nil
	end
	return "manual"
end


-- True when this right-click already means something to the engine (resurrect a wreck, for example).
local function rightClickWouldIssueOrder()
	local _, activeCmdID = spGetActiveCommand()
	if activeCmdID then
		return true
	end
	if spGetSelectedUnits()[1] == nil then
		return false
	end
	local _, defaultCmdID = spGetDefaultCommand()
	return defaultCmdID ~= nil and defaultCmdID ~= CMD.MOVE
end


-- Hand back a right-click the squad-move gesture consumed but did not use
-- (Alt+RMB without a drag, which is the game's own move-into-formation).
local function giveBackRightClickMove()
	if spGetSelectedUnits()[1] == nil then
		return
	end
	local wx, wz = getMouseWorldPos()
	if not wx then
		return
	end
	local alt, ctrl, meta, shift = spGetModKeyState()
	local opts = CMD.OPT_RIGHT + (alt and CMD.OPT_ALT or 0) + (ctrl and CMD.OPT_CTRL or 0) + (meta and CMD.OPT_META or 0) + (shift and CMD.OPT_SHIFT or 0)
	spGiveOrder(CMD.MOVE, {wx, spGetGroundHeight(wx, wz) or 0, wz}, opts)
end


-------------------------------------------------------------------------------
-- Selection analysis
-------------------------------------------------------------------------------

--- Inspect the current selection and return a summary used by squad-select actions.
--
-- Returns a table with:
--   selectedSet        — set (unitID → true) for O(1) membership tests
--   selectedTypeSet    — set of defIDs present in the selection (only from
--                          tracked squad units). Used to filter squads by unit
--                          type, e.g. "select all Grunts in the closest squad".
--   selectedDomainSet  — set of domains ("land"/"air"/"naval") in the
--                          selection. Used by append_domain to constrain
--                          cycling to compatible squads.
--   hasTrackedUnits    — true when at least one selected unit is a tracked
--                          squad unit with a known type. When false, callers
--                          fall back to type-agnostic behavior.
local function analyzeSelection()
	local selected = spGetSelectedUnits()
	local selectedSet = {}
	local selectedTypeSet = {}
	local selectedDomainSet = {}
	local hasTrackedUnits = false

	for i = 1, #selected do
		local u = selected[i]
		selectedSet[u] = true
		if unitSquad[u] then
			local defId = defidOf[u]
			if defId then
				selectedTypeSet[defId] = true
				local d = unitDomain[defId]
				if d then
					selectedDomainSet[d] = true
				end
				hasTrackedUnits = true
			end
		end
	end

	return {
		selectedSet = selectedSet,
		selectedTypeSet = selectedTypeSet,
		selectedDomainSet = selectedDomainSet,
		hasTrackedUnits = hasTrackedUnits,
	}
end


-------------------------------------------------------------------------------
-- Selection primitives
--
-- All six selection actions share one core, doSquadSelect. The per-action
-- wrappers only differ in which opts they pass:
--
--   whole-squad / filtered / group    → steps={1}, cycleWhenFull=true
--   portion / portion-filtered /group → steps=<parsed>, cycleWhenFull=false
--
-- Filtering by unit type and by control group is expressed uniformly via the
-- filterDefs / groupSet options.
-------------------------------------------------------------------------------

--- Convert a step value to a unit count.
-- 0 → 1 unit; 0 < step <= 1 → percentage; step > 1 → fixed count.
local function stepToCount(step, poolSize)
	if poolSize <= 0 then
		return 0
	end
	if step <= 0 then
		return 1
	end
	if step <= 1 then
		return math.max(1, math.ceil(step * poolSize))
	end
	return math.min(math.floor(step), poolSize)
end


--- Squad-kind keywords accepted by every selection action: restrict the search
-- to manual squads (player-created) or reserve squads (per-factory +
-- uncategorized). "any" is the default and only exists so a bind can state it
-- explicitly.
local SQUAD_KIND_TOKENS = {
	manual = "manual",
	reserve = "reserve",
	any = false, -- recognized as a token, but imposes no filter
}


--- Parse the args of any squad_select* action. Every token is optional and
-- position-independent:
--   "append"        — add to the selection instead of replacing it
--   "append_domain" — implies append, and restricts cycling to the domains
--                     ("land"/"air"/"naval") present in the current selection
--   "retarget"      — filtered actions only; let a replace-mode click swing
--                     the type filter to the closest unit's type
--   "manual"/"reserve"/"any" — squad-kind filter (see SQUAD_KIND_TOKENS)
--   "distance_<N>"  — cap the selection to units within N world-distance of
--                     the cursor
--   numbers         — step values, in order
--
-- The whole-squad actions ignore the returned steps and maxDistance, so a stray
-- number (e.g. the leading group number of squad_select_group) is harmless there.
local function parseSelectArgs(args)
	if not args then
		return false, false, false, nil, {}, nil
	end
	local append = false
	local useDomainFilter = false
	local retarget = false
	local squadKind = nil
	local steps = {}
	local maxDistance
	for i = 1, #args do
		local arg = args[i]
		if arg == "append" then
			append = true
		elseif arg == "append_domain" then
			append = true
			useDomainFilter = true
		elseif arg == "retarget" then
			retarget = true
		elseif SQUAD_KIND_TOKENS[arg] ~= nil then
			squadKind = SQUAD_KIND_TOKENS[arg] or nil
		elseif type(arg) == "string" and arg:sub(1, 9) == "distance_" then
			local d = tonumber(arg:sub(10))
			if d and d > 0 then
				maxDistance = d
			end
		else
			local n = tonumber(arg)
			if n then
				steps[#steps + 1] = n
			end
		end
	end
	return append, useDomainFilter, retarget, squadKind, steps, maxDistance
end


--- Sort a unit array in-place by distance to a world point.
local function sortUnitsByDistance(units, wx, wz)
	local distCache = {}
	for i = 1, #units do
		local u = units[i]
		local x, _, z = spGetUnitPosition(u)
		if x then
			distCache[u] = (x - wx) * (x - wx) + (z - wz) * (z - wz)
		else
			distCache[u] = math.huge
		end
	end
	table.sort(units, function(a, b)
		return distCache[a] < distCache[b]
	end
)
end


--- Build a squad's pool(s): units matching the optional filters.
-- Returns (pool, stepPool). stepPool is the filter-only pool used for step
-- progression; pool is stepPool additionally capped to units within
-- maxDistanceSq of (wx, wz). When maxDistanceSq is nil the two are the
-- same array.
local function buildPools(squad, filterDefs, groupSet, maxDistanceSq, wx, wz)
	local stepPool = {}
	local pool = maxDistanceSq and {} or stepPool
	for j = 1, #squad do
		local u = squad[j]
		if (not groupSet or groupSet[u]) and (not filterDefs or (defidOf[u] and filterDefs[defidOf[u]])) then
			stepPool[#stepPool + 1] = u
			if maxDistanceSq then
				local ux, _, uz = spGetUnitPosition(u)
				if ux then
					local dx = ux - wx
					local dz = uz - wz
					if dx * dx + dz * dz <= maxDistanceSq then
						pool[#pool + 1] = u
					end
				end
			end
		end
	end
	return pool, stepPool
end


--- Count how many pool units are already selected.
local function countSelectedIn(pool, selectedSet)
	local n = 0
	for i = 1, #pool do
		if selectedSet[pool[i]] then
			n = n + 1
		end
	end
	return n
end


--- True when every unit in pool is in selectedSet. 
local function poolFullySelected(pool, selectedSet)
	for i = 1, #pool do
		if not selectedSet[pool[i]] then
			return false
		end
	end
	return true
end


--- Walk the step progression: return the first resolved count greater than
-- `currentInPool`, or the last step's count once we're past the end
-- (no-op repeat).
local function resolveTargetCount(steps, poolSize, currentInPool)
	for i = 1, #steps do
		local c = stepToCount(steps[i], poolSize)
		if c > currentInPool then
			return c
		end
	end
	return stepToCount(steps[#steps], poolSize)
end


--- Given a distance-sorted pool, pick which units go to SelectUnitArray.
-- Replace mode: first `targetCount` pool units.
-- Append mode: up to `targetCount` closest pool units that aren't already
-- selected (so repeated presses accumulate).
local function pickUnits(pool, targetCount, selectedSet, append)
	local toSelect = {}
	if append then
		for i = 1, #pool do
			if not selectedSet[pool[i]] then
				toSelect[#toSelect + 1] = pool[i]
				if #toSelect >= targetCount then
					break
				end
			end
		end
	else
		for i = 1, targetCount do
			toSelect[i] = pool[i]
		end
	end
	return toSelect
end


--- Determine the defID set for filtered actions. Uses the selection's types
-- if any tracked units are selected; otherwise falls back to the closest
-- unit's type. Returns nil when nothing suitable is found (caller bails).
-- squadKind restricts the closest-unit peek to that kind of squad.
local function resolveFilterDefs(sel, wx, wz, squadKind)
	if sel.hasTrackedUnits then
		return sel.selectedTypeSet
	end
	local _, closest = findClosestSquad(nil, nil, nil, wx, wz, nil, nil, squadKind)
	if not closest then
		return nil
	end
	local defId = defidOf[closest]
	if not defId then
		return nil
	end
	return {
		[defId] = true,
	}
end


--- Retarget variant: in replace mode, always peek the closest unit. If its
-- type is in the current selection's types, behave like resolveFilterDefs
-- (use the selection). If not, treat the click as a fresh selection on that
-- single new type — letting the player swing the filter to a different unit
-- type without first deselecting.
local function resolveRetargetFilterDefs(sel, wx, wz, squadKind)
	local _, closest = findClosestSquad(nil, nil, nil, wx, wz, nil, nil, squadKind)
	if not closest then
		return resolveFilterDefs(sel, wx, wz, squadKind)
	end
	local defId = defidOf[closest]
	if not defId then
		return resolveFilterDefs(sel, wx, wz, squadKind)
	end
	if sel.hasTrackedUnits and sel.selectedTypeSet[defId] then
		return sel.selectedTypeSet
	end
	return {
		[defId] = true,
	}
end


--- Build a set of unitIDs belonging to a control group.
-- Tries GetGroupUnits first, falls back to iterating tracked units. (I copied this from another widget, I'm not sure how necessary it is)
local function buildGroupSet(groupNum)
	local groupUnits
	if spGetGroupUnits then
		groupUnits = spGetGroupUnits(groupNum)
	end

	local groupSet = {}
	if groupUnits and #groupUnits > 0 then
		for i = 1, #groupUnits do
			groupSet[groupUnits[i]] = true
		end
	else
		for _, squad in ipairs(squads) do
			for j = 1, #squad do
				local u = squad[j]
				if spGetUnitGroup(u) == groupNum then
					groupSet[u] = true
				end
			end
		end
	end
	return groupSet
end


-------------------------------------------------------------------------------
-- Unified squad selection core
--
-- opts = {
--   append             bool,
--   steps              array of step values; nil → {1} (whole pool),
--   filterDefs         nil or defID set (narrow pool to matching types),
--   groupSet           nil or unitID set (narrow pool to group members),
--   maxDistance        nil or number — cap pool to units within that world
--                      distance from the cursor,
--   squadKind          nil, "manual" or "reserve" — only consider squads of
--                      that kind; nil considers both,
--   cycleWhenFull      bool — when the closest squad's pool is already fully
--                      selected, re-pick a squad with those units excluded,
--   useDomainFilter    bool — restrict squad cycling to domains
--                      ("land"/"air"/"naval") present in the selection.
--                      Ignored when no tracked units are selected.
--   isMousePress       bool — true for left-click initiated selection,
--                      false for action/hotkey initiated selection.
-- }
-------------------------------------------------------------------------------

local function doSquadSelect(opts)
	opts = opts or {}

	local wx, wz = getMouseWorldPos()
	if not wx then
		return
	end

	local mx, my = spGetMouseState()

	-- External hook for companion widgets.
	-- Return false to veto selection.
	-- Return a table to shallow-override opts for this call.
	if beforeSquadSelectCallback then
		local ok, hookResult = pcall(beforeSquadSelectCallback, {
			opts = opts,
			mx = mx,
			my = my,
			wx = wx,
			wz = wz,
			selected = spGetSelectedUnits(),
		})
		if not ok then
			log("beforeSquadSelect callback error: ", hookResult)
		elseif hookResult == false then
			return
		elseif type(hookResult) == "table" then
			for k, v in pairs(hookResult) do
				opts[k] = v
			end
		end
	end

	local steps = opts.steps or {1}
	if #steps == 0 then
		return
	end

	-- Selection "kind" identifies the logical selection type so the same-mode
	-- double-tap gestures only fire on a same-type repeat: e.g. a squadSelect
	-- followed by a squadSelectFiltered must not trigger viewselection. The
	-- filter/group dimension plus whole-vs-portion (the codebase's whole-squad
	-- definition is exactly {} or {1}) captures every action variant.
	local kind = (opts.groupSet and "group") or (opts.filterDefs and "filtered") or "plain"
	if not (#steps == 1 and steps[1] == 1) then
		kind = kind .. ":portion"
	end
	-- Squad-kind restriction is part of the identity too.
	if opts.squadKind then
		kind = kind .. ":" .. opts.squadKind
	end

	-- Compute the double-tap window match against the *previous* tap, then
	-- snapshot its append flag and kind before we overwrite lastSquadSelect below.
	local inDoubleTapWindow = false
	local prevAppend = false
	local prevKind = nil
	if lastSquadSelect and config.viewselectionDoubleTapMs > 0 then
		local dtMs = spDiffTimers(spGetTimer(), lastSquadSelect.t, true)
		local dx = mx - lastSquadSelect.x
		local dy = my - lastSquadSelect.y
		local px = config.viewselectionDoubleTapPx
		inDoubleTapWindow = dtMs < config.viewselectionDoubleTapMs and (dx * dx + dy * dy) < (px * px)
		prevAppend = lastSquadSelect.append
		prevKind = lastSquadSelect.kind
	end

	-- Arm now (not at the end) so subsequent taps detect this one even when the selection ends up a no-op.
	-- `squad` is filled in below once the final target is known; staying nil on no-ops is the correct
	-- signal for createSquadFromSelection's reserve-merge gate (no widget selection happened).
	lastSquadSelect = {
		t = spGetTimer(),
		x = mx,
		y = my,
		append = opts.append,
		kind = kind,
		squad = nil,
	}

	-- Single-step same-mode double-tap dispatch. Replace→replace fires
	-- viewselection. Append→append flips the domain filter
	if inDoubleTapWindow and prevAppend == opts.append and prevKind == kind then
		if opts.append then
			opts.useDomainFilter = not opts.useDomainFilter
		else
			if #steps == 1 then
				spSendCommands("viewselection")
				lastSquadSelect = nil
				return
			end
		end
	end

	local sel = analyzeSelection()
	local filterDefs = opts.filterDefs
	local groupSet = opts.groupSet
	local maxDistanceSq = opts.maxDistance and opts.maxDistance * opts.maxDistance or nil
	local domainFilter = opts.useDomainFilter and sel.hasTrackedUnits and sel.selectedDomainSet or nil

	local targetSquad = findClosestSquad(filterDefs, groupSet, nil, wx, wz, domainFilter, nil, opts.squadKind)
	if not targetSquad then
		return
	end
	local pool, stepPool = buildPools(targetSquad, filterDefs, groupSet, maxDistanceSq, wx, wz)

	if #stepPool == 0 then
		return
	end

	-- Multi-step calls need currentInStepPool to advance through the step
	-- progression; single-step ones only need fullySelected, which is a pure
	-- function of pool size and selection.
	local currentInStepPool
	if #steps > 1 then
		currentInStepPool = countSelectedIn(stepPool, sel.selectedSet)
	end
	local fullySelected = #pool > 0 and poolFullySelected(pool, sel.selectedSet)

	-- Double-tap viewselection (late): multi-step replace fires only when the
	-- player has already reached the last step (no progression left), so
	-- intermediate taps still advance through steps as normal. Same same-mode
	-- gating as the early check — only replace→replace triggers.
	-- TODO: should work even with distance filter.
	if inDoubleTapWindow and prevKind == kind and #steps > 1 and not opts.append and not prevAppend and #pool > 0 and currentInStepPool >= stepToCount(steps[#steps], #stepPool) then
		spSendCommands("viewselection")
		lastSquadSelect = nil
		return
	end

	if opts.cycleWhenFull and fullySelected then
		-- If cycling finds no other squad (e.g. the player previously appended
		-- their way through every squad so nothing is unselected), keep the
		-- original target so a replace tap still replaces with the closest
		-- squad instead of silently doing nothing. For append, the empty
		-- pickUnits result later short-circuits to a no-op.
		local cycledTarget = findClosestSquad(filterDefs, groupSet, sel.selectedSet, wx, wz, domainFilter, nil, opts.squadKind)
		if cycledTarget then
			targetSquad = cycledTarget
			pool, stepPool = buildPools(targetSquad, filterDefs, groupSet, maxDistanceSq, wx, wz)
			if #steps > 1 then
				currentInStepPool = countSelectedIn(stepPool, sel.selectedSet)
			end
		end
	end

	if #pool == 0 then
		return
	end

	local targetCount
	if #steps == 1 then
		targetCount = stepToCount(steps[1], #stepPool)
	else
		targetCount = resolveTargetCount(steps, #stepPool, currentInStepPool)
	end

	if targetCount < #pool then
		sortUnitsByDistance(pool, wx, wz)
	end
	local toSelect = pickUnits(pool, targetCount, sel.selectedSet, opts.append)
	if #toSelect == 0 then
		return
	end
	spSelectUnitArray(toSelect, opts.append)
	pushToMru(targetSquad)
	lastSquadSelect.squad = targetSquad

	log("Squad select [", targetSquad.index or "?", "]: ", #toSelect, "/", #pool, opts.append and " +append" or "")
end


-------------------------------------------------------------------------------
-- Action handlers (thin wrappers over doSquadSelect)
-------------------------------------------------------------------------------

local function squadSelect(_, _, args)
	local append, useDomainFilter, _, squadKind = parseSelectArgs(args) -- steps/maxDistance intentionally ignored: whole-squad action
	doSquadSelect({
		append = append,
		useDomainFilter = useDomainFilter,
		squadKind = squadKind,
		cycleWhenFull = append or config.cyclingToNextSquad,
	})
	return true
end


local function squadCreate()
	assignFactorySquad()
	createSquadFromSelection()
	return true
end


local function squadCycleRecent()
	if #mru == 0 then
		spEcho("[Squad] MRU is empty")
		return true
	end
	local currentSquad = selectionIsExistingSquad(spGetSelectedUnits())
	local currentIndex = 0
	for k = 1, #mru do
		if mru[k] == currentSquad then
			currentIndex = k
			break
		end
	end
	recallMru((currentIndex % #mru) + 1)
	return true
end


local function squadCycleIdle()
	if #squads == 0 then
		return true
	end

	local currentSquad = selectionIsExistingSquad(spGetSelectedUnits())
	local startIndex = 0
	if currentSquad then
		for i = 1, #squads do
			if squads[i] == currentSquad then
				startIndex = i
				break
			end
		end
	end

	local n = #squads
	for offset = 1, n do
		local sq = squads[((startIndex - 1 + offset) % n) + 1]
		local size = #sq
		if size > 0 and squadIdleState[sq] then
			local units = {}
			for j = 1, size do
				units[j] = sq[j]
			end
			spSelectUnitArray(units)
			spSendCommands("viewselection")
			pushToMru(sq)
			log("Idle squad [", sq.index or "?", "]")
			return true
		end
	end

	spEcho("[Squad] No idle squads found")
	return true
end


local function squadSelectFiltered(_, _, args)
	local wx, wz = getMouseWorldPos()
	if not wx then
		return true
	end
	local append, useDomainFilter, retarget, squadKind = parseSelectArgs(args) -- steps/maxDistance intentionally ignored: whole-squad action
	local sel = analyzeSelection()
	local filterDefs = (retarget and not append) and resolveRetargetFilterDefs(sel, wx, wz, squadKind) or resolveFilterDefs(sel, wx, wz, squadKind)
	if not filterDefs then
		return true
	end
	doSquadSelect({
		append = append,
		useDomainFilter = useDomainFilter,
		filterDefs = filterDefs,
		squadKind = squadKind,
		cycleWhenFull = append or config.cyclingToNextSquad,
	})
	return true
end


local function squadSelectGroup(_, _, args)
	if not args or not args[1] then
		return true
	end
	local groupNum = tonumber(args[1])
	if not groupNum then
		return true
	end
	-- steps/maxDistance intentionally ignored, which also swallows the leading group number.
	local append, useDomainFilter, _, squadKind = parseSelectArgs(args)
	doSquadSelect({
		append = append,
		useDomainFilter = useDomainFilter,
		groupSet = buildGroupSet(groupNum),
		squadKind = squadKind,
		cycleWhenFull = append or config.cyclingToNextSquad,
	})
	return true
end


local function squadSelectPortion(_, _, args)
	local append, useDomainFilter, _, squadKind, steps, maxDistance = parseSelectArgs(args)
	doSquadSelect({
		append = append,
		useDomainFilter = useDomainFilter,
		steps = steps,
		maxDistance = maxDistance,
		squadKind = squadKind,
		cycleWhenFull = append,
	})
	return true
end


local function squadSelectPortionFiltered(_, _, args)
	local append, useDomainFilter, retarget, squadKind, steps, maxDistance = parseSelectArgs(args)
	local wx, wz = getMouseWorldPos()
	if not wx then
		return true
	end
	local sel = analyzeSelection()
	local filterDefs = (retarget and not append) and resolveRetargetFilterDefs(sel, wx, wz, squadKind) or resolveFilterDefs(sel, wx, wz, squadKind)
	if not filterDefs then
		return true
	end
	doSquadSelect({
		append = append,
		useDomainFilter = useDomainFilter,
		steps = steps,
		filterDefs = filterDefs,
		maxDistance = maxDistance,
		squadKind = squadKind,
		cycleWhenFull = append,
	})
	return true
end


local function squadSelectPortionGroup(_, _, args)
	if not args or not args[1] then
		return true
	end
	local groupNum = tonumber(args[1])
	if not groupNum then
		return true
	end
	local remaining = {}
	for i = 2, #args do
		remaining[#remaining + 1] = args[i]
	end
	local append, useDomainFilter, _, squadKind, steps, maxDistance = parseSelectArgs(remaining)
	doSquadSelect({
		append = append,
		useDomainFilter = useDomainFilter,
		steps = steps,
		groupSet = buildGroupSet(groupNum),
		maxDistance = maxDistance,
		squadKind = squadKind,
		cycleWhenFull = append,
	})
	return true
end


-- Shared core for squad_limit / squad_limit_flip. Picks the target squad (owner
-- of the tracked-selected unit closest to the cursor) and shapes the existing
-- selection against that one squad, dropping everything else. Replace-only.
--   do_flip == false → limit/narrow: result = selection ∩ target_squad.
--   do_flip == true  → limit AND flip: result = target_squad \ selection (the
--     target squad's other units). A fully-selected squad flips to empty.
--   No tracked units selected → fall back to plain closest-squad-select.
local function limitOrFlip(doFlip)
	local wx, wz = getMouseWorldPos()
	if not wx then
		return true
	end

	local sel = analyzeSelection()
	if not sel.hasTrackedUnits then
		doSquadSelect({
			cycleWhenFull = config.cyclingToNextSquad,
		})
		return true
	end

	local targetSquad
	local closestD2 = math.huge
	for u in pairs(sel.selectedSet) do
		local sq = unitSquad[u]
		if sq then
			local x, _, z = spGetUnitPosition(u)
			if x then
				local dx, dz = x - wx, z - wz
				local d2 = dx * dx + dz * dz
				if d2 < closestD2 then
					closestD2 = d2
					targetSquad = sq
				end
			end
		end
	end

	if not targetSquad then
		return true
	end

	local result = {}
	for i = 1, #targetSquad do
		local u = targetSquad[i]
		local selected = sel.selectedSet[u]
		if (doFlip and not selected) or (not doFlip and selected) then
			result[#result + 1] = u
		end
	end

	spSelectUnitArray(result)
	pushToMru(targetSquad)
	log(doFlip and "Flip" or "Limit", " squad [", targetSquad.index or "?", "]: ", #result, "/", #targetSquad)
	return true
end


local function squadLimitFlip()
	return limitOrFlip(true)
end


local function squadLimit()
	return limitOrFlip(false)
end


-- Always flips, across every squad that has a selected unit: each such squad's
-- selected units are swapped for its unselected ones. Cursor-independent.
local function squadFlip()
	local sel = analyzeSelection()
	if not sel.hasTrackedUnits then
		doSquadSelect({
			cycleWhenFull = config.cyclingToNextSquad,
		})
		return true
	end

	local flippedSquads = {}
	for u in pairs(sel.selectedSet) do
		local sq = unitSquad[u]
		if sq then
			flippedSquads[sq] = true
		end
	end

	local result = {}
	local squadCount = 0
	for sq in pairs(flippedSquads) do
		squadCount = squadCount + 1
		for i = 1, #sq do
			local u = sq[i]
			if not sel.selectedSet[u] then
				result[#result + 1] = u
			end
		end
		pushToMru(sq)
	end

	spSelectUnitArray(result)
	log("Flip ", squadCount, " squad(s): ", #result, " units")
	return true
end


-------------------------------------------------------------------------------
-- GL4 hull rendering
--
-- One shared VBO (2D world x,z + ground-sampled y) is re-uploaded per squad
-- per frame, then drawn as TRIANGLE_FAN (fill) and LINE_LOOP (border).
-- The 2D hull geometry is convex, so a fan starting from vertex 0 covers it.
-------------------------------------------------------------------------------

local HULL_MAX_VERTICES = 512
local hullShader = nil
local hullColorLoc = nil
local hullStripeLoc = nil
local hullCentroidLoc = nil
local hullPulseLoc = nil
local hullVbo = nil
local hullVao = nil
local hullReady = false
local hullInitFailed = false -- so we don't spam retries after a failure
local hullTimeOrigin = nil -- wall-clock origin for stripe/pulse animation

-- Center→edge alpha gradient: alpha at the centroid as a fraction of the edge.
local HULL_GRADIENT_CENTER = 0.2

local hullVsSrc = [[
#version 330 compatibility

layout(location = 0) in vec3 position;

out vec3 worldPos;

void main() {
	worldPos = position;
	gl_Position = gl_ModelViewProjectionMatrix * vec4(position, 1.0);
}
]]

local hullFsSrc = [[
#version 330 compatibility

uniform vec4 color;
// stripe.x = period in world units (0 disables stripes)
// stripe.y = alpha multiplier for the dim band
// stripe.z = phase offset in world units (per-squad, so overlapping hulls don't align)
uniform vec3 stripe;
// centroidRadius.xy = squad centroid in world XZ
// centroidRadius.z  = max distance from centroid to a perimeter vertex (gradient norm)
uniform vec3 centroidRadius;
// breathing alpha multiplier (per-squad phase, computed CPU-side)
uniform float pulse;
// alpha at the centroid as a fraction of the edge alpha
uniform float gradientCenter;

in vec3 worldPos;

out vec4 fragColor;

void main() {
	float a = color.a;

	if (stripe.x > 0.0) {
		float band = step(0.5, fract((worldPos.x + worldPos.z + stripe.z) / stripe.x));
		a *= mix(stripe.y, 1.0, band);
	}

	// soft center→edge alpha gradient
	vec2 toCenter = worldPos.xz - centroidRadius.xy;
	float dist = length(toCenter) / max(centroidRadius.z, 1.0);
	a *= mix(gradientCenter, 1.0, smoothstep(0.0, 1.0, dist));

	a *= pulse;

	fragColor = vec4(color.rgb, a);
}
]]

local function initGlHull()
	if hullReady or hullInitFailed then
		return hullReady
	end
	if not glCreateShader or not glGetVBO or not glGetVAO then
		log("GL4 unavailable — convex hull drawing disabled")
		hullInitFailed = true
		return false
	end

	hullShader = glCreateShader({
		vertex = hullVsSrc,
		fragment = hullFsSrc,
	})
	if not hullShader then
		local shaderLog = gl.GetShaderLog and gl.GetShaderLog() or "(no log)"
		log("Failed to compile hull shader: ", shaderLog)
		hullInitFailed = true
		return false
	end
	hullColorLoc = glGetUniformLocation(hullShader, "color")
	hullStripeLoc = glGetUniformLocation(hullShader, "stripe")
	hullCentroidLoc = glGetUniformLocation(hullShader, "centroidRadius")
	hullPulseLoc = glGetUniformLocation(hullShader, "pulse")
	local gradientLoc = glGetUniformLocation(hullShader, "gradientCenter")
	if gradientLoc then
		glUseShader(hullShader)
		glUniform(gradientLoc, HULL_GRADIENT_CENTER)
		glUseShader(0)
	end

	hullVbo = glGetVBO(GL.ARRAY_BUFFER, false)
	if not hullVbo then
		glDeleteShader(hullShader)
		hullShader = nil
		log("Failed to create hull VBO")
		hullInitFailed = true
		return false
	end
	hullVbo:Define(HULL_MAX_VERTICES, {
		{
			id = 0,
			name = 'position',
			size = 3,
		}})

	hullVao = glGetVAO()
	if not hullVao then
		hullVbo:Delete()
		hullVbo = nil
		glDeleteShader(hullShader)
		hullShader = nil
		log("Failed to create hull VAO")
		hullInitFailed = true
		return false
	end
	hullVao:AttachVertexBuffer(hullVbo)

	hullReady = true
	return true
end


local function cleanupGlHull()
	if hullVao then
		hullVao:Delete()
	end
	if hullVbo then
		hullVbo:Delete()
	end
	if hullShader then
		glDeleteShader(hullShader)
	end
	hullVao = nil
	hullVbo = nil
	hullShader = nil
	hullColorLoc = nil
	hullStripeLoc = nil
	hullCentroidLoc = nil
	hullPulseLoc = nil
	hullReady = false
	hullInitFailed = false
end


-------------------------------------------------------------------------------
-- Options panel integration (gui_options.lua)
--
-- `setOptionValue(key, value)` is the single config-write helper, called
-- from both the panel's onchange and the squad_setting console action. It
-- writes config[key] AND, when `key` has a registered panel option, mirrors
-- the change onto that option's `value` field so the panel UI reflects it.
--
-- The squad-creation-method select doesn't map 1:1 to a config key: one control
-- reads and writes the three mutually-exclusive rightClick* booleans.
-------------------------------------------------------------------------------

local OPTION_ADVANCED = 2 -- BAR gui_options category constant (basic=1, advanced=2, dev=3)

local panelOptionsByKey = {} -- configVariable -> registered panel option
local OPTION_SPECS_BY_KEY -- configVariable -> spec (assigned after OPTION_SPECS)

-- the `visualization` hull options show only while hulls are on and the gate is on.
local visualizationGateShown = false
local visualizationOptionsShown = false
local syncVisualizationPanel -- assigned after build_option

-- Synthetic "squadCreateMethod" select owning three mutually-exclusive booleans
-- (1 = Off). setOptionValue re-derives the select when any is written directly.
local SQUAD_CREATE_METHOD_KEYS = {
	rightClickSquadCreate = true,
	ctrlRightClickCreatesSquad = true,
	ctrlRightClickDragCreatesSquad = true,
}

local function squadCreateMethodIndex()
	if config.rightClickSquadCreate then
		return 2
	end
	if config.ctrlRightClickCreatesSquad then
		return 3
	end
	if config.ctrlRightClickDragCreatesSquad then
		return 4
	end
	return 1
end


-- Synthetic "hullDisplayMode" select owning visualizationMode + showReserveSquads.
-- 1 = Off, 2 = All squads, 3 = Manual squads only.
local HULL_DISPLAY_MODE_KEYS = {
	visualizationMode = true,
	showReserveSquads = true,
}

local function hullDisplayModeIndex()
	if config.visualizationMode ~= "convexHull" then
		return 1
	end
	if config.showReserveSquads then
		return 2
	end
	return 3
end


-- Synthetic "preset" select: the panel stores a 1-based index into PRESET_NAMES
-- while config.preset holds the name.
local function presetIndex()
	for i = 1, #PRESET_NAMES do
		if PRESET_NAMES[i] == config.preset then
			return i
		end
	end
	return #PRESET_NAMES -- "custom"
end


-- Set while applyPreset writes the settings it owns, so those writes don't
-- immediately demote the preset back to "custom".
local applyingPreset = false

-- Single config-write entry point: writes config[key] and mirrors it onto the
-- registered panel option (selects translate to a 1-based index).
local function setOptionValue(key, value)
	config[key] = value
	if key == "preset" then
		local sel = panelOptionsByKey["preset"]
		if sel then
			sel.value = presetIndex()
		end
		return
	end
	-- A hand-written change to a setting a preset owns means the player has left that preset.
	if PRESET_OWNED_KEYS[key] and not applyingPreset and config.preset ~= "custom" then
		config.preset = "custom"
		local sel = panelOptionsByKey["preset"]
		if sel then
			sel.value = presetIndex()
		end
	end
	if HULL_DISPLAY_MODE_KEYS[key] then
		local sel = panelOptionsByKey["hullDisplayMode"]
		if sel then
			sel.value = hullDisplayModeIndex()
		end
		if syncVisualizationPanel then
			syncVisualizationPanel()
		end
		return
	end
	if key == "showVisualizationOptions" then
		local toggle = panelOptionsByKey["showVisualizationOptions"]
		if toggle then
			toggle.value = value
		end
		if syncVisualizationPanel then
			syncVisualizationPanel()
		end
		return
	end
	if SQUAD_CREATE_METHOD_KEYS[key] then
		local sel = panelOptionsByKey["squadCreateMethod"]
		if sel then
			sel.value = squadCreateMethodIndex()
		end
	end
	local option = panelOptionsByKey[key]
	if not option then
		return
	end
	local spec = OPTION_SPECS_BY_KEY[key]
	if spec.type == "select" then
		for i, v in ipairs(spec.options) do
			if value == v then
				option.value = i
				return
			end
		end
	else
		option.value = value
	end
end


-- Write every setting the named preset owns, then record it as the active one.
local function applyPreset(name)
	local preset = PRESETS[name]
	if not preset then
		return false
	end
	applyingPreset = true
	for key, value in pairs(preset) do
		setOptionValue(key, value)
	end
	applyingPreset = false
	setOptionValue("preset", name)
	return true
end


local OPTION_SPECS = {
	{
		configVariable = "preset", -- synthetic; the select index maps onto PRESET_NAMES
		name = "Playstyle preset",
		description = "Sets every switch a playstyle needs in one go.\n\nMinimal: the least surprising behaviour.\nAuto-group focused: leans on the automatic squads to limit your auto-group selections. You can still use manual squads.\nSquad focused: for constantly creating and merging squads and using primarily the squad selection features to select your units.\nCustom: your own mix — picked automatically as soon as you change a setting a preset owns.",
		type = "select",
		options = {"Minimal", "Auto-group focused", "Squad focused", "Custom (advanced)"},
	}, {
		configVariable = "cyclingToNextSquad",
		name = "Selects next closest squad on re-tap",
		description = "If squad selection would produce the current selection, selects from the next-closest squad instead.",
		type = "bool",
	}, {
		configVariable = "leftClickSelectsSquad",
		name = "Modifier + left-click selects a squad",
		description = "Ctrl-clicking empty ground selects the nearest squad. Ctrl+Shift appends it; hold Alt to select with type filter.\n\nAppends stay within the domain of what you already have selected, e.g. a nearby air squad is skipped while you have a land selection. Double-tap the append to select across domains instead.",
		type = "bool",
	}, {
		configVariable = "leftClickAlternativeSelection",
		name = "Alternative left-click selection",
		description = "When on, left-click squad selections are limited by distance, and selecting the same squad again narrows the selection down to the closest half of it (useful to split up squads).",
		type = "bool",
		category = OPTION_ADVANCED,
	}, {
		configVariable = "squadCreateMethod", -- synthetic; not a real config field
		name = "Right-click creates squad",
		description = "How right-click groups the current selection into a new squad. The engine's move command still issues alongside it.",
		type = "select",
		options = {"Off", "Plain right-click", "Ctrl+right-click", "Ctrl+right-click drag"},
	}, {
		configVariable = "rightClickMovesSquad",
		name = "Right-click moves the nearest squad",
		description = "With nothing selected, right-click-drag move-orders the squad nearest the press point to the release point. Hold Alt to do this even when you have a selection. With shift you lock the squad and append the order to its queue. With ctrl it moves in formation. Hold Space to also select the squad.",
		type = "bool",
	}, {
		configVariable = "rightClickMoveControlsReserves",
		name = "Right-click move on automatic squads",
		description = "When on, right-click move can command automatic squads (the per-factory ones and the catch-all squad the game keeps for everything else) and converts the commanded one into a manual squad. When off, it ignores them and only picks manual squads.",
		type = "bool",
		category = OPTION_ADVANCED,
	}, {
		configVariable = "mergeIntoReserves",
		name = "Merge into automatic squads",
		description = "When on, appending an automatic squad to your selection and running squad_create merges the selection into that automatic squad. When off, squad_create always creates a fresh manual squad.",
		type = "bool",
		category = OPTION_ADVANCED,
	}, {
		configVariable = "mruSize",
		name = "Recent-squad cycle size",
		description = "How many recent squads squad_cycle_recent cycles through.",
		type = "slider",
		min = 1,
		max = 9,
		step = 1,
		category = OPTION_ADVANCED,
	}, {
		configVariable = "excludeConstructors",
		name = "Exclude constructors & commanders",
		description = "When on, basic constructors and commanders are never tracked as squad units. Independent of your manual exclusion list. (manual exclusion: \"/squad_setting add|remove excludedUnitTypes <unitDefID>\")",
		type = "bool",
		rebuild = true,
		category = OPTION_ADVANCED,
	}, {
		configVariable = "excludeResurrectionUnits",
		name = "Exclude resurrection units",
		description = "When on, resurrection units are never tracked as squad units. Independent of your manual exclusion list. (manual exclusion: \"/squad_setting add|remove excludedUnitTypes <unitDefID>\")",
		type = "bool",
		rebuild = true,
		category = OPTION_ADVANCED,
	}, {
		configVariable = "excludeCombatEngineers",
		name = "Exclude combat engineers",
		description = "When on, combat engineers are never tracked as squad units. Independent of your manual exclusion list. (manual exclusion: \"/squad_setting add|remove excludedUnitTypes <unitDefID>\")",
		type = "bool",
		rebuild = true,
		category = OPTION_ADVANCED,
	}, {
		configVariable = "hullDisplayMode", -- synthetic; not a real config field
		name = "Squad hulls",
		description = "Convex hull outlines around squads; 'Manual squads only' excludes the automatic ones.",
		type = "select",
		options = {"Off", "All squads", "Manual squads only"},
	}, {
		-- Reveals the hull appearance options below it; shown only while hulls are on.
		configVariable = "showVisualizationOptions",
		visGate = true,
		name = "Show visualization options",
		description = "Reveal the detailed hull appearance settings.",
		type = "bool",
		category = OPTION_ADVANCED,
	}, {
		configVariable = "convexHullPadding",
		visualization = true,
		name = "Hull padding",
		description = "Distance (in elmos) between units and the hull boundary.",
		type = "slider",
		min = 0,
		max = 200,
		step = 5,
		category = OPTION_ADVANCED,
	}, {
		configVariable = "convexHullArcResolution",
		visualization = true,
		name = "Hull arc resolution",
		description = "Angle each chord of the rounded corners spans, in radians. Smaller is smoother but more expensive.",
		type = "slider",
		min = 0.05,
		max = 1.0,
		step = 0.05,
		category = OPTION_ADVANCED,
	}, {
		configVariable = "convexHullFillOpacity",
		visualization = true,
		name = "Hull fill opacity",
		type = "slider",
		min = 0,
		max = 1,
		step = 0.05,
		category = OPTION_ADVANCED,
	}, {
		configVariable = "convexHullBorderOpacity",
		visualization = true,
		name = "Hull border opacity",
		type = "slider",
		min = 0,
		max = 1,
		step = 0.05,
		category = OPTION_ADVANCED,
	}, {
		configVariable = "convexHullBorderThickness",
		visualization = true,
		name = "Hull border thickness",
		type = "slider",
		min = 0.5,
		max = 5,
		step = 0.5,
		category = OPTION_ADVANCED,
	}, {
		configVariable = "convexHullColorMode",
		visualization = true,
		name = "Hull color mode",
		description = "Player color, a single custom color, or a unique color per squad.",
		type = "select",
		options = {"player", "custom", "squad"},
		category = OPTION_ADVANCED,
	}, {
		configVariable = "convexHullCustomColorR",
		visualization = true,
		name = "Custom color Red",
		type = "slider",
		min = 0,
		max = 1,
		step = 0.05,
		category = OPTION_ADVANCED,
	}, {
		configVariable = "convexHullCustomColorG",
		visualization = true,
		name = "Custom color Green",
		type = "slider",
		min = 0,
		max = 1,
		step = 0.05,
		category = OPTION_ADVANCED,
	}, {
		configVariable = "convexHullCustomColorB",
		visualization = true,
		name = "Custom color Blue",
		type = "slider",
		min = 0,
		max = 1,
		step = 0.05,
		category = OPTION_ADVANCED,
	}}

-- Populate the forward-declared OPTION_SPECS_BY_KEY now that OPTION_SPECS exists.
OPTION_SPECS_BY_KEY = {}
for i = 1, #OPTION_SPECS do
	OPTION_SPECS_BY_KEY[OPTION_SPECS[i].configVariable] = OPTION_SPECS[i]
end

local function getOptionId(spec)
	return "squad_selection__" .. spec.configVariable
end


-- Forward declaration; defined in the Lifecycle section. Re-classifies and
-- re-routes every tracked unit (used by the exclude* settings written through
-- the panel/WG API and by the excludedUnitTypes console commands).
local rebuildTracking

local function buildOption(spec)
	local option = {}
	for k, v in pairs(spec) do
		option[k] = v
	end
	option.configVariable = nil
	option.widgetName = widget:GetInfo().name
	option.id = getOptionId(spec)

	-- Seed from config (selects store a 1-based index).
	if spec.type == "select" then
		if spec.configVariable == "squadCreateMethod" then
			option.value = squadCreateMethodIndex()
		elseif spec.configVariable == "hullDisplayMode" then
			option.value = hullDisplayModeIndex()
		elseif spec.configVariable == "preset" then
			option.value = presetIndex()
		else
			option.value = 1
			for i, v in ipairs(spec.options) do
				if config[spec.configVariable] == v then
					option.value = i
					break
				end
			end
		end
	else
		option.value = config[spec.configVariable]
	end

	-- Translate the panel value back to config shape, then write through.
	option.onchange = function(_, panelValue)
		if spec.configVariable == "preset" then
			applyPreset(PRESET_NAMES[panelValue])
			return
		end
		if spec.configVariable == "hullDisplayMode" then
			setOptionValue("visualizationMode", panelValue == 1 and "none" or "convexHull")
			setOptionValue("showReserveSquads", panelValue == 2)
			return
		end
		if spec.configVariable == "squadCreateMethod" then
			setOptionValue("rightClickSquadCreate", panelValue == 2)
			setOptionValue("ctrlRightClickCreatesSquad", panelValue == 3)
			setOptionValue("ctrlRightClickDragCreatesSquad", panelValue == 4)
			return
		end
		local configValue = panelValue
		if spec.type == "select" then
			configValue = spec.options[panelValue]
		end
		setOptionValue(spec.configVariable, configValue)
		-- Toggles that change unit eligibility must re-classify
		if spec.rebuild and rebuildTracking then
			rebuildTracking()
		end
	end


	return option
end


-- Add or remove every OPTION_SPEC carrying `flag`; returns the new shown-state.
local function applyOptionGroup(flag, show, currentlyShown)
	if show == currentlyShown or not (WG['options'] and WG['options'].addOptions) then
		return currentlyShown
	end
	if show then
		local options = {}
		for i = 1, #OPTION_SPECS do
			local spec = OPTION_SPECS[i]
			if spec[flag] then
				local option = buildOption(spec)
				options[#options + 1] = option
				panelOptionsByKey[spec.configVariable] = option
			end
		end
		WG['options'].addOptions(options)
	else
		local ids = {}
		for i = 1, #OPTION_SPECS do
			local spec = OPTION_SPECS[i]
			if spec[flag] then
				ids[#ids + 1] = getOptionId(spec)
				panelOptionsByKey[spec.configVariable] = nil
			end
		end
		WG['options'].removeOptions(ids)
	end
	return show
end


syncVisualizationPanel = function()
	local hullsOn = (config.visualizationMode == "convexHull")
	visualizationGateShown = applyOptionGroup("visGate", hullsOn, visualizationGateShown)
	visualizationOptionsShown = applyOptionGroup("visualization", hullsOn and config.showVisualizationOptions, visualizationOptionsShown)
end


local function registerOptions()
	if not (WG['options'] and WG['options'].addOptions) then
		return
	end
	-- Register the always-shown options; sync_visualization_panel then appends the
	-- gate and hull options as needed, so they land beneath the hull select.
	local options = {}
	for i = 1, #OPTION_SPECS do
		local spec = OPTION_SPECS[i]
		if not spec.visGate and not spec.visualization then
			local option = buildOption(spec)
			options[#options + 1] = option
			panelOptionsByKey[spec.configVariable] = option
		end
	end
	WG['options'].addOptions(options)
	visualizationGateShown = false
	visualizationOptionsShown = false
	syncVisualizationPanel()
end


local function unregisterOptions()
	panelOptionsByKey = {}
	visualizationGateShown = false
	visualizationOptionsShown = false
	if not (WG['options'] and WG['options'].removeOptions) then
		return
	end
	local ids = {}
	for i = 1, #OPTION_SPECS do
		ids[i] = getOptionId(OPTION_SPECS[i])
	end
	WG['options'].removeOptions(ids)
end


-------------------------------------------------------------------------------
-- Settings action — toggle/set config values from chat
-- Usage:
--   /luaui squad_setting toggle rightClickSquadCreate
--   /luaui squad_setting toggle ctrlRightClickCreatesSquad
--   /luaui squad_setting toggle cyclingToNextSquad
--   /luaui squad_setting set visualizationMode convexHull
--   /luaui squad_setting set visualizationMode none
--   /luaui squad_setting get cyclingToNextSquad
--   /luaui squad_setting preset squad
--   /luaui squad_setting reload
-------------------------------------------------------------------------------

local function squadSetting(_, _, args)
	if not args or not args[1] then
		spEcho("[Squad] Usage: squad_setting toggle|set|add|remove|get|preset|reload <key> [value]")
		return
	end
	local action = args[1]

	if action == "preset" then
		if not args[2] then
			spEcho("[Squad] preset = " .. config.preset .. " (available: " .. table.concat(PRESET_NAMES, ", ") .. ")")
			return
		end
		if not applyPreset(args[2]) then
			spEcho("[Squad] Unknown preset: " .. tostring(args[2]) .. " (available: " .. table.concat(PRESET_NAMES, ", ") .. ")")
			return
		end
		spEcho("[Squad] preset = " .. config.preset)
		return
	end

	if action == "reload" then
		for k, v in pairs(configDefaults) do
			setOptionValue(k, v)
		end
		rebuildTracking()
		spEcho("[Squad] Config reset to defaults from squad-selection.lua")
		return
	end

	local key = args[2]
	if not key or config[key] == nil then
		spEcho("[Squad] Unknown config key: " .. tostring(key))
		return
	end
	-- The preset owns other keys, so it is only ever written through applyPreset.
	if key == "preset" and action ~= "get" then
		spEcho("[Squad] Use: squad_setting preset " .. table.concat(PRESET_NAMES, "|"))
		return
	end

	local function formatValue(v)
		if type(v) == "table" then
			return "[" .. table.concat(v, ", ") .. "]"
		end
		return tostring(v)
	end


	if action == "add" then
		if key ~= "excludedUnitTypes" then
			spEcho("[Squad] 'add' only applies to excludedUnitTypes")
			return
		end
		if not args[3] then
			spEcho("[Squad] Usage: squad_setting add excludedUnitTypes <name> [name ...]")
			return
		end
		local existing = {}
		for entry in config.excludedUnitTypes:gmatch("[^,]+") do
			existing[entry:match("^%s*(.-)%s*$")] = true
		end
		local parts = {}
		for entry in config.excludedUnitTypes:gmatch("[^,]+") do
			parts[#parts + 1] = entry:match("^%s*(.-)%s*$")
		end
		for i = 3, #args do
			local name = args[i]
			if not existing[name] then
				parts[#parts + 1] = name
				existing[name] = true
			end
		end
		setOptionValue(key, table.concat(parts, ","))
		rebuildTracking()
		spEcho("[Squad] excludedUnitTypes = \"" .. config[key] .. "\" (applied)")
		return
	elseif action == "remove" then
		if key ~= "excludedUnitTypes" then
			spEcho("[Squad] 'remove' only applies to excludedUnitTypes")
			return
		end
		if not args[3] then
			spEcho("[Squad] Usage: squad_setting remove excludedUnitTypes <name> [name ...]")
			return
		end
		local toRemove = {}
		for i = 3, #args do
			toRemove[args[i]] = true
		end
		local parts = {}
		for entry in config.excludedUnitTypes:gmatch("[^,]+") do
			entry = entry:match("^%s*(.-)%s*$")
			if not toRemove[entry] then
				parts[#parts + 1] = entry
			end
		end
		setOptionValue(key, table.concat(parts, ","))
		rebuildTracking()
		spEcho("[Squad] excludedUnitTypes = \"" .. config[key] .. "\" (applied)")
		return
	elseif action == "toggle" then
		if type(config[key]) ~= "boolean" then
			spEcho("[Squad] Cannot toggle non-boolean key: " .. key)
			return
		end
		setOptionValue(key, not config[key])
		-- Eligibility toggles must re-classify and re-route all tracked units.
		if key == "excludeConstructors" or key == "excludeResurrectionUnits" or key == "excludeCombatEngineers" then
			rebuildTracking()
		end
		spEcho("[Squad] " .. key .. " = " .. tostring(config[key]))
	elseif action == "set" then
		-- excludedUnitTypes collects all remaining args joined with commas.
		if key == "excludedUnitTypes" then
			local parts = {}
			for i = 3, #args do
				parts[#parts + 1] = args[i]
			end
			setOptionValue(key, table.concat(parts, ","))
			rebuildTracking()
			spEcho("[Squad] excludedUnitTypes = \"" .. config[key] .. "\" (applied)")
			return
		end
		-- Table-typed keys collect all remaining args as a list of numbers plus
		-- distance_<N> and squad-kind tokens. Passing no values clears the list.
		if type(config[key]) == "table" then
			local list = {}
			for i = 3, #args do
				local tok = args[i]
				local n = tonumber(tok)
				if n then
					list[#list + 1] = n
				elseif tok:match("^distance_%d+%.?%d*$") or tok == "manual" or tok == "reserve" or tok == "any" then
					list[#list + 1] = tok
				end
			end
			setOptionValue(key, list)
			spEcho("[Squad] " .. key .. " = " .. formatValue(list))
			return
		end
		local value = args[3]
		if not value then
			spEcho("[Squad] Missing value for set")
			return
		end
		-- coerce to number or boolean if appropriate
		if value == "true" then
			value = true
		elseif value == "false" then
			value = false
		elseif tonumber(value) then
			value = tonumber(value)
		end
		setOptionValue(key, value)
		-- Eligibility toggles must re-classify and re-route all tracked units.
		if key == "excludeConstructors" or key == "excludeResurrectionUnits" or key == "excludeCombatEngineers" then
			rebuildTracking()
		end
		spEcho("[Squad] " .. key .. " = " .. tostring(config[key]))
	elseif action == "get" then
		spEcho("[Squad] " .. key .. " = " .. formatValue(config[key]))
	else
		spEcho("[Squad] Unknown action: " .. action .. " (use toggle, set, add, remove, get, preset, or reload)")
	end
end


-------------------------------------------------------------------------------
-- Lifecycle
-------------------------------------------------------------------------------

-- Team color for unselected-squad hulls. Populated in widget:Initialize.
local teamColor = {1, 1, 1}

-- Wipe and rebuild all squad tracking from scratch. Shared by widget:Initialize
-- and the excludedUnitTypes chat commands so a change to the exclusion list
-- takes effect immediately (re-classify + re-route every unit).
function rebuildTracking()
	squads = {}
	factorySquad = {}
	unitSquad = {}
	unitSlot = {}
	squadIdleState = {}
	squadIdleBlend = {}
	squadHideIdleAirHull = {}
	mru = {}
	lastSquadSelect = nil
	idleScanIndex = 0
	nextSquadTag = 0

	classifyUnitdefs()

	uncategorizedReserve = {}
	for _, d in ipairs({"land", "air", "naval"}) do
		local sq = makeReserveSquad(false)
		sq.uncatDomain = d
		uncategorizedReserve[d] = sq
	end

	local all = spGetTeamUnits(spGetMyTeamID())
	local count = 0

	-- Factories first, so their auto-squads exist before we route anything.
	for i = 1, #all do
		local u = all[i]
		local defId = getDefid(u)
		if defId and isFactory[defId] then
			createFactorySquad(u)
		end
	end

	-- Combat units: we have no builder info here, so everything goes to the
	-- domain-specific uncategorized reserves. Future builds route via UnitCreated.
	for i = 1, #all do
		local u = all[i]
		local defId = getDefid(u)
		if defId and isCombat[defId] then
			addToSquad(u, getUncategorizedReserveForDef(defId))
			count = count + 1
		end
	end

	selectionDirty = true
	notifySquadChange("rebuild", nil, nil)
	return count
end


function widget:Initialize()
	if spGetSpectatingState() or spIsReplay() then
		log("Spectating or replay mode detected, not initializing")
		widgetHandler:RemoveWidget()
		return
	end

	local tr, tg, tb = spGetTeamColor(spGetMyTeamID())
	teamColor[1], teamColor[2], teamColor[3] = tr or 1, tg or 1, tb or 1

	local count = rebuildTracking()

	widgetHandler:AddAction("squad_create", squadCreate, nil, "pt")
	widgetHandler:AddAction("squad_select", squadSelect, nil, "pt")
	widgetHandler:AddAction("squad_select_filtered", squadSelectFiltered, nil, "pt")
	widgetHandler:AddAction("squad_select_group", squadSelectGroup, nil, "pt")
	widgetHandler:AddAction("squad_select_portion", squadSelectPortion, nil, "pt")
	widgetHandler:AddAction("squad_select_portion_filtered", squadSelectPortionFiltered, nil, "pt")
	widgetHandler:AddAction("squad_select_portion_group", squadSelectPortionGroup, nil, "pt")
	widgetHandler:AddAction("squad_limit_flip", squadLimitFlip, nil, "pt")
	widgetHandler:AddAction("squad_limit", squadLimit, nil, "pt")
	widgetHandler:AddAction("squad_flip", squadFlip, nil, "pt")
	widgetHandler:AddAction("squad_setting", squadSetting, nil, "t")
	widgetHandler:AddAction("squad_cycle_recent", squadCycleRecent, nil, "pt")
	widgetHandler:AddAction("squad_cycle_idle", squadCycleIdle, nil, "pt")

	-- WG interface. Auto-generates
	-- get<Key>/set<Key> pairs for every exposed config key.
	-- `preset` is deliberately absent: it owns other keys, so it goes through applyPreset below.
	local exposedSettings = {
		"leftClickSelectsSquad", "leftClickAlternativeSelection", "leftClickAlternativeArgs", "leftClickAppendFiltersDomain", "leftClickFilteredRetargets", "cyclingToNextSquad", "rightClickSquadCreate", "rightClickMovesSquad", "rightClickMoveControlsReserves", "ctrlRightClickCreatesSquad", "ctrlRightClickDragCreatesSquad", "viewselectionDoubleTapMs", "viewselectionDoubleTapPx", "mruSize", "excludedUnitTypes", "showReserveSquads", "mergeIntoReserves", "visualizationMode", "convexHullPadding", "convexHullArcResolution", "convexHullFillOpacity", "convexHullBorderOpacity", "convexHullBorderThickness", "convexHullColorMode", "convexHullCustomColorR", "convexHullCustomColorG", "convexHullCustomColorB", "excludeConstructors", "excludeResurrectionUnits", "excludeCombatEngineers"}
	WG['squadselection'] = {}
	for _, key in ipairs(exposedSettings) do
		local cap = key:sub(1, 1):upper() .. key:sub(2)
		WG['squadselection']["get" .. cap] = function()
			return config[key]
		end


		WG['squadselection']["set" .. cap] = function(v)
			setOptionValue(key, v)
		end


	end

	WG['squadselection'].getPreset = function()
		return config.preset
	end


	WG['squadselection'].applyPreset = function(name)
		return applyPreset(name)
	end


	-- Re-classify units. Called by gui_options.lua after writing any of the exclude* settings
	WG['squadselection'].rebuildTracking = function()
		rebuildTracking()
	end


	WG['squadselection'].setBeforeSquadSelectCallback = function(fn)
		if fn ~= nil and type(fn) ~= "function" then
			spEcho("[Squad] setBeforeSquadSelectCallback expects function or nil")
			return false
		end
		beforeSquadSelectCallback = fn
		return true
	end


	-- Read-only snapshot of all squad state for companion widgets.
	-- Returns live references — do not mutate the tables.
	-- Fields on each squad array: .index (number, monotonically increasing),
	--   .tagSeed (number, golden-ratio phase offset for animation),
	--   .isReserve (bool), .fromFactory (bool), integer keys are unitIDs.
	WG['squadselection'].getSquadState = function()
		return {
			squads = squads,
			unitSquad = unitSquad,
			factorySquad = factorySquad,
			uncategorizedReserve = uncategorizedReserve,
			squadIdleState = squadIdleState,
			squadIdleBlend = squadIdleBlend,
		}
	end


	WG['squadselection'].addSquadChangeListener = function(fn)
		if type(fn) ~= "function" then
			return false
		end
		squadChangeListeners[#squadChangeListeners + 1] = fn
		pcall(fn, "rebuild", nil, nil)
		return true
	end


	WG['squadselection'].removeSquadChangeListener = function(fn)
		for i = #squadChangeListeners, 1, -1 do
			if squadChangeListeners[i] == fn then
				table.remove(squadChangeListeners, i)
				return true
			end
		end
		return false
	end


	-- Create a new manual squad from an explicit list of unit IDs. 
	-- Returns the new squad's .index on success, nil if no eligible units were found.
	-- Does not touch the player's selection or the reserve-merge gate.
	WG['squadselection'].createSquadFromUnits = function(unitIds)
		if not unitIds or #unitIds == 0 then
			return nil
		end

		local newSquad = {}
		for i = 1, #unitIds do
			local u = unitIds[i]
			local defId = getDefid(u)
			if defId and isCombat[defId] and unitSquad[u] then
				removeFromSquad(u)
				addToSquad(u, newSquad)
			end
		end

		if #newSquad == 0 then
			return nil
		end

		assignSquadTag(newSquad)
		squads[#squads + 1] = newSquad
		pruneEmptySquads()
		notifySquadChange("rebuild", nil, nil)
		selectionDirty = true
		pushToMru(newSquad)

		log("WG createSquadFromUnits: squad [", newSquad.index, "] with ", #newSquad, " units")
		return newSquad.index
	end


	registerOptions()

	log("Initialized — ", count, " combat units in domain uncategorized reserves")
end


function widget:Update(dt)
	if pendingDragCreate then
		local mx, my, _, _, rmb = spGetMouseState()
		local _, ctrl = spGetModKeyState()
		if not (rmb and ctrl) then
			-- RMB released or Ctrl let go before dragging far enough: no create.
			pendingDragCreate = nil
		else
			local dx = mx - pendingDragCreate.x
			local dy = my - pendingDragCreate.y
			local threshold = spGetConfigInt("MouseDragFrontCommandThreshold", 30) or 30
			if dx * dx + dy * dy >= threshold * threshold then
				squadCreate()
				pendingDragCreate = nil
			end
		end
	end

	if pendingSquadMove then
		local mx, my, _, _, rmb = spGetMouseState()
		if pendingSquadMove.requiresDrag and not pendingSquadMove.dragged then
			local dx = mx - pendingSquadMove.x
			local dy = my - pendingSquadMove.y
			local threshold = spGetConfigInt("MouseDragFrontCommandThreshold", 30) or 30
			pendingSquadMove.dragged = dx * dx + dy * dy >= threshold * threshold
		end
		if not rmb then
			-- RMB released: move-order the picked squad to the release point.
			local sq = pendingSquadMove.squad
			local formation = pendingSquadMove.formation
			local keepSelection = pendingSquadMove.keepSelection
			local clickWithoutDrag = pendingSquadMove.requiresDrag and not pendingSquadMove.dragged
			pendingSquadMove = nil
			if clickWithoutDrag then
				-- Never dragged, so this was the game's move-into-formation click.
				giveBackRightClickMove()
				log("RMB click handed back to the game (no drag)")
			elseif sq and #sq > 0 then
				local wx, wz = getMouseWorldPos()
				if wx then
					local wy = spGetGroundHeight(wx, wz) or 0
					local units = {}
					for i = 1, #sq do
						units[i] = sq[i]
					end
					local _, _, _, shift = spGetModKeyState()
					local opts = (shift and CMD.OPT_SHIFT or 0) + (formation and CMD.OPT_CTRL or 0)
					local saved = spGetSelectedUnits()
					spSelectUnitArray(units)
					spGiveOrder(CMD.MOVE, {wx, wy, wz}, opts)
					-- Commanding a reserve promotes it to a manual squad.
					if config.rightClickMoveControlsReserves and sq.isReserve then
						createSquadFromSelection()
						local promoted = unitSquad[units[1]]
						if promoted then
							-- Re-latch the Shift lock so queued follow-up moves keep hitting the same units.
							if highlightLockedSquad == sq then
								highlightLockedSquad = promoted
							end
							sq = promoted
						end
					end
					if not keepSelection then
						spSelectUnitArray(saved)
					end
					pushToMru(sq)
					log("RMB squad ", formation and "formation move" or "move", " [", sq.index or "?", "]: ", #units, " unit(s)", shift and " (queued)" or "")
				end
			end
		end
	end

	if #squads == 0 then
		idleScanIndex = 0
		return
	end

	if idleScanIndex >= #squads then
		idleScanIndex = 0
	end
	idleScanIndex = idleScanIndex + 1

	local sq = squads[idleScanIndex]
	if sq then
		refreshSquadIdleState(sq)
	end

	-- Highlight closest-squad, commanded squad, next closest-squad, etc. with throttle.
	highlightRecomputeAccum = highlightRecomputeAccum + dt
	if highlightRecomputeAccum >= HIGHLIGHT_RECOMPUTE_INTERVAL then
		highlightRecomputeAccum = 0
		highlightTarget, controlTarget = nil, nil
		if pendingSquadMove then
			highlightTarget = pendingSquadMove.squad
			controlTarget = highlightTarget
		else
			local alt, _, _, shift = spGetModKeyState()
			local maxDistSq = config.rightClickMoveRange > 0 and config.rightClickMoveRange * config.rightClickMoveRange or nil
			if config.rightClickMovesSquad and (alt or spGetSelectedUnits()[1] == nil) and not rightClickWouldIssueOrder() then
				-- Squad-move engaged: RMB commands the closest squad.
				local hx, hz = getMouseWorldPos()
				if not (shift and highlightLockedSquad) then
					highlightLockedSquad = hx and findClosestSquad(nil, nil, nil, hx, hz, nil, maxDistSq, rightClickMoveSquadKind()) or nil
				end
				highlightTarget = highlightLockedSquad
				if shift then
					-- A Shift-latched squad is the live target of the queued moves, so show it as controlled.
					controlTarget = highlightLockedSquad
				else
					highlightLockedSquad = nil
					-- A reserve the gesture skips is still selectable, so the preview keeps
					-- showing the closest squad of any kind — same thing the passive highlight shows.
					if hx and rightClickMoveSquadKind() then
						highlightTarget = findClosestSquad(nil, nil, nil, hx, hz, nil, maxDistSq) or highlightTarget
					end
				end
			else
				-- Passive closest-squad highlight
				highlightLockedSquad = nil
				local hx, hz = getMouseWorldPos()
				if hx then
					highlightTarget = findClosestSquad(nil, nil, nil, hx, hz, nil, maxDistSq)
					if highlightTarget then
						local sel = analyzeSelection()
						if squadFullySelected(highlightTarget, sel.selectedSet) then
							-- Mirror squad_select's cycle-when-full: a fully-selected closest squad makes a plain squad-select skip to the next closest, so highlight that one instead.
							highlightTarget = config.cyclingToNextSquad and findClosestSquad(nil, nil, sel.selectedSet, hx, hz, nil, maxDistSq) or nil
						end
					end
				end
			end
		end
	end

	-- Animate idle + highlight + control blends for all squads.
	local step = config.idleColorBlendSeconds > 0 and constrain(dt / config.idleColorBlendSeconds, 0, 1) or 1
	local hlStep = config.highlightBlendSeconds > 0 and constrain(dt / config.highlightBlendSeconds, 0, 1) or 1
	-- A highlighted reserve the right-click move won't command only answers half
	-- the gestures (select yes, move no), so it previews at half strength.
	local hlStrength = 1.0
	if highlightTarget and highlightTarget.isReserve and config.rightClickMovesSquad and not config.rightClickMoveControlsReserves then
		hlStrength = 0.5
	end
	for i = 1, #squads do
		local s = squads[i]
		squadIdleBlend[s] = approach(squadIdleBlend[s] or 0, squadIdleState[s] and 1 or 0, step)
		squadHighlightBlend[s] = approach(squadHighlightBlend[s] or 0, s == highlightTarget and hlStrength or 0, hlStep)
		squadControlBlend[s] = approach(squadControlBlend[s] or 0, s == controlTarget and 1 or 0, hlStep)
	end
end


function widget:Shutdown()
	unregisterOptions()
	beforeSquadSelectCallback = nil
	squadChangeListeners = {}
	WG['squadselection'] = nil
	widgetHandler:RemoveAction("squad_create")
	widgetHandler:RemoveAction("squad_select")
	widgetHandler:RemoveAction("squad_select_filtered")
	widgetHandler:RemoveAction("squad_select_group")
	widgetHandler:RemoveAction("squad_select_portion")
	widgetHandler:RemoveAction("squad_select_portion_filtered")
	widgetHandler:RemoveAction("squad_select_portion_group")
	widgetHandler:RemoveAction("squad_limit_flip")
	widgetHandler:RemoveAction("squad_limit")
	widgetHandler:RemoveAction("squad_flip")
	widgetHandler:RemoveAction("squad_setting")
	widgetHandler:RemoveAction("squad_cycle_recent")
	widgetHandler:RemoveAction("squad_cycle_idle")
	cleanupGlHull()
	log("Shutdown")
end


function widget:PlayerChanged(playerID)
	if playerID ~= spGetMyPlayerID() then
		return
	end
	if spGetSpectatingState() then
		log("Became spectator, shutting down")
		widgetHandler:RemoveWidget()
	end
end


function widget:GameOver()
	widgetHandler:RemoveWidget()
end


function widget:UnitCreated(unitId, unitDefId, unitTeam, builderId)
	if unitTeam ~= spGetMyTeamID() then
		return
	end
	defidOf[unitId] = unitDefId or false

	if unitDefId and isFactory[unitDefId] then
		createFactorySquad(unitId)
	end

	if unitDefId and isCombat[unitDefId] then
		local sq = (builderId and factorySquad[builderId]) or getUncategorizedReserveForDef(unitDefId)
		addToSquad(unitId, sq)
		log("Unit ", unitId, " created → squad [", sq.index or "?", "] (", #sq, " units)")
	end
end


--- Remove a unit's tracking state (combat unit AND/OR factory).
-- Returns true if anything was cleared.
local function stopTracking(unitId)
	local tracked = unitSquad[unitId] ~= nil
	local wasFactory = factorySquad[unitId] ~= nil

	removeFromSquad(unitId)
	defidOf[unitId] = nil
	factorySquad[unitId] = nil

	if tracked or wasFactory then
		pruneEmptySquads()
		return true
	end
	return false
end


function widget:UnitDestroyed(unitId, unitDefId, unitTeam, _)
	if stopTracking(unitId) then
		log("Unit ", unitId, " destroyed — ", #squads, " squad(s) remain")
	end
end


function widget:UnitTaken(unitId, unitDefId, unitTeam, newTeam)
	if unitTeam ~= spGetMyTeamID() then
		return
	end
	if stopTracking(unitId) then
		log("Unit ", unitId, " taken by team ", newTeam)
	end
end


function widget:UnitGiven(unitId, unitDefId, unitTeam, oldTeam)
	if unitTeam ~= spGetMyTeamID() then
		return
	end
	defidOf[unitId] = unitDefId or false

	if unitDefId and isFactory[unitDefId] then
		createFactorySquad(unitId)
	end

	if unitDefId and isCombat[unitDefId] then
		local sq = getUncategorizedReserveForDef(unitDefId)
		addToSquad(unitId, sq)
		log("Unit ", unitId, " given to us → uncategorized-", (sq.uncatDomain or "?"), " reserve (", #sq, " units)")
	end
end


-------------------------------------------------------------------------------
-- Selection-change tracking (for cached allSelected per squad)
-------------------------------------------------------------------------------

function widget:SelectionChanged(sel)
	-- Reset all counts
	for sq, _ in pairs(squadSelCount) do
		squadSelCount[sq] = 0
	end
	-- Tally from the new selection
	for i = 1, #sel do
		local sq = unitSquad[sel[i]]
		if sq then
			squadSelCount[sq] = (squadSelCount[sq] or 0) + 1
		end
	end
	selectionDirty = false
end


-------------------------------------------------------------------------------
-- Input
-------------------------------------------------------------------------------
function widget:MousePress(x, y, button)
	playerInputSinceLastResquad = true
	local alt, ctrl, meta, shift = spGetModKeyState()
	local cursor = spGetMouseCursor()
	if button == 3 then
		local plain = not (alt or ctrl or meta or shift)
		local modCombo = ctrl and not alt and not meta and not shift
		-- The squad-move gesture fires like a normal RMB move: Alt commands a squad
		-- even with units selected; without Alt only when nothing is selected, so we
		-- never hijack an RMB move of your current selection. With a selection the Alt
		-- form also needs a drag, since an Alt+RMB click is the game's own
		-- move-into-formation (see requiresDrag). Shift queues, Ctrl makes
		-- it a slowest-speed "move in formation", and Space (meta) keeps the moved
		-- squad selected — Space sets keepSelection only, never WHEN we fire.
		local willCreate = (config.rightClickSquadCreate and plain) or (config.ctrlRightClickCreatesSquad and modCombo)
		if (willCreate and cursor ~= "cursornormal") then
			squadCreate()
		elseif config.ctrlRightClickDragCreatesSquad and modCombo and cursor ~= "cursornormal" then
			-- Defer creation: fire only once the player drags past the engine's
			-- front-command threshold (checked in widget:Update). A plain Ctrl+RMB
			-- with no drag never creates in this mode.
			pendingDragCreate = {
				x = x,
				y = y,
			}
		elseif config.rightClickMovesSquad and widget.canControlUnits and (alt or spGetSelectedUnits()[1] == nil) then
			-- Skip when the click already carries an order (a pending fight/patrol/build that RMB cancels, or a default command such as resurrect).
			if rightClickWouldIssueOrder() then
				return false
			end
			if spTraceScreenRay(x, y) ~= "unit" then
				local sq
				if shift and highlightLockedSquad and #highlightLockedSquad > 0 then
					-- Shift reuses the latched squad so each queued move hits it.
					sq = highlightLockedSquad
				else
					local wx, wz = getMouseWorldPos()
					if wx then
						local maxDistSq = config.rightClickMoveRange > 0 and config.rightClickMoveRange * config.rightClickMoveRange or nil
						sq = findClosestSquad(nil, nil, nil, wx, wz, nil, maxDistSq, rightClickMoveSquadKind())
					end
				end
				-- If the picked squad is exactly the current selection, don't
				-- intercept — let the engine drive its normal RMB drag (formation
				-- move) rather than clobbering it with our single-point order.
				-- Exception: Space (meta) is not a formation drag but the engine's
				-- front-of-queue insert; Alt+Space explicitly asks for the widget's
				-- simple move, so we still intercept even when picked == selection.
				local pickedIsSelection = false
				if sq and not meta then
					local selUnits = spGetSelectedUnits()
					if #selUnits == #sq then
						local selSet = {}
						for i = 1, #selUnits do
							selSet[selUnits[i]] = true
						end
						pickedIsSelection = squadFullySelected(sq, selSet)
					end
				end
				if sq and not pickedIsSelection then
					pendingSquadMove = {
						squad = sq,
						formation = ctrl, -- Ctrl → slowest-speed "move in formation" (see widget:Update)
						keepSelection = meta, -- Space → leave the moved squad selected instead of restoring
						x = x,
						y = y,
						requiresDrag = alt and spGetSelectedUnits()[1] ~= nil, -- an Alt+RMB click over a live selection is the game's move-into-formation; only a drag is ours
					}
					if alt then
						return true -- consume so the engine doesn't move the current selection
					end
				end
			end
		end
	elseif button == 1 and config.leftClickSelectsSquad then
		-- A plain ground click normally deselects the selection on mouse-release
		-- (engine behavior), which would wipe the squad we just selected here on
		-- press. So a modifier is required to trigger: Ctrl → replace,
		-- Ctrl+Shift → append, +Alt → filtered. Alt+Shift also triggers (filtered
		-- append) since Ctrl is redundant there.
		--
		-- Exception: when SmartSelect's "deselect only when drag-selecting" option
		-- is on, a plain click keeps the selection, so we drop the modifier
		-- requirement and allow modifier-free squad-select (plain → replace,
		-- Shift → append, Alt → filtered, Alt+Shift → filtered append).
		if not (ctrl or (alt and shift)) then
			return
		end

		-- Skip when an active command is pending (fight, patrol, build, etc.). This may be unnecessary or should be configurable.
		local _, cmdID = spGetActiveCommand()
		if cmdID then
			return
		end
		-- Skip clicks that land directly on a unit — engine select takes over.
		if spTraceScreenRay(x, y) == "unit" then
			return
		end
		-- Skip when something is already selected and the cursor isn't the move
		-- cursor (hack: implies we're over a UI element, not open ground).
		if spGetSelectedUnits()[1] ~= nil and cursor ~= "Move" then
			return
		end

		-- Normal mode: the whole closest squad, any kind, no distance cap.
		-- Alternative mode: leftClickAlternativeArgs in full — step values,
		-- distance cap and squad-kind filter.
		local steps, maxDistance, squadKind = {1}, nil, nil
		if config.leftClickAlternativeSelection then
			local _, _, _, cfgSquadKind, cfgSteps, cfgMaxDistance = parseSelectArgs(config.leftClickAlternativeArgs)
			steps = #cfgSteps > 0 and cfgSteps or {1}
			maxDistance, squadKind = cfgMaxDistance, cfgSquadKind
		end
		-- Whole-squad mode = the config is just {1} (or was empty and fell back
		-- to {1}). Anything else (including {0.5} or {5}) is portion mode.
		local wholeSquad = #steps == 1 and steps[1] == 1
		local append = shift

		-- Append always cycles across squads (grow-the-selection semantics).
		-- Whole-squad replace cycles per user config. 
		local opts = {
			append = append,
			useDomainFilter = append and config.leftClickAppendFiltersDomain,
			steps = steps,
			maxDistance = maxDistance,
			squadKind = squadKind,
			isMousePress = true,
			cycleWhenFull = append or (wholeSquad and config.cyclingToNextSquad),
		}

		if alt then
			local wx, wz = getMouseWorldPos()
			if not wx then
				return
			end
			local sel = analyzeSelection()
			opts.filterDefs = (config.leftClickFilteredRetargets and not append) and resolveRetargetFilterDefs(sel, wx, wz, squadKind) or resolveFilterDefs(sel, wx, wz, squadKind)
			if not opts.filterDefs then
				return
			end
		end

		doSquadSelect(opts)
	end
	-- Never return true: let the click pass through to the engine.
end


function widget:KeyPress(key, mods, isRepeat)
	playerInputSinceLastResquad = true
end


-------------------------------------------------------------------------------
-- Settings persistence (data/LuaUi/Config/BYAR.lua -> Squad Selection)
-------------------------------------------------------------------------------

function widget:SetConfigData(data)
	for key, value in pairs(data) do
		if config[key] ~= nil then
			config[key] = value
		end
	end
end


function widget:GetConfigData()
	return config
end


-------------------------------------------------------------------------------
-- Drawing
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Convex hull
-------------------------------------------------------------------------------

-- Persistent scratch buffers. Tables inside (scratchWorld / scratchPadded
-- entries) are reused across frames. scratchHull / scratchUpper hold refs
-- *into* scratchWorld, not independent tables.
local scratchWorld = {} -- {x=world_x, y=world_z} per unit
local scratchHull = {} -- refs into scratchWorld
local scratchUpper = {} -- internal to convexHull
local scratchPadded = {} -- {x, y} per padded-hull vertex
local scratchFlat = {} -- flat {x, y, z, x, y, z, ...} for VBO upload

local function comparePoints(a, b)
	return a.x < b.x or (a.x == b.x and a.y < b.y)
end


local function cross(o, a, b)
	return (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x)
end


local function truncate(buf, newLen)
	for i = #buf, newLen + 1, -1 do
		buf[i] = nil
	end
end


-- Writes refs-into-world into out. Sorts `world` in place. Expects #world == n.
local function convexHull(world, n, out, upper)
	table.sort(world, comparePoints)

	local h = 0
	for i = 1, n do
		local p = world[i]
		while h >= 2 and cross(out[h - 1], out[h], p) <= 0 do
			out[h] = nil
			h = h - 1
		end
		h = h + 1
		out[h] = p
	end

	local u = 0
	for i = n, 1, -1 do
		local p = world[i]
		while u >= 2 and cross(upper[u - 1], upper[u], p) <= 0 do
			upper[u] = nil
			u = u - 1
		end
		u = u + 1
		upper[u] = p
	end

	for i = 2, u - 1 do
		h = h + 1
		out[h] = upper[i]
	end

	truncate(upper, 0)
	truncate(out, h)
	return h
end


-- circle for squads with only one unit. Writes into out, reuses its tables.
local function paddedCircle(cx, cy, radius, arcSegmentsAngle, out)
	local segments = math.max(math.ceil(2 * math.pi / arcSegmentsAngle), 3)
	for i = 0, segments - 1 do
		local angle = 2 * math.pi * i / segments
		local p = out[i + 1]
		if not p then
			p = {}
			out[i + 1] = p
		end
		p.x = cx + radius * math.cos(angle)
		p.y = cy + radius * math.sin(angle)
	end
	truncate(out, segments)
	return segments
end


-- rounded padded convex hull for 2+ units. Writes into out, reuses its tables.
local function paddedMoreThanOneUnit(hull, nHull, radius, arcSegmentsAngle, out)
	local n = 0
	for i = 1, nHull do
		local prev = hull[i == 1 and nHull or i - 1]
		local curr = hull[i]
		local nxt = hull[i == nHull and 1 or i + 1]

		local dxPrev = curr.x - prev.x
		local dyPrev = curr.y - prev.y
		local dxNext = nxt.x - curr.x
		local dyNext = nxt.y - curr.y

		-- right normals (outward for CCW): (dy, -dx)
		local anglePrev = math.atan2(-dxPrev, dyPrev)
		local angleNext = math.atan2(-dxNext, dyNext)
		local angleDiff = angleNext - anglePrev
		while angleDiff < 0 do
			angleDiff = angleDiff + 2 * math.pi
		end
		local arcSegments = math.max(math.ceil(angleDiff / arcSegmentsAngle), 1)
		for j = 0, arcSegments do
			local t = j / arcSegments
			local theta = anglePrev + t * angleDiff
			n = n + 1
			local p = out[n]
			if not p then
				p = {}
				out[n] = p
			end
			p.x = curr.x + radius * math.cos(theta)
			p.y = curr.y + radius * math.sin(theta)
		end
	end
	truncate(out, n)
	return n
end


-- Fill scratchPadded from scratchWorld[1..nWorld]. Returns padded count.
local function getPaddedHull(nWorld, radius, arcSegmentsAngle)
	if nWorld == 1 then
		local p = scratchWorld[1]
		return paddedCircle(p.x, p.y, radius, arcSegmentsAngle, scratchPadded)
	elseif nWorld >= 2 then
		local nHull = convexHull(scratchWorld, nWorld, scratchHull, scratchUpper)
		return paddedMoreThanOneUnit(scratchHull, nHull, radius, arcSegmentsAngle, scratchPadded)
	else
		truncate(scratchPadded, 0)
		return 0
	end
end


function widget:DrawWorldPreUnit()
	if spIsGUIHidden() or config.visualizationMode ~= "convexHull" then
		return
	end
	if not squads or #squads == 0 then
		return
	end
	if not hullReady and not initGlHull() then
		return
	end

	-- Lazy recount if SelectionChanged hasn't fired yet (e.g. first frame)
	if selectionDirty then
		local sel = spGetSelectedUnits()
		for sq, _ in pairs(squadSelCount) do
			squadSelCount[sq] = 0
		end
		for i = 1, #sel do
			local sq = unitSquad[sel[i]]
			if sq then
				squadSelCount[sq] = (squadSelCount[sq] or 0) + 1
			end
		end
		selectionDirty = false
	end

	-- re-read styling each frame so squad_setting changes take effect live
	local fillOpacity = config.convexHullFillOpacity
	local borderOpacity = config.convexHullBorderOpacity
	local borderThickness = config.convexHullBorderThickness
	local padding = config.convexHullPadding
	local arcRes = config.convexHullArcResolution
	local showReserves = config.showReserveSquads
	local colorMode = config.convexHullColorMode

	if not hullTimeOrigin then
		hullTimeOrigin = spGetTimer()
	end
	local now = spDiffTimers(spGetTimer(), hullTimeOrigin)

	glDepthTest(false)
	glUseShader(hullShader)
	glLineWidth(borderThickness)

	for _, squad in ipairs(squads) do
		if not squad.isReserve or showReserves then
			local size = #squad
			if size > 0 then
				local idleBlend = squadIdleBlend[squad] or 0
				local hb = squadHighlightBlend[squad] or 0
				local ctb = squadControlBlend[squad] or 0
				local fullySelected = (squadSelCount[squad] or 0) >= size
				local alphaScale = 1
				if squadHideIdleAirHull[squad] then
					-- Idle strafing air squads normally fade their hull out, but keep it visible while fully selected, highlighted, or controlled
					alphaScale = fullySelected and 1 or math.max(1 - idleBlend, hb, ctb)
				end

				if alphaScale <= 0.001 then
					-- Fully hidden for idle flying-air squads.
				else
					local cr, cg, cb
					if fullySelected then
						cr, cg, cb = 1, 1, 1
					elseif colorMode == "custom" then
						cr, cg, cb = config.convexHullCustomColorR, config.convexHullCustomColorG, config.convexHullCustomColorB
					elseif colorMode == "squad" and squad.color then
						cr, cg, cb = squad.color[1], squad.color[2], squad.color[3]
					else
						cr = teamColor[1]
						cg = teamColor[2]
						cb = teamColor[3]
					end
					local effIdle = idleBlend * (1 - hb)
					if effIdle > 0 and not fullySelected then
						local ir = cr * 0.3
						local ig = cg * 0.3
						local ib = cb * 0.3
						cr = cr + (ir - cr) * effIdle
						cg = cg + (ig - cg) * effIdle
						cb = cb + (ib - cb) * effIdle
					end
					if squad.isReserve then
						alphaScale = alphaScale * 0.70
						cr, cg, cb = cr * 1.25, cg * 1.25, cb * 1.25
					end

					-- Highlight tiers faded in by their blends.
					local effFill, effBorder = fillOpacity, borderOpacity
					local effPadding = padding
					if hb > 0 or ctb > 0 then
						effFill = math.min(1, fillOpacity + 0.2 * hb + 0.2 * ctb)
						effBorder = math.min(1, borderOpacity + 0.4 * hb + 0.4 * ctb)
						effPadding = padding + 5 * hb + 5 * ctb
						local bright = 0.4 * ctb
						cr = cr + (1 - cr) * bright
						cg = cg + (1 - cg) * bright
						cb = cb + (1 - cb) * bright
					end

					-- fill scratchWorld in place (reuse {x,y} tables) and track
					-- the bbox in the same pass, so we can frustum-cull without a
					-- second iteration.
					local nWorld = 0
					local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
					for i = 1, size do
						local x, _, z = spGetUnitPosition(squad[i])
						if x and z then
							nWorld = nWorld + 1
							local p = scratchWorld[nWorld]
							if not p then
								p = {}
								scratchWorld[nWorld] = p
							end
							p.x = x
							p.y = z
							if x < minX then
								minX = x
							end
							if x > maxX then
								maxX = x
							end
							if z < minZ then
								minZ = z
							end
							if z > maxZ then
								maxZ = z
							end
						end
					end
					truncate(scratchWorld, nWorld)

					if nWorld > 0 then
						-- Frustum cull: enclose the squad + padding in one sphere
						-- around the bbox centre. Vertical slop (256) covers
						-- terrain variation under the ground-projected hull.
						local cx = (minX + maxX) * 0.5
						local cz = (minZ + maxZ) * 0.5
						local hx = (maxX - minX) * 0.5
						local hz = (maxZ - minZ) * 0.5
						local cy = spGetGroundHeight(cx, cz)
						local radius = math.sqrt(hx * hx + hz * hz) + effPadding + 256
						local visible = (not spIsSphereInView) or spIsSphereInView(cx, cy, cz, radius)

						if visible then
							local n = getPaddedHull(nWorld, effPadding, arcRes)
							if n >= 3 and n <= HULL_MAX_VERTICES then
								local seed = squad.tagSeed or 0

								-- Centroid (average of padded vertices) and max radius
								-- are uploaded as a uniform to drive the fragment-shader
								-- center -> edge alpha gradient. The hull stays convex so
								-- TRIANGLE_FAN can still pivot on vertex 0.
								local pcx, pcy = 0, 0
								local fi = 0
								for i = 1, n do
									local p = scratchPadded[i]
									pcx = pcx + p.x
									pcy = pcy + p.y
									scratchFlat[fi + 1] = p.x
									scratchFlat[fi + 2] = spGetGroundHeight(p.x, p.y)
									scratchFlat[fi + 3] = p.y
									fi = fi + 3
								end
								pcx = pcx / n
								pcy = pcy / n

								local maxR2 = 0
								for i = 1, n do
									local p = scratchPadded[i]
									local rdx = p.x - pcx
									local rdy = p.y - pcy
									local r2 = rdx * rdx + rdy * rdy
									if r2 > maxR2 then
										maxR2 = r2
									end
								end
								local hullRadiusNorm = math.sqrt(maxR2)

								hullVbo:Upload(scratchFlat, nil, nil, 1, fi)

								local pulseVal = 1 + config.hullPulseAmplitude * math.sin(now * config.hullPulseRate + seed * 6.2831853)
								glUniform(hullCentroidLoc, pcx, pcy, hullRadiusNorm)
								glUniform(hullPulseLoc, pulseVal)

								if squad.isReserve then
									glUniform(hullStripeLoc, config.reserveStripePeriod, config.reserveStripeAlphaMul, seed * config.reserveStripePeriod)
								else
									glUniform(hullStripeLoc, 0, 1, 0)
								end
								glUniform(hullColorLoc, cr, cg, cb, effFill * alphaScale)
								hullVao:DrawArrays(GL.TRIANGLE_FAN, n)
								if squad.isReserve then
									glUniform(hullStripeLoc, 0, 1, 0)
								end
								glUniform(hullColorLoc, cr, cg, cb, effBorder * alphaScale)
								if hb > 0 then
									glLineWidth(borderThickness + 1.5 * hb)
									hullVao:DrawArrays(GL.LINE_LOOP, n)
									glLineWidth(borderThickness)
								else
									hullVao:DrawArrays(GL.LINE_LOOP, n)
								end
							end
						end
					end
				end
			end
		end
	end

	glUseShader(0)
	glLineWidth(1)
	glDepthTest(true)
	glColor(1, 1, 1, 1)
end


function widget:UnitCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOpts, cmdTag)

	if not config.commandCreatesSquad then
		return
	end

	local teamId = spGetMyTeamID()
	if playerInputSinceLastResquad and unitTeam == teamId and isCombat[unitDefID] then
		createSquadFromSelection(unitID)
	end
end


