#!/usr/bin/env lua

-- Prompt user to paste logs
io.stderr:write("\nPlease paste the device output, then press Ctrl-D\n\n")
io.stderr:flush()

-- Open output files
local activation_hex = io.open("/tmp/activation_code.hex", "w")
local intrinsic_hex  = io.open("/tmp/intrinsic_key.hex", "w")
local activation_bin = io.open("/tmp/activation_code.bin", "wb")
local intrinsic_bin  = io.open("/tmp/intrinsic_key.bin", "wb")

if not activation_hex or not intrinsic_hex or not activation_bin or not intrinsic_bin then
    io.stderr:write("Error: Failed to open output files.\n")
    os.exit(1)
end

-- State
local capturing_activation = false
local capturing_intrinsic = false

-- Extract byte values from hex column and write to files
local function extract_bytes_and_write(line, hex_f, bin_f)
    local hex_part = line:match("^[^|]+") or ""
    for byte in hex_part:gmatch("%x%x") do
        hex_f:write(byte .. " ")
        bin_f:write(string.char(tonumber(byte, 16)))
    end
    hex_f:write("\n")
end

-- Read from stdin
for line in io.lines() do
    line = line:gsub("^%s+", ""):gsub("%s+$", "")  -- trim

    if line:find("Activation Code") then
        capturing_activation = true
        capturing_intrinsic = false
        goto continue
    end

    if line:find("Intrinsic key code") then
        capturing_intrinsic = true
        capturing_activation = false
        goto continue
    end

    -- Stop capturing on new log line (timestamp prefix)
    if line:match("^%[%d%d:%d%d:%d%d") then
        capturing_activation = false
        capturing_intrinsic = false
    end

    -- Only write if in hex dump block
    if capturing_activation then
        extract_bytes_and_write(line, activation_hex, activation_bin)
    elseif capturing_intrinsic then
        extract_bytes_and_write(line, intrinsic_hex, intrinsic_bin)
    end

    ::continue::
end

-- Close output files
activation_hex:close()
intrinsic_hex:close()
activation_bin:close()
intrinsic_bin:close()

-- Validate file sizes
local function check_size(path, expected)
    local f = io.open(path, "rb")
    if not f then return false end
    local size = f:seek("end")
    f:close()
    return size == expected
end

if not check_size("/tmp/activation_code.bin", 1192) then
    io.stderr:write("Error: Activation code is not 1192 bytes.\n")
    os.exit(1)
end

if not check_size("/tmp/intrinsic_key.bin", 148) then
    io.stderr:write("Error: Intrinsic key is not 148 bytes. Check your PUF_KEY_SIZE value\n")
    os.exit(1)
end

-- Final status messages
io.stderr:write("\nExtraction complete.\r\n")
io.stderr:write("Activation code hex saved to /tmp/activation_code.hex\r\n")
io.stderr:write("Activation code bin saved to /tmp/activation_code.bin\r\n")
io.stderr:write("Intrinsic key hex saved to /tmp/intrinsic_key.hex\r\n")
io.stderr:write("Intrinsic key bin saved to /tmp/intrinsic_key.bin\r\n")

os.exit(0)
