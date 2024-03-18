local ReplicatedStorage = game.ReplicatedStorage
local ECS = require(ReplicatedStorage.Util.ECS)
local Memory = require(ReplicatedStorage.Util.Memory)
local Network = require(ReplicatedStorage.Util.Network)
local PlayerTemplate = require(ReplicatedStorage.Templates.Player)
local PlayerComponent = ECS.Component(function()
	return table.clone(PlayerTemplate)
end)
local Alive = ECS.Tag()
local World = ECS.World()

local Channel = Network:Create("Player")
local PlayerMemory = Memory.new(PlayerTemplate, { MemoryName = "Player", Version = 1 })

local function PlayerAdded(player: Player)
	local PlayerEntity = World:Create()
	World:Add(PlayerEntity, PlayerComponent)

	PlayerMemory:LoadAsync(player.UserId):andThen(function(data)
		World:Set(PlayerEntity, PlayerComponent, data)
		Channel:SendTo(player, data)
	end)

	player.CharacterAdded:Connect(function(character)
		World:Add(PlayerEntity, Alive)
		Channel:SendTo(player, World:Get(PlayerEntity, PlayerComponent), true)
		character.AncestryChanged:Connect(function(_, parent)
			if parent == nil then
				World:Remove(PlayerEntity, Alive)
			end
		end)
	end)

	player.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			World:Destroy(PlayerEntity)
			PlayerMemory:Release(player.UserId)
		end
	end)
end

game.Players.PlayerAdded:Connect(PlayerAdded)
for _, player in pairs(game.Players:GetPlayers()) do
	PlayerAdded(player)
end

local UpdateTimePlayed = function(dt: number)
	for entity, player in World:View(PlayerComponent):Get() do
		player.TimePlayed += dt
	end
end

game:GetService("RunService").Stepped:Connect(function(dt)
	UpdateTimePlayed(dt)
end)
