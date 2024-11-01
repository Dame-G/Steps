local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Components = require(ReplicatedStorage.Templates.Components)

local Connections = {}
local Item = {}

function Item:Init(World, ItemEntity, Channel)
	table.insert(
		Connections,
		Channel:Receive(function(Player, Action)
			if Action == "Unequip" then
				World:patch(ItemEntity, Components.Item, function(CurrentComponent)
					CurrentComponent.Equipped = false
					return CurrentComponent
				end)
			end
		end)
	)
end

function Item:Equip(World, ItemEntity, Channel)
	local ItemInstance = ServerStorage.Models:FindFirstChild("Katana")
	assert(ItemInstance, "Item was not found")
	local ItemModel = ItemInstance:Clone()
	local Weld = Instance.new("Weld")
	Weld.Part0 = ItemModel:FindFirstChild("Handle")
	Weld.Part1 = script.Parent.Parent:FindFirstChild("RightHand")
	Weld.C0 = CFrame.Angles(0, 7 * math.pi / 2, 0) * CFrame.new(0, 0, -0.45)
	Weld.Parent = ItemModel
	ItemModel.Parent = script.Parent
end

function Item:Unequip(World, ItemEntity, Channel)
	local Controller = script.Parent
	local Model = Controller:FindFirstChildOfClass("Model")
	if Model then
		Model:Destroy()
	end
	task.wait(5)

	if World:has(ItemEntity, Components.Item) then
		World:patch(ItemEntity, Components.Item, function(CurrentComponent)
			CurrentComponent.Equipped = true
			return CurrentComponent
		end)
	end
end

function Item:Destroy(World, ItemEntity, Channel)
	for _, Connection in Connections do
		Connection:Disconnect()
	end
end

return Item
