--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Network = require(ReplicatedStorage.Util.Network)

local PlayerChannel = Network:Create("Player")

PlayerChannel:Receive(function(...)
	print(...)
	return
end)
