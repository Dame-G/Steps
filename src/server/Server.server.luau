--!strict

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local ECR = require(ReplicatedStorage.Util.ECR)
local Items = require(ReplicatedStorage.Util.Items)
local Memory = require(ReplicatedStorage.Util.Memory)
local Network = require(ReplicatedStorage.Util.Network)
local Table = require(ReplicatedStorage.Util.Table)

-- Data saving
local CharacterTemplate = require(ReplicatedStorage.Templates.Character)
local PlayerTemplate = require(ReplicatedStorage.Templates.Player)
local PlayerMemory = Memory.new(PlayerTemplate, { MemoryName = "Player-Test", Version = 30, Mock = true })
local CharacterMemory = Memory.new(CharacterTemplate, { MemoryName = "Character-Test", Version = 32, Mock = true })

-- ECS setup
local Components = require(ReplicatedStorage.Templates.Components)
local Tags = require(ReplicatedStorage.Templates.Tags)
local World = ECR.registry()
local Systems = {
	require(script.Parent.Systems.TimePlayed),
}

-- Network setup
local Channel = Network:Create("Player")
Channel:Receive(function(Player: Player, Data, ...)
	local PlayerEntity = World:find(Components.Player, function(PlayerComponent)
		return PlayerComponent.UserId == Player.UserId
	end)
	assert(PlayerEntity, "PlayerEntity was not found")
	local PlayerComponent = World:get(PlayerEntity, Components.Player)

	if Data == "CreateCharacter" and #PlayerComponent.Characters < PlayerComponent.MaxNumberOfCharacters then
		local Id = HttpService:GenerateGUID(false):gsub("-", "")
		local CharacterComponent = CharacterMemory:LoadAsync(Id):await()
		CharacterComponent.Id = Id
		World:set(PlayerEntity, Components.Character, CharacterComponent)
		World:patch(PlayerEntity, Components.Player, function(PlayerComponent)
			table.insert(PlayerComponent.Characters, Id)
			return PlayerComponent
		end)

		Player:LoadCharacter()
	elseif Data == "SelectCharacter" and not World:has(PlayerEntity, Components.Character) then
		local Id = unpack({ ... })
		assert(Id, "Id must be provided")

		local CharacterComponent = CharacterMemory:LoadAsync(Id):await()
		World:set(PlayerEntity, Components.Character, CharacterComponent)

		Player:LoadCharacter()
	end
end)

-- Connection to player & character events
local function PlayerAdded(Player: Player)
	local PlayerEntity = World:create()

	local PlayerComponent = PlayerMemory:LoadAsync(tostring(Player.UserId)):await()
	assert(PlayerComponent, "PlayerComponent was not found")
	PlayerComponent.UserId = Player.UserId
	PlayerComponent.Username = Player.Name
	World:set(PlayerEntity, Components.Player, PlayerComponent)
end

local function PlayerRemoved(Player: Player)
	local PlayerEntity = World:find(Components.Player, function(PlayerComponent)
		return PlayerComponent.UserId == Player.UserId
	end)
	assert(PlayerEntity, "PlayerEntity was not found")

	PlayerMemory:Release(tostring(Player.UserId))
	local Character = World:get(PlayerEntity, Components.Character)
	if Character then
		CharacterMemory:Release(Character.Id)
	end

	World:destroy(PlayerEntity)
end

local function CharacterAdded(Player: Player, Character: Model)
	local PlayerEntity = World:find(Components.Player, function(PlayerComponent)
		return PlayerComponent.UserId == Player.UserId
	end)
	assert(PlayerEntity, "PlayerEntity was not found")

	local CharacterComponent = World:get(PlayerEntity, Components.Character)
	assert(CharacterComponent, "CharacterComponent was not found")
	local Inventory = CharacterComponent.Inventory

	type Connection = { disconnect: (self: Connection) -> () }
	local Connections: { Connection | RBXScriptConnection } = {}
	local Root = Character:WaitForChild("HumanoidRootPart") :: BasePart
	Root.AncestryChanged:Connect(function(part, parent)
		if parent == nil and part == Root then
			World:patch(PlayerEntity, Components.Character, function(CharacterComponent)
				CharacterComponent.Lives = CharacterComponent.Lives - 1
				return CharacterComponent
			end)
			for _, Connection in Connections do
				if typeof(Connection) == "RBXScriptConnection" then
					Connection:Disconnect()
				else
					Connection:disconnect()
				end
			end

			World:remove(PlayerEntity, Tags.Alive)
			for _, Item in Inventory do
				local ItemEntity = World:find(Components.Item, function(ItemComponent)
					return ItemComponent.Id == Item.Id
				end)
				if ItemEntity then
					World:destroy(ItemEntity)
				end
			end

			if Root.Parent then
				Root.Parent:Destroy()
			end

			task.wait(1)
			if Player and CharacterComponent.Lives > 0 then
				Player:LoadCharacter()
			end
		end
	end)

	local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart") :: BasePart
	local PreviousCFrame = HumanoidRootPart.CFrame
	table.insert(
		Connections,
		RunService.Heartbeat:Connect(function()
			local CFrame = HumanoidRootPart.CFrame
			if CFrame ~= PreviousCFrame and (CFrame.Position - PreviousCFrame.Position).Magnitude > 0.1 then
				local Location = {
					X = CFrame.Position.X,
					Y = CFrame.Position.Y,
					Z = CFrame.Position.Z,
					Area = "Untracked",
				}
				World:patch(PlayerEntity, Components.Character, function(CharacterComponent)
					CharacterComponent.Location = Location
					return CharacterComponent
				end)
			end
			PreviousCFrame = CFrame
		end)
	)

	table.insert(
		Connections,
		World:on_change(Components.Character):connect(function(Entity, NewComponent)
			for _, Item in Inventory do
				if
					not World:find(Components.Item, function(ItemComponent)
						return ItemComponent.Id == Item.Id
					end) and World:has(PlayerEntity, Tags.Alive)
				then
					local ItemEntity = World:create()
					Item.Owner = Player.Name
					World:set(ItemEntity, Components.Item, Item)
				end
			end
		end)
	)

	for _, Item in Inventory do
		Item.Owner = Player.Name
		if not World:find(Components.Item, function(ItemComponent)
			return ItemComponent.Id == Item.Id
		end) then
			local ItemEntity = World:create()
			World:set(ItemEntity, Components.Item, Item)
		end
	end

	World:add(PlayerEntity, Tags.Alive)
end

game.Players.PlayerAdded:Connect(function(Player)
	PlayerAdded(Player)
	Player.CharacterAdded:Connect(function(Character)
		CharacterAdded(Player, Character)
	end)
end)
for _, Player in pairs(game.Players:GetPlayers()) do
	PlayerAdded(Player)
	Player.CharacterAdded:Connect(function(Character)
		CharacterAdded(Player, Character)
	end)
end

game.Players.PlayerRemoving:Connect(PlayerRemoved)

-- Subscribe changes in ECS components for PlayerEntity and ItemEntity over network
for Name, Component in Components do
	local Cache = {}
	World:on_add(Component):connect(function(Entity, NewComponent)
		if World:has(Entity, Components.Player) then
			local PlayerComponent = World:get(Entity, Components.Player)
			local Player = game.Players:GetPlayerByUserId(PlayerComponent.UserId)
			if not Player then
				return
			end

			Channel:SendTo(Player, Name, NewComponent, "Player", "Create")
			Cache[Entity] = Table.deepCopy(NewComponent)
		elseif World:has(Entity, Components.Item) then
			local ItemComponent = World:get(Entity, Components.Item)
			local Player = game.Players:FindFirstChild(ItemComponent.Owner) :: Player
			if not Player then
				return
			end
			local Character = Player and Player.Character :: Model
			if not Character then
				return
			end

			local ItemInstance = ServerStorage.Items:FindFirstChild(ItemComponent.Name)
			assert(ItemInstance, "Item was not found")
			local ItemClone = ItemInstance:Clone()
			ItemClone.Parent = Character
			local ItemModule = ItemClone:WaitForChild("Server") :: ModuleScript
			assert(ItemModule, "ItemController was not found")
			task.spawn(function()
				local Functions = require(ItemModule) :: any
				Items:Register(World, Entity, Functions)
			end)

			Channel:SendTo(Player, Name, NewComponent, "Item", "Create")
			Cache[Entity] = Table.deepCopy(NewComponent)
		end
	end)
	World:on_remove(Component):connect(function(Entity)
		if World:has(Entity, Components.Player) then
			local PlayerComponent = World:get(Entity, Components.Player)
			local Player = game.Players:GetPlayerByUserId(PlayerComponent.UserId)
			if not Player then
				return
			end

			Channel:SendTo(Player, Name, World:get(Entity, Component), "Player", "Destroy")
		elseif World:has(Entity, Components.Item) then
			local ItemComponent = World:get(Entity, Components.Item)
			local Player = game.Players:FindFirstChild(ItemComponent.Owner) :: Player
			if not Player then
				return
			end
			local Character = Player and Player.Character :: Model
			if not Character then
				return
			end

			Channel:SendTo(Player, Name, ItemComponent, "Item", "Destroy")
		end
	end)
	World:on_change(Component):connect(function(Entity, NewComponent)
		if World:has(Entity, Components.Player) then
			local PlayerComponent = World:get(Entity, Components.Player)
			local Player = game.Players:GetPlayerByUserId(PlayerComponent.UserId)
			if not Player then
				return
			end

			local OldComponent = Cache[Entity]
			local Changes
			if OldComponent then
				Changes = Table.getChanges(OldComponent, NewComponent)
			else
				Changes = NewComponent
			end

			if Changes then
				Channel:SendTo(Player, Name, Changes, "Player", "Update")
			else
				Channel:SendTo(Player, Name, NewComponent, "Player", "Update")
			end

			Cache[Entity] = Table.deepCopy(NewComponent)
		elseif World:has(Entity, Components.Item) then
			local ItemComponent = World:get(Entity, Components.Item)
			local Player = game.Players:FindFirstChild(ItemComponent.Owner) :: Player
			if not Player then
				return
			end
			local Character = Player and Player.Character :: Model
			if not Character then
				return
			end

			local OldComponent = Cache[Entity]
			local Changes
			if OldComponent then
				Changes = Table.getChanges(OldComponent, NewComponent)
			else
				Changes = NewComponent
			end

			if Changes then
				Changes.Id = ItemComponent.Id
				Channel:SendTo(Player, Name, Changes, "Item", "Update")
			else
				Channel:SendTo(Player, Name, NewComponent, "Item", "Update")
			end

			Cache[Entity] = Table.deepCopy(NewComponent)
		end
	end)
end

for Name, Tag in Tags do
	World:on_add(Tag):connect(function(Entity)
		if not World:has(Entity, Components.Player) then
			return
		end
		local PlayerComponent = World:get(Entity, Components.Player)
		local Player = game.Players:GetPlayerByUserId(PlayerComponent.UserId)
			or game.Players:GetPlayerFromCharacter(PlayerComponent.Character)
		if Player == nil then
			return
		end
		Channel:SendTo(Player, Name, Tag, true)
	end)
	World:on_remove(Tag):connect(function(Entity)
		if not World:has(Entity, Components.Player) then
			return
		end
		local PlayerComponent = World:get(Entity, Components.Player)
		local Player = game.Players:GetPlayerByUserId(PlayerComponent.UserId)
			or game.Players:GetPlayerFromCharacter(PlayerComponent.Character)
		if Player == nil then
			return
		end
		Channel:SendTo(Player, Name, Tag, false)
	end)
end

-- Start game systems
for Name, _System in pairs(Systems) do
	local System = _System(World)
	task.spawn(function()
		if System.Delta then
			while true do
				local Time = task.wait(System.Delta)
				System.Update(Time)
			end
		else
			System.Update()
		end
	end)
end
