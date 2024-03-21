--!strict

local function updateLabels(frame, data, indent)
	for key, value in pairs(data) do
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.SourceSans
		label.TextColor3 = Color3.new(1, 1, 1)
		label.TextSize = 16
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.Text = string.format("%s%s: %s", string.rep(" ", indent), key, tostring(value))
		label.Size = UDim2.new(1, 0, 0, label.TextBounds.Y)
		label.Parent = frame

		if type(value) == "table" then
			updateLabels(frame, value, indent + 7)
		end
	end
end

local function Menu(props)
	local ScreenGui = Instance.new("ScreenGui", game.Players.LocalPlayer.PlayerGui)
end

local Interface = {}

function Interface.new(playerComponent, characterComponent, charactersComponent)
	local components = {
		{ name = "Player", data = playerComponent },
		{ name = "Character", data = characterComponent },
		{ name = "Characters", data = charactersComponent },
	}

	return Menu({ components = components })
end

return Interface
