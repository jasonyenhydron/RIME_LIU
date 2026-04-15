-- liu_translation_translator.lua
-- 英翻中查詢模式（,,tr）：使用本地 TSV 詞典提供輕量英文翻譯候選。
-- 設計目標：
-- 1. 不干擾平常英文或嘸蝦米主輸入流程
-- 2. 先做本地常用詞典查詢，不依賴網路服務
-- 3. 之後只要擴充 english_zh.tsv 就能增加翻譯詞彙

local M = {}

local cache = {
    loaded = false,
    exact = {},
}

local function trim(text)
    if not text then
        return ""
    end
    return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function normalize_key(text)
    local normalized = trim((text or ""):lower())
    normalized = normalized:gsub("%s+", " ")
    return normalized
end

local function split_translations(text)
    local items = {}
    for part in tostring(text):gmatch("[^|]+") do
        local value = trim(part)
        if value ~= "" then
            items[#items + 1] = value
        end
    end
    return items
end

local function build_dict_paths()
    return {
        rime_api.get_user_data_dir() .. "/english_zh.tsv",
        rime_api.get_shared_data_dir() .. "/english_zh.tsv",
    }
end

local function load_dictionary()
    cache.loaded = true
    cache.exact = {}

    for _, path in ipairs(build_dict_paths()) do
        local fh = io.open(path, "r")
        if fh then
            for line in fh:lines() do
                if line ~= "" and not line:match("^#") then
                    local source, target = line:match("^([^\t]+)\t(.+)$")
                    if source and target then
                        local key = normalize_key(source)
                        if key ~= "" then
                            cache.exact[key] = split_translations(target)
                        end
                    end
                end
            end
            fh:close()
            if next(cache.exact) then
                return
            end
        end
    end
end

local function ensure_loaded()
    if not cache.loaded then
        load_dictionary()
    end
end

function M.translator(input, seg, env)
    if not seg:has_tag("translation_mode") then
        return
    end

    ensure_loaded()

    local query = normalize_key(input)
    if query == "" then
        local hint = Candidate("translation_hint", seg.start, seg._end, "請輸入英文", "")
        hint.preedit = "《英翻中》"
        yield(hint)
        return
    end

    local exact_hits = cache.exact[query]
    local yielded = 0

    if exact_hits then
        for _, translated in ipairs(exact_hits) do
            local cand = Candidate("translation", seg.start, seg._end, translated, "〔英翻中〕")
            cand.preedit = "《英翻中》" .. query
            yield(cand)
            yielded = yielded + 1
        end
    end

    if yielded > 0 then
        return
    end

    local prefix_hits = {}
    for source, translations in pairs(cache.exact) do
        if source:find(query, 1, true) == 1 then
            prefix_hits[#prefix_hits + 1] = {
                source = source,
                translations = translations,
            }
        end
    end

    table.sort(prefix_hits, function(a, b)
        if #a.source == #b.source then
            return a.source < b.source
        end
        return #a.source < #b.source
    end)

    for index = 1, math.min(#prefix_hits, 8) do
        local item = prefix_hits[index]
        for _, translated in ipairs(item.translations) do
            local cand = Candidate("translation", seg.start, seg._end, translated, "〔" .. item.source .. "〕")
            cand.preedit = "《英翻中》" .. query
            yield(cand)
        end
    end

    if #prefix_hits == 0 then
        local hint = Candidate("translation_hint", seg.start, seg._end, "查無翻譯", "")
        hint.preedit = "《英翻中》" .. query
        yield(hint)
    end
end

return M
