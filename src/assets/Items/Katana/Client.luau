local UserInputService = game:GetService("UserInputService")

local Connections = {}
local Item = {}

function Item:Init(World, ItemEntity, Channel)
	Channel:Receive(function(Action)
		print(Action)
	end)
end

function Item:Equip(World, ItemEntity, Channel)
	table.insert(
		Connections,
		UserInputService.InputBegan:Connect(function(Input)
			if Input.KeyCode == Enum.KeyCode.Q then
				Channel:Send("Unequip")
			end
		end)
	)
end

function Item:Unequip(World, ItemEntity, Channel)
	self:Destroy(World, ItemEntity, Channel)
end

function Item:Destroy(World, ItemEntity, Channel)
	for _, Connection in Connections do
		Connection:Disconnect()
	end
end

return Item
