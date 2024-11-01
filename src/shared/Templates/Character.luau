local HttpService = game:GetService("HttpService")

local Item = require(script.Parent.Item)

export type Character = {
	Level: number,
	Lives: number,
	Location: {
		X: number,
		Y: number,
		Z: number,
		Area: string,
	},
	Stats: { [string]: number },
	Quests: { [string]: { boolean } },
	Inventory: { Item.Item },
	TimePlayed: number,
	LastPlayed: string,
	Id: string,
	Name: string,
}

return {
	Level = 1,
	Lives = 5,
	Location = {
		X = 0,
		Y = 0,
		Z = 0,
		Area = "Start",
	},
	Stats = {},
	Quests = {},
	Inventory = {
		table.clone(Item),
	},
	TimePlayed = 0,
	LastPlayed = os.date(),
	Id = HttpService:GenerateGUID(false):gsub("-", ""),
	Name = "Character",
} :: Character