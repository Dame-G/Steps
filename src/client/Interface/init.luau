--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Character = require(ReplicatedStorage.Templates.Character)
local Fusion = require(ReplicatedStorage.Util.Fusion)

local Layouts = script.Layouts
local Root = require(Layouts.Root)

local UI = script.UI
local PlayerHUD = require(UI.PlayerHUD)

local function Init(props: { Character: typeof(Character) })
	local Interface = Fusion:scoped()
	Root(Interface)({
		title = "Interface",
		children = {
			PlayerHUD(Interface, props),
		},
	})

	return Interface
end

return Init
