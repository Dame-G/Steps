--!strict

local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game.ReplicatedStorage
local ECS = require(ReplicatedStorage.Util.ECS)
local Network = require(ReplicatedStorage.Util.Network)
local PlayerTemplate = require(ReplicatedStorage.Templates.Player)
local CharacterTemplate = require(ReplicatedStorage.Templates.Character)
local PlayerComponent = ECS.Component(function()
	return table.clone(PlayerTemplate)
end)
local CharacterComponent = ECS.Component(function()
	return table.clone(CharacterTemplate)
end)
local CharactersComponent = ECS.Component(function()
	return {}
end)

local World = ECS.World()
local PlayerEntity = World:Create()
World:Add(PlayerEntity, PlayerComponent, CharacterComponent, CharactersComponent)

local UpdatePlayer = function(Player)
	World:Set(PlayerEntity, PlayerComponent, Player)
end

local UpdateCharacter = function(Character)
	World:Set(PlayerEntity, CharacterComponent, Character)
end

local UpdateCharacters = function(Characters)
	World:Set(PlayerEntity, CharactersComponent, Characters)
end

local Channel = Network:Create("Player")

Channel:Receive(function(Kind, Data)
	if Kind == "Player" then
		UpdatePlayer(Data)
	elseif Kind == "Character" then
		UpdateCharacter(Data)
	elseif Kind == "Characters" then
		UpdateCharacters(Data)
	end
end)

UserInputService.InputBegan:Connect(function(Input)
	if Input.KeyCode == Enum.KeyCode.Q then
		Channel:Send("Create")
	end
end)
