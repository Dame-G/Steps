local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Components = require(ReplicatedStorage.Templates.Components)

return function(World)
	return {
		Update = function(Time: number)
			for Entity, Player in World:view(Components.Player) do
				World:patch(Entity, Components.Player, function(PlayerData)
					PlayerData.TimePlayed = PlayerData.TimePlayed + Time
					return PlayerData
				end)
			end

			for Entity, Character in World:view(Components.Character) do
				World:patch(Entity, Components.Character, function(CharacterData)
					CharacterData.TimePlayed = CharacterData.TimePlayed + Time
					CharacterData.LastPlayed = os.date()
					return CharacterData
				end)
			end
		end,

		Delta = 1,
	}
end
