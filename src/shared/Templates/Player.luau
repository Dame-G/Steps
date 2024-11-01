export type Player = {
	Username: string,
	UserId: number,
	TimePlayed: number,
	Characters: { string },
}

return {
	Username = "Player",
	UserId = 0,
	TimePlayed = 0,
	Characters = {},
	MaxNumberOfCharacters = 5,
} :: Player