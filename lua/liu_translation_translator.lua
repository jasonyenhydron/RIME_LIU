-- liu_translation_translator.lua
-- Local English to Chinese lookup for ",,tr".
-- Keep labels ASCII to avoid editor/runtime encoding issues.

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
                    local source, target = line:match("^([^	]+)	(.+)$")
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
        local hint = Candidate("translation_hint", seg.start, seg._end, "type english", "")
        hint.preedit = "[TR]"
        yield(hint)
        return
    end

    local exact_hits = cache.exact[query]
    local yielded = 0

    if exact_hits then
        for _, translated in ipairs(exact_hits) do
            local cand = Candidate("translation", seg.start, seg._end, translated, "[TR]")
            cand.preedit = "[TR] " .. query
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
            local cand = Candidate("translation", seg.start, seg._end, translated, "[" .. item.source .. "]")
            cand.preedit = "[TR] " .. query
            yield(cand)
        end
    end

    if #prefix_hits == 0 then
        local hint = Candidate("translation_hint", seg.start, seg._end, "no translation", "")
        hint.preedit = "[TR] " .. query
        yield(hint)
    end
end

return M
