-- liu_candidate_ellipsis_filter.lua
-- 浮動視窗候選顯示過長時，只縮短顯示文字，不改變實際上屏內容。
-- 這裡使用 shadow candidate 包住原候選，讓使用者仍可選到完整詞句。

local MAX_VISIBLE_CHARS = 5
local ELLIPSIS = "..."

local function utf8_length(text)
    local count = 0
    for _ in utf8.codes(text) do
        count = count + 1
    end
    return count
end

local function utf8_sub(text, max_chars)
    if max_chars <= 0 then
        return ""
    end

    local result = {}
    local count = 0
    for _, code in utf8.codes(text) do
        count = count + 1
        if count > max_chars then
            break
        end
        result[#result + 1] = utf8.char(code)
    end
    return table.concat(result)
end

local function should_truncate(text)
    if not text or text == "" then
        return false
    end
    return utf8_length(text) > MAX_VISIBLE_CHARS
end

local function filter(input, env)
    for cand in input:iter() do
        local text = cand.text or ""
        if should_truncate(text) then
            local shortened = utf8_sub(text, MAX_VISIBLE_CHARS) .. ELLIPSIS
            yield(cand:to_shadow_candidate(cand.type, shortened, cand.comment or ""))
        else
            yield(cand)
        end
    end
end

return filter
