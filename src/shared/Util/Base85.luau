--!strict

--[[
    Base85 Module
    Provides functions for encoding and decoding strings using Base85 (Ascii85).
]]

local Base85 = {}

local chars = "!#$%&()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[]^_`abcdefghijklmnopqrstu"

function Base85.encode(data: string): string
	local encodedData = {}
	local len = string.len(data)
	local i = 1

	while i <= len do
		local b1, b2, b3, b4 = string.byte(data, i, i + 3)
		i = i + 4

		local value = bit32.lshift(b1 or 0, 24) + bit32.lshift(b2 or 0, 16) + bit32.lshift(b3 or 0, 8) + (b4 or 0)

		local enc1 = chars:sub(bit32.rshift(value, 32) + 1, bit32.rshift(value, 32) + 1)
		local enc2 = chars:sub(bit32.band(bit32.rshift(value, 27), 63) + 1, bit32.band(bit32.rshift(value, 27), 63) + 1)
		local enc3 = chars:sub(bit32.band(bit32.rshift(value, 22), 63) + 1, bit32.band(bit32.rshift(value, 22), 63) + 1)
		local enc4 = chars:sub(bit32.band(bit32.rshift(value, 17), 63) + 1, bit32.band(bit32.rshift(value, 17), 63) + 1)
		local enc5 = chars:sub(bit32.band(bit32.rshift(value, 12), 63) + 1, bit32.band(bit32.rshift(value, 12), 63) + 1)

		table.insert(encodedData, enc1)
		table.insert(encodedData, enc2)
		table.insert(encodedData, enc3)
		table.insert(encodedData, enc4)
		table.insert(encodedData, enc5)
	end

	return table.concat(encodedData)
end

function Base85.decode(data: string): string
	local decodedData = {}
	local len = string.len(data)
	local i = 1

	while i <= len do
		local enc1, enc2, enc3, enc4, enc5 = string.byte(data, i, i + 4)
		i = i + 5

		enc1 = chars:find(string.char(enc1)) :: number - 1
		enc2 = chars:find(string.char(enc2)) :: number - 1
		enc3 = chars:find(string.char(enc3)) :: number - 1
		enc4 = chars:find(string.char(enc4)) :: number - 1
		enc5 = chars:find(string.char(enc5)) :: number - 1

		local value = bit32.lshift(enc1, 32)
			+ bit32.lshift(enc2, 27)
			+ bit32.lshift(enc3, 22)
			+ bit32.lshift(enc4, 17)
			+ bit32.lshift(enc5, 12)

		local dec1 = bit32.rshift(value, 24)
		local dec2 = bit32.band(bit32.rshift(value, 16), 255)
		local dec3 = bit32.band(bit32.rshift(value, 8), 255)
		local dec4 = bit32.band(value, 255)

		table.insert(decodedData, string.char(dec1))
		table.insert(decodedData, string.char(dec2))
		table.insert(decodedData, string.char(dec3))
		table.insert(decodedData, string.char(dec4))
	end

	return table.concat(decodedData)
end

return Base85
