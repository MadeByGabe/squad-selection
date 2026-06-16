function widget:GetInfo()
	return {
		name = "Squad doSquadSelect Pre-Hook Example",
		desc = "Example companion widget for Squad Selection",
		author = "Example",
		date = "2026",
		license = "GNU GPL, v2 or later",
		layer = -999997,
		enabled = false,
	}
end


local function hasFactorySelected(selected)
	for i = 1, #selected do
		local unitDefID = Spring.GetUnitDefID(selected[i])
		if unitDefID then
			local def = UnitDefs[unitDefID]
			if def and def.isFactory then
				return true
			end
		end
	end
	return false
end


local function preSelectHook(ctx)
	local selected = ctx.selected or {}
	-- Spring.Echo(ctx.opts)
	-- Veto squad selection while any factory is selected.
	if ctx.opts and not ctx.opts.isMousePress and hasFactorySelected(selected) then
		return false
	end

	-- Optional override example:
	-- return {
	-- 	cycleWhenFull = false,
	-- 	useDomainFilter = true,
	-- }
end


local function installHook()
	if WG and WG['squadselection'] then
		WG['squadselection'].setBeforeSquadSelectCallback(preSelectHook)
		return true
	end
	return false
end


local hookInstalled = false

function widget:Initialize()
	hookInstalled = installHook()
end


function widget:Shutdown()
	hookInstalled = false
	if WG and WG['squadselection'] then
		WG['squadselection'].setBeforeSquadSelectCallback(nil)
	end
end


-- Handles widget reload order: if Squad Selection loads after this widget,
-- install the hook as soon as APIs become available.
function widget:Update()
	if hookInstalled then
		return
	end
	if installHook() then
		hookInstalled = true
	end
end


