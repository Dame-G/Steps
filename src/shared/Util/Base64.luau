--!strict

--[[
    Base64 Module
    Provides functions for encoding and decoding strings using Base64.
]]

local Base64 = {}

local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

function Base64.encode(data: string): string
	local encodedData = {}
	local len = string.len(data)
	local i = 1

	while i <= len do
		local b1, b2, b3 = string.byte(data, i, i + 2)
		i = i + 3

		local enc1 = chars:sub(bit32.rshift(b1, 2) + 1, bit32.rshift(b1, 2) + 1)
		local enc2 = chars:sub(
			bit32.bor(bit32.lshift(bit32.band(b1, 3), 4), bit32.rshift(b2 or 0, 4)) + 1,
			bit32.bor(bit32.lshift(bit32.band(b1, 3), 4), bit32.rshift(b2 or 0, 4)) + 1
		)
		local enc3 = b2
				and chars:sub(
					bit32.bor(bit32.lshift(bit32.band(b2, 15), 2), bit32.rshift(b3 or 0, 6)) + 1,
					bit32.bor(bit32.lshift(bit32.band(b2, 15), 2), bit32.rshift(b3 or 0, 6)) + 1
				)
			or "="
		local enc4 = b3 and chars:sub(bit32.band(b3, 63) + 1, bit32.band(b3, 63) + 1) or "="

		table.insert(encodedData, enc1)
		table.insert(encodedData, enc2)
		table.insert(encodedData, enc3)
		table.insert(encodedData, enc4)
	end

	return table.concat(encodedData)
end

function Base64.decode(data: string): string
	local decodedData = {}
	local len = string.len(data)
	local i = 1

	while i <= len do
		local enc1, enc2, enc3, enc4 = string.byte(data, i, i + 3)
		i = i + 4

		enc1 = chars:find(string.char(enc1)) :: number - 1
		enc2 = chars:find(string.char(enc2)) :: number - 1
		enc3 = enc3 == 61 and 0 or chars:find(string.char(enc3)) :: number - 1
		enc4 = enc4 == 61 and 0 or chars:find(string.char(enc4)) :: number - 1

		local dec1 = bit32.bor(bit32.lshift(enc1, 2), bit32.rshift(enc2, 4))
		local dec2 = bit32.bor(bit32.lshift(bit32.band(enc2, 15), 4), bit32.rshift(enc3, 2))
		local dec3 = bit32.bor(bit32.lshift(bit32.band(enc3, 3), 6), enc4)

		table.insert(decodedData, string.char(dec1))
		if enc3 ~= 0 then
			table.insert(decodedData, string.char(dec2))
		end
		if enc4 ~= 0 then
			table.insert(decodedData, string.char(dec3))
		end
	end

	return table.concat(decodedData)
end

return Base64
