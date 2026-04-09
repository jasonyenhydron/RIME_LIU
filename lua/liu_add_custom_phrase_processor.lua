-- liu_add_custom_phrase_processor.lua
-- 兩段式加詞：
-- 1. 輸入 ,, + 字根（5碼內），按 Enter
-- 2. 接著正常輸入中文詞句（100字內）
-- 3. 完成後在空白輸入狀態按 Enter，即寫入 openxiami_CustomWord.dict.yaml

local custom_word_module = require("liu_custom_word_translator")

local runtime_state = {
    phase = nil,
    code = nil,
    phrase = "",
}

local RESERVED_COMMANDS = {
    [",,h"] = true,
    [",,x"] = true,
    [",,sp"] = true,
    [",,sf"] = true,
    [",,en"] = true,
    [",,zh"] = true,
    [",,wc"] = true,
    [",,ec"] = true,
}

local function utf8_length(text)
    local count = 0
    for _ in utf8.codes(text or "") do
        count = count + 1
    end
    return count
end

local function is_reserved_command(input)
    return RESERVED_COMMANDS[input] == true
end

local function is_code_mode_input(input)
    if not input or input == "" or is_reserved_command(input) then
        return false
    end
    return input:match("^,,[a-z]{1,5}$") ~= nil
end

local function clear_runtime_state()
    runtime_state.phase = nil
    runtime_state.code = nil
    runtime_state.phrase = ""
end

local function init(env)
    env.add_phrase_commit_notifier = env.engine.context.commit_notifier:connect(function(ctx)
        if runtime_state.phase ~= "phrase" then
            return
        end

        local committed_text = tostring(ctx:get_commit_text() or "")
        if committed_text == "" then
            return
        end

        runtime_state.phrase = runtime_state.phrase .. committed_text
    end)
end

local function fini(env)
    if env.add_phrase_commit_notifier then
        env.add_phrase_commit_notifier:disconnect()
        env.add_phrase_commit_notifier = nil
    end
end

local function processor(key, env)
    if key:release() then
        return 2
    end

    local engine = env.engine
    local context = engine.context
    local input = context.input or ""
    local key_repr = key:repr()
    local composition = context.composition
    local has_composition = composition and not composition:empty()

    if key_repr == "Escape" and runtime_state.phase then
        clear_runtime_state()
        context:clear()
        return 1
    end

    if runtime_state.phase == "phrase" then
        if key_repr == "Return" or key_repr == "KP_Enter" then
            if input == "" and not has_composition then
                local phrase = runtime_state.phrase
                local code = runtime_state.code
                clear_runtime_state()

                if phrase == "" or not code then
                    return 1
                end

                if utf8_length(phrase) > 100 then
                    return 1
                end

                custom_word_module.add_custom_entry(phrase, code)
                return 1
            end
        end
        return 2
    end

    if is_reserved_command(input) then
        return 2
    end

    if key_repr == "Return" or key_repr == "KP_Enter" then
        if is_code_mode_input(input) then
            runtime_state.phase = "phrase"
            runtime_state.code = input:sub(3)
            runtime_state.phrase = ""
            context:clear()
            return 1
        end
    end

    if input == ",," and key_repr == "space" then
        return 1
    end

    return 2
end

return {
    init = init,
    func = processor,
    fini = fini,
}
