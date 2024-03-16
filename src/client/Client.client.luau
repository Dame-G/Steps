--!strict
local _start = os.clock()

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Network = require(ReplicatedStorage.Util.Network)

local PlayerChannel = Network:Create("Player")
local CharacterChannel = Network:Create("Character")

local PlayerData
local CharacterData

PlayerChannel:Receive(function(data)
	PlayerData = data
	return
end)

CharacterChannel:Receive(function(data)
	CharacterData = data
	return
end)

while not CharacterData or not PlayerData do
	task.wait()
end

print("Character loaded in", os.clock() - _start, "seconds")
