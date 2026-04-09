-- liu_keypad_selector.lua
-- 修正數字小鍵盤在候選視窗開啟時無法直接選字的問題。
-- 當浮動視窗存在且按下 KP_1 ~ KP_9 時，
-- 直接使用 Rime context 選取對應候選，避免按鍵被當成一般數字輸入。

local liu_common = require("liu_common")
local get_digit = liu_common.get_digit
local select_by_digit = liu_common.select_by_digit

local function processor(key, env)
    if key:release() then
        return 2
    end

    local context = env.engine.context
    if not context:has_menu() then
        return 2
    end

    if key:ctrl() or key:alt() then
        return 2
    end

    local key_repr = key:repr()
    local digit = get_digit(key_repr)
    if not digit or digit == "0" then
        return 2
    end

    if key_repr:match("^KP_[1-9]$") then
        return select_by_digit(env, tonumber(digit))
    end

    return 2
end

return processor
