--!strict

local ReplicatedStorage = game.ReplicatedStorage
local ECS = require(ReplicatedStorage.Util.ECS)
local Network = require(ReplicatedStorage.Util.Network)
local PlayerTemplate = require(ReplicatedStorage.Templates.Player)
local PlayerComponent = ECS.Component(function()
	return table.clone(PlayerTemplate)
end)

local Alive = ECS.Tag()
local World = ECS.World()
local PlayerEntity = World:Create()
World:Add(PlayerEntity, PlayerComponent)

local Channel = Network:Create("Player")

Channel:Receive(function(data, alive)
	World:Set(PlayerEntity, PlayerComponent, data)
	if alive and not World:Has(PlayerEntity, Alive) then
		World:Add(PlayerEntity, Alive)
	elseif not alive and World:Has(PlayerEntity, Alive) then
		World:Remove(PlayerEntity, Alive)
	end
end)

local UpdatePlayer = function(dt)
	for entity, player in World:View(PlayerComponent):Get() do
		if World:Has(PlayerEntity, Alive) then
		end
	end
end

game:GetService("RunService").RenderStepped:Connect(function(dt)
	UpdatePlayer(dt)
end)
