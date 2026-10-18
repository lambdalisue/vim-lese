-- fzf's extended search in pure Lua: whitespace-separated terms, each fuzzy
-- unless prefixed with ' ^ ! or suffixed with $, and `|` between terms for
-- OR. Fuzzy terms are placed and scored as fzf's v1 algorithm does.

local define = require("lese.define")

local byte, find, sub, gsub, char = string.byte, string.find, string.sub, string.gsub, string.char

local SCORE_MATCH = 16
local SCORE_GAP_START = -3
local SCORE_GAP_EXTENSION = -1
local BONUS_BOUNDARY = 8
local BONUS_NONWORD = 8
local BONUS_CAMEL = 7
local BONUS_CONSECUTIVE = 4
local BONUS_FIRST_CHAR_MULTIPLIER = 2

local NONWORD, LOWER, UPPER, NUMBER, LETTER = 0, 1, 2, 3, 4

-- Indexed by a byte. A multibyte character counts as a letter by its lead byte.
local CLASS = {}
-- The length in bytes of the UTF-8 character a byte starts.
local CHAR_LENGTH = {}
for b = 0, 255 do
  if b >= 97 and b <= 122 then
    CLASS[b] = LOWER
  elseif b >= 65 and b <= 90 then
    CLASS[b] = UPPER
  elseif b >= 48 and b <= 57 then
    CLASS[b] = NUMBER
  elseif b >= 128 then
    CLASS[b] = LETTER
  else
    CLASS[b] = NONWORD
  end
  if b >= 240 and b <= 247 then
    CHAR_LENGTH[b] = 4
  elseif b >= 224 and b <= 239 then
    CHAR_LENGTH[b] = 3
  elseif b >= 192 and b <= 223 then
    CHAR_LENGTH[b] = 2
  else
    CHAR_LENGTH[b] = 1
  end
end

-- PUC Lua's string.lower follows the C locale, which may fold the bytes of a
-- UTF-8 character (macOS does) and break byte offsets. Use it only when it
-- leaves every non-ASCII byte alone; the gsub fallback is several times slower.
local ASCII_LOWER = {}
for b = 65, 90 do
  ASCII_LOWER[char(b)] = char(b + 32)
end

local fold
do
  local high = {}
  for b = 128, 255 do
    high[#high + 1] = char(b)
  end
  local probe = table.concat(high)
  if string.lower(probe) == probe then
    fold = string.lower
  else
    fold = function(s)
      if find(s, "[A-Z]") then
        return (gsub(s, "[A-Z]", ASCII_LOWER))
      end
      return s
    end
  end
end

local SPACE = " \t\r\n\f\v"
local LEADING_SPACE = "^[" .. SPACE .. "]*"
local TRAILING_SPACE = "[" .. SPACE .. "]*$"

local function bonus_for(prev_class, class)
  if prev_class == NONWORD and class ~= NONWORD then
    return BONUS_BOUNDARY
  elseif (prev_class == LOWER and class == UPPER) or (prev_class ~= NUMBER and class == NUMBER) then
    return BONUS_CAMEL
  elseif class == NONWORD then
    return BONUS_NONWORD
  end
  return 0
end

local function class_before(text, i)
  if i == 1 then
    return NONWORD
  end
  return CLASS[byte(text, i - 1)]
end

---@class lese.builtin.matcher.fzf.Term
---@field kind "fuzzy"|"exact"|"prefix"|"suffix"|"equal"
---@field inverse boolean
---@field text string             -- folded unless case_sensitive
---@field chars string[]          -- the UTF-8 characters of text
---@field firsts integer[]        -- the first byte of each character
---@field case_sensitive boolean

---@param text string
---@param case_sensitive boolean
---@return lese.builtin.matcher.fzf.Term?
local function parse_term(text, case_sensitive)
  local kind, inverse = "fuzzy", false
  if sub(text, 1, 1) == "!" then
    kind, inverse, text = "exact", true, sub(text, 2)
  end
  if text ~= "$" and sub(text, -1) == "$" then
    kind, text = "suffix", sub(text, 1, -2)
  end
  -- As in fzf, ' flips exactness and wins over a trailing $.
  if sub(text, 1, 1) == "'" then
    kind, text = (kind == "fuzzy" and not inverse) and "exact" or "fuzzy", sub(text, 2)
  elseif sub(text, 1, 1) == "^" then
    kind, text = kind == "suffix" and "equal" or "prefix", sub(text, 2)
  end
  if text == "" then
    return nil
  end
  if not case_sensitive then
    text = fold(text)
  end
  local chars, firsts = {}, {}
  for c in string.gmatch(text, "[%z\1-\127\192-\247][\128-\191]*") do
    chars[#chars + 1] = c
    firsts[#firsts + 1] = byte(c)
  end
  return {
    kind = kind,
    inverse = inverse,
    text = text,
    chars = chars,
    firsts = firsts,
    case_sensitive = case_sensitive,
  }
end

---@param query string
---@param casing "smart"|"respect"|"ignore"
---@return lese.builtin.matcher.fzf.Term[][] groups every group must match; a group matches when any term does
local function parse_query(query, casing)
  local groups = {}
  local join = false
  for word in string.gmatch(query, "[^" .. SPACE .. "]+") do
    if word == "|" then
      join = #groups > 0
    else
      local case_sensitive = casing == "respect"
        or (casing == "smart" and find(word, "[A-Z]") ~= nil)
      local term = parse_term(word, case_sensitive)
      if term then
        if join then
          local group = groups[#groups]
          group[#group + 1] = term
        else
          groups[#groups + 1] = { term }
        end
      end
      join = false
    end
  end
  return groups
end

-- Walk the characters of text[s..e], matching the term's characters greedily,
-- and score the walk as fzf does. Matched characters go to `starts`/`lengths`.
local function score_window(text, target, s, e, term, starts, lengths)
  local chars, firsts = term.chars, term.firsts
  local n = #chars
  local score, consecutive, first_bonus, in_gap = 0, 0, 0, false
  local prev_class = class_before(text, s)
  local k = 1
  local i = s
  while i <= e and k <= n do
    local b = byte(target, i)
    local len = CHAR_LENGTH[b]
    local class = CLASS[byte(text, i)]
    if b == firsts[k] and (len == 1 or sub(target, i, i + len - 1) == chars[k]) then
      starts[#starts + 1] = i
      lengths[#lengths + 1] = len
      score = score + SCORE_MATCH
      local bonus = bonus_for(prev_class, class)
      if consecutive == 0 then
        first_bonus = bonus
      else
        if bonus == BONUS_BOUNDARY then
          first_bonus = bonus
        end
        bonus = math.max(bonus, first_bonus, BONUS_CONSECUTIVE)
      end
      if k == 1 then
        score = score + bonus * BONUS_FIRST_CHAR_MULTIPLIER
      else
        score = score + bonus
      end
      in_gap = false
      consecutive = consecutive + 1
      k = k + 1
    else
      score = score + (in_gap and SCORE_GAP_EXTENSION or SCORE_GAP_START)
      in_gap = true
      consecutive = 0
      first_bonus = 0
    end
    prev_class = class
    i = i + len
  end
  return score
end

-- fzf v1: find the characters left to right, then walk back from the last
-- one to the latest start that still holds them all, and score that window.
local function match_fuzzy(text, target, term, starts, lengths)
  local chars, firsts = term.chars, term.firsts
  local n = #chars
  local first, pos = nil, 1
  for k = 1, n do
    local s, e = find(target, chars[k], pos, true)
    if not s then
      return nil
    end
    first = first or s
    pos = e + 1
  end
  local last = pos - 1
  local i = last
  for k = n, 1, -1 do
    local c, b = chars[k], firsts[k]
    local len = #c
    i = i - len + 1
    while i >= first do
      if byte(target, i) == b and (len == 1 or sub(target, i, i + len - 1) == c) then
        break
      end
      i = i - 1
    end
    if k > 1 then
      i = i - 1
    end
  end
  return score_window(text, target, i, last, term, starts, lengths)
end

local function match_exact(text, target, term, starts, lengths)
  local needle = term.text
  local best, best_bonus = nil, -1
  local init = 1
  while true do
    local s = find(target, needle, init, true)
    if not s then
      break
    end
    local bonus = bonus_for(class_before(text, s), CLASS[byte(text, s)])
    if bonus > best_bonus then
      best, best_bonus = s, bonus
      if bonus >= BONUS_BOUNDARY then
        break
      end
    end
    init = s + 1
  end
  if not best then
    return nil
  end
  return score_window(text, target, best, best + #needle - 1, term, starts, lengths)
end

local function match_prefix(text, target, term, starts, lengths)
  local needle = term.text
  local s = 1
  if not find(needle, "^[" .. SPACE .. "]") then
    s = select(2, find(target, LEADING_SPACE)) + 1
  end
  local e = s + #needle - 1
  if sub(target, s, e) ~= needle then
    return nil
  end
  return score_window(text, target, s, e, term, starts, lengths)
end

local function match_suffix(text, target, term, starts, lengths)
  local needle = term.text
  local e = #target
  if not find(needle, "[" .. SPACE .. "]$") then
    e = find(target, TRAILING_SPACE) - 1
  end
  local s = e - #needle + 1
  if s < 1 or sub(target, s, e) ~= needle then
    return nil
  end
  return score_window(text, target, s, e, term, starts, lengths)
end

local function match_equal(text, target, term, starts, lengths)
  local s = select(2, find(target, LEADING_SPACE)) + 1
  local e = find(target, TRAILING_SPACE) - 1
  if sub(target, s, e) ~= term.text then
    return nil
  end
  return score_window(text, target, s, e, term, starts, lengths)
end

local MATCH = {
  fuzzy = match_fuzzy,
  exact = match_exact,
  prefix = match_prefix,
  suffix = match_suffix,
  equal = match_equal,
}

-- Score `text` against every group, or return nil when a group fails.
local function score_item(text, groups, starts, lengths)
  local folded
  local total = 0
  for g = 1, #groups do
    local group = groups[g]
    local matched = false
    for t = 1, #group do
      local term = group[t]
      local target = text
      if not term.case_sensitive then
        folded = folded or fold(text)
        target = folded
      end
      if term.inverse then
        local mark = #starts
        if MATCH[term.kind](text, target, term, starts, lengths) == nil then
          matched = true
        end
        for j = #starts, mark + 1, -1 do
          starts[j], lengths[j] = nil, nil
        end
      else
        local score = MATCH[term.kind](text, target, term, starts, lengths)
        if score then
          total = total + score
          matched = true
        end
      end
      if matched then
        break
      end
    end
    if not matched then
      return nil
    end
  end
  return total
end

-- Stands for the identity order when the matched characters already ascend.
local ASCENDING = setmetatable({}, {
  __index = function(_, i)
    return i
  end,
})

-- Turn matched characters into decorations, joining adjacent ones.
local function decorate(item, starts, lengths)
  local decorations = {}
  for i, d in ipairs(item.decorations or {}) do
    decorations[i] = d
  end
  local n = #starts
  if n > 0 then
    local order = ASCENDING
    for i = 2, n do
      if starts[i] < starts[i - 1] then
        order = {}
        for j = 1, n do
          order[j] = j
        end
        table.sort(order, function(a, b)
          return starts[a] < starts[b]
        end)
        break
      end
    end
    local s = starts[order[1]]
    local e = s + lengths[order[1]] - 1
    for j = 2, n do
      local i = order[j]
      local ns = starts[i]
      local ne = ns + lengths[i] - 1
      if ns <= e + 1 then
        if ne > e then
          e = ne
        end
      else
        decorations[#decorations + 1] = { column = s, length = e - s + 1 }
        s, e = ns, ne
      end
    end
    decorations[#decorations + 1] = { column = s, length = e - s + 1 }
  end
  local copy = {}
  for k, v in pairs(item) do
    copy[k] = v
  end
  copy.decorations = decorations
  return copy
end

local function trimmed_length(value)
  local s = select(2, find(value, LEADING_SPACE)) + 1
  local e = find(value, TRAILING_SPACE) - 1
  return e >= s and e - s + 1 or 0
end

-- Sorting plain numbers with the default comparison is several times faster
-- than calling a Lua comparator, so score (descending), trimmed length and
-- input index are packed into one exact double: 19 + 12 + 21 bits < 2^53.
local INDEX_SPAN = 2 ^ 21
local LENGTH_SPAN = 2 ^ 12
local SCORE_LIMIT = 2 ^ 18

local function rank_key(score, length, index)
  if score >= SCORE_LIMIT then
    score = SCORE_LIMIT - 1
  elseif score <= -SCORE_LIMIT then
    score = -SCORE_LIMIT + 1
  end
  if length >= LENGTH_SPAN then
    length = LENGTH_SPAN - 1
  end
  return (-score * LENGTH_SPAN + length) * INDEX_SPAN + index
end

---@class lese.builtin.matcher.FzfOptions
---@field case_sensitive? boolean -- always respect case; wins over ignore_case
---@field ignore_case? boolean    -- always ignore case; by default a term with an upper-case letter respects case
---@field sort? boolean           -- order by score (default true); false keeps the input order

---@param opts? lese.builtin.matcher.FzfOptions
---@return lese.Matcher
return function(opts)
  opts = opts or {}
  local casing = opts.case_sensitive and "respect" or (opts.ignore_case and "ignore" or "smart")
  local sort = opts.sort ~= false
  return define.matcher({
    name = "builtin.matcher.fzf",
    match = function(ctx, params)
      local items = params.items
      local groups = parse_query(params.query, casing)
      if #groups == 0 then
        ctx:emit(items)
        return
      end
      -- Past INDEX_SPAN items the key no longer holds the index.
      local ranking = sort and #items < INDEX_SPAN
      local found, keys = {}, {}
      local starts, lengths = {}, {}
      for i = 1, #items do
        if i % 64 == 0 then
          ctx:checkpoint()
        end
        local item = items[i]
        for j = #starts, 1, -1 do
          starts[j], lengths[j] = nil, nil
        end
        local score = score_item(item.value, groups, starts, lengths)
        if score then
          local n = #found + 1
          found[n] = decorate(item, starts, lengths)
          if ranking then
            keys[n] = rank_key(score, trimmed_length(item.value), n)
          end
        end
      end
      if ranking then
        table.sort(keys)
        local ordered = {}
        for i = 1, #keys do
          ordered[i] = found[keys[i] % INDEX_SPAN]
        end
        found = ordered
      end
      -- Handing everything over at once leaves whoever receives the items
      -- (the contract checks among them) without a checkpoint.
      for first = 1, #found, 256 do
        local chunk = {}
        for i = first, math.min(first + 255, #found) do
          chunk[#chunk + 1] = found[i]
        end
        ctx:emit(chunk)
        ctx:checkpoint()
      end
    end,
  })
end
