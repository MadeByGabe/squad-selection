function widget:GetInfo()
	return {
		name = "Squad Selection Buttons",
		desc = "Squad Selection companion widget: on-screen buttons for the cursor-independent actions (cycle idle, cycle recent, create squad, exclude/include selected types). Anchors above the advanced player list if present.",
		author = "Baldric",
		date = "2026",
		license = "GNU GPL, v2 or later",
		layer = -9000,
		enabled = false,
	}
end


-- Draws a small row of clickable buttons for actions that have no natural
-- cursor context (so a hotkey isn't strictly required). Each button fires the
-- corresponding registered action via Spring.SendCommands and consumes the
-- click. Positioning is delegated to advplayerslist's exported panel rect so we
-- sit just above it; if that panel isn't loaded we fall back to the top-right
-- screen corner. No position persistence — we re-read the anchor every frame.

local spGetViewGeometry = Spring.GetViewGeometry
local spGetMouseState = Spring.GetMouseState
local spIsGUIHidden = Spring.IsGUIHidden
local spSendCommands = Spring.SendCommands
local spGetConfigFloat = Spring.GetConfigFloat
local spGetSelectedUnits = Spring.GetSelectedUnits
local spGetUnitDefID = Spring.GetUnitDefID
local spEcho = Spring.Echo

local glColor = gl.Color
local glRect = gl.Rect

-- left, bottom, right, top filled in each DrawScreen so MousePress can hit-test
-- against exactly what was drawn.
local buttons = {
	{
		label = "Idle",
		action = "squad_cycle_idle",
		tooltip = "Select the next idle squad",
	}, {
		label = "Recent",
		action = "squad_cycle_recent",
		tooltip = "Cycle through recently selected squads",
	}, {
		label = "Create",
		action = "squad_create",
		tooltip = "Group the current selection into a squad",
	}, {
		label = "Exclude",
		action = "squad_exclude_selected",
		tooltip = "Stop squad-tracking the selected units' types (adds them to excludedUnitTypes)",
	}, {
		label = "Include",
		action = "squad_unexclude_selected",
		tooltip = "Resume squad-tracking the selected units' types (removes them from excludedUnitTypes)",
	}}


-- Exclude/include the selected units' types from squad tracking. Implemented
-- here (not in the main widget) on top of the main widget's
-- `squad_setting add/remove excludedUnitTypes` chat commands, which dedupe,
-- rebuild tracking live, and echo the resulting list. Registered as actions so
-- they stay hotkey-bindable; the buttons fire them through the same path.
local function selected_unit_def_names()
	local sel = spGetSelectedUnits()
	local names = {}
	local seen = {}
	for i = 1, #sel do
		local def_id = spGetUnitDefID(sel[i])
		local def = def_id and UnitDefs[def_id]
		if def and def.name and not seen[def.name] then
			seen[def.name] = true
			names[#names + 1] = def.name
		end
	end
	return names
end


local function change_selection_exclusion(exclude)
	local names = selected_unit_def_names()
	if #names == 0 then
		spEcho("[Squad] No units selected to " .. (exclude and "exclude" or "unexclude"))
		return
	end
	spSendCommands("squad_setting " .. (exclude and "add" or "remove") .. " excludedUnitTypes " .. table.concat(names, " "))
end


local function squad_exclude_selected()
	change_selection_exclusion(true)
end


local function squad_unexclude_selected()
	change_selection_exclusion(false)
end

local vsx, vsy = spGetViewGeometry()

-- FlowUI helpers (resolved in ViewResize; nil => fall back to plain gl drawing)
local UiButton, UiSelectHighlight, font
local bgpadding

local function resolveUI()
	if WG.FlowUI and WG.FlowUI.Draw then
		UiButton = WG.FlowUI.Draw.Button
		UiSelectHighlight = WG.FlowUI.Draw.SelectHighlight
		bgpadding = WG.FlowUI.elementPadding
	else
		UiButton, UiSelectHighlight = nil, nil
		bgpadding = 3
	end
	if WG['fonts'] and WG['fonts'].getFont then
		font = WG['fonts'].getFont()
	else
		font = nil
	end
end


-- UI scale: prefer the advplayerslist panel's own scale (so we match it), else
-- the global ui_scale config.
local function getScale()
	local api = WG['displayinfo']
	if api and api.GetPosition then
		local pos = api.GetPosition()
		if pos and pos[5] and pos[5] > 0 then
			return pos[5]
		end
	end
	return (vsy / 980) * (1 + (spGetConfigFloat("ui_scale", 1) - 1) / 1.25)
end


-- Returns the screen-pixel rect (left, bottom, right, top) of the whole button
-- row, anchored above advplayerslist when available.
local function getRowRect(scale)
	local btnW = math.floor(58 * scale + 0.5)
	local btnH = math.floor(22 * scale + 0.5)
	local gap = math.floor(4 * scale + 0.5)
	local rowW = (#buttons * btnW) + ((#buttons - 1) * gap)

	-- Anchor on the topmost element of the player-list stack. displayinfo sits
	-- above advplayerslist (with the music player/stats between them), so its
	-- top edge is the clear edge to stack on; fall back to advplayerslist, then
	-- the screen corner. Both expose GetPosition() as { top, left, bottom, right, scale }.
	local api = WG['displayinfo'] or WG['advplayerlist_api']
	local right, bottom
	if api and api.GetPosition then
		local pos = api.GetPosition()
		if pos then
			right = pos[4] - 8
			bottom = pos[1] + gap -- sit just above the panel's top edge
		end
	end
	if not right then
		-- Fallback: top-right corner.
		right = vsx - math.floor(8 * scale + 0.5)
		bottom = vsy - btnH - math.floor(8 * scale + 0.5)
	end

	local left = right - rowW
	local top = bottom + btnH
	return left, bottom, right, top, btnW, btnH, gap
end


local function layout()
	local scale = getScale()
	local left, bottom, right, top, btnW, btnH, gap = getRowRect(scale)
	local x = left
	for i = 1, #buttons do
		local b = buttons[i]
		b.left, b.bottom, b.right, b.top = x, bottom, x + btnW, top
		x = x + btnW + gap
	end
	return scale
end


-- Exported for downstream widgets that want to stack above our button row.
-- Same shape advplayerslist publishes ({ top, left, bottom, right, scale }) so
-- a consumer reads [1] as our top edge and anchors above it, exactly the way we
-- anchor on advplayerslist. Computed fresh on each call so it's never stale.
local function get_row_position()
	local scale = getScale()
	local left, bottom, right, top = getRowRect(scale)
	return {top, left, bottom, right, scale}
end


local function hovered(b, mx, my)
	return mx >= b.left and mx <= b.right and my >= b.bottom and my <= b.top
end


function widget:DrawScreen()
	if spIsGUIHidden() then
		return
	end

	local scale = layout()
	local mx, my = spGetMouseState()

	for i = 1, #buttons do
		local b = buttons[i]
		local isHover = hovered(b, mx, my)

		if UiButton then
			UiButton(b.left, b.bottom, b.right, b.top, 1, 1, 1, 1, -- corner flags
			1, 1, 1, 1, -- padding flags
			nil, nil, nil, bgpadding and (bgpadding * 0.5) or nil)
			if isHover and UiSelectHighlight then
				UiSelectHighlight(b.left, b.bottom, b.right, b.top, nil, 0.18)
			end
		else
			-- Plain fallback.
			if isHover then
				glColor(0.35, 0.35, 0.35, 0.85)
			else
				glColor(0.12, 0.12, 0.12, 0.8)
			end
			glRect(b.left, b.bottom, b.right, b.top)
			glColor(1, 1, 1, 1)
		end

		local cx = (b.left + b.right) * 0.5
		local cy = (b.bottom + b.top) * 0.5
		local fontSize = math.floor(12 * scale + 0.5)
		if font then
			font:Begin()
			-- Set color explicitly every frame. Fonts are shared singletons, so
			-- whatever color the previous widget left is still active otherwise —
			-- that's the black/white flicker.
			font:SetTextColor(1, 1, 1, 1)
			font:SetOutlineColor(0, 0, 0, 1)
			font:Print(b.label, cx, cy, fontSize, "cvo") -- center, vertical-center, outline
			font:End()
		else
			gl.Text(b.label, cx, cy - fontSize * 0.35, fontSize, "cn")
		end
	end
end


function widget:MousePress(x, y, button)
	if button ~= 1 or spIsGUIHidden() then
		return false
	end
	for i = 1, #buttons do
		local b = buttons[i]
		if b.left and hovered(b, x, y) then
			spSendCommands(b.action)
			return true -- consume the click so it doesn't fall through to the map
		end
	end
	return false
end


function widget:IsAbove(x, y)
	if spIsGUIHidden() then
		return false
	end
	for i = 1, #buttons do
		local b = buttons[i]
		if b.left and hovered(b, x, y) then
			return true
		end
	end
	return false
end


function widget:GetTooltip(x, y)
	for i = 1, #buttons do
		local b = buttons[i]
		if b.left and hovered(b, x, y) then
			return b.tooltip
		end
	end
	return nil
end


function widget:ViewResize()
	vsx, vsy = spGetViewGeometry()
	resolveUI()
end


function widget:Initialize()
	resolveUI()
	widgetHandler:AddAction("squad_exclude_selected", squad_exclude_selected, nil, "t")
	widgetHandler:AddAction("squad_unexclude_selected", squad_unexclude_selected, nil, "t")
	WG['squadselection_buttons'] = {
		GetPosition = get_row_position,
	}
end


function widget:Shutdown()
	widgetHandler:RemoveAction("squad_exclude_selected")
	widgetHandler:RemoveAction("squad_unexclude_selected")
	WG['squadselection_buttons'] = nil
end

