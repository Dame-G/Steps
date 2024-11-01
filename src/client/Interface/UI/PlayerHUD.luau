--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Character = require(ReplicatedStorage.Templates.Character)
local Fusion = require(ReplicatedStorage.Util.Fusion)
local peek = require(ReplicatedStorage.Util.Fusion.State.peek)

local function PlayerHUD(scope: Fusion.Scope, props: { Character: typeof(Character) })
	local character = game.Players.LocalPlayer.Character :: Model
	local root = character:WaitForChild("HumanoidRootPart") :: BasePart
	local velocity = root.AssemblyLinearVelocity
	local speed = scope:Value(math.round(velocity.Magnitude))
	local distanceTravelled = scope:Value(0)
	local section = scope:Value(0)

	local generatedSections = {} -- Keep track of sections generated

	table.insert(
		scope,
		RunService.Heartbeat:Connect(function()
			local character = game.Players.LocalPlayer.Character
			if character then
				local shell = character:WaitForChild("Shell") :: BasePart
				local touchingParts = shell:GetTouchingParts()

				for _, part in ipairs(touchingParts) do
					local sectionValue = part.Parent
						and part.Parent.Parent
						and part.Parent.Parent:FindFirstChild("Section") :: IntValue
					if sectionValue and sectionValue.Value ~= peek(section) then
						local currentSection = sectionValue.Value
						section:set(currentSection)

						break
					end
				end
			end
		end)
	)

	table.insert(
		scope,
		RunService.Heartbeat:Connect(function()
			local velocity = root.AssemblyLinearVelocity
			speed:set(math.round(velocity.Magnitude))
		end)
	)

	table.insert(
		scope,
		RunService.Heartbeat:Connect(function()
			local velocity = root.AssemblyLinearVelocity
			local distance = velocity.Magnitude * RunService.Heartbeat:Wait()
			distanceTravelled:set(peek(distanceTravelled) + distance)
		end)
	)

	return scope:New("Frame")({
		Name = "PlayerHUD",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, 0),
		Position = UDim2.new(0, 0, 0, 0),
		[Fusion.Children] = {
			scope:New("UIListLayout")({
				VerticalAlignment = Enum.VerticalAlignment.Bottom,
			}),
			scope:New("Frame")({
				Name = "Section",
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 25),
				[Fusion.Children] = {
					scope:New("TextLabel")({
						Name = "SectionText",
						BackgroundTransparency = 1,
						Size = UDim2.new(1, 0, 1, 0),
						Position = UDim2.new(0, 0, 0, 0),
						Text = scope:Computed(function(use)
							return `Section: {use(section)}`
						end),
						TextSize = 20,
						Font = Enum.Font.SourceSansBold,
						TextColor3 = Color3.new(1, 1, 1),
						TextStrokeColor3 = Color3.new(0, 0, 0),
						TextStrokeTransparency = 0.5,
						TextXAlignment = Enum.TextXAlignment.Left,
					}),
				},
			}),
			scope:New("Frame")({
				Name = "Speed",
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 25),
				[Fusion.Children] = {
					scope:New("TextLabel")({
						Name = "SpeedText",
						BackgroundTransparency = 1,
						Size = UDim2.new(1, 0, 1, 0),
						Position = UDim2.new(0, 0, 0, 0),
						Text = scope:Computed(function(use)
							return `Speed: {use(speed)}`
						end),
						TextSize = 20,
						Font = Enum.Font.SourceSansBold,
						TextColor3 = Color3.new(1, 1, 1),
						TextStrokeColor3 = Color3.new(0, 0, 0),
						TextStrokeTransparency = 0.5,
						TextXAlignment = Enum.TextXAlignment.Left,
					}),
				},
			}),
			scope:New("Frame")({
				Name = "Distance",
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 25),
				[Fusion.Children] = {
					scope:New("TextLabel")({
						Name = "DistanceText",
						BackgroundTransparency = 1,
						Size = UDim2.new(1, 0, 1, 0),
						Position = UDim2.new(0, 0, 0, 0),
						Text = scope:Computed(function(use)
							return `Distace Travelled: {math.floor(use(distanceTravelled) / 10)}`
						end),
						TextSize = 20,
						Font = Enum.Font.SourceSansBold,
						TextColor3 = Color3.new(1, 1, 1),
						TextStrokeColor3 = Color3.new(0, 0, 0),
						TextStrokeTransparency = 0.5,
						TextXAlignment = Enum.TextXAlignment.Left,
					}),
				},
			}),
			scope:New("Frame")({
				Name = "Lives",
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 25),
				[Fusion.Children] = {
					scope:New("TextLabel")({
						Name = "LivesText",
						BackgroundTransparency = 1,
						Size = UDim2.new(1, 0, 1, 0),
						Position = UDim2.new(0, 0, 0, 0),
						Text = `Lives: {props.Character.Lives}`,
						TextSize = 20,
						Font = Enum.Font.SourceSansBold,
						TextColor3 = Color3.new(1, 1, 1),
						TextStrokeColor3 = Color3.new(0, 0, 0),
						TextStrokeTransparency = 0.5,
						TextXAlignment = Enum.TextXAlignment.Left,
					}),
				},
			}),
		},
	})
end

return PlayerHUD
