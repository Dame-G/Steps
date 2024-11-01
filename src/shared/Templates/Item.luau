local HttpService = game:GetService("HttpService")

export type Requirements = {
	Stats: { [string]: number },
	Quests: { [string]: { boolean } },
}

export type Perk = {
	Name: string,
	Description: string,
	Type: string,
	Multiplier: number,
}

export type ItemType = "Weapon" | "Armor" | "Accessory" | "Consumable" | "Ability" | "Misc"

export type Item = {
	Name: string,
	Description: string,
	Id: string,
	Owner: number,
	Type: ItemType,
	Price: number,
	Rarity: string,
	Quantity: number,
	Stackable: boolean,
	Tradeable: boolean,
	Equipped: boolean,
	Slot: number,
	Requirements: Requirements,
	Stats: { [string]: number },
	Perks: { Perk },
	Tags: { string },
	Options: { string },
}

return {
	Name = "Test",
	Description = "Testing item for development purposes",
	Id = HttpService:GenerateGUID(false):gsub("-", ""),
	Owner = 0,
	Type = "Misc",
	Price = 0,
	Rarity = "Common",
	Quantity = 1,
	Stackable = false,
	Tradeable = false,
	Equipped = true,
	Slot = 0,
	Requirements = {
		Stats = {},
		Quests = {},
	},
	Stats = {},
	Perks = {},
	Tags = {},
	Options = {},
} :: Item