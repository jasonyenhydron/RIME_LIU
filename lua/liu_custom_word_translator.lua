-- liu_custom_word_translator.lua
-- 自定詞翻譯器：讀取 openxiami_CustomWord.dict.yaml 並產生候選。
-- 另外提供 add_custom_entry()，讓 ,, 加詞流程可直接寫入加詞檔且立即生效。

local M = {}

local trie = nil
local exact_matches = nil

local MIN_COMPLETION_LEN = 99
local MAX_COMPLETION_RESULTS = 10
local DIGIT_TRANSLATION = {
    ["0"] = "v",
    ["1"] = "e",
    ["2"] = "r",
    ["3"] = "s",
    ["4"] = "f",
    ["5"] = "w",
    ["6"] = "l",
    ["7"] = "c",
    ["8"] = "b",
    ["9"] = "k",
}

local CUSTOM_WORD_HEADER = [[# Rime schema 中州輸入法的字碼檔
# encoding: utf-8
#
# 自定詞字典（由 lua_translator@liu_custom_word_translator 載入）
# 格式：詞條<Tab>編碼
#
---
name: openxiami_CustomWord
version: "1"
sort: original
...
# 人工編碼詞，適合超長句子，或包含數字的詞
# 自定詞會排在完整匹配漢字後面、補字候選前面
#
# 下方內容由輸入法內建加詞工具維護
]]

local function new_node()
    return { children = {}, words = nil }
end

local function trie_insert(root, code, word)
    local node = root
    local code_lower = code:lower()

    for i = 1, #code_lower do
        local char = code_lower:sub(i, i)
        if not node.children[char] then
            node.children[char] = new_node()
        end
        node = node.children[char]
    end

    if not node.words then
        node.words = {}
    end

    for _, item in ipairs(node.words) do
        if item.text == word and item.code == code_lower then
            return
        end
    end

    node.words[#node.words + 1] = { text = word, code = code_lower }
end

local function trie_find_node(root, prefix)
    local node = root
    local prefix_lower = prefix:lower()

    for i = 1, #prefix_lower do
        local char = prefix_lower:sub(i, i)
        if not node.children[char] then
            return nil
        end
        node = node.children[char]
    end

    return node
end

local function collect_words(node, results, max_count, input_len)
    if #results >= max_count then
        return
    end

    if node.words then
        for _, item in ipairs(node.words) do
            if #results >= max_count then
                return
            end
            if #item.code > input_len then
                results[#results + 1] = item
            end
        end
    end

    for _, child in pairs(node.children) do
        if #results >= max_count then
            return
        end
        collect_words(child, results, max_count, input_len)
    end
end

local function normalize_spaces(text)
    local normalized = tostring(text or "")
    normalized = normalized:gsub("\r", " "):gsub("\n", " "):gsub("\t", " ")
    normalized = normalized:gsub("%s+", " ")
    return normalized:gsub("^%s+", ""):gsub("%s+$", "")
end

local function normalize_code(code)
    local normalized = tostring(code or ""):lower()
    normalized = normalized:gsub("\r", ""):gsub("\n", ""):gsub("\t", "")
    normalized = normalized:gsub("%s+", "")
    normalized = normalized:gsub("%d", DIGIT_TRANSLATION)
    return normalized
end

local function resolve_paths()
    local user_dir = rime_api and rime_api.get_user_data_dir and rime_api.get_user_data_dir() or ""
    local shared_dir = rime_api and rime_api.get_shared_data_dir and rime_api.get_shared_data_dir() or ""

    return {
        user_path = user_dir ~= "" and (user_dir .. "/openxiami_CustomWord.dict.yaml") or "",
        shared_path = shared_dir ~= "" and (shared_dir .. "/openxiami_CustomWord.dict.yaml") or "",
    }
end

local function ensure_cache()
    if trie and exact_matches then
        return trie, exact_matches
    end

    trie = new_node()
    exact_matches = {}

    local paths = resolve_paths()
    local candidates = {}
    if paths.user_path ~= "" then
        candidates[#candidates + 1] = paths.user_path
    end
    if paths.shared_path ~= "" then
        candidates[#candidates + 1] = paths.shared_path
    end

    for _, path in ipairs(candidates) do
        local file = io.open(path, "r")
        if file then
            local in_data = false
            for line in file:lines() do
                line = line:gsub("\r$", "")
                if line == "..." then
                    in_data = true
                elseif in_data and #line > 0 and line:byte(1) ~= 35 then
                    local word, code = line:match("^([^\t]+)\t([^\t]+)")
                    if word and code then
                        local normalized_word = normalize_spaces(word)
                        local normalized_code = normalize_code(code)
                        if normalized_word ~= "" and normalized_code ~= "" then
                            trie_insert(trie, normalized_code, normalized_word)
                            local list = exact_matches[normalized_code]
                            if not list then
                                list = {}
                                exact_matches[normalized_code] = list
                            end
                            local exists = false
                            for _, item in ipairs(list) do
                                if item == normalized_word then
                                    exists = true
                                    break
                                end
                            end
                            if not exists then
                                list[#list + 1] = normalized_word
                            end
                        end
                    end
                end
            end
            file:close()
            break
        end
    end

    return trie, exact_matches
end

local function ensure_user_dictionary_file(path)
    local file = io.open(path, "r")
    if file then
        file:close()
        return
    end

    local writer = io.open(path, "w")
    if writer then
        writer:write(CUSTOM_WORD_HEADER)
        writer:close()
    end
end

local function has_exact_entry(word, code)
    local _, matches = ensure_cache()
    local list = matches[code]
    if not list then
        return false
    end

    for _, item in ipairs(list) do
        if item == word then
            return true
        end
    end
    return false
end

local function append_entry_to_cache(word, code)
    local root, matches = ensure_cache()
    trie_insert(root, code, word)

    local list = matches[code]
    if not list then
        list = {}
        matches[code] = list
    end

    for _, item in ipairs(list) do
        if item == word then
            return
        end
    end

    list[#list + 1] = word
end

local function get_next_char_hint(full_code, input_len)
    if #full_code > input_len then
        return "▸⟨" .. full_code:sub(input_len + 1, input_len + 1) .. "⟩"
    end
    return ""
end

function M.add_custom_entry(word, code)
    local normalized_word = normalize_spaces(word)
    local normalized_code = normalize_code(code)

    if normalized_word == "" or normalized_code == "" then
        return false, "詞句或字根不可為空。"
    end

    local paths = resolve_paths()
    if paths.user_path == "" then
        return false, "找不到使用者資料夾，無法寫入加詞檔。"
    end

    ensure_user_dictionary_file(paths.user_path)

    if has_exact_entry(normalized_word, normalized_code) then
        return true, "已存在相同詞碼。", normalized_word, normalized_code
    end

    local file = io.open(paths.user_path, "a")
    if not file then
        return false, "無法開啟加詞檔寫入。"
    end

    file:write(normalized_word, "\t", normalized_code, "\n")
    file:close()

    append_entry_to_cache(normalized_word, normalized_code)
    return true, "已加入自定詞。", normalized_word, normalized_code
end

function M.translator(input, seg, env)
    if not seg:has_tag("abc") and not seg:has_tag("mkst") then
        return
    end

    local root, matches = ensure_cache()
    local input_lower = input:lower()
    local input_len = #input_lower
    local start_pos, end_pos = seg.start, seg._end

    local exact_list = matches[input_lower]
    if exact_list then
        for i = 1, #exact_list do
            local cand = Candidate("custom", start_pos, end_pos, exact_list[i], "")
            cand.quality = 999
            yield(cand)
        end
    end

    if input_len >= MIN_COMPLETION_LEN then
        local node = trie_find_node(root, input_lower)
        if node then
            local completions = {}
            collect_words(node, completions, MAX_COMPLETION_RESULTS, input_len)
            for _, item in ipairs(completions) do
                local hint = get_next_char_hint(item.code, input_len)
                local cand = Candidate("custom_completion", start_pos, end_pos, item.text, hint)
                cand.quality = 500
                yield(cand)
            end
        end
    end
end

return M
