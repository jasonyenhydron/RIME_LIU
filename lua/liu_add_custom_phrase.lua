-- liu_add_custom_phrase.lua
-- 顯示 ,, 加詞模式的即時提示，實際寫入由 processor 在按 Enter 時完成。

local RESERVED_COMMANDS = {
    [",,h"] = true,
    [",,x"] = true,
    [",,sp"] = true,
    [",,sf"] = true,
}

local function is_reserved_command(input)
    return RESERVED_COMMANDS[input] == true
end

local function translator(input, seg, env)
    local full_input = env.engine.context.input or ""

    if is_reserved_command(full_input) then
        return
    end

    if full_input == ",," then
        yield(Candidate("add_phrase_hint", seg.start, seg._end, "《造詞》請輸入字根（5碼內）", "例如：,,abc 後按 Enter"))
        return
    end

    local code = full_input:match("^,,([a-z]{1,5})$")
    if code then
        local cand = Candidate("add_phrase_preview", seg.start, seg._end, "《造詞》" .. code, "按 Enter 進入詞句收集")
        yield(cand)
    end
end

return translator
