local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game.ReplicatedStorage
local ECS = require(ReplicatedStorage.Util.ECS)
local Memory = require(ReplicatedStorage.Util.Memory)
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

local Channel = Network:Create("Player")
local PlayerMemory = Memory.new(PlayerTemplate, { MemoryName = "Player-Test", Version = 4 })
local CharacterMemory = Memory.new(CharacterTemplate, { MemoryName = "Character-Test", Version = 4 })

local function PlayerAdded(Player: Player)
	local PlayerEntity = World:Create()

	PlayerMemory:LoadAsync(Player.UserId):andThen(function(PlayerData)
		PlayerData.UserId = Player.UserId
		PlayerData.Username = Player.Name
		World:Add(PlayerEntity, PlayerComponent, CharactersComponent)
		World:Set(PlayerEntity, PlayerComponent, PlayerData)

		local Characters = {}
		for _, Id in pairs(PlayerData.Characters) do
			Characters[Id] = CharacterMemory:LoadAsync(Id, false):await()
		end

		World:Set(PlayerEntity, CharactersComponent, Characters)
	end)

	Player.AncestryChanged:Connect(function(_, Parent)
		if Parent == nil then
			PlayerMemory:Release(Player.UserId)
			for Entity, _Player, Characters in World:View(PlayerComponent, CharactersComponent):Get() do
				if _Player.UserId == Player.UserId then
					for Id, Character in pairs(Characters) do
						CharacterMemory:Release(Id)
					end
				end
			end
			World:Destroy(PlayerEntity)
		end
	end)
end

World:onChange(PlayerComponent):Connect(function(Entity, Player)
	local _Player = game.Players:GetPlayerByUserId(Player.UserId)
	if _Player == nil then
		return
	end
	Channel:SendTo(_Player, "Player", Player)
end)

World:onChange(CharacterComponent):Connect(function(Entity, Character)
	local Player = World:Get(Entity, PlayerComponent)
	local _Player = game.Players:GetPlayerByUserId(Player.UserId)
	if _Player == nil then
		return
	end
	Channel:SendTo(_Player, "Character", Character)
end)

World:onChange(CharactersComponent):Connect(function(Entity, Characters)
	local Player = World:Get(Entity, PlayerComponent)
	local _Player = game.Players:GetPlayerByUserId(Player.UserId)
	if _Player == nil then
		return
	end
	Channel:SendTo(_Player, "Characters", Characters)
end)

local UpdateTimePlayed = function(Time: number)
	for Entity, Player in World:View(PlayerComponent):Get() do
		World:Append(Entity, PlayerComponent, {
			TimePlayed = Player.TimePlayed + Time,
		})
	end
end

game:GetService("RunService").Stepped:Connect(function(Time)
	UpdateTimePlayed(Time)
end)

game.Players.PlayerAdded:Connect(PlayerAdded)
for _, player in pairs(game.Players:GetPlayers()) do
	PlayerAdded(player)
end

Channel:Receive(function(Player, Data)
	if Data == "Create" then
		local PlayerEntity = World:Find(PlayerComponent, { UserId = Player.UserId })
		if PlayerEntity == nil then
			return
		end

		local Id = HttpService:GenerateGUID(false)
		local CharacterData = CharacterMemory:LoadAsync(Id, false):await()
		CharacterData.Id = Id

		World:Append(PlayerEntity, PlayerComponent, {
			Characters = { Id },
		})
		World:Append(PlayerEntity, CharactersComponent, {
			[Id] = CharacterData,
		})
	end
end)
