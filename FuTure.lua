luaocal modules = {}
local cache = {}
local function drequire(name)
	
	if cache[name] ~= nil then
		return cache[name]
	end
	
	local module_func = modules[name]
	if not module_func then
		error("module '" .. name .. "' not found in bundle", 2)
	end
	
	cache[name] = true
	
	local result = module_func()
	
	if result ~= nil then
		cache[name] = result
	end
	return cache[name]
end

modules["PNGLib\\Chunks\\bKGD.lua"] = function()
	local function bKGD(file, chunk)
		local data = chunk.Data
		
		local bitDepth = file.BitDepth
		local colorType = file.ColorType
		
		bitDepth = (2 ^ bitDepth) - 1
		
		if colorType == 3 then
			local index = data:ReadByte()
			file.BackgroundColor = file.Palette[index]
		elseif colorType == 0 or colorType == 4 then
			local gray = data:ReadUInt16() / bitDepth
			file.BackgroundColor = Color3.fromHSV(0, 0, gray)
		elseif colorType == 2 or colorType == 6 then
			local r = data:ReadUInt16() / bitDepth
			local g = data:ReadUInt16() / bitDepth
			local b = data:ReadUInt16() / bitDepth
			file.BackgroundColor = Color3.new(r, g, b)
		end
	end
	return bKGD
end

modules["PNGLib\\Chunks\\cHRM.lua"] = function()
	local colors = {"White", "Red", "Green", "Blue"}
	local function cHRM(file, chunk)
		local chrome = {}
		local data = chunk.Data
		
		for i = 1, 4 do
			local color = colors[i]
			
			chrome[color] =
			{
				[1] = data:ReadUInt32() / 10e4;
				[2] = data:ReadUInt32() / 10e4;
			}
		end
		
		file.Chromaticity = chrome
	end
	return cHRM
end

modules["PNGLib\\Chunks\\gAMA.lua"] = function()
	local function gAMA(file, chunk)
		local data = chunk.Data
		local value = data:ReadUInt32()
		file.Gamma = value / 10e4
	end
	return gAMA
end

modules["PNGLib\\Chunks\\IDAT.lua"] = function()
	local function IDAT(file, chunk)
		local crc = chunk.CRC
		local hash = file.Hash or 0
		
		local data = chunk.Data
		local buffer = data.Buffer
		
		file.Hash = bit32.bxor(hash, crc)
		file.ZlibStream = file.ZlibStream .. buffer
	end
	return IDAT
end

modules["PNGLib\\Chunks\\IEND.lua"] = function()
	local function IEND(file)
		file.Reading = nil
	end
	return IEND
end

modules["PNGLib\\Chunks\\IHDR.lua"] = function()
	local function IHDR(file, chunk)
		local data = chunk.Data
		
		file.Width = data:ReadInt32();
		file.Height = data:ReadInt32();
		
		file.BitDepth = data:ReadByte();
		file.ColorType = data:ReadByte();
		
		file.Methods =
		{
			Compression = data:ReadByte();
			Filtering   = data:ReadByte();
			Interlace   = data:ReadByte();
		}
	end
	return IHDR
end

modules["PNGLib\\Chunks\\PLTE.lua"] = function()
	local function PLTE(file, chunk)
		if not file.Palette then
			file.Palette = {}
		end
		
		local data = chunk.Data
		local palette = data:ReadAllBytes()
		
		if #palette % 3 ~= 0 then
			error("PNG - Invalid PLTE chunk.")
		end
		
		for i = 1, #palette, 3 do
			local r = palette[i]
			local g = palette[i + 1]
			local b = palette[i + 2]
			
			local color = Color3.fromRGB(r, g, b)
			local index = #file.Palette + 1
			
			file.Palette[index] = color
		end
	end
	return PLTE
end

modules["PNGLib\\Chunks\\sRGB.lua"] = function()
	local function sRGB(file, chunk)
		local data = chunk.Data
		file.RenderIntent = data:ReadByte()
	end
	return sRGB
end

modules["PNGLib\\Chunks\\tEXt.lua"] = function()
	local function tEXt(file, chunk)
		local data = chunk.Data
		local key, value = "", ""
		
		for byte in data:IterateBytes() do
			local char = string.char(byte)
			
			if char == '\0' then
				key = value
				value = ""
			else
				value = value .. char
			end
		end
		
		file.Metadata[key] = value
	end
	return tEXt
end

modules["PNGLib\\Chunks\\tIME.lua"] = function()
	local function tIME(file, chunk)
		local data = chunk.Data
		
		local timeStamp = 
		{
			Year  = data:ReadUInt16();
			Month = data:ReadByte();
			Day   = data:ReadByte();
			
			Hour   = data:ReadByte();
			Minute = data:ReadByte();
			Second = data:ReadByte();
		}
		
		file.TimeStamp = timeStamp
	end
	return tIME
end

modules["PNGLib\\Chunks\\tRNS.lua"] = function()
	local function tRNS(file, chunk)
		local data = chunk.Data
		
		local bitDepth = file.BitDepth
		local colorType = file.ColorType
		
		bitDepth = (2 ^ bitDepth) - 1
		
		if colorType == 3 then
			local palette = file.Palette
			local alphaMap = {}
			
			for i = 1, #palette do
				local alpha = data:ReadByte()
				
				if not alpha then
					alpha = 255
				end
				
				alphaMap[i] = alpha
			end
			
			file.AlphaData = alphaMap
		elseif colorType == 0 then
			local grayAlpha = data:ReadUInt16()
			file.Alpha = grayAlpha / bitDepth
		elseif colorType == 2 then
			
			local r = data:ReadUInt16() / bitDepth
			local g = data:ReadUInt16() / bitDepth
			local b = data:ReadUInt16() / bitDepth
			file.Alpha = Color3.new(r, g, b)
		else
			error("PNG - Invalid tRNS chunk")
		end	
	end
	return tRNS
end

modules["PNGLib\\Modules\\BinaryReader.lua"] = function()
	local BinaryReader = {}
	BinaryReader.__index = BinaryReader
	function BinaryReader.new(buffer)
		local reader = 
		{
			Position = 1;
			Buffer = buffer;
			Length = #buffer;
		}
		
		return setmetatable(reader, BinaryReader)
	end
	function BinaryReader:ReadByte()
		local buffer = self.Buffer
		local pos = self.Position
		
		if pos <= self.Length then
			local result = buffer:sub(pos, pos)
			self.Position = pos + 1
			
			return result:byte()
		end
	end
	function BinaryReader:ReadBytes(count, asArray)
		local values = {}
		
		for i = 1, count do
			values[i] = self:ReadByte()
		end
		
		if asArray then
			return values
		end
		
		return unpack(values)
	end
	function BinaryReader:ReadAllBytes()
		return self:ReadBytes(self.Length, true)
	end
	function BinaryReader:IterateBytes()
		return function ()
			return self:ReadByte()
		end
	end
	function BinaryReader:TwosComplementOf(value, numBits)
		if value >= (2 ^ (numBits - 1)) then
			value = value - (2 ^ numBits)
		end
		
		return value
	end
	function BinaryReader:ReadUInt16()
		local upper, lower = self:ReadBytes(2)
		return (upper * 256) + lower
	end
	function BinaryReader:ReadInt16()
		local unsigned = self:ReadUInt16()
		return self:TwosComplementOf(unsigned, 16)
	end
	function BinaryReader:ReadUInt32()
		local upper = self:ReadUInt16()
		local lower = self:ReadUInt16()
		
		return (upper * 65536) + lower
	end
	function BinaryReader:ReadInt32()
		local unsigned = self:ReadUInt32()
		return self:TwosComplementOf(unsigned, 32)
	end
	function BinaryReader:ReadString(length)
	    if length == nil then
	        length = self:ReadByte()
	    end
	    
	    local pos = self.Position
	    local nextPos = math.min(self.Length, pos + length)
	    
	    local result = self.Buffer:sub(pos, nextPos - 1)
	    self.Position = nextPos
	    
	    return result
	end
	function BinaryReader:ForkReader(length)
		local chunk = self:ReadString(length)
		return BinaryReader.new(chunk)
	end
	return BinaryReader
end

modules["PNGLib\\Modules\\Deflate.lua"] = function()
--[[Lua模块
在Lua中实现了compress.deflateLua-Deflate(和zlib)。
描述
这是解压缩Deflate格式的纯Lua实现。
包括相关的zlib格式。
注:此库仅支持解压缩。
当前未实现压缩。
参考文献
[1]压缩数据格式规范1.3版
 http://tools.ietf.org/html/rfc1951 
[2]GZIP文件格式规范4.3版
 http://tools.ietf.org/html/rfc1952 
[3]http://en.wikipedia.org/wiki/DEFLATE 
[4]Pyflate，作者Paul Sladen
 http://www.paul.sladen.org/projects/pyflate/ 
[5]compress::zlib::perl-部分纯Perl实现
压缩::zlib
 http://search.cpan.org/~nwclark/compres-zlib-perl/perl.pm
	]]
	local Deflate = {}
	local band = bit32.band
	local lshift = bit32.lshift
	local rshift = bit32.rshift
	local BTYPE_NO_COMPRESSION = 0
	local BTYPE_FIXED_HUFFMAN = 1
	local BTYPE_DYNAMIC_HUFFMAN = 2
	local lens = 
	{
		[0] = 3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31,
		35, 43, 51, 59, 67, 83, 99, 115, 131, 163, 195, 227, 258
	}
	local lext = 
	{
		[0] = 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2,
		3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 0
	}
	local dists = 
	{
		[0] = 1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193,
		257, 385, 513, 769, 1025, 1537, 2049, 3073, 4097, 6145,
		8193, 12289, 16385, 24577
	}
	local dext = 
	{
		[0] = 0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6,
		7, 7, 8, 8, 9, 9, 10, 10, 11, 11,
		12, 12, 13, 13
	}
	local order = 
	{
		16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 
		11, 4, 12, 3, 13, 2, 14, 1, 15
	}
	
	local fixedLit = {0, 8, 144, 9, 256, 7, 280, 8, 288}
	 
	local fixedDist = {0, 5, 32}
	local function createState(bitStream)
		local state = 
		{
			Output = bitStream;
			Window = {};
			Pos = 1;
		}
		
		return state
	end
	local function write(state, byte)
		local pos = state.Pos
		state.Output(byte)
		state.Window[pos] = byte
		state.Pos = pos % 32768 + 1  
	end
	local function memoize(fn)
		local meta = {}
		local memoizer = setmetatable({}, meta)
		
		function meta:__index(k)
			local v = fn(k)
			memoizer[k] = v
			
			return v
		end
		
		return memoizer
	end
	
	local pow2 = memoize(function (n) 
		return 2 ^ n 
	end)
	
	local isBitStream = setmetatable({}, { __mode = 'k' })
	local function createBitStream(reader)
		local buffer = 0
		local bitsLeft = 0
		
		local stream = {}
		isBitStream[stream] = true
		
		function stream:GetBitsLeft()
			return bitsLeft
		end
		
		function stream:Read(count)
			count = count or 1
			
			while bitsLeft < count do
				local byte = reader:ReadByte()
				
				if not byte then 
					return 
				end
				
				buffer = buffer + lshift(byte, bitsLeft)
				bitsLeft = bitsLeft + 8
			end
			
			local bits
			
			if count == 0 then
				bits = 0
			elseif count == 32 then
				bits = buffer
				buffer = 0
			else
				bits = band(buffer, rshift(2^32 - 1, 32 - count))
				buffer = rshift(buffer, count)
			end
			
			bitsLeft = bitsLeft - count
			return bits
		end
		
		return stream
	end
	local function getBitStream(obj)
		if isBitStream[obj] then
			return obj
		end
		
		return createBitStream(obj)
	end
	local function sortHuffman(a, b)
		return a.NumBits == b.NumBits and a.Value < b.Value or a.NumBits < b.NumBits
	end
	local function msb(bits, numBits)
		local res = 0
			
		for i = 1, numBits do
			res = lshift(res, 1) + band(bits, 1)