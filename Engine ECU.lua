require("Libs.PID")
require("Libs.UpDownCounter")
function clamp(value, min, max)
	return math.min(math.max(value, min), max)
end

MAX_ALTITUDE = property.getNumber("Max Altitude")
ENERGY_EFFICIENCY = 1 - property.getNumber("Energy Efficiency")
THROTTLE_PERCENTAGE = property.getNumber("Throttle Percentage") / 100

TH_UDC = UpDownCounter:new(1 / 60, 1 / 60, 0, 1)
ENERGY_LOSS = 0
THROTTLE_IN = 0
TH_F_PID = PID:new(0.01, 0.03, 0, 0.5)
--TH_A_PID = PID:new(0.003, 0.015, 0.000001, 0.5)

ALTTITUDE_P = 0
CR_UDC = UpDownCounter:new(1 / 600, 1 / 1200 / ENERGY_EFFICIENCY, 0, 0.7)

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
	1 * math.exp(-altitude / MAX_ALTITUDE),
		altitude - ALTTITUDE_P

	local idealAFR = 0.004 * engineTemp + 13.6
	local afr = volumeFuel == 0 and 20 or volumeAir / volumeFuel
	local afrError = clamp(afr - idealAFR, -1, 1)


	local e_loss = (climbRate-0.04*(1-ENERGY_EFFICIENCY))/4200
	if climbRate > 0 then
		ENERGY_LOSS = clamp(ENERGY_LOSS + e_loss, 0, 0.8)
	else
		ENERGY_LOSS = clamp(ENERGY_LOSS + e_loss, 0, 0.8)
	end
	if input.getNumber(5) > 0.5 then
		THROTTLE_IN = (TH_UDC:update(1)) * THROTTLE_PERCENTAGE * (1 - ENERGY_LOSS)
	elseif input.getNumber(5) < -0.5 then
		THROTTLE_IN = (TH_UDC:update(0)) * THROTTLE_PERCENTAGE * (1 - ENERGY_LOSS)
	end

	if isEngineOn then
		if RPS < 3.5 then
			OUT_ENGINE_STARTER = true
			THROTTLE_OUT_AIR = THROTTLE_IN * currentAirDensity
			THROTTLE_OUT_FUEL = THROTTLE_IN / 2
		elseif RPS < 7 then
			OUT_ENGINE_STARTER = false
			THROTTLE_OUT_AIR = THROTTLE_IN * currentAirDensity
			THROTTLE_OUT_FUEL = THROTTLE_IN / 2
		else
			OUT_ENGINE_STARTER = false
			THROTTLE_OUT_AIR = THROTTLE_IN * currentAirDensity -- + TH_A_PID:update(-afrError, 0)
			THROTTLE_OUT_FUEL = THROTTLE_OUT_AIR / 2 + TH_F_PID:update(afrError, 0)
		end
	else
		OUT_ENGINE_STARTER = false
		THROTTLE_OUT_AIR = 0
		THROTTLE_OUT_FUEL = 0
		TH_F_PID:reset()
	end
	output.setBool(1, OUT_ENGINE_STARTER)

	--debug.log("$$ climbRate" .. climbRate)
	--debug.log("$$ F" .. THROTTLE_OUT_FUEL .. ", A" .. THROTTLE_OUT_AIR .. ", afrError" .. afrError)
	output.setNumber(1, clamp(THROTTLE_OUT_FUEL, 0, 1))
	output.setNumber(2, clamp(THROTTLE_OUT_AIR, 0, 1))
	--output.setNumber(3, OUT_PROP_PITCH)

	ALTTITUDE_P = altitude
end
