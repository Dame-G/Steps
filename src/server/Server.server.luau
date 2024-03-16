--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ECS = require(ReplicatedStorage.Util.ECS)
local Memory = require(ReplicatedStorage.Util.Memory)
local Network = require(ReplicatedStorage.Util.Network)
local PlayerTemplate = require(ReplicatedStorage.Templates.Player)
local CharacterTemplate = require(ReplicatedStorage.Templates.Character)
local WorldTemplate = require(ReplicatedStorage.Templates.World)

local PlayerChannel = Network:Create("Player")
local CharacterChannel = Network:Create("Character")

local PlayerMemory = Memory.new(PlayerTemplate, { MemoryName = "Player", Version = 1 })

local World = ECS.World.new(WorldTemplate)
local PlayerSystem = ECS.System.new(function(entity, components, tick, config)
	local Player = components.Player
	Player:Set({ "TimePlayed" }, Player.Data.TimePlayed + 1)
	PlayerChannel:SendTo(entity.Reference, Player.Data)
end, { "Player" })
local CharacterSystem = ECS.System.new(function(entity, components, tick, config)
	local Character = components.Character
	CharacterChannel:SendTo(entity.Reference, Character.Data)
end, { "Character" })

World:AddSystem(PlayerSystem)
World:AddSystem(CharacterSystem)

local CharacterAdded = function(player, character)
	local CharacterEntity = ECS.Entity.new(character)
	local Character = CharacterEntity:AddComponent(ECS.Component.new("Character", CharacterTemplate))

	World:AddEntity(CharacterEntity)
	CharacterChannel:SendTo(player, Character.Data)
end

local CharacterRemoved = function(character)
	local CharacterEntity = World:GetEntity(function(entity)
		return entity.Reference == character
	end)
	if CharacterEntity then
		World:RemoveEntity(CharacterEntity)
	end
end

local PlayerRemoved = function(player)
	local PlayerEntity = World:GetEntity(function(entity)
		return entity.Reference == player
	end)
	if PlayerEntity then
		World:RemoveEntity(PlayerEntity)
	end
	PlayerMemory:Release(player.UserId)
end

local PlayerAdded = function(player: Player)
	local PlayerEntity = ECS.Entity.new(player)
	local Player = PlayerEntity:AddComponent(ECS.Component.new("Player", PlayerTemplate))

	PlayerMemory:LoadAsync(player.UserId):andThen(function(data)
		Player.Data = data
		World:AddEntity(PlayerEntity)
		PlayerChannel:SendTo(player, Player.Data)
	end)

	player.CharacterAdded:Connect(function(character)
		CharacterAdded(player, character)

		character.AncestryChanged:Connect(function(_, parent)
			if parent == nil then
				CharacterRemoved(character)
			end
		end)
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
	World:Update()
end
