-- liu_code_hint_filter.lua
-- 嘸蝦米實用版：在正常輸入時為前段候選補精簡字根提示。
-- 只顯示主碼，避免完整反查資訊過度干擾。

local liu_data = require("liu_data")

local MAX_HINTED_CANDIDATES = 9

local function should_bypass(context)
    local input = context.input or ""
    if input == "" then
        return true
    end
    if context:get_option("ascii_mode") or context:get_option("liu_w2c") then
        return true
    end

    local first = input:sub(1, 1)
    local first_two = input:sub(1, 2)
    if first == ";" or first == "`" or first_two == "';" or first_two == ",," then
        return true
    end
    return false
end

local function parse_primary_code(raw_codes)
    if not raw_codes or raw_codes == "" then
        return nil
    end

    raw_codes = raw_codes:gsub("\\⟩", "\1")
    for code in raw_codes:gmatch("⟨([^⟩]+)⟩") do
        code = code:gsub("\1", "⟩")
        if not code:find("^", 1, true) then
            return code:lower()
        end
    end
    return nil
end

local function build_phrase_code_hint(text, code_dict)
    local chars = {}
    for _, codepoint in utf8.codes(text) do
        chars[#chars + 1] = utf8.char(codepoint)
    end

    if #chars == 0 or #chars > 4 then
        return nil
    end

    local parts = {}
    for _, char in ipairs(chars) do
        local code = parse_primary_code(code_dict[char])
        if not code then
            return nil
        end
        parts[#parts + 1] = code
    end

    return table.concat(parts, "·")
end

local function append_hint(comment, hint)
    local base = tostring(comment or "")
    if base:find("⟨", 1, true) then
        return base
    end

    if base == "" then
        return "⟨" .. hint .. "⟩"
    end

    return base .. " ⟨" .. hint .. "⟩"
end

local function filter(input, env)
    local context = env.engine.context
    if should_bypass(context) then
        for cand in input:iter() do
            yield(cand)
        end
        return
    end

    local code_dict = liu_data.get_w2c_data()
    local count = 0

    for cand in input:iter() do
        count = count + 1
        if count > MAX_HINTED_CANDIDATES then
            yield(cand)
        else
            local text = cand.text or ""
            local text_len = utf8.len(text)
            local hint = nil

            if text_len == 1 then
                hint = parse_primary_code(code_dict[text])
            elseif text_len and text_len > 1 then
                hint = build_phrase_code_hint(text, code_dict)
            end

            if hint and hint ~= "" then
                yield(cand:to_shadow_candidate(cand.type, cand.text, append_hint(cand.comment, hint)))
            else
                yield(cand)
            end
        end
    end
end

return filter

