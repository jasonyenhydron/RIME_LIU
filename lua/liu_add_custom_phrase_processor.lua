-- liu_add_custom_phrase_processor.lua
-- 指令格式：,,add 字根 詞句
-- 用法：
-- 1. 輸入 ,,add
-- 2. 按空白輸入字根，再按空白輸入詞句
-- 3. 按 Enter 寫入 openxiami_CustomWord.dict.yaml，並直接上屏該詞句

local custom_word_module = require("liu_custom_word_translator")

local PREFIX = ",,add"

local function parse_command(input)
    local code, phrase = input:match("^,,add%s+([^%s]+)%s+(.+)$")
    if not code or not phrase then
        return nil
    end
    return {
        code = code,
        phrase = phrase,
    }
end

local function is_add_mode(input)
    return input == PREFIX or input:match("^,,add%s") ~= nil
end

local function processor(key, env)
    if key:release() then
        return 2
    end

    local engine = env.engine
    local context = engine.context
    local input = context.input or ""
    local key_repr = key:repr()

    if not is_add_mode(input) then
        return 2
    end

    if key_repr == "Escape" then
        context:clear()
        return 1
    end

    if key_repr == "space" then
        context:push_input(" ")
        return 1
    end

    if key_repr == "Return" or key_repr == "KP_Enter" then
        local command = parse_command(input)
        if not command then
            return 1
        end

        local ok, _message, normalized_phrase = custom_word_module.add_custom_entry(command.phrase, command.code)
        if ok then
            context:clear()
            engine:commit_text(normalized_phrase)
            return 1
        end
        return 1
    end

    return 2
end

return processor
