-- UTF-8 and display width without the editor, so what the picker shows is
-- computed the same way on every host. Widths follow East Asian Width: wide
-- and fullwidth characters and pictographic emoji take two cells.

local M = {}

local byte, sub = string.byte, string.sub

-- Ranges of code points two cells wide, sorted, as { first, last }.
local WIDE = {
  { 0x1100, 0x115F },
  { 0x231A, 0x231B },
  { 0x2329, 0x232A },
  { 0x23E9, 0x23EC },
  { 0x23F0, 0x23F0 },
  { 0x23F3, 0x23F3 },
  { 0x25FD, 0x25FE },
  { 0x2614, 0x2615 },
  { 0x2648, 0x2653 },
  { 0x267F, 0x267F },
  { 0x2693, 0x2693 },
  { 0x26A1, 0x26A1 },
  { 0x26AA, 0x26AB },
  { 0x26BD, 0x26BE },
  { 0x26C4, 0x26C5 },
  { 0x26CE, 0x26CE },
  { 0x26D4, 0x26D4 },
  { 0x26EA, 0x26EA },
  { 0x26F2, 0x26F3 },
  { 0x26F5, 0x26F5 },
  { 0x26FA, 0x26FA },
  { 0x26FD, 0x26FD },
  { 0x2705, 0x2705 },
  { 0x270A, 0x270B },
  { 0x2728, 0x2728 },
  { 0x274C, 0x274C },
  { 0x274E, 0x274E },
  { 0x2753, 0x2755 },
  { 0x2757, 0x2757 },
  { 0x2795, 0x2797 },
  { 0x27B0, 0x27B0 },
  { 0x27BF, 0x27BF },
  { 0x2B1B, 0x2B1C },
  { 0x2B50, 0x2B50 },
  { 0x2B55, 0x2B55 },
  { 0x2E80, 0x303E },
  { 0x3041, 0x33FF },
  { 0x3400, 0x4DBF },
  { 0x4E00, 0x9FFF },
  { 0xA000, 0xA4CF },
  { 0xA960, 0xA97F },
  { 0xAC00, 0xD7A3 },
  { 0xF900, 0xFAFF },
  { 0xFE10, 0xFE19 },
  { 0xFE30, 0xFE6F },
  { 0xFF00, 0xFF60 },
  { 0xFFE0, 0xFFE6 },
  { 0x16FE0, 0x16FE4 },
  { 0x17000, 0x18CFF },
  { 0x1B000, 0x1B2FF },
  { 0x1F004, 0x1F004 },
  { 0x1F0CF, 0x1F0CF },
  { 0x1F18E, 0x1F18E },
  { 0x1F191, 0x1F19A },
  { 0x1F200, 0x1F251 },
  { 0x1F300, 0x1F64F },
  { 0x1F680, 0x1F6FF },
  { 0x1F7E0, 0x1F7EB },
  { 0x1F90C, 0x1F9FF },
  { 0x1FA70, 0x1FAFF },
  { 0x20000, 0x2FFFD },
  { 0x30000, 0x3FFFD },
}

---Decode the UTF-8 character starting at byte `i`. Invalid bytes decode as
---themselves, one byte long.
---@param s string
---@param i integer
---@return integer codepoint
---@return integer length in bytes
function M.decode(s, i)
  local c = byte(s, i)
  if c < 0x80 then
    return c, 1
  end
  local n, cp
  if c >= 0xF0 and c < 0xF8 then
    n, cp = 4, c - 0xF0
  elseif c >= 0xE0 then
    n, cp = 3, c - 0xE0
  elseif c >= 0xC0 then
    n, cp = 2, c - 0xC0
  else
    return c, 1
  end
  for k = 1, n - 1 do
    local cc = byte(s, i + k)
    if not cc or cc < 0x80 or cc >= 0xC0 then
      return c, 1
    end
    cp = cp * 64 + (cc - 0x80)
  end
  return cp, n
end

---The number of screen cells a code point takes.
---@param cp integer
---@return integer
function M.codepoint_width(cp)
  if cp < 0x1100 then
    if cp < 0x20 or (cp >= 0x7F and cp < 0xA0) then
      return 0
    end
    return 1
  end
  local low, high = 1, #WIDE
  while low <= high do
    local mid = math.floor((low + high) / 2)
    local range = WIDE[mid]
    if cp < range[1] then
      high = mid - 1
    elseif cp > range[2] then
      low = mid + 1
    else
      return 2
    end
  end
  return 1
end

---The number of screen cells `s` takes.
---@param s string
---@return integer
function M.width(s)
  local w, i, n = 0, 1, #s
  while i <= n do
    local c = byte(s, i)
    if c < 0x80 then
      if c >= 0x20 and c ~= 0x7F then
        w = w + 1
      end
      i = i + 1
    else
      local cp, len = M.decode(s, i)
      w = w + M.codepoint_width(cp)
      i = i + len
    end
  end
  return w
end

---The characters of `s`, each as { text, width }.
---@param s string
---@return { [1]: string, [2]: integer }[]
function M.chars(s)
  local out, i, n = {}, 1, #s
  while i <= n do
    local cp, len = M.decode(s, i)
    out[#out + 1] = { sub(s, i, i + len - 1), M.codepoint_width(cp) }
    i = i + len
  end
  return out
end

---Cut `s` to at most `width` cells, padding with spaces up to exactly `width`
---when `pad` is set. A wide character that would straddle the edge becomes a
---space.
---@param s string
---@param width integer
---@param pad? boolean
---@return string
function M.fit(s, width, pad)
  local parts, used = {}, 0
  local i, n = 1, #s
  while i <= n do
    local cp, len = M.decode(s, i)
    local w = M.codepoint_width(cp)
    if used + w > width then
      break
    end
    parts[#parts + 1] = sub(s, i, i + len - 1)
    used = used + w
    i = i + len
  end
  local out = table.concat(parts)
  if pad and used < width then
    out = out .. string.rep(" ", width - used)
  end
  return out
end

---The byte index just past the character that starts at byte `i`.
---@param s string
---@param i integer
---@return integer
function M.next(s, i)
  local _, len = M.decode(s, i)
  return i + len
end

return M
