--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ECS = require(ReplicatedStorage.Util.ECS)
local Memory = require(ReplicatedStorage.Util.Memory)
local Network = require(ReplicatedStorage.Util.Network)
local PlayerDataTemplate = require(script.Parent.Templates.PlayerData)

local PlayerChannel = Network:Create("Player")

local PlayerMemory = Memory.new(PlayerDataTemplate, {
	MemoryName = "PlayerData",
	Version = 21,
})

local World = ECS.World.new()
local PlayerSystem = ECS.System.new(function(entity, dt)
	local PlayerSave = entity:GetComponent("Player")
	assert(PlayerSave, "PlayerSystem requires PlayerComponent")
	PlayerSave:Set({ "TimePlayed" }, PlayerSave:Get({ "TimePlayed" }) + dt) -- Update the player's time played
end, { "Player" })

local PlayerRemoved = function(player)
	local PlayerEntity = World:GetEntity(function(entity)
		return entity.Reference == player
	end)
	if PlayerEntity then
		World:RemoveEntity(PlayerEntity)
	end
	PlayerMemory:Release(player.UserId) -- Release the player's memory (session lock and save)
end

local PlayerAdded = function(player: Player)
	local PlayerEntity = ECS.Entity.new(player)
	local PlayerSave = PlayerEntity:AddComponent(ECS.Component.new("Player", PlayerDataTemplate))

	PlayerMemory:LoadAsync(player.UserId):andThen(function(data) -- Load the player's data from memory
		PlayerSave.Data = data
		PlayerSave.Changed:Connect(function(path, value) -- Connect to changes in the player's data to the client
			PlayerChannel:SendTo(player, PlayerSave.Data)
		end)

		World:AddEntity(PlayerEntity) -- Add the player's entity to the world
		PlayerChannel:SendTo(player, PlayerSave.Data) -- Send the initial player data to the player
	end)

	player.AncestryChanged:Connect(function(_, parent) -- Connect AncestryChanged to player removal
		if parent == nil then
			PlayerRemoved(player)
		end
	end)
end
game.Players.PlayerAdded:Connect(PlayerAdded) -- Connect to the player added event
for _, player in pairs(game.Players:GetPlayers()) do -- Handle existing players
	PlayerAdded(player)
end

World:AddSystem(PlayerSystem) -- Add the player system to the world

while true do -- Update the world every 0.5 seconds
	World:Update(1)
	task.wait(0.5)
end
