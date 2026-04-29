function widget:GetInfo()
	return {
		name = "Squad do_squad_select Pre-Hook Example",
		desc = "Example companion widget for Squad Selection",
		author = "Example",
		date = "2026",
		license = "GNU GPL, v2 or later",
		layer = -999997,
		enabled = false,
	}
end


local function has_factory_selected(selected)
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


local function pre_select_hook(ctx)
	local selected = ctx.selected or {}
	-- Spring.Echo(ctx.opts)
	-- Veto squad selection while any factory is selected.
	if ctx.opts and not ctx.opts.isMousePress and has_factory_selected(selected) then
		return false
	end

	-- Optional override example:
	-- return {
	-- 	cycle_when_full = false,
	-- 	use_domain_filter = true,
	-- }
end


local function install_hook()
	if WG and WG['squadselection'] then
		WG['squadselection'].setBeforeSquadSelectCallback(pre_select_hook)
		return true
	end
	return false
end


local hook_installed = false

function widget:Initialize()
	hook_installed = install_hook()
end


function widget:Shutdown()
	hook_installed = false
	if WG and WG['squadselection'] then
		WG['squadselection'].setBeforeSquadSelectCallback(nil)
	end
end


-- Handles widget reload order: if Squad Selection loads after this widget,
-- install the hook as soon as APIs become available.
function widget:Update()
	if hook_installed then
		return
	end
	if install_hook() then
		hook_installed = true
	end
end


