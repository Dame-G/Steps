--!strict

local ReplicatedStorage = game.ReplicatedStorage
local ECS = require(ReplicatedStorage.Util.ECR)
local Interface = require(script.Parent.Interface)
local Items = require(ReplicatedStorage.Util.Items)
local Network = require(ReplicatedStorage.Util.Network)
local Table = require(ReplicatedStorage.Util.Table)

-- ECS setup
local Components = require(ReplicatedStorage.Templates.Components)
local Tags = require(ReplicatedStorage.Templates.Tags)
local World = ECS.registry()
local PlayerEntity = World:create()

-- Network setup
local Channel = Network:Create("Player")
Channel:Receive(function(Kind, Changes, Base, Operation)
	if Components[Kind] then
		if Base == "Player" then
			if not World:has(PlayerEntity, Components[Kind]) and Operation == "Create" then
				World:set(PlayerEntity, Components[Kind], Changes)
			elseif Operation == "Update" then
				World:patch(PlayerEntity, Components[Kind], function(CurrentComponent)
					return Table.deepUpdate(CurrentComponent, Changes)
				end)
			elseif Operation == "Destroy" then
				World:remove(PlayerEntity, Components[Kind])
			end
		elseif Base == "Item" then
			if Operation == "Create" then
				local ItemEntity = World:create()
				World:set(ItemEntity, Components[Kind], Changes)
			elseif Operation == "Update" then
				local ItemEntity = World:find(Components[Kind], function(ItemComponent)
					return ItemComponent.Id == Changes.Id
				end)
				assert(ItemEntity, "ItemEntity was not found")
				World:patch(ItemEntity, Components[Kind], function(CurrentComponent)
					return Table.deepUpdate(CurrentComponent, Changes)
				end)
			elseif Operation == "Destroy" then
				local ItemEntity = World:find(Components[Kind], function(ItemComponent)
					return ItemComponent.Id == Changes.Id
				end)
				assert(ItemEntity, "ItemEntity was not found")
				World:destroy(ItemEntity)
			end
		end
	elseif Tags[Kind] then
		if Base then
			if not World:has(PlayerEntity, Tags[Kind]) then
				World:add(PlayerEntity, Tags[Kind])
			end
		else
			if World:has(PlayerEntity, Tags[Kind]) then
				World:remove(PlayerEntity, Tags[Kind])
			end
		end
	end
end)

-- Connection to PlayerEntity and ItemEntity ECS events
World:on_add(Components.Player):connect(function(PlayerEntity)
	-- TODO: Create interface for character creation / selection
	local Player = World:get(PlayerEntity, Components.Player)
	if #Player.Characters == 0 then
		Channel:Send("CreateCharacter")
	else
		Channel:Send("SelectCharacter", Player.Characters[1])
	end
end)

World:on_add(Components.Item):connect(function(ItemEntity)
	local Character = game.Players.LocalPlayer.Character :: Model
	assert(Character, "Character was not found")
	local ItemComponent = World:get(ItemEntity, Components.Item)
	local ItemInstance = Character:WaitForChild(ItemComponent.Name)
	if ItemInstance then
		local ItemModule = ItemInstance:WaitForChild("Client") :: ModuleScript
		if ItemModule then
			local Functions = require(ItemModule) :: any
			Items:Register(World, ItemEntity, Functions)
		end
	end
end)

local interface
World:on_add(Tags.Alive):connect(function(PlayerEntity)
	print(
		"ALIVE\nPlayer data:",
		World:get(PlayerEntity, Components.Player),
		"\nCharacter data:",
		World:get(PlayerEntity, Components.Character)
	)
	interface = Interface({ Character = World:get(PlayerEntity, Components.Character) })
end)

World:on_remove(Tags.Alive):connect(function(PlayerEntity)
	print("DEAD")
	if interface then
		interface:doCleanup()
	end
end)
