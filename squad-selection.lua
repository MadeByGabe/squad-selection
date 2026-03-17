function widget:GetInfo()
	return {
		name = "Squad Selection",
		desc = "Automagical squad creation and proximity-based selection",
		author = "Baldric, yyyy",
		date = "2026",
		license = "GNU GPL, v2 or later",
		layer = -999998,
		enabled = true,
	}
end


-------------------------------------------------------------------------------
-- Config
-------------------------------------------------------------------------------

local LEFT_CLICK_SELECTS_SQUAD = true -- left-click can be used to select squads
local CYCLING_TO_NEXT_SQUAD = true -- when full squad/type is selected, exclude it to cycle to next

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
local spWorldToScreenCoords = Spring.WorldToScreenCoords
local spIsGUIHidden = Spring.IsGUIHidden
local spGetModKeyState = Spring.GetModKeyState

local glColor = gl.Color
local glText = gl.Text

-------------------------------------------------------------------------------
-- State
-------------------------------------------------------------------------------

local squads = {} -- ordered list of squad arrays; reserve squads are always first
local unit_squad = {} -- unitID -> the squad array it belongs to
local unit_slot = {} -- unitID -> index within that squad (for O(1) removal)
local reserve_squads = {} -- domain string -> reserve squad for that domain
local DOMAINS = {"land", "air", "naval"}

-------------------------------------------------------------------------------
-- Debug
-------------------------------------------------------------------------------

local DEBUG = false

local function log(msg)
	if DEBUG then
		spEcho("[Squad] " .. tostring(msg))
	end
end


local function log_squads()
	if not DEBUG then
		return
	end
	log("  " .. #squads .. " squad(s):")
	for _, squad in ipairs(squads) do
		local label = squad.letter or "?"
		if squad.domain then
			label = label .. ":" .. squad.domain
		end
		log("    [" .. label .. "] " .. #squad .. " units")
	end
end


-------------------------------------------------------------------------------
-- Squad-eligible exceptions
--
-- Units listed here are treated as squad-eligible even if they don't pass the
-- normal combat-unit filter (mobile + armed + no build options). Use the
-- internal unit name (UnitDefs[defID].name), NOT the human-readable name.
-------------------------------------------------------------------------------

local SQUAD_ELIGIBLE_EXTRAS = {
	corfink = true, -- Cortex T1 air scout
	corawac = true, -- Cortex T2 air scout
	armpeep = true, -- Arm T1 air scout
	armawac = true, -- Arm T2 air scout
}

-------------------------------------------------------------------------------
-- Squad appearance
--
-- Each squad gets a color and a letter, assigned on
-- creation.  These are stored directly on the squad table as string-keyed
-- fields (squad.color, squad.letter) which don't interfere with the integer-
-- keyed unit list or #squad.
-------------------------------------------------------------------------------

local SQUAD_COLORS = {
	{1.0, 0.3, 0.3}, -- red
	{0.3, 1.0, 0.3}, -- green
	{0.3, 0.5, 1.0}, -- blue
	{1.0, 1.0, 0.3}, -- yellow
	{1.0, 0.3, 1.0}, -- magenta
	{0.3, 1.0, 1.0}, -- cyan
	{1.0, 0.6, 0.2}, -- orange
	{0.7, 0.3, 1.0} -- purple
}

local SQUAD_LETTERS = "ABCDEFGHIJKLMNOPQRSTUVWXYZ+#@!$=&"
local next_squad_tag = 0

local RESERVE_SQUAD_STYLES = {
	land = {
		color = {0.75, 0.75, 0.55},
		letter = "-",
	},
	air = {
		color = {0.65, 0.55, 0.50},
		letter = "^",
	},
	naval = {
		color = {0.45, 0.55, 0.80},
		letter = "~",
	},
}

local function assign_squad_tag(squad)
	next_squad_tag = next_squad_tag + 1
	local ci = (next_squad_tag - 1) % #SQUAD_COLORS + 1
	local li = (next_squad_tag - 1) % #SQUAD_LETTERS + 1
	squad.color = SQUAD_COLORS[ci]
	squad.letter = SQUAD_LETTERS:sub(li, li)
end


-------------------------------------------------------------------------------
-- Unit classification
--
-- is_combat[defID] — true if the unit type is squad-eligible.
-- unit_domain[defID] — "land", "air", or "naval".
-- Both tables are fully populated once by classify_unitdefs() in Initialize,
-- so runtime lookups are a single table index with no branching.
-------------------------------------------------------------------------------

local defid_of = {} -- unitID -> defID  (false when lookup fails)
local is_combat = {} -- defID  -> bool
local unit_domain = {} -- defID -> "land" | "air" | "naval"

local function get_defid(unit_id)
	local v = defid_of[unit_id]
	if v ~= nil then
		return v
	end
	local id = spGetUnitDefID(unit_id)
	v = id or false
	defid_of[unit_id] = v
	return v
end


--- Pre-compute is_combat and unit_domain for every defID in one pass.
local function classify_unitdefs()
	for defID, def in pairs(UnitDefs) do
		-- Domain
		if def.canFly then
			unit_domain[defID] = "air"
		elseif def.minWaterDepth and def.minWaterDepth > 0 then
			unit_domain[defID] = "naval"
		else
			unit_domain[defID] = "land"
		end

		-- Squad eligibility
		if SQUAD_ELIGIBLE_EXTRAS[def.name] then
			is_combat[defID] = true
		elseif def.canMove and def.weapons and #def.weapons > 0 and not (def.buildOptions and #def.buildOptions > 0) then
			is_combat[defID] = true
		else
			is_combat[defID] = false
		end
	end
end


-------------------------------------------------------------------------------
-- Squad operations
-------------------------------------------------------------------------------

local function add_to_squad(unit_id, squad)
	local slot = #squad + 1
	squad[slot] = unit_id
	unit_squad[unit_id] = squad
	unit_slot[unit_id] = slot
end


-- Swap-with-last removal: O(1), order within a squad is not meaningful.
local function remove_from_squad(unit_id)
	local squad = unit_squad[unit_id]
	if not squad then
		return
	end

	local slot = unit_slot[unit_id]
	local last = squad[#squad]

	if last ~= unit_id then
		squad[slot] = last
		unit_slot[last] = slot
	end

	squad[#squad] = nil
	unit_squad[unit_id] = nil
	unit_slot[unit_id] = nil
end


-- Remove squads that have become empty (never removes reserve squads).
local function prune_empty_squads()
	for i = #squads, 1, -1 do
		local sq = squads[i]
		if not sq.is_reserve and #sq == 0 then
			log("Squad [" .. (sq.letter or "?") .. "] emptied and removed")
			table.remove(squads, i)
		end
	end
end


-------------------------------------------------------------------------------
-- Squad creation from selection
-------------------------------------------------------------------------------

-- Returns true when the selection and the squad are exactly the same set. 
-- In that case right-clicking is a no-op. This preserves the squad label and color.
local function selection_is_existing_squad(selected)
	local squad = nil
	local combat_count = 0
	for i = 1, #selected do
		local u = selected[i]
		local def_id = get_defid(u)
		if def_id and is_combat[def_id] then
			combat_count = combat_count + 1
			local s = unit_squad[u]
			if s and s.is_reserve then
				return false
			end
			if squad == nil then
				squad = s
			elseif s ~= squad then
				return false
			end
		end
	end
	return squad ~= nil and #squad == combat_count
end


local function create_squad_from_selection()
	local selected = spGetSelectedUnits()
	if #selected == 0 then
		return
	end
	if selection_is_existing_squad(selected) then
		return
	end

	local new_squad = {}
	for i = 1, #selected do
		local u = selected[i]
		local def_id = get_defid(u)
		if def_id and is_combat[def_id] then
			remove_from_squad(u)
			add_to_squad(u, new_squad)
		end
	end

	if #new_squad == 0 then
		return
	end

	assign_squad_tag(new_squad)
	squads[#squads + 1] = new_squad
	prune_empty_squads()

	log("New squad [" .. new_squad.letter .. "]: " .. #new_squad .. " units")
	log_squads()
end


-------------------------------------------------------------------------------
-- Finding closest unit
--
-- Returns the mouse cursor's world position, then iterates all tracked units
-- to find the one nearest to it.  Reusable for filtered variants later.
-------------------------------------------------------------------------------

local function get_mouse_world_pos()
	local mx, my = spGetMouseState()
	local _, coords = spTraceScreenRay(mx, my, true)
	if not coords then
		return nil
	end
	return coords[1], coords[3] -- world x, world z
end


-- Returns the unitID closest to the mouse cursor, or nil if none found.
-- Optional filter_defs (defID set) and exclude (unitID set) narrow the search.
local function find_closest_unit(filter_defs, exclude)
	local wx, wz = get_mouse_world_pos()
	if not wx then
		return nil
	end

	local best_unit = nil
	local best_dist_sq = math.huge

	for _, squad in ipairs(squads) do
		for j = 1, #squad do
			local u = squad[j]
			if not (exclude and exclude[u]) then
				if not filter_defs or (defid_of[u] and filter_defs[defid_of[u]]) then
					local x, _, z = spGetUnitPosition(u)
					if x then
						local dx = x - wx
						local dz = z - wz
						local dist_sq = dx * dx + dz * dz
						if dist_sq < best_dist_sq then
							best_dist_sq = dist_sq
							best_unit = u
						end
					end
				end
			end
		end
	end

	return best_unit
end


-------------------------------------------------------------------------------
-- Selection analysis
--
-- Classifies the current selection into one of four states:
--   no filter       — no tracked units selected (builders/empty)
--   single-squad    — all tracked units belong to one squad
--   multi-squad     — tracked units span multiple squads
--   full squad      — single-squad AND every unit in that squad is selected
--   full type match — single-squad AND every unit matching the filter types
--                     in that squad is selected (full squad implies this)
--
-- Returns a table with all the information both actions need.
-------------------------------------------------------------------------------

--- Inspect the current selection and return a summary used by squad-select actions.
--
-- Returns a table with:
--   selected          — array of currently selected unitIDs (from engine)
--   selected_set      — set (unitID → true) for O(1) membership tests
--   selected_type_set — set of defIDs present in the selection (only from
--                        tracked squad units). Used to filter squads by unit
--                        type, e.g. "select all Grunts in the closest squad".
--   has_tracked_units — true when at least one selected unit is a tracked
--                        squad unit with a known type. When false, callers
--                        fall back to type-agnostic behavior.
--   single_squad      — the squad table if every tracked unit belongs to the
--                        same squad, nil otherwise (mixed-squad or no squads).
--   is_full_squad     — true when the entire single_squad is selected.
--   is_full_type_match — true when every unit in single_squad whose type
--                        appears in selected_type_set is already selected.
--                        A full squad trivially satisfies this. Used by
--                        filtered-select to decide whether to cycle.
local function analyze_selection()
	local selected = spGetSelectedUnits()
	local selected_set = {}
	local selected_type_set = {}
	local has_tracked_units = false
	local single_squad = nil
	local from_multiple_squads = false
	local tracked_count = 0

	for i = 1, #selected do
		local u = selected[i]
		selected_set[u] = true
		local sq = unit_squad[u]
		if sq then
			tracked_count = tracked_count + 1
			local def_id = defid_of[u]
			if def_id then
				selected_type_set[def_id] = true
				has_tracked_units = true
			end
			if single_squad == nil then
				single_squad = sq
			elseif sq ~= single_squad then
				from_multiple_squads = true
			end
		end
	end

	if from_multiple_squads then
		single_squad = nil
	end

	local is_full_squad = single_squad ~= nil and tracked_count == #single_squad

	-- Check if all units of matching types in the single squad are selected.
	-- A full squad trivially satisfies this (every type is fully selected).
	local is_full_type_match = is_full_squad
	if single_squad and has_tracked_units and not is_full_squad then
		local matching_total = 0
		local matching_selected = 0
		for j = 1, #single_squad do
			local u = single_squad[j]
			local def_id = defid_of[u]
			if def_id and selected_type_set[def_id] then
				matching_total = matching_total + 1
				if selected_set[u] then
					matching_selected = matching_selected + 1
				end
			end
		end
		is_full_type_match = matching_total > 0 and matching_selected == matching_total
	end

	return {
		selected = selected,
		selected_set = selected_set,
		selected_type_set = selected_type_set,
		has_tracked_units = has_tracked_units,
		single_squad = single_squad,
		is_full_squad = is_full_squad,
		is_full_type_match = is_full_type_match,
	}
end


--- Filter a squad down to units whose defID is in the given set.
local function filter_squad_by_defs(squad, defs)
	local result = {}
	for j = 1, #squad do
		local u = squad[j]
		local def_id = defid_of[u]
		if def_id and defs[def_id] then
			result[#result + 1] = u
		end
	end
	return result
end


-------------------------------------------------------------------------------
-- Closest squad selection action
--
-- See development.md "Selection action decision matrix" for the full table.
-- Only excludes selected units from the closest-unit search when the entire
-- squad is already selected (to cycle to the next squad).
-------------------------------------------------------------------------------

local function closest_squad_select(_, _, args)
	local sel = analyze_selection()
	local append = args and args[1] == "append"

	-- Full squad: cycle to next squad (exclude selected) or fall through as multi-squad
	local exclude = nil
	if sel.is_full_squad and CYCLING_TO_NEXT_SQUAD then
		exclude = sel.selected_set
	end

	local unit = find_closest_unit(nil, exclude)
	if not unit then
		return
	end

	local squad = unit_squad[unit]
	if not squad then
		return
	end

	spSelectUnitArray(squad, append)
	log("Selected squad [" .. (squad.letter or "?") .. "] (" .. #squad .. " units)" .. (append and " +append" or ""))
end


-------------------------------------------------------------------------------
-- Filtered squad selection
--
-- See development.md "Selection action decision matrix" for the full table.
-- Three paths:
--   1. Single-squad, not all matching types selected → complete the type
--      selection within that squad (no closest-unit search needed).
--   2. Full type match → exclude selected and search for the next squad.
--   3. No filter / multi-squad → search for closest matching unit.
-------------------------------------------------------------------------------

local function closest_squad_select_filtered(_, _, args)
	local sel = analyze_selection()
	local append = args and args[1] == "append"

	-- Full type match: cycle to next squad (exclude selected) or fall through as multi-squad
	local exclude = nil
	if sel.is_full_type_match and CYCLING_TO_NEXT_SQUAD then
		exclude = sel.selected_set
	end

	local search_defs = sel.has_tracked_units and sel.selected_type_set or nil
	local closest = find_closest_unit(search_defs, exclude)
	if not closest then
		return
	end

	local squad = unit_squad[closest]
	if not squad then
		return
	end

	-- If no filter types from selection, use the closest unit's type
	local defs = sel.selected_type_set
	if not sel.has_tracked_units then
		local def_id = defid_of[closest]
		if not def_id then
			spSelectUnitArray({closest}, append)
			return
		end
		defs = {
			[def_id] = true,
		}
	end

	local result = filter_squad_by_defs(squad, defs)
	spSelectUnitArray(result, append)
	log("Filtered select from squad [" .. (squad.letter or "?") .. "]: " .. #result .. "/" .. #squad .. " units" .. (append and " +append" or ""))
end


-------------------------------------------------------------------------------
-- Lifecycle
-------------------------------------------------------------------------------

function widget:Initialize()
	squads = {}
	reserve_squads = {}
	unit_squad = {}
	unit_slot = {}
	next_squad_tag = 0

	classify_unitdefs()

	for _, domain in ipairs(DOMAINS) do
		local sq = {}
		local style = RESERVE_SQUAD_STYLES[domain]
		sq.color = style.color
		sq.letter = style.letter
		sq.is_reserve = true
		sq.domain = domain
		reserve_squads[domain] = sq
		squads[#squads + 1] = sq
	end

	local team_id = spGetMyTeamID()
	local all = spGetTeamUnits(team_id)
	local count = 0

	for i = 1, #all do
		local u = all[i]
		local def_id = get_defid(u)
		if def_id and is_combat[def_id] then
			add_to_squad(u, reserve_squads[unit_domain[def_id]])
			count = count + 1
		end
	end

	widgetHandler:AddAction("closest_squad_select", closest_squad_select, nil, "p")
	widgetHandler:AddAction("closest_squad_select_filtered", closest_squad_select_filtered, nil, "p")

	log("Initialized — " .. count .. " combat units across reserve squads")
	log_squads()
end


function widget:Shutdown()
	widgetHandler:RemoveAction("closest_squad_select")
	widgetHandler:RemoveAction("closest_squad_select_filtered")
	log("Shutdown")
end


function widget:UnitCreated(unit_id, unit_def_id, unit_team, builder_id)
	if unit_team ~= spGetMyTeamID() then
		return
	end
	defid_of[unit_id] = unit_def_id or false

	if unit_def_id and is_combat[unit_def_id] then
		local domain = unit_domain[unit_def_id]
		local sq = reserve_squads[domain]
		add_to_squad(unit_id, sq)
		log("Unit " .. unit_id .. " created → reserve:" .. domain .. " (" .. #sq .. " units)")
	end
end


function widget:UnitDestroyed(unit_id, unit_def_id, unit_team, attacker_id)
	local tracked = unit_squad[unit_id] ~= nil

	remove_from_squad(unit_id)
	defid_of[unit_id] = nil

	if tracked then
		prune_empty_squads()
		log("Unit " .. unit_id .. " destroyed — " .. #squads .. " squad(s) remain")
	end
end


function widget:UnitTaken(unit_id, unit_def_id, unit_team, new_team)
	if unit_team ~= spGetMyTeamID() then
		return
	end

	local tracked = unit_squad[unit_id] ~= nil

	remove_from_squad(unit_id)
	defid_of[unit_id] = nil

	if tracked then
		prune_empty_squads()
		log("Unit " .. unit_id .. " taken by team " .. new_team)
	end
end


function widget:UnitGiven(unit_id, unit_def_id, unit_team, old_team)
	if unit_team ~= spGetMyTeamID() then
		return
	end
	defid_of[unit_id] = unit_def_id or false

	if unit_def_id and is_combat[unit_def_id] then
		local domain = unit_domain[unit_def_id]
		local sq = reserve_squads[domain]
		add_to_squad(unit_id, sq)
		log("Unit " .. unit_id .. " given to us → reserve:" .. domain .. " (" .. #sq .. " units)")
	end
end


-------------------------------------------------------------------------------
-- Input
-------------------------------------------------------------------------------

function widget:MousePress(x, y, button)
	if button == 3 then
		local alt, ctrl, meta, shift = spGetModKeyState()
		if not (alt or ctrl or meta or shift) then
			create_squad_from_selection()
		end
	elseif button == 1 and LEFT_CLICK_SELECTS_SQUAD then
		local hit_type = spTraceScreenRay(x, y)
		if hit_type ~= "unit" then
			-- Skip if any selected unit is a builder (avoid interfering with build queuing)
			local selected = spGetSelectedUnits()
			local has_builder = false
			for i = 1, #selected do
				local def_id = get_defid(selected[i])
				if def_id then
					local def = UnitDefs[def_id]
					if def.buildOptions and #def.buildOptions > 0 then
						has_builder = true
						break
					end
				end
			end
			if not has_builder then
				local alt, ctrl, _, shift = spGetModKeyState()
				if alt and shift then
					closest_squad_select_filtered(nil, nil, {"append"})
				elseif alt and ctrl then
					closest_squad_select_filtered(nil, nil, nil)
				elseif shift then
					closest_squad_select(nil, nil, {"append"})
				elseif ctrl then
					closest_squad_select(nil, nil, nil)
				end
			end
		end
	end
	-- Never return true: let the click pass through to the engine.
end


-------------------------------------------------------------------------------
-- Drawing
--
-- Each squad draws its assigned letter above every unit in its color.
-------------------------------------------------------------------------------

function widget:DrawScreen()
	if spIsGUIHidden() then
		return
	end

	for _, squad in ipairs(squads) do
		if #squad > 0 and squad.color then
			local c = squad.color
			glColor(c[1], c[2], c[3], 0.75)
			for j = 1, #squad do
				local _, _, _, x, y, z = spGetUnitPosition(squad[j], true)
				if x then
					local sx, sy = spWorldToScreenCoords(x, y, z)
					if sx then
						glText(squad.letter, sx, sy + 14, 10, "co")
					end
				end
			end
		end
	end

	glColor(1, 1, 1, 1)
end


