--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ECS = require(ReplicatedStorage.Util.ECS)
local Memory = require(ReplicatedStorage.Util.Memory)
local Network = require(ReplicatedStorage.Util.Network)

local MemoryTemplate = {
	Level = 1,
	Experience = 0,
	Health = {
		Current = 100,
		Max = 100,
	},
	Mana = {
		Current = 50,
		Max = 50,
	},
	Stamina = {
		Current = 100,
		Max = 100,
	},
	Inventory = {
		Items = {},
		Gold = 0,
	},
	Skills = {},
	Quests = {},
	Location = {
		Map = "StartingTown",
		X = 0,
		Y = 0,
	},
}

local PlayerMemory = Memory.new(MemoryTemplate, {
	MemoryName = "TestMemory",
	Version = 3,
})

local World = ECS.World.new()
local PlayerSystem = ECS.System.new(function(entity, dt)
	local component = entity:GetComponent("Player")
	if not component then
		return
	end
	component:Set({ "Level" }, component:Get({ "Level" }) + 1)
end, { "Player" })
World:AddSystem(PlayerSystem)

local PlayerChannel = Network:Create("Player")

local PlayerRemoved = function(player)
	local playerEntity = World:GetEntity(function(entity)
		return entity.Reference == player
	end)
	if playerEntity then
		World:RemoveEntity(playerEntity)
	end
	print(PlayerMemory:SaveAsync(tostring(player.UserId)):await())
	PlayerMemory:Release(tostring(player.UserId))
end
local PlayerAdded = function(player: Player)
	local PlayerEntity = ECS.Entity.new(player)
	local PlayerComponent = ECS.Component.new("Player", MemoryTemplate)
	local PlayerSave = PlayerEntity:AddComponent(PlayerComponent)
	PlayerMemory:LoadAsync(tostring(player.UserId)):andThen(function(data)
		PlayerSave.Data = data
		PlayerSave.Changed:Connect(function(path, value)
			local lastKey = table.remove(path, #path)
			local target = data
			for _, key in pairs(path) do
				target = target[key]
			end
			target[lastKey] = value
			PlayerChannel:SendTo(player, PlayerSave.Data)
		end)

		World:AddEntity(PlayerEntity)
		PlayerChannel:SendTo(player, PlayerSave.Data)
	end)

	player.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			PlayerRemoved(player)
		end
	end)
end
game.Players.PlayerAdded:Connect(PlayerAdded)
for _, player in pairs(game.Players:GetPlayers()) do
	PlayerAdded(player)
end

while true do
	World:Update(1)
	task.wait(0.5)
end
