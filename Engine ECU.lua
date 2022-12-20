require("Libs.PID")
require("Libs.UpDownCounter")
function clamp(value, min, max)
	return math.min(math.max(value, min), max)
end

MAX_ALTITUDE = property.getNumber("Max Altitude")
THROTTLE_PERCENTAGE = property.getNumber("Throttle Percentage") / 100

TH_UDC = UpDownCounter:new(1 / 90, 0, 1)
THROTTLE_IN = 0
TH_PID = PID:new(0.3, 0.003, 0.000001, 0.5)

ALTTITUDE_P = 0
CR_UDC = UpDownCounter:new(1 / 60, 0, 0.5)

THROTTLE_OUT_AIR = 0
THROTTLE_OUT_FUEL = 0
function onTick()
	local volumeAir, volumeFuel, engineTemp, RPS, isEngineOn, altitude =
	input.getNumber(1),
		input.getNumber(2),
		input.getNumber(3),
		input.getNumber(4),
		input.getNumber(6) == 1,
		input.getNumber(7)

	local currentAirDensity, climbRate =
	1.225 * math.exp(-altitude / MAX_ALTITUDE),
		altitude - ALTTITUDE_P

	local idealAFR = 0.004 * engineTemp + 13.6
	local afr = volumeFuel == 0 and idealAFR or volumeAir / volumeFuel
	local afrError = afr - idealAFR

	if input.getNumber(5) > 0.5 then
		THROTTLE_IN = (TH_UDC:update(1)) * THROTTLE_PERCENTAGE*(1-CR_UDC:update(climbRate))
	elseif input.getNumber(5) < -0.5 then
		THROTTLE_IN = (TH_UDC:update(0)) * THROTTLE_PERCENTAGE*(1-CR_UDC:update(climbRate))
	end

	if isEngineOn then
		if RPS < 3.5 then
			OUT_ENGINE_STARTER = true
			THROTTLE_OUT_AIR = THROTTLE_IN
			THROTTLE_OUT_FUEL = THROTTLE_IN / 2
		else
			OUT_ENGINE_STARTER = false
			THROTTLE_OUT_AIR = THROTTLE_IN * currentAirDensity
			THROTTLE_OUT_FUEL = THROTTLE_OUT_AIR / 2 + TH_PID:update(afrError, 0)
		end
	else
		OUT_ENGINE_STARTER = false
		THROTTLE_OUT_AIR = 0
		THROTTLE_OUT_FUEL = 0
	end
	output.setBool(1, OUT_ENGINE_STARTER)

	output.setNumber(1, clamp(THROTTLE_OUT_FUEL, 0, 1))
	output.setNumber(2, clamp(THROTTLE_OUT_AIR, 0, 1))
	--output.setNumber(3, OUT_PROP_PITCH)

	ALTTITUDE_P = altitude
end
