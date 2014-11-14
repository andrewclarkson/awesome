local setmetatable = setmetatable
local os = os
local textbox = require("wibox.widget.textbox")
local naughty = require("naughty")
local button = require("awful.button")
local util = require("awful.util")
local capi = { timer = timer }

--- Text battery widget.
-- awful.widget.textbattery
local textbattery = { mt = {} }
local battery = {}


--{{{ Extract battery info from acpi
function battery:get()
	local cmd = "acpi -ba"

	local fd = io.popen(cmd)
	local data = fd:read("*all")
	fd:close()

	local info = {}
	info.charge = tonumber(string.match(data, "(%d+)%%") or nil)
	info.time = string.match(data, "(%d%d:%d%d:%d%d)") or nil
	info.adapter = (string.match(data, "(on[-]line)") == "on-line")

	return info
end
--}}}


--{{{ Report what the level of battery depletion is
function level(charge)
	local levels = {5, 10, 15}
	for i = 1,#levels do
		if charge <= levels[i] then
			return i-1
		end
	end
	return #levels
end
--}}}


--{{{ Textbattery constructor
function textbattery.new(timeout)
	local timeout = timeout or 10
	local w = textbox()

	w.level = level(100)

--{{{ Updates the widget
	function w:update()
		local info   = battery:get()
		local charge = info.charge and info.charge or "--"
		local color  = info.adapter and "#AFD700" or "#F53145"
		local text   = string.format("Bat <span color='%s'>%s</span>", color, charge)

		if info.charge ~= nil then
			if info.adapter == false then
				if level(info.charge) < w.level then
					w:warn(info)
				end
				w.level = level(info.charge)
			else
				w.level = level(100)
			end
		end

		w:set_markup(text)
	end
--}}}

--{{{ Displays low-battery warnings
	function w:warn(info)
		naughty.notify({
			preset = naughty.config.presets.critical,
			title = "Warning: low battery!",
			text = string.format("Battery at %d%%", info.charge)
		})
	end
--}}}

--{{{ Displays info about battery charging state
	function w:info()
		local info = battery:get()
		local title
		if info.adapter then
			title = "Batery charging"
		else
			title = "Batery discharging"
		end
		naughty.notify({
			preset = naughty.config.presets.normal,
			title = title,
			text = (info.time or "unknown") .. " remaining"
		})
	end
--}}}

--{{{ Key bindings
	w:buttons(util.table.join(
		button({ }, 1, function()
			w:info()
		end)
	))
--}}}

	local timer = capi.timer { timeout = timeout }
	timer:connect_signal("timeout", function() w:update() end)
	timer:start()
	timer:emit_signal("timeout")
	return w
end
--}}}


function textbattery.mt:__call(...)
	return textbattery.new(...)
end

return setmetatable(textbattery, textbattery.mt)
