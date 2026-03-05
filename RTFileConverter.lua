local __bundle_require, __bundle_loaded, __bundle_register, __bundle_modules = (function(superRequire)
	local loadingPlaceholder = {[{}] = true}

	local register
	local modules = {}

	local require
	local loaded = {}

	register = function(name, body)
		if not modules[name] then
			modules[name] = body
		end
	end

	require = function(name)
		local loadedModule = loaded[name]

		if loadedModule then
			if loadedModule == loadingPlaceholder then
				return nil
			end
		else
			if not modules[name] then
				if not superRequire then
					local identifier = type(name) == 'string' and '\"' .. name .. '\"' or tostring(name)
					error('Tried to require ' .. identifier .. ', but no such module has been registered')
				else
					return superRequire(name)
				end
			end

			loaded[name] = loadingPlaceholder
			loadedModule = modules[name](require, loaded, register, modules)
			loaded[name] = loadedModule
		end

		return loadedModule
	end

	return require, loaded, register, modules
end)(require)
__bundle_register("__root", function(require, _LOADED, __bundle_register, __bundle_modules)

local zlib = require("zlib_lua")
local png  = require("png_lua")

local function u8(s, pos)
    return s:byte(pos)
end

local function i32le(s, pos)
    local a, b, c, d = s:byte(pos, pos + 3)
    local v = a + b * 0x100 + c * 0x10000 + d * 0x1000000
    if v >= 0x80000000 then v = v - 0x100000000 end
    return v
end

local function u32le(s, pos)
    local a, b, c, d = s:byte(pos, pos + 3)
    return a + b * 0x100 + c * 0x10000 + d * 0x1000000
end

local function u16le(s, pos)
    local a, b = s:byte(pos, pos + 1)
    return a + b * 0x100
end

local function put_u8(t, pos, v)
    t[pos] = v & 0xFF
end

local function put_u16le(t, pos, v)
    t[pos]     = v & 0xFF
    t[pos + 1] = (v >> 8) & 0xFF
end

local function put_u32le(t, pos, v)
    if v < 0 then v = v + 0x100000000 end
    t[pos]     = v & 0xFF
    t[pos + 1] = (v >>  8) & 0xFF
    t[pos + 2] = (v >> 16) & 0xFF
    t[pos + 3] = (v >> 24) & 0xFF
end

local put_i32le = put_u32le

local function put_str(t, pos, s)
    for i = 1, #s do t[pos + i - 1] = s:byte(i) end
end

local function table_to_str(t, len)
    local c = {}
    for i = 1, len do c[i] = string.char(t[i] or 0) end
    return table.concat(c)
end

local function flip_vertical(raw_rgba, width, height)
    local row = width * 4
    local rows = {}
    for y = 0, height - 1 do
        rows[height - y] = raw_rgba:sub(y * row + 1, (y + 1) * row)
    end
    return table.concat(rows)
end

local function get_pow2(n)
    local v = 1
    while v < n do v = v * 2 end
    return v
end

local RTTEX = {}
RTTEX.__index = RTTEX

function RTTEX.new(image_bytes)
    assert(type(image_bytes) == "string", "Please pass a string of bytes.")
    local hdr = image_bytes:sub(1, 6)
    assert(hdr == "RTPACK" or hdr == "RTTXTR",
        "File header must be RTPACK or RTTXTR, got: " .. hdr)
    return setmetatable({ image = image_bytes, type = hdr }, RTTEX)
end

function RTTEX:parseRTPACK()
    assert(self.type == "RTPACK", "Expected RTPACK, got " .. self.type)
    local img = self.image
    local r2  = {}
    for i = 18, 32 do r2[#r2+1] = u8(img, i) end
    return {
        type             = img:sub(1, 6),
        version          = u8(img, 7),
        reserved         = u8(img, 8),
        compressedSize   = u32le(img, 9),
        decompressedSize = u32le(img, 13),
        compressionType  = u8(img, 17),
        reserved2        = r2,
    }
end

function RTTEX:parseRTTXTR()
    local img = self.image
    if self.type == "RTPACK" then
        img = zlib.inflate(img:sub(33))   

    end
    assert(img:sub(1, 6) == "RTTXTR", "Inner header must be RTTXTR")

    local r2 = {}
    local pos = 37   

    for i = 1, 16 do r2[i] = i32le(img, pos); pos = pos + 4 end

    return {
        type           = img:sub(1, 6),
        version        = u8(img, 7),
        reserved       = u8(img, 8),
        width          = i32le(img, 9),
        height         = i32le(img, 13),
        format         = i32le(img, 17),
        originalWidth  = i32le(img, 21),
        originalHeight = i32le(img, 25),
        isAlpha        = u8(img, 29),
        isCompressed   = u8(img, 30),
        reservedFlags  = u16le(img, 31),
        mipmap = {
            count        = i32le(img, 33),
            width        = i32le(img, 101),
            height       = i32le(img, 105),
            bufferLength = i32le(img, 109),
        },
        reserved2 = r2,
    }
end

function RTTEX.hash(buf)
    local hash = 0x55555555
    for i = 1, #buf do
        local b = buf:byte(i)
        hash = (((hash >> 27) | ((hash << 5) & 0xFFFFFFFF)) + b) & 0xFFFFFFFF
    end
    return hash
end

function RTTEX.decode(rttex_bytes)
    assert(type(rttex_bytes) == "string", "Please pass a string of bytes.")

    local data = rttex_bytes
    if data:sub(1, 6) == "RTPACK" then
        data = zlib.inflate(data:sub(33))   

    end
    assert(data:sub(1, 6) == "RTTXTR", "Invalid format: expected RTTXTR after decompression")

    local stored_h = i32le(data, 9)
    local stored_w = i32le(data, 13)
    local orig_h   = i32le(data, 21)
    local orig_w   = i32le(data, 25)

    local raw_rgba = data:sub(125)
    local flipped  = flip_vertical(raw_rgba, stored_w, stored_h)

    local row_size = stored_w * 4
    local cropped  = {}
    for y = 0, orig_h - 1 do
        cropped[#cropped + 1] = flipped:sub(y * row_size + 1, y * row_size + orig_w * 4)
    end

    return png.encode(orig_w, orig_h, table.concat(cropped))
end

function RTTEX.encode(png_bytes)
    assert(type(png_bytes) == "string", "Please pass a string of bytes.")
    local hdr = png_bytes:sub(1, 6)
    assert(hdr ~= "RTPACK" and hdr ~= "RTTXTR",
        "Input must be a PNG, not RTTEX/RTPACK")

    local img      = png.decode(png_bytes)
    local width    = img.width
    local height   = img.height
    local raw_rgba = flip_vertical(img.data, width, height)

    local rttex = {}
    for i = 1, 124 do rttex[i] = 0 end

    put_str   (rttex,  1, "RTTXTR")
    put_u8    (rttex,  7, 0)                    

    put_u8    (rttex,  8, 0)                    

    put_i32le (rttex,  9, get_pow2(height))     

    put_i32le (rttex, 13, get_pow2(width))      

    put_i32le (rttex, 17, 5121)                 

    put_i32le (rttex, 21, width)               

    put_i32le (rttex, 25, height)                

    put_u8    (rttex, 29, 1)                    

    put_u8    (rttex, 30, 0)                    

    put_u16le (rttex, 31, 1)                    

    put_i32le (rttex, 33, 1)                    

    put_i32le (rttex, 101, width)              

    put_i32le (rttex, 105, height)               

    put_i32le (rttex, 109, #raw_rgba)           

    local payload    = table_to_str(rttex, 124) .. raw_rgba
    local compressed = zlib.deflate(payload)    

    local rtpack = {}
    for i = 1, 32 do rtpack[i] = 0 end

    put_str   (rtpack,  1, "RTPACK")
    put_u8    (rtpack,  7, 1)                   

    put_u8    (rtpack,  8, 1)                   

    put_u32le (rtpack,  9, #compressed)         

    put_u32le (rtpack, 13, #payload)            

    put_u8    (rtpack, 17, 1)                   

    return table_to_str(rtpack, 32) .. compressed
end

return RTTEX

end)
__bundle_register("png_lua", function(require, _LOADED, __bundle_register, __bundle_modules)

local zlib = require("zlib_lua")

local M = {}

local CRC_TABLE = {}
do
    for i = 0, 255 do
        local c = i
        for _ = 1, 8 do
            if c & 1 ~= 0 then
                c = 0xEDB88320 ~ (c >> 1)
            else
                c = c >> 1
            end
        end
        CRC_TABLE[i] = c
    end
end

local function crc32(data, crc)
    crc = (crc or 0xFFFFFFFF) & 0xFFFFFFFF
    for i = 1, #data do
        crc = CRC_TABLE[(crc ~ data:byte(i)) & 0xFF] ~ (crc >> 8)
    end
    return (crc ~ 0xFFFFFFFF) & 0xFFFFFFFF
end

local function u32be_str(v)
    v = v & 0xFFFFFFFF
    return string.char(
        (v >> 24) & 0xFF,
        (v >> 16) & 0xFF,
        (v >>  8) & 0xFF,
         v        & 0xFF
    )
end

local function u32be(s, pos)
    local a, b, c, d = s:byte(pos, pos + 3)
    return a * 0x1000000 + b * 0x10000 + c * 0x100 + d
end

local function make_chunk(name, data)
    local payload = name .. data
    return u32be_str(#data) .. payload .. u32be_str(crc32(payload))
end

local function paeth(a, b, c)
    local p  = a + b - c
    local pa = math.abs(p - a)
    local pb = math.abs(p - b)
    local pc = math.abs(p - c)
    if pa <= pb and pa <= pc then return a
    elseif pb <= pc then return b
    else return c end
end

function M.decode(png_bytes)
    local PNG_SIG = "\137\080\078\071\013\010\026\010"
    assert(png_bytes:sub(1, 8) == PNG_SIG, "Not a valid PNG file")

    local pos   = 9
    local width, height, bit_depth, color_type
    local palette = {}
    local idat_chunks = {}

    while pos <= #png_bytes do
        local length   = u32be(png_bytes, pos);       pos = pos + 4
        local name     = png_bytes:sub(pos, pos + 3); pos = pos + 4
        local data     = png_bytes:sub(pos, pos + length - 1); pos = pos + length
        pos = pos + 4  

        if name == "IHDR" then
            width      = u32be(data, 1)
            height     = u32be(data, 5)
            bit_depth  = data:byte(9)
            color_type = data:byte(10)
            assert(bit_depth == 8, "Only 8-bit PNG supported, got: " .. bit_depth)
            assert(data:byte(12) == 0, "Interlaced PNG not supported")

        elseif name == "PLTE" then
            for i = 0, math.floor(#data / 3) - 1 do
                palette[i] = {
                    data:byte(i*3 + 1),
                    data:byte(i*3 + 2),
                    data:byte(i*3 + 3),
                    255,
                }
            end

        elseif name == "IDAT" then
            idat_chunks[#idat_chunks + 1] = data

        elseif name == "IEND" then
            break
        end
    end

    local ch_map = { [0]=1, [2]=3, [3]=1, [4]=2, [6]=4 }
    local channels = assert(ch_map[color_type], "Unsupported color type: " .. tostring(color_type))
    local bpp      = channels  

    local raw = zlib.inflate(table.concat(idat_chunks))

    local stride   = width * bpp
    local out_rgba = {}
    local prev     = {}   

    for i = 1, stride do prev[i] = 0 end

    local rpos = 1
    for _ = 1, height do
        local filter = raw:byte(rpos); rpos = rpos + 1
        local row    = { raw:byte(rpos, rpos + stride - 1) }
        rpos = rpos + stride

        if filter == 0 then

        elseif filter == 1 then

            for i = bpp + 1, stride do
                row[i] = (row[i] + row[i - bpp]) & 0xFF
            end
        elseif filter == 2 then

            for i = 1, stride do
                row[i] = (row[i] + prev[i]) & 0xFF
            end
        elseif filter == 3 then

            for i = 1, stride do
                local a = (i > bpp) and row[i - bpp] or 0
                row[i] = (row[i] + math.floor((a + prev[i]) / 2)) & 0xFF
            end
        elseif filter == 4 then

            for i = 1, stride do
                local a = (i > bpp) and row[i - bpp] or 0
                local b = prev[i]
                local c = (i > bpp) and prev[i - bpp] or 0
                row[i] = (row[i] + paeth(a, b, c)) & 0xFF
            end
        else
            error("Unknown PNG filter type: " .. filter)
        end

        if color_type == 6 then

            for i = 1, stride do
                out_rgba[#out_rgba + 1] = string.char(row[i])
            end
        elseif color_type == 2 then

            for i = 1, stride, 3 do
                out_rgba[#out_rgba + 1] = string.char(row[i], row[i+1], row[i+2], 255)
            end
        elseif color_type == 0 then

            for i = 1, stride do
                local g = row[i]
                out_rgba[#out_rgba + 1] = string.char(g, g, g, 255)
            end
        elseif color_type == 4 then

            for i = 1, stride, 2 do
                local g = row[i]
                out_rgba[#out_rgba + 1] = string.char(g, g, g, row[i+1])
            end
        elseif color_type == 3 then

            for i = 1, stride do
                local c = palette[row[i]]
                out_rgba[#out_rgba + 1] = string.char(c[1], c[2], c[3], c[4])
            end
        end

        prev = row
    end

    return {
        width  = width,
        height = height,
        data   = table.concat(out_rgba),
    }
end

function M.encode(width, height, rgba)
    assert(#rgba == width * height * 4,
        string.format("RGBA size mismatch: got %d, expected %d", #rgba, width*height*4))

    local PNG_SIG = "\137\080\078\071\013\010\026\010"

    local ihdr_data = u32be_str(width) .. u32be_str(height)
        .. "\8\6\0\0\0"   

    local row_bytes = width * 4
    local scanlines = {}
    for y = 0, height - 1 do
        scanlines[#scanlines + 1] = "\0"  

        scanlines[#scanlines + 1] = rgba:sub(y * row_bytes + 1, (y + 1) * row_bytes)
    end
    local raw_scanlines = table.concat(scanlines)

    local compressed = zlib.deflate(raw_scanlines)

    return PNG_SIG
        .. make_chunk("IHDR", ihdr_data)
        .. make_chunk("IDAT", compressed)
        .. make_chunk("IEND", "")
end

return M

end)
__bundle_register("zlib_lua", function(require, _LOADED, __bundle_register, __bundle_modules)

local M = {}

local band, bor, bxor, lshift, rshift

if bit32 then
    band   = bit32.band
    bor    = bit32.bor
    bxor   = bit32.bxor
    lshift = bit32.lshift
    rshift = bit32.rshift
elseif bit then
    band   = bit.band
    bor    = bit.bor
    bxor   = bit.bxor
    lshift = bit.lshift
    rshift = bit.rshift
else

    band   = function(a,b) return a & b end
    bor    = function(a,b) return a | b end
    bxor   = function(a,b) return a ~ b end
    lshift = function(a,b) return a << b end
    rshift = function(a,b) return (a & 0xFFFFFFFF) >> b end
end

local function adler32(data)
    local s1, s2 = 1, 0
    local BASE = 65521
    for i = 1, #data do
        s1 = (s1 + data:byte(i)) % BASE
        s2 = (s2 + s1)           % BASE
    end
    return s2 * 65536 + s1
end

local function new_bs(data)
    return { data=data, pos=1, buf=0, nbits=0 }
end

local function bs_fill(bs)
    local d, p, b, n = bs.data, bs.pos, bs.buf, bs.nbits
    while n < 24 and p <= #d do
        b = bor(b, lshift(d:byte(p), n))
        n = n + 8
        p = p + 1
    end
    bs.data = d   

    bs.pos  = p
    bs.buf  = b
    bs.nbits= n
end

local function bs_read(bs, n)
    if n == 0 then return 0 end
    if bs.nbits < n then bs_fill(bs) end
    local v  = band(bs.buf, lshift(1, n) - 1)
    bs.buf   = rshift(bs.buf, n)
    bs.nbits = bs.nbits - n
    return v
end

local function bs_read_bytes(bs, n)

    bs.pos   = bs.pos - math.floor(bs.nbits / 8)
    bs.buf   = 0
    bs.nbits = 0
    local s  = bs.data:sub(bs.pos, bs.pos + n - 1)
    bs.pos   = bs.pos + n
    return s
end

local function build_huff(lengths, nsym)
    if nsym == 0 then return {}, 0 end
    local max_len = 0
    for i = 1, nsym do
        if lengths[i] > max_len then max_len = lengths[i] end
    end
    if max_len == 0 then return {}, 0 end

    local count = {}
    for i = 0, max_len do count[i] = 0 end
    for i = 1, nsym do count[lengths[i]] = count[lengths[i]] + 1 end

    local next_code = {}
    local code = 0
    count[0] = 0
    for i = 1, max_len do
        code = lshift(code + count[i-1], 1)
        next_code[i] = code
    end

    local t  = {}
    local nc = {}
    for i = 0, max_len do nc[i] = next_code[i] or 0 end

    for sym = 0, nsym - 1 do
        local l = lengths[sym + 1]
        if l ~= 0 then
            local c  = nc[l]
            nc[l]    = nc[l] + 1

            local rev = 0
            local tmp = c
            for _ = 1, l do
                rev = lshift(rev, 1) + band(tmp, 1)
                tmp = rshift(tmp, 1)
            end
            t[rev + lshift(l, 16)] = sym
        end
    end
    return t, max_len
end

local function huff_sym(bs, t, ml)
    local code = 0
    for l = 1, ml do
        code = bor(code, lshift(bs_read(bs, 1), l - 1))
        local sym = t[code + lshift(l, 16)]
        if sym then return sym end
    end
    error("inflate: bad huffman code")
end

local FIXED_LL_T, FIXED_LL_ML, FIXED_DT_T, FIXED_DT_ML

local function ensure_fixed()
    if FIXED_LL_T then return end
    local ll = {}
    for i = 0,   143 do ll[i+1] = 8 end
    for i = 144, 255 do ll[i+1] = 9 end
    for i = 256, 279 do ll[i+1] = 7 end
    for i = 280, 287 do ll[i+1] = 8 end
    FIXED_LL_T, FIXED_LL_ML = build_huff(ll, 288)
    local dt = {}
    for i = 0, 31 do dt[i+1] = 5 end
    FIXED_DT_T, FIXED_DT_ML = build_huff(dt, 32)
end

local LEN_BASE = {
    3,4,5,6,7,8,9,10,11,13,15,17,19,23,27,31,
    35,43,51,59,67,83,99,115,131,163,195,227,258
}
local LEN_EXTRA = {
    0,0,0,0,0,0,0,0,1,1,1,1,2,2,2,2,
    3,3,3,3,4,4,4,4,5,5,5,5,0
}

local DIST_BASE = {
    1,2,3,4,5,7,9,13,17,25,33,49,65,97,129,193,
    257,385,513,769,1025,1537,2049,3073,4097,6145,
    8193,12289,16385,24577
}
local DIST_EXTRA = {
    0,0,0,0,1,1,2,2,3,3,4,4,5,5,6,6,
    7,7,8,8,9,9,10,10,11,11,12,12,13,13
}

local CLCL = {16,17,18,0,8,7,9,6,10,5,11,4,12,3,13,2,14,1,15}

local function inflate_block(bs, out, ll_t, ll_ml, dt_t, dt_ml)
    while true do
        local sym = huff_sym(bs, ll_t, ll_ml)
        if sym < 256 then
            out[#out + 1] = sym
        elseif sym == 256 then
            return           

        else
            local li   = sym - 256   

            local len  = LEN_BASE[li]  + bs_read(bs, LEN_EXTRA[li])
            local di   = huff_sym(bs, dt_t, dt_ml) + 1  

            local dist = DIST_BASE[di] + bs_read(bs, DIST_EXTRA[di])
            local base = #out - dist
            for j = 1, len do
                out[#out + 1] = out[base + j]
            end
        end
    end
end

local function read_dynamic(bs)
    local hlit  = bs_read(bs, 5) + 257
    local hdist = bs_read(bs, 5) + 1
    local hclen = bs_read(bs, 4) + 4

    local cl = {}
    for i = 0, 18 do cl[i+1] = 0 end
    for i = 1, hclen do
        cl[CLCL[i] + 1] = bs_read(bs, 3)
    end
    local cl_t, cl_ml = build_huff(cl, 19)

    local all = {}
    while #all < hlit + hdist do
        local sym = huff_sym(bs, cl_t, cl_ml)
        if sym <= 15 then
            all[#all+1] = sym
        elseif sym == 16 then
            local rep  = bs_read(bs, 2) + 3
            local last = all[#all]
            for _ = 1, rep do all[#all+1] = last end
        elseif sym == 17 then
            for _ = 1, bs_read(bs, 3)  + 3  do all[#all+1] = 0 end
        elseif sym == 18 then
            for _ = 1, bs_read(bs, 7)  + 11 do all[#all+1] = 0 end
        end
    end

    local ll_len = {}
    local dt_len = {}
    for i = 1, hlit  do ll_len[i] = all[i]         end
    for i = 1, hdist do dt_len[i] = all[hlit + i]  end

    local ll_t, ll_ml = build_huff(ll_len, hlit)
    local dt_t, dt_ml = build_huff(dt_len, hdist)
    return ll_t, ll_ml, dt_t, dt_ml
end

-- Decompress a zlib stream (RFC 1950) to a raw byte string.

-- @param zlib_data string  zlib-compressed data

-- @return string           decompressed data

function M.inflate(zlib_data)

    local bs  = new_bs(zlib_data:sub(3))
    local out = {}
    ensure_fixed()

    local bfinal = 0
    while bfinal == 0 do
        bfinal      = bs_read(bs, 1)
        local btype = bs_read(bs, 2)

        if btype == 0 then

            local raw = bs_read_bytes(bs, 0)   

            local lo  = bs.data:byte(bs.pos)
            local hi  = bs.data:byte(bs.pos + 1)
            local len = lo + hi * 256
            bs.pos    = bs.pos + 4              

            local chunk = bs.data:sub(bs.pos, bs.pos + len - 1)
            bs.pos    = bs.pos + len
            for i = 1, #chunk do out[#out+1] = chunk:byte(i) end

        elseif btype == 1 then
            inflate_block(bs, out, FIXED_LL_T, FIXED_LL_ML, FIXED_DT_T, FIXED_DT_ML)

        elseif btype == 2 then
            local ll_t, ll_ml, dt_t, dt_ml = read_dynamic(bs)
            inflate_block(bs, out, ll_t, ll_ml, dt_t, dt_ml)

        else
            error("inflate: invalid block type 3")
        end
    end

    local chars = {}
    for i = 1, #out do chars[i] = string.char(out[i]) end
    return table.concat(chars)
end

-- Wrap raw bytes in a valid zlib stream using stored (uncompressed) blocks.

-- Output is larger than the input by ~6 bytes per 64 KB chunk, but is

-- accepted by any standard zlib decompressor including inflate() above.

-- @param data string  raw bytes to wrap

-- @return string      valid zlib stream

function M.deflate(data)
    local out   = {}
    local len   = #data
    local CHUNK = 65535

    out[#out+1] = "\120\001"

    local pos = 1
    while pos <= len do
        local chunk_end = math.min(pos + CHUNK - 1, len)
        local chunk     = data:sub(pos, chunk_end)
        local clen      = #chunk
        local final     = (chunk_end == len) and 1 or 0

        out[#out+1] = string.char(final)

        out[#out+1] = string.char(band(clen, 0xFF), rshift(clen, 8))

        local nlen = bxor(clen, 0xFFFF)
        out[#out+1] = string.char(band(nlen, 0xFF), rshift(nlen, 8))

        out[#out+1] = chunk
        pos = chunk_end + 1
    end

    local ck = adler32(data)
    out[#out+1] = string.char(
        band(rshift(ck, 24), 0xFF),
        band(rshift(ck, 16), 0xFF),
        band(rshift(ck,  8), 0xFF),
        band(ck, 0xFF)
    )

    return table.concat(out)
end

return M

end)
return __bundle_require("__root")
