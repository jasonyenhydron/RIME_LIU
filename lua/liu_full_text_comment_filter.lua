-- liu_full_text_comment_filter.lua
-- 當候選文字超過指定長度時，把完整字詞補到 comment，
-- 讓小狼毫使用內建縮寫顯示時，仍可在候選右側看到完整內容。

local MAX_VISIBLE_CHARS = 5
local FULL_TEXT_MARKER = "〔全文〕"

local function utf8_length(text)
    local count = 0
    for _ in utf8.codes(text or "") do
        count = count + 1
    end
    return count
end

local function should_annotate(text)
    return text and text ~= "" and utf8_length(text) > MAX_VISIBLE_CHARS
end

local function build_comment(original_comment, full_text)
    local comment = original_comment or ""
    local marker_text = FULL_TEXT_MARKER .. full_text

    if comment:find(marker_text, 1, true) then
        return comment
    end

    if comment == "" then
        return marker_text
    end

    return comment .. " " .. marker_text
end

local function filter(input, env)
    for cand in input:iter() do
        local text = cand.text or ""
        if should_annotate(text) then
            local new_comment = build_comment(cand.comment, text)
            yield(cand:to_shadow_candidate(cand.type, cand.text, new_comment))
        else
            yield(cand)
        end
    end
end

return filter
