require("Libs.PID")
require("Libs.UpDownCounter")

function clamp(value, min, max)
	return math.min(math.max(value, min), max)
end

PROPELLER_PITCH_MAX = clamp(property.getNumber("Propeller Pitch Max"), 0, 0.25)
THROTTLE_PERCENTAGE = property.getNumber("Throttle Percentage") / 100

MAX_RPS = 30
AFR_TGT = property.getNumber("AFR Target")
TH_UDC = UpDownCounter:new(1 / 90, 0, 1)
throttleIn = 0
AFR_UDC = UpDownCounter:new(0.002, 10, 17)
FUEL_UDC = UpDownCounter:new(1 / 180, 0, 1)
AIR_UDC = UpDownCounter:new(1 / 180, 0, 1)

ALT_P = 0

---PID Controllers
FUEL_PID = PID:new(0.03, 0.03, 0.000001, 0.5) --0.006
AIR_PID = PID:new(0.003, 0.015, 0.000001, 0.5)

---Output Numbers
OUT_FUEL = 0 -- Fuel output(0~1)
OUT_AIR = 0 -- Air output(0~1)
OUT_PROP_PITCH = 0 -- Propeller pitch output(0~1)

---Output Booleans
OUT_ENGINE_STARTER = false -- Engine starter output

function onTick()
	local volumeAir, volumeFuel, engineTemp, RPS, isEngineOn, altitude =
	input.getNumber(1),
		input.getNumber(2),
		input.getNumber(3),
		input.getNumber(4),
		input.getNumber(6) == 1,
		input.getNumber(7)

	if input.getNumber(5) == 1 then
		throttleIn = (TH_UDC:update(1)) * THROTTLE_PERCENTAGE
	elseif input.getNumber(5) == -1 then
		throttleIn = (TH_UDC:update(0)) * THROTTLE_PERCENTAGE
	end
	local AFR = volumeFuel == 0 and AFR_TGT or volumeAir / volumeFuel
	local fuel, air = FUEL_UDC:update((throttleIn / 2) * (1 - altitude / 4000)),
		AIR_UDC:update(throttleIn * (1 - altitude / 4000))
	local AFRTarget = AFR_UDC:update(AFR_TGT - altitude / 800 - clamp(altitude - ALT_P, 0, 100) * 1.35)
	local AFRforPID = AFR - AFRTarget

	if isEngineOn then
		if RPS < 3.5 then
			OUT_ENGINE_STARTER = true
			OUT_FUEL = fuel
			OUT_AIR = air
		else
			OUT_ENGINE_STARTER = false
			OUT_FUEL = fuel + FUEL_PID:update(AFRforPID, 0) + 0.1 * fuel / 0.5
			OUT_AIR = air - AIR_PID:update(AFRforPID, 0) + 0.1 * air
		end
	else
		OUT_ENGINE_STARTER = false
		OUT_AIR = 0
		OUT_FUEL = 0
	end

	ALT_P = altitude
	debug.log("$$AFR_TGT: " .. floatFloor(AFRTarget, 2) .. "  ADR:" .. floatFloor(AFR, 2))
	---output
	output.setBool(1, OUT_ENGINE_STARTER)

	output.setNumber(1, clamp(OUT_FUEL, 0, 1))
	output.setNumber(2, clamp(OUT_AIR, 0, 1))
	output.setNumber(3, OUT_PROP_PITCH)

end

function floatFloor(num, exp)
	return tonumber(math.floor(num * 10 ^ exp) / 10 ^ exp)
end
