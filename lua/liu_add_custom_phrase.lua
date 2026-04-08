-- liu_add_custom_phrase.lua
-- 顯示 ,,add 指令的即時提示，實際寫入由 processor 在按 Enter 時完成。

local function parse_command(input)
    local code, phrase = input:match("^,,add%s+([^%s]+)%s+(.+)$")
    if not code or not phrase then
        return nil
    end
    return code, phrase
end

local function translator(input, seg, env)
    local full_input = env.engine.context.input or ""

    if full_input == ",,add" then
        yield(Candidate("add_phrase_hint", seg.start, seg._end, "請輸入空白後接字根", "例如：,,add abc"))
        return
    end

    if full_input:match("^,,add%s+[^%s]*$") then
        yield(Candidate("add_phrase_hint", seg.start, seg._end, "請再輸入空白後接詞句", "例如：,,add abc 你好嗎？"))
        return
    end

    local code, phrase = parse_command(full_input)
    if code and phrase then
        local cand = Candidate("add_phrase_preview", seg.start, seg._end, phrase, "按 Enter 加入 ⇐ " .. code)
        yield(cand)
    end
end

return translator
