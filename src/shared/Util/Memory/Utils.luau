local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MessagePack = require(ReplicatedStorage.Util.MessagePack)

local Utils = {}

-- Compression functions
function Utils.compressIfNeeded(data: any, threshold: number): { data: any, wasCompressed: boolean }
	local encoded = MessagePack.encode(data)

	if #encoded > threshold then
		local compressed = "--" .. MessagePack.utf8Encode(encoded)
		return { data = compressed, wasCompressed = true }
	end

	return { data = data, wasCompressed = false }
end

function Utils.decompressIfNeeded(data: any): any
	if type(data) == "string" and data:sub(1, 2) == "--" then
		local decompressed = MessagePack.decode(MessagePack.utf8Decode(data:sub(3)))
		return decompressed
	end

	return data
end

function Utils.updateCacheOrder(cacheKeys: { string }, key: string)
	local index = table.find(cacheKeys, key)
	if index then
		table.remove(cacheKeys, index)
		table.insert(cacheKeys, key)
	end
end

function Utils.removeFromCache(cacheKeys: { string }, key: string)
	local index = table.find(cacheKeys, key)
	if index then
		table.remove(cacheKeys, index)
	end
end

return Utils
