local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Components = require(ReplicatedStorage.Templates.Components)
local Network = require(ReplicatedStorage.Util.Network)

local Items = {}
local Connections = {}

function Items:Register(World, ItemEntity, Functions)
	local ItemComponent = World:get(ItemEntity, Components.Item)
	local Channel = Network:Create(ItemComponent.Id)
	local PreviousEquipped = ItemComponent.Equipped
	if not Connections[ItemComponent.Id] then
		Connections[ItemComponent.Id] = {}
	end
	table.insert(
		Connections[ItemComponent.Id],
		World:on_change(Components.Item):connect(function(ItemEntity, Component)
			if ItemComponent.Id == Component.Id then
				if Component.Equipped and not PreviousEquipped then
					task.spawn(function()
						Functions:Equip(World, ItemEntity, Channel)
					end)
				elseif not Component.Equipped and PreviousEquipped then
					task.spawn(function()
						Functions:Unequip(World, ItemEntity, Channel)
					end)
				end

				PreviousEquipped = Component.Equipped
			end
		end)
	)

	table.insert(
		Connections[ItemComponent.Id],
		World:on_remove(Components.Item):connect(function(ItemEntity)
			if Functions.Destroy then
				for _, connection in Connections[ItemComponent.Id] do
					connection:disconnect()
				end
				task.spawn(function()
					Functions:Destroy(World, ItemEntity, Channel)
				end)
			end
		end)
	)

	if Functions.Init then
		Functions:Init(World, ItemEntity, Channel)
	end

	if ItemComponent.Equipped then
		if Functions.Equip then
			task.spawn(function()
				Functions:Equip(World, ItemEntity, Channel)
			end)
		end
	else
		if Functions.Unequip then
			task.spawn(function()
				Functions:Unequip(World, ItemEntity, Channel)
			end)
		end
	end
end

return Items