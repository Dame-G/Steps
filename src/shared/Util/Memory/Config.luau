--!strict

export type Config = {
	MemoryName: string,
	Version: number,
	Mock: boolean?,
	CompressThreshold: number?,
	AutoSaveInterval: number?,
	CacheSize: number?,
}

local DEFAULT_CONFIG: Config = {
	MemoryName = "Data",
	Version = 1,
	Mock = false,
	CompressThreshold = 256,
	AutoSaveInterval = 5,
	CacheSize = 100,
}

local Config = {}

function Config.createConfig(userConfig: Config?): Config
	local config = table.clone(DEFAULT_CONFIG)
	if userConfig then
		for key, value in pairs(userConfig) do
			if config[key] ~= nil then
				config[key] = value
			end
		end
	end
	return config
end

return Config
