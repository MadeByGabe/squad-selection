function widget:GetInfo()
	return {
		name = "Squad Selection Colored Labels (example)",
		desc = "Squad Selection companion widget: draws squad letters above units using getSquadState(). Note: this is not GPU accelerated and is meant as an example of using the API, not as a polished visualization.",
		author = "Baldric",
		date = "2026",
		license = "GNU GPL, v2 or later",
		layer = -999998,
		enabled = false,
	}
end


-- Draws a floating letter above each unit indicating its squad.
-- Uses WG['squadselection'].getSquadState() to read live squad data.

local spGetUnitPosition = Spring.GetUnitPosition
local spWorldToScreenCoords = Spring.WorldToScreenCoords
local spIsGUIHidden = Spring.IsGUIHidden
local glColor = gl.Color
local glText = gl.Text

local LETTERS = "ABCDEFGHIJKLMNOPQRSTUVWXYZ+#@!$=&"

local function indexToLetter(idx)
	local i = (idx - 1) % #LETTERS + 1
	return LETTERS:sub(i, i)
end


local function getApi()
	return WG and WG['squadselection']
end


function widget:DrawScreenEffects()
	if spIsGUIHidden() then
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

	local showReserves = api.getShowReserveSquads and api.getShowReserveSquads()
	local squads = state.squads
	local factorySquad = state.factorySquad
	local squadIdleBlend = state.squadIdleBlend

	for i = 1, #squads do
		local sq = squads[i]
		if #sq > 0 and (not sq.isReserve or showReserves) then
			local idx = sq.index
			local sc = sq.color
			local r, g, b = sc and sc[1] or 1, sc and sc[2] or 1, sc and sc[3] or 1
			local blend = (squadIdleBlend and squadIdleBlend[sq]) or 0
			local dim = 1 - blend * 0.5
			r, g, b = r * dim, g * dim, b * dim
			local label = indexToLetter(idx)
			glColor(r, g, b, 1)
			for j = 1, #sq do
				-- Predicted position keeps the label glued to moving units between sim frames.
				local _, _, _, x, y, z = spGetUnitPosition(sq[j], true)
				if x then
					local sx, sy = spWorldToScreenCoords(x, y + 20, z)
					if sx then
						glText(label, sx, sy, 11, "co")
					end
				end
			end
		end
	end

	if showReserves and factorySquad then
		for fid, sq in pairs(factorySquad) do
			local idx = sq.index
			local sc = sq.color
			local r, g, b = sc and sc[1] or 1, sc and sc[2] or 1, sc and sc[3] or 1
			local label = indexToLetter(idx)
			local _, _, _, x, y, z = spGetUnitPosition(fid, true)
			if x then
				local sx, sy = spWorldToScreenCoords(x, y, z)
				if sx then
					glColor(r, g, b, 1)
					glText(label, sx, sy, 14, "co")
				end
			end
		end
	end

	glColor(1, 1, 1, 1)
end


