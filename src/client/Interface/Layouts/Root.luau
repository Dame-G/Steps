--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage.Util.Fusion)
local Children = Fusion.Children

type RootLayoutProps = {
	title: string,
	children: Fusion.Child,
}

local function Root(scope: Fusion.Scope)
	return function(props: RootLayoutProps)
		local title = props.title
		local children = props.children

		return scope:New("ScreenGui")({
			Name = title,
			Parent = game.Players.LocalPlayer.PlayerGui,
			[Children] = children,
		})
	end
end

return Root
