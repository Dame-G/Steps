local Level = {}

Level.GetXP = function(Target: number): number
	return 0.075 * Target * (Target - 1) + 19 * ((2 ^ ((Target - 1) * 0.57) - 1) / (1 - 2 ^ -0.57))
end

return Level
