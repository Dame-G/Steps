--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ECS = require(ReplicatedStorage.Util.ECS)
local Network = require(ReplicatedStorage.Util.Network)
local WorldTemplate = require(ReplicatedStorage.Templates.World)

local PlayerChannel = Network:Create("Player")
local CharacterChannel = Network:Create("Character")

local World = ECS.World.new(WorldTemplate)
local PlayerEntity, CharacterEntity, Player, Character

local PlayerSystem = ECS.System.new(function(entity, components, tick, config)
	print(components.Player.Data.TimePlayed)
end, { "Player" })
local CharacterSystem = ECS.System.new(function(entity, components, tick, config)
	--	print(entity)
end, { "Character" })

World:AddSystem(PlayerSystem)
World:AddSystem(CharacterSystem)

PlayerChannel:Receive(function(data)
	if
		not World:GetEntity(function(entity)
			return entity.Reference == game.Players.LocalPlayer
		end) and not Player
	then
		PlayerEntity = ECS.Entity.new(game.Players.LocalPlayer)
		Player = ECS.Component.new("Player", data)
		PlayerEntity:AddComponent(Player)
		World:AddEntity(PlayerEntity)
	else
		Player:Set({}, data)
	end
	return
end)

CharacterChannel:Receive(function(data)
	if
		not World:GetEntity(function(entity)
			return entity.Reference == game.Players.LocalPlayer.Character
		end) and not Character
	then
		CharacterEntity = ECS.Entity.new(game.Players.LocalPlayer.Character)
		Character = ECS.Component.new("Character", data)
		CharacterEntity:AddComponent(Character)
		World:AddEntity(CharacterEntity)
	else
		Character:Set({}, data)
	end
	return
end)

while true do
	World:Update()
end
